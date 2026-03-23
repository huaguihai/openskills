#!/usr/bin/env python3
"""
Claude Code 授权自学习 — 分析引擎
用户手动运行: python3 ~/.claude/auto-approve/analyze.py

4 步流程:
  1. 聚合: 读 approval-log.jsonl，按 (tool, input) 分组统计
  2. 泛化: 相同前缀的命令合并为通配模式
  3. 安全过滤: 候选 vs deny-patterns.json
  4. 阈值检查 + 交互确认 → 写入 learned-rules.json
"""

import json
import os
import re
import sys
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

BASE_DIR = Path.home() / ".claude" / "auto-approve"
DATA_DIR = BASE_DIR / "data"
LOG_FILE = DATA_DIR / "approval-log.jsonl"
RULES_FILE = DATA_DIR / "learned-rules.json"
DENY_FILE = BASE_DIR / "deny-patterns.json"

# 阈值
MIN_COUNT = 3   # 最少出现次数
MIN_DAYS = 2    # 最少跨天数


def load_log():
    """读取审计日志，返回记录列表"""
    if not LOG_FILE.exists():
        return []
    records = []
    with open(LOG_FILE) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                rec = json.loads(line)
                # 跳过自动放行的记录
                if rec.get("auto"):
                    continue
                records.append(rec)
            except json.JSONDecodeError:
                continue
    return records


def load_deny_patterns():
    """加载危险模式黑名单"""
    if not DENY_FILE.exists():
        return []
    with open(DENY_FILE) as f:
        data = json.load(f)
    return data.get("patterns", [])


def load_existing_rules():
    """加载已有规则，避免重复推荐"""
    if not RULES_FILE.exists():
        return []
    with open(RULES_FILE) as f:
        data = json.load(f)
    return [r["pattern"] for r in data.get("rules", [])]


# ── Step 1: 聚合 ──

def aggregate(records):
    """按 (tool, input) 分组，统计次数和跨天数"""
    groups = defaultdict(lambda: {"count": 0, "days": set()})
    for rec in records:
        tool = rec.get("tool", "")
        inp = rec.get("input", "")
        if not tool or not inp:
            continue
        key = (tool, inp)
        groups[key]["count"] += 1
        ts = rec.get("ts", "")
        if ts:
            day = ts[:10]  # YYYY-MM-DD
            groups[key]["days"].add(day)
    return groups


# ── Step 2: 泛化 ──

def tokenize_command(cmd):
    """将命令拆分为 token 列表"""
    return cmd.split()


def common_prefix_tokens(tokens_list):
    """求多组 token 的公共前缀"""
    if not tokens_list:
        return []
    prefix = list(tokens_list[0])
    for tokens in tokens_list[1:]:
        new_prefix = []
        for a, b in zip(prefix, tokens):
            if a == b:
                new_prefix.append(a)
            else:
                break
        prefix = new_prefix
    return prefix


def generalize_bash(entries):
    """
    Bash 命令泛化:
    - 按命令前缀分组（取前 N 个公共 token），尾部不同则用 *
    - 前缀至少保留 2 个 token
    """
    # entries: list of (input_str, count, days_set)
    # 按第一个 token 分组
    by_first = defaultdict(list)
    for inp, count, days in entries:
        tokens = tokenize_command(inp)
        if not tokens:
            continue
        first = tokens[0]
        by_first[first].append((tokens, inp, count, days))

    results = []
    for first, group in by_first.items():
        if len(group) == 1:
            # 只有一条命令，直接使用原文
            tokens, inp, count, days = group[0]
            pattern = f"Bash({inp})"
            regex = "^" + re.escape(inp) + "$"
            results.append({
                "pattern": pattern,
                "tool": "Bash",
                "regex": regex,
                "count": count,
                "days": days,
            })
        else:
            # 多条命令，求公共前缀
            all_tokens = [g[0] for g in group]
            prefix = common_prefix_tokens(all_tokens)

            # 前缀至少 2 个 token
            if len(prefix) < 2:
                # 前缀不够长，逐条保留
                for tokens, inp, count, days in group:
                    pattern = f"Bash({inp})"
                    regex = "^" + re.escape(inp) + "$"
                    results.append({
                        "pattern": pattern,
                        "tool": "Bash",
                        "regex": regex,
                        "count": count,
                        "days": days,
                    })
            else:
                # 合并: 前缀 + *
                total_count = sum(g[2] for g in group)
                all_days = set()
                for g in group:
                    all_days.update(g[3])
                prefix_str = " ".join(prefix)
                # 检查是否所有命令都完全匹配前缀（即没有尾部差异）
                all_same = all(len(g[0]) == len(prefix) for g in group)
                if all_same:
                    pattern = f"Bash({prefix_str})"
                    regex = "^" + re.escape(prefix_str) + "$"
                else:
                    pattern = f"Bash({prefix_str} *)"
                    regex = "^" + re.escape(prefix_str) + " .*$"
                results.append({
                    "pattern": pattern,
                    "tool": "Bash",
                    "regex": regex,
                    "count": total_count,
                    "days": all_days,
                })

    return results


