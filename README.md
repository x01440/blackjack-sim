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
Use `--help` to see all options. Per-simulation results are written to `data-out/simulation_results.csv`.

## Command Line Parameters

- `--hands <number>`: Specifies the number of blackjack hands to play in each simulation attempt.
- `--attempts <number>`: Sets how many times to run the entire simulation (each with the specified number of hands).
- `--decks <number>`: (If implemented) Sets the number of decks to use in the shoe.
- `--bet <amount>`: (If implemented) Sets the base bet amount for each hand.
- `--strategy [flat|increase|high_increase|random]`: Sets the betting strategy based on the built in betting strategy.
  - `flat`: Always bet the table minimum.
  - `increase`: Increase the bet by the table minimum after each win; reset to the minimum when the streak ends.
  - `high_increase`: Double the bet after the first two wins, then increase by 50% per win; reset to the minimum when the streak ends.
  - `random`: Bet a random 1-8 units on every hand, where a unit is the table minimum (`--minimum`).
- `--verbose`: (If implemented) Enables detailed output for each hand played.

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