#!/usr/bin/env python3
"""Summarize per-run outcome probabilities by betting strategy.

Reads the simulator's results CSV (data-out/simulation_results.csv by default)
and prints a Markdown table with one column per betting strategy found in the
file. Each run (row) ends in exactly one of three ways:

  - reached the quit target (final bankroll >= --target)
  - went broke (final bankroll < --minimum, so no further bet was possible)
  - played every hand with money left

Usage:
  python3 scripts/analyze_results.py [CSV] [--target 2000] [--minimum 10]

--target and --minimum default to the simulator's defaults; pass the values you
used for --quit_threshold and --minimum if you changed them.
"""

import argparse
import csv
import math
import statistics
import sys
from math import comb

Z_95 = 1.96


def wilson_interval(successes, n, z=Z_95):
    """95% confidence interval for a proportion (Wilson score interval)."""
    if n == 0:
        return 0.0, 0.0
    p = successes / n
    denom = 1 + z * z / n
    center = (p + z * z / (2 * n)) / denom
    half = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / denom
    return max(0.0, center - half), min(1.0, center + half)


def fisher_exact_two_sided(a, n1, b, n2):
    """Two-sided Fisher's exact test p-value for a/n1 vs b/n2."""
    total = a + b
    population = n1 + n2

    def prob(x):
        return comb(n1, x) * comb(n2, total - x) / comb(population, total)

    observed = prob(a)
    low, high = max(0, total - n2), min(total, n1)
    return min(1.0, sum(prob(x) for x in range(low, high + 1) if prob(x) <= observed * (1 + 1e-9)))


def runs_needed(p, margin=0.02, z=Z_95):
    """Runs needed to estimate a proportion p within +/- margin at 95% confidence."""
    return math.ceil(z * z * p * (1 - p) / (margin * margin))


def pct(x):
    return f"{x:.0%}"


def money(x):
    return f"−${abs(x):,.0f}" if x < 0 else f"${x:,.0f}"


def summarize(rows, target, minimum):
    n = len(rows)
    final = [float(r["final_bankroll"]) for r in rows]
    net = [float(r["net_winnings"]) for r in rows]
    hands = [int(r["total_hands"]) for r in rows]

    reached = sum(f >= target for f in final)
    broke = sum(f < minimum for f in final)
    return {
        "n": n,
        "reached": reached,
        "broke": broke,
        "survived": n - reached - broke,
        "profit": sum(x > 0 for x in net),
        "mean_net": statistics.mean(net),
        "median_hands": statistics.median(hands),
        "max_bet": max(float(r["max_bet"]) for r in rows),
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("csv", nargs="?", default="data-out/simulation_results.csv",
                        help="results CSV (default: data-out/simulation_results.csv)")
    parser.add_argument("--target", type=float, default=2000.0,
                        help="quit threshold used in the runs (default: 2000)")
    parser.add_argument("--minimum", type=float, default=10.0,
                        help="table minimum used in the runs (default: 10)")
    args = parser.parse_args()

    try:
        with open(args.csv, newline="") as f:
            rows = list(csv.DictReader(f))
    except FileNotFoundError:
        sys.exit(f"CSV not found: {args.csv}")

    if not rows:
        sys.exit(f"No rows in {args.csv}")
    if "betting_strategy" not in rows[0]:
        sys.exit("CSV has no betting_strategy column; re-run the simulator without --append to regenerate it.")

    # Group runs by strategy, keeping the order strategies first appear in the file
    by_strategy = {}
    for row in rows:
        by_strategy.setdefault(row["betting_strategy"], []).append(row)
    names = list(by_strategy)
    stats = {name: summarize(by_strategy[name], args.target, args.minimum) for name in names}

    def ratio(name, key):
        s = stats[name]
        return f"{pct(s[key] / s['n'])} ({s[key]}/{s['n']})"

    def interval(name, key):
        lo, hi = wilson_interval(stats[name][key], stats[name]["n"])
        return f"{lo:.0%}–{hi:.0%}"

    table = [
        (f"Reach {money(args.target)} (quit target)", lambda s: ratio(s, "reached")),
        ("...likely true range (95% confidence)", lambda s: interval(s, "reached")),
        (f"Go broke (under {money(args.minimum)} left)", lambda s: ratio(s, "broke")),
        ("Play all hands with money left", lambda s: ratio(s, "survived")),
        ("End with any profit", lambda s: pct(stats[s]["profit"] / stats[s]["n"])),
        ("Average net result", lambda s: money(stats[s]["mean_net"])),
        ("Median hands per run", lambda s: f"{stats[s]['median_hands']:g}"),
        ("Largest bet", lambda s: money(stats[s]["max_bet"])),
    ]

    print(f"Runs per strategy: " + ", ".join(f"{name} {stats[name]['n']}" for name in names))
    print()
    # Pad every cell to its column's width so the table lines up in a terminal
    # (it is still a valid Markdown table: labels left-aligned, values right-aligned)
    header = ["Per-run probability"] + names
    body = [[label] + [cell(name) for name in names] for label, cell in table]
    widths = [max(len(row[i]) for row in [header] + body) for i in range(len(header))]

    def format_row(row):
        cells = [row[0].ljust(widths[0])] + [c.rjust(w) for c, w in zip(row[1:], widths[1:])]
        return "| " + " | ".join(cells) + " |"

    print(format_row(header))
    print("|" + "|".join(["-" * (widths[0] + 2)] + ["-" * (w + 1) + ":" for w in widths[1:]]) + "|")
    for row in body:
        print(format_row(row))

    # Is the difference in reaching the target statistically meaningful?
    if len(names) == 2:
        a, b = (stats[name] for name in names)
        p_value = fisher_exact_two_sided(a["reached"], a["n"], b["reached"], b["n"])
        verdict = "likely a real difference" if p_value < 0.05 else "could be chance"
        print()
        print(f"Fisher's exact test, reaching the target ({names[0]} vs {names[1]}): "
              f"{'p < 0.001' if p_value < 0.001 else f'p = {p_value:.3f}'} ({verdict})")

    print()
    for name in names:
        s = stats[name]
        if s["reached"] in (0, s["n"]):
            # Rule of three: with 0 successes in n runs, the true rate is likely below 3/n
            outcome = "never" if s["reached"] == 0 else "always"
            print(f"{name} {outcome} reached the target in {s['n']} runs; "
                  f"run more attempts to estimate it (true rate likely within {3 / s['n']:.0%} of that)")
            continue
        needed = runs_needed(s["reached"] / s["n"])
        print(f"Runs needed to estimate {name}'s reach-target probability within ±2 points: ~{needed:,}")


if __name__ == "__main__":
    main()