def generalize_path(tool, entries):
    """
    路径类工具泛化 (Edit/Write/Read):
    - 按公共目录前缀归纳
    - 前缀至少保留 1 级目录
    """
    if len(entries) == 1:
        inp, count, days = entries[0]
        pattern = f"{tool}({inp})"
        regex = "^" + re.escape(inp) + "$"
        return [{
            "pattern": pattern,
            "tool": tool,
            "regex": regex,
            "count": count,
            "days": days,
        }]

    # 求公共路径前缀
    paths = [e[0] for e in entries]
    common = os.path.commonpath(paths) if paths else ""

    if not common or common == ".":
        # 无公共前缀，逐条保留
        results = []
        for inp, count, days in entries:
            pattern = f"{tool}({inp})"
            regex = "^" + re.escape(inp) + "$"
            results.append({
                "pattern": pattern,
                "tool": tool,
                "regex": regex,
                "count": count,
                "days": days,
            })
        return results

    # 合并
    total_count = sum(e[1] for e in entries)
    all_days = set()
    for e in entries:
        all_days.update(e[2])

    # 如果 common 是目录（不含文件名），用 **
    if os.path.isdir(common) or not os.path.splitext(common)[1]:
        pattern = f"{tool}({common}/**)"
        regex = "^" + re.escape(common) + "/.*$"
    else:
        pattern = f"{tool}({common})"
        regex = "^" + re.escape(common) + "$"

    return [{
        "pattern": pattern,
        "tool": tool,
        "regex": regex,
        "count": total_count,
        "days": all_days,
    }]


def generalize(groups):
    """对聚合结果进行泛化"""
    # 按 tool 分组
    by_tool = defaultdict(list)
    for (tool, inp), stats in groups.items():
        by_tool[tool].append((inp, stats["count"], stats["days"]))

    candidates = []

    for tool, entries in by_tool.items():
        if tool == "Bash":
            candidates.extend(generalize_bash(entries))
        elif tool in ("Edit", "Write", "Read"):
            candidates.extend(generalize_path(tool, entries))
        elif tool in ("Glob", "Grep"):
            # 搜索类工具直接逐条保留
            for inp, count, days in entries:
                pattern = f"{tool}({inp})"
                regex = "^" + re.escape(inp) + "$"
                candidates.append({
                    "pattern": pattern,
                    "tool": tool,
                    "regex": regex,
                    "count": count,
                    "days": days,
                })

    return candidates


# ── Step 3: 安全过滤 ──

def is_denied(candidate, deny_patterns):
    """检查候选模式是否匹配危险模式"""
    # 从 pattern 中提取原始内容
    raw = candidate["regex"]
    for dp in deny_patterns:
        flags = re.IGNORECASE if dp.get("case_insensitive") else 0
        try:
            if re.search(dp["regex"], raw, flags):
                return True, dp.get("desc", "匹配危险模式")
        except re.error:
            continue

    # 也检查 pattern 文本
    pattern_text = candidate["pattern"]
    # 提取括号内的内容
    m = re.match(r'\w+\((.+)\)', pattern_text)
    if m:
        content = m.group(1)
        for dp in deny_patterns:
            flags = re.IGNORECASE if dp.get("case_insensitive") else 0
            try:
                if re.search(dp["regex"], content, flags):
                    return True, dp.get("desc", "匹配危险模式")
            except re.error:
                continue

    return False, ""


