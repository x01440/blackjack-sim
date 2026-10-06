# Blackjack Simulator

This is a blackjack simulator written in zig. For details about how it was constructed, refer to the `.claude/CLAUDE.md` file. This simulator was written with Claude.

## Building and Running

### Requirements
- **Zig 0.15.x** (tested with 0.15.2). Older versions such as 0.14 will not build this project because the build and standard library APIs changed.
  - On macOS with Homebrew: `brew install zig`
  - Otherwise, download 0.15.2 for your platform from https://ziglang.org/download/, extract it, and add the extracted folder to your `PATH`.
  - Check with `zig version`, which should print `0.15.x`.

### Build
From the project root:
```sh
zig build -Doptimize=ReleaseFast
```
This produces the executable at `./zig-out/bin/blackjack-sim`. Omit `-Doptimize=ReleaseFast` for a debug build.

### Run
Run the simulator from the project root, since it loads `strategies/basic_strategy.csv` with a relative path:
```sh
./zig-out/bin/blackjack-sim --hands 1000 --strategy random
```
Or build and run in one step, passing arguments after `--`:
```sh
zig build run -- --hands 1000 --strategy random
```
Use `--help` to see all options. Per-simulation results are written to `data-out/simulation_results.csv` (see [Output CSV](#output-csv)).

## Command Line Parameters

Required:
- `--hands <number>`: Number of blackjack hands to play in each simulation attempt.

Optional:
- `--attempts <number>`: How many times to run the entire simulation, each with the specified number of hands (default: 1).
- `--bankroll <amount>`: Starting bankroll (default: $1000).
- `--minimum <amount>`: Table minimum bet; also the "unit" for the `random` strategy (default: $10).
- `--spots <number>`: Maximum spots at the table (default: 5).
- `--decks <2|6>`: Number of decks in the shoe (default: 6).
- `--quit_threshold <amount>`: Stop a simulation when the bankroll reaches this amount (default: $2000).
- `--strategy [flat|increase|high_increase|random]`: Betting strategy (default: `increase`).
  - `flat`: Always bet the table minimum.
  - `increase`: Increase the bet by the table minimum after each win; reset to the minimum when the streak ends.
  - `high_increase`: Double the bet after the first two wins, then increase by 50% per win; reset to the minimum when the streak ends.
  - `random`: Bet a random 1-8 units on every hand, where a unit is the table minimum (`--minimum`).
- `--seed <string>`: Seed for the random number generator, for repeatable results.
- `--append`: Append this run's results to `data-out/simulation_results.csv` instead of replacing the file. The header row is only written when the file is new or empty. See [Output CSV](#output-csv).
- `--help`: Show the help message.

## Output CSV
Each run writes one row per simulation attempt to `data-out/simulation_results.csv` with these columns:

`simulation, betting_strategy, total_hands, player_wins, player_losses, ties, max_bet, winnings, final_bankroll, starting_bankroll, net_winnings, win_rate`

- `betting_strategy` is the strategy name used for that run (`flat`, `increase`, `high_increase`, or `random`).
- By default the file is replaced on every run. Pass `--append` to add rows to the existing file, e.g. to compare strategies in one CSV:
  ```sh
  ./zig-out/bin/blackjack-sim --hands 1000 --attempts 10 --strategy flat
  ./zig-out/bin/blackjack-sim --hands 1000 --attempts 10 --strategy random --append
  ```
- `simulation` numbering restarts at 1 for each run.
- If your existing CSV was created before the `betting_strategy` column was added, delete it (or run once without `--append`) so the columns line up.

## Analyzing Results
`scripts/analyze_results.py` (Python 3, standard library only) reads the results CSV and prints a Markdown table comparing every betting strategy in the file: how often a run reaches the quit target, goes broke, or plays all hands; average net result; median hands; and largest bet. With exactly two strategies it also reports whether the difference in reaching the target is statistically meaningful.

```sh
./zig-out/bin/blackjack-sim --hands 2000 --attempts 1000 --strategy increase
./zig-out/bin/blackjack-sim --hands 2000 --attempts 1000 --strategy random --append
python3 scripts/analyze_results.py
```
If you changed `--quit_threshold` or `--minimum`, pass the same values: `python3 scripts/analyze_results.py --target 3000 --minimum 25`. A different CSV path can be given as the first argument.

## Notes on Claude's mistakes
- Player didn't actually play at first, Claude was instructed to load the basic strategy from CSV and use that strategy matrix to execute basic strategy. Claude missed that and I had to prompt it a couple of times to do this work.
- Spliting pairs was implemented as a TODO initially.
- The betting strategy to increase the bet didn't actually increase the bet at first.
- I asked to shuffle when about 15-20% of the cards were remaining in the decks. Claude implemented this to shuffle when 80-85% of the cards were remaining.
- The shuffle function only shuffled the remaining cards, eventually resulting in a divide by zero error when not enough cards were remaining for a 15-20% remaining number to start shuffling.
- When fixed, the shuffle function added cards to the remaining queue instead of clearing the queue before shuffling.

## Sample command lines
2000 hands, 2 attempts at the entire simulation
`./zig-out/bin/blackjack-sim --hands 2000 --attempts 2`

1000 hands, 10 attempts with random betting, adding the results to the existing CSV
`./zig-out/bin/blackjack-sim --hands 1000 --attempts 10 --strategy random --append`