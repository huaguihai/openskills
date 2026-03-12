#!/usr/bin/env python3
"""
split_readme.py - 从 public-apis/public-apis 仓库下载 README 并按分类拆分。

用法:
    python3 split_readme.py                  # 从 GitHub 下载并拆分
    python3 split_readme.py --input FILE     # 使用本地文件
    python3 split_readme.py --dry-run        # 预览模式，不写入文件
"""

import argparse
import os
import re
import sys
import urllib.request
from datetime import date
from pathlib import Path

UPSTREAM_URL = (
    "https://raw.githubusercontent.com/public-apis/public-apis/master/README.md"
)
SCRIPT_DIR = Path(__file__).resolve().parent
SKILL_DIR = SCRIPT_DIR.parent
REFERENCES_DIR = SKILL_DIR / "references"
SKILL_MD = SKILL_DIR / "SKILL.md"


def slugify(name: str) -> str:
    """将分类名转为文件名 slug。"""
    s = name.strip().lower()
    s = s.replace("&", "-and-")
    s = re.sub(r"[^\w\s-]", "", s)
    s = re.sub(r"[\s]+", "-", s)
    s = re.sub(r"-+", "-", s)
    return s.strip("-")


def download_readme() -> str:
    """从 GitHub 下载 README。"""
    print(f"正在从 {UPSTREAM_URL} 下载...")
    req = urllib.request.Request(UPSTREAM_URL, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=30) as resp:
        content = resp.read().decode("utf-8")
    print(f"下载完成，共 {len(content)} 字节")
    return content


def parse_categories(readme: str) -> list[dict]:
    """
    解析 README，按 ### 标题拆分分类。
    返回 [{"name": "Animals", "slug": "animals", "content": "...", "api_count": N}, ...]
    """
    categories = []
    # 匹配 ### 开头的分类标题
    pattern = re.compile(r"^### (.+)$", re.MULTILINE)
    matches = list(pattern.finditer(readme))

    for i, match in enumerate(matches):
        name = match.group(1).strip()
        start = match.start()
        end = matches[i + 1].start() if i + 1 < len(matches) else len(readme)
        block = readme[start:end].strip()

        # 统计 API 数量：表头有两种格式
        # 格式1: "| API | Description | ..."（前导 |）
        # 格式2: "API | Description | ..."（无前导 |）
        # 分隔符: "|---|..." 或 "|:---|..."
        # 数据行: 以 "| [" 或 "| **[" 开头
        lines = block.split("\n")
        api_count = 0
        in_table = False
        for line in lines:
            stripped = line.strip()
            # 检测表头行（两种格式）
            if "API" in stripped and "Description" in stripped and "|" in stripped:
                in_table = True
                continue
            # 跳过分隔符行
            if in_table and re.match(r"^\|[-:\s|]+$", stripped):
                continue
            # 数据行：以 | 开头，包含链接或文字内容
            if in_table and stripped.startswith("|") and stripped.count("|") >= 3:
                # 排除空行和尾部装饰
                if len(stripped) > 10:
                    api_count += 1
            elif in_table and stripped and not stripped.startswith("|"):
                in_table = False

        # 清理上游残留内容（Back to Index 链接、br 标签、License 等）
        cleaned_lines = []
        for line in lines:
            stripped = line.strip()
            if stripped.startswith("**[⬆"):
                break
            cleaned_lines.append(line)
        clean_block = "\n".join(cleaned_lines).rstrip()

        slug = slugify(name)
        categories.append(
            {
                "name": name,
                "slug": slug,
                "content": clean_block,
                "api_count": api_count,
            }
        )

    return categories


def write_references(categories: list[dict], dry_run: bool) -> None:
    """将每个分类写入 references/{slug}.md。"""
    if not dry_run:
        REFERENCES_DIR.mkdir(parents=True, exist_ok=True)

    existing_files = set(REFERENCES_DIR.glob("*.md")) if REFERENCES_DIR.exists() else set()
    new_files = set()

    for cat in categories:
        filepath = REFERENCES_DIR / f"{cat['slug']}.md"
        new_files.add(filepath)
        if dry_run:
            print(f"  [预览] {filepath.name} — {cat['name']} ({cat['api_count']} APIs)")
        else:
            filepath.write_text(cat["content"], encoding="utf-8")
            print(f"  [写入] {filepath.name} — {cat['name']} ({cat['api_count']} APIs)")

    # 清理过时文件
    stale = existing_files - new_files
    for f in stale:
        if dry_run:
            print(f"  [预览删除] {f.name}")
        else:
            f.unlink()
            print(f"  [已删除] {f.name}")


def update_skill_md(categories: list[dict], dry_run: bool) -> None:
    """更新 SKILL.md 中的分类索引表和统计信息。"""
    if not SKILL_MD.exists():
        print("  SKILL.md 不存在，跳过索引更新。请先创建 SKILL.md。")
        return

    content = SKILL_MD.read_text(encoding="utf-8")
    today = date.today().isoformat()
    total_apis = sum(c["api_count"] for c in categories)

    # 更新同步日期占位符
    content = re.sub(
        r"(同步日期：)\S+",
        rf"\g<1>{today}",
        content,
    )
    # 更新 API 总数占位符
    content = re.sub(
        r"(收录了 )\d+([ +]*个免费 API)",
        rf"\g<1>{total_apis}\g<2>",
        content,
    )

    # 更新分类索引表
    table_start_marker = "<!-- CATEGORY_TABLE_START -->"
    table_end_marker = "<!-- CATEGORY_TABLE_END -->"

    if table_start_marker in content and table_end_marker in content:
        table_lines = ["| 分类 | API 数量 | Reference 文件 |", "| --- | --- | --- |"]
        for cat in sorted(categories, key=lambda c: c["name"]):
            table_lines.append(
                f"| {cat['name']} | {cat['api_count']} | `references/{cat['slug']}.md` |"
            )
        new_table = "\n".join(table_lines)

        pattern = re.compile(
            re.escape(table_start_marker) + r".*?" + re.escape(table_end_marker),
            re.DOTALL,
        )
        content = pattern.sub(
            f"{table_start_marker}\n{new_table}\n{table_end_marker}",
            content,
        )

    if dry_run:
        print(f"  [预览] SKILL.md 更新: {len(categories)} 个分类, {total_apis} 个 API, 日期 {today}")
    else:
        SKILL_MD.write_text(content, encoding="utf-8")
        print(f"  [更新] SKILL.md: {len(categories)} 个分类, {total_apis} 个 API, 日期 {today}")


def main():
    parser = argparse.ArgumentParser(description="拆分 public-apis README 为分类 reference 文件")
    parser.add_argument("--input", type=str, help="使用本地 README 文件而非从 GitHub 下载")
    parser.add_argument("--dry-run", action="store_true", help="预览模式，不实际写入文件")
    args = parser.parse_args()

    if args.input:
        print(f"正在读取本地文件: {args.input}")
        readme = Path(args.input).read_text(encoding="utf-8")
    else:
        readme = download_readme()

    print("\n正在解析分类...")
    categories = parse_categories(readme)
    print(f"共发现 {len(categories)} 个分类\n")

    if not categories:
        print("错误：未发现任何分类，请检查 README 格式。", file=sys.stderr)
        sys.exit(1)

    total = sum(c["api_count"] for c in categories)
    print(f"API 总数: {total}\n")

    print("正在写入 reference 文件...")
    write_references(categories, args.dry_run)

    print("\n正在更新 SKILL.md...")
    update_skill_md(categories, args.dry_run)

    print("\n完成！")


if __name__ == "__main__":
    main()