def filter_candidates(candidates, deny_patterns, existing_rules):
    """过滤掉危险模式和已有规则"""
    safe = []
    for c in candidates:
        # 跳过已有规则
        if c["pattern"] in existing_rules:
            continue

        denied, reason = is_denied(c, deny_patterns)
        if denied:
            continue

        # 阈值检查
        if c["count"] < MIN_COUNT:
            continue
        day_count = len(c["days"]) if isinstance(c["days"], set) else c["days"]
        if day_count < MIN_DAYS:
            continue

        safe.append(c)

    return safe


# ── Step 4: 交互确认 ──

def interactive_confirm(candidates):
    """展示候选规则，用户逐条确认"""
    if not candidates:
        print("\n没有发现新的候选自动授权规则。")
        print(f"  (日志记录数可通过 wc -l {LOG_FILE} 查看)")
        print(f"  (阈值: 次数 >= {MIN_COUNT}, 跨天 >= {MIN_DAYS})")
        return []

    print(f"\n发现 {len(candidates)} 条可自动授权的候选规则:\n")

    confirmed = []
    for i, c in enumerate(candidates, 1):
        day_count = len(c["days"]) if isinstance(c["days"], set) else c["days"]
        prompt = f"  [{i}] {c['pattern']:40s} -- {c['count']:3d} 次 / {day_count} 天  [Y/n] "
        try:
            answer = input(prompt).strip().lower()
        except (EOFError, KeyboardInterrupt):
            print("\n已取消。")
            return confirmed

        if answer in ("", "y", "yes"):
            confirmed.append(c)

    return confirmed


def save_rules(confirmed):
    """将确认的规则写入 learned-rules.json"""
    # 加载已有规则
    existing = {"version": 1, "updated": "", "rules": []}
    if RULES_FILE.exists():
        with open(RULES_FILE) as f:
            existing = json.load(f)

    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    existing["updated"] = now

    for c in confirmed:
        day_count = len(c["days"]) if isinstance(c["days"], set) else c["days"]
        rule = {
            "pattern": c["pattern"],
            "tool": c["tool"],
            "regex": c["regex"],
            "added": today,
            "evidence": {
                "count": c["count"],
                "days": day_count,
            }
        }
        existing["rules"].append(rule)

    DATA_DIR.mkdir(parents=True, exist_ok=True)
    with open(RULES_FILE, "w") as f:
        json.dump(existing, f, indent=2, ensure_ascii=False)
        f.write("\n")

    print(f"\n已写入 {len(confirmed)} 条规则到 {RULES_FILE}")


def show_current_rules():
    """显示当前已有规则"""
    if not RULES_FILE.exists():
        return
    with open(RULES_FILE) as f:
        data = json.load(f)
    rules = data.get("rules", [])
    if rules:
        print(f"\n当前已有 {len(rules)} 条自动授权规则:")
        for r in rules:
            ev = r.get("evidence", {})
            print(f"  - {r['pattern']:40s} (added {r['added']}, {ev.get('count', '?')} 次 / {ev.get('days', '?')} 天)")


def main():
    print("=" * 60)
    print("  Claude Code 授权自学习 — 分析引擎")
    print("=" * 60)

    # 显示当前规则
    show_current_rules()

    # Step 1: 加载日志
    records = load_log()
    if not records:
        print(f"\n审计日志为空或不存在: {LOG_FILE}")
        print("请先使用 Claude Code 一段时间以积累数据。")
        return

    print(f"\n共加载 {len(records)} 条审计记录")

    # Step 1: 聚合
    groups = aggregate(records)
    print(f"聚合为 {len(groups)} 组不同的工具调用")

    # Step 2: 泛化
    candidates = generalize(groups)
    print(f"泛化后得到 {len(candidates)} 个候选模式")

    # Step 3: 安全过滤
    deny_patterns = load_deny_patterns()
    existing_rules = load_existing_rules()
    safe_candidates = filter_candidates(candidates, deny_patterns, existing_rules)
    filtered_count = len(candidates) - len(safe_candidates)
    if filtered_count > 0:
        print(f"过滤掉 {filtered_count} 个 (危险/已有/未达阈值)")

    # Step 4: 交互确认
    confirmed = interactive_confirm(safe_candidates)
    if confirmed:
        save_rules(confirmed)
    elif safe_candidates:
        print("\n未确认任何规则。")

    print("\n完成。")


if __name__ == "__main__":
    main()
