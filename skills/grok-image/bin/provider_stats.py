#!/usr/bin/env python3
"""Provider reliability scoring for grok-image skill.

Tracks success/failure per provider and ranks them so reliable ones
get tried first. Uses Laplace-smoothed success rate with periodic
decay so recent performance matters more than ancient history.

Stats file: ~/.claude/skills/grok-image/data/provider_stats.json

Usage:
    python3 provider_stats.py rank <providers_file>    # Sort by score, overwrite file
    python3 provider_stats.py record <name> success    # Record a success
    python3 provider_stats.py record <name> fail       # Record a failure
    python3 provider_stats.py show                     # Print current scores
"""

import json, os, sys, time

STATS_DIR = os.path.expanduser("~/.claude/skills/grok-image/data")
STATS_FILE = os.path.join(STATS_DIR, "provider_stats.json")
DECAY_INTERVAL = 86400 * 3  # Apply decay every 3 days
DECAY_FACTOR = 0.7          # Multiply counters by this on decay


def load_stats():
    if os.path.exists(STATS_FILE):
        with open(STATS_FILE) as f:
            return json.load(f)
    return {"providers": {}, "last_decay": time.time()}


def save_stats(stats):
    os.makedirs(STATS_DIR, exist_ok=True)
    with open(STATS_FILE, "w") as f:
        json.dump(stats, f, indent=2)


def apply_decay(stats):
    """Decay old data so recent performance weighs more.
    Every DECAY_INTERVAL seconds, multiply all counters by DECAY_FACTOR.
    This means a provider that was great last week but terrible today
    will quickly drop in ranking."""
    now = time.time()
    elapsed = now - stats.get("last_decay", now)
    if elapsed < DECAY_INTERVAL:
        return stats

    # How many decay periods have passed
    periods = int(elapsed / DECAY_INTERVAL)
    factor = DECAY_FACTOR ** periods

    for name, data in stats.get("providers", {}).items():
        data["s"] = round(data.get("s", 0) * factor, 2)
        data["f"] = round(data.get("f", 0) * factor, 2)

    stats["last_decay"] = now
    return stats


def score(data):
    """Laplace-smoothed success rate.
    New providers with no history get 0.5 (neutral).
    A provider with 10 successes and 0 failures gets ~0.92.
    A provider with 0 successes and 10 failures gets ~0.08."""
    s = data.get("s", 0)
    f = data.get("f", 0)
    return (s + 1) / (s + f + 2)


def strip_fallback_tag(name):
    """Remove '(fallback)' suffix for consistent stats tracking."""
    return name.replace("(fallback)", "").strip()


def cmd_rank(providers_file):
    """Read providers file, sort by score (best first), overwrite."""
    stats = apply_decay(load_stats())
    save_stats(stats)

    providers_data = stats.get("providers", {})

    with open(providers_file) as f:
        lines = [l.strip() for l in f if l.strip()]

    def sort_key(line):
        name = line.split("|")[0]
        clean_name = strip_fallback_tag(name)
        data = providers_data.get(clean_name, {})
        # Primary providers (no "(fallback)") get a bonus
        is_primary = "(fallback)" not in name
        return (is_primary, score(data))

    lines.sort(key=sort_key, reverse=True)

    with open(providers_file, "w") as f:
        for line in lines:
            f.write(line + "\n")

    # Print ranking to stderr for visibility
    for line in lines:
        name = strip_fallback_tag(line.split("|")[0])
        data = providers_data.get(name, {})
        s = data.get("s", 0)
        f_count = data.get("f", 0)
        sc = score(data)
        tag = " (new)" if s == 0 and f_count == 0 else ""
        print(f"  {sc:.2f} {line.split('|')[0]}{tag} [{s:.0f}W/{f_count:.0f}L]", file=sys.stderr)


def cmd_record(name, result):
    """Record a success or failure for a provider."""
    clean_name = strip_fallback_tag(name)
    stats = load_stats()

    if clean_name not in stats["providers"]:
        stats["providers"][clean_name] = {"s": 0, "f": 0}

    if result == "success":
        stats["providers"][clean_name]["s"] += 1
        stats["providers"][clean_name]["last_success"] = time.time()
    else:
        stats["providers"][clean_name]["f"] += 1
        stats["providers"][clean_name]["last_failure"] = time.time()

    save_stats(stats)


def cmd_show():
    """Print current provider scores."""
    stats = apply_decay(load_stats())
    providers = stats.get("providers", {})

    if not providers:
        print("No stats yet. Scores will build up as you use /grok-image.")
        return

    ranked = sorted(providers.items(), key=lambda x: score(x[1]), reverse=True)
    print(f"{'Provider':<45} {'Score':>5} {'W':>4} {'L':>4}")
    print("-" * 62)
    for name, data in ranked:
        sc = score(data)
        print(f"{name:<45} {sc:>5.2f} {data.get('s',0):>4.0f} {data.get('f',0):>4.0f}")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    cmd = sys.argv[1]
    if cmd == "rank" and len(sys.argv) >= 3:
        cmd_rank(sys.argv[2])
    elif cmd == "record" and len(sys.argv) >= 4:
        cmd_record(sys.argv[2], sys.argv[3])
    elif cmd == "show":
        cmd_show()
    else:
        print(__doc__)
        sys.exit(1)
