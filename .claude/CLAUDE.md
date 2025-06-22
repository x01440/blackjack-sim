# Blackjack Simulator
We're going to create a blackjack simulator that can simulate thousands of hands.

## Architecture

1. We're writing this in Zig, but may switch languages later.
2. It should be a command line tool.
3. The result of each hand should be logged to the console indicating a win, loss, or push for the player, the bet, how much the player won/lost, and the total bankroll remaining.
4. The simulation is over if the player's bankroll reaches zero.
5. The cards should be shuffled once a random amount of the cards are leftover in the queue, between 15% and 20%, decided at the time of shuffle.

## Code Organization

The codebase should be modular with the following file structure:
- `src/card.zig` - Card and Hand structures with game logic (soft hands, pairs, strategy keys)
- `src/player.zig` - Player structure and betting strategies
- `src/deck.zig` - Deck management, shuffling, and dealing
- `src/main.zig` - Main simulation loop, strategy loading, and command line interface
- `strategies/` - Directory containing CSV strategy files

## Parameters

1. The number of hands to simulate. Required.
2. The starting amount of money for the player. Default to $1000.
3. The betting minimum on the table. Default to $10.
4. The number of spots at the table. Default to 5.
5. The number of decks, can be 2 or 6.

## Command Line Interface

Required arguments:
- `--hands <number>` - Number of hands to simulate

Optional arguments:
- `--bankroll <amount>` - Starting bankroll (default: $1000)
- `--minimum <amount>` - Table minimum bet (default: $10)
- `--spots <number>` - Max spots at table (default: 5)
- `--decks <2|6>` - Number of decks (default: 6)
- `--strategy <flat|increase|high_increase>` - Betting strategy (default: increase)
- `--help` - Show help message

Example: `blackjack-sim --hands 1000 --bankroll 500 --strategy flat`

## Strategy Implementation

1. The simulator loads basic strategy from CSV files using a lookup table approach
2. Player hands are categorized as:
   - Hard totals (numeric value)
   - Soft hands (100 + non-ace card value, e.g., A2 = 102)
   - Pairs (200 + card rank, e.g., 22 = 202, AA = 201)
3. Strategy lookup uses [player_hand_key, dealer_up_card] as the key
4. Use "P" for split actions in CSV files (not "SP")

## Strategy Input Files (Updated)

Each strategy file should be a CSV with:
- First column: Player hand (5-21 for hard, A2-A9 for soft, 22-AA for pairs)
- Remaining columns: Dealer up cards (2-10, A)
- Actions: "H" (hit), "S" (stand), "D" (double), "P" (split)
- Example: `basic_strategy.csv` contains standard basic strategy matrix

## Number of players
The number of players in each hand may vary. The game will start off with the "player", which is the last position to receive cards and a random number of other players up to the maximum number of spots a the table. Each additional hand will have a chance of adding or removing other players. Only add players if the maximum number of players is at the table. Never remove the "player" for whom we're recording the wins, losses, and bankroll.

## Betting strategies

### Increase after win
This strategy is to increase the bet by the table minimum after a win. When a streak of wins is over, the bet goes back to table minimum.

### High increase after win
This strategy is to double the bet after the first two wins, then increase the bet by 50% of the bet each win therafter. When a streak of wins is over, the bet goes back to table minimum.

## Game Logic Implementation

1. **Player Strategy**: Player follows loaded CSV strategy for hit/stand/double/split decisions
2. **Dealer Rules**: Dealer hits soft 17 and stands on hard 17+
3. **Hand Analysis**: Proper detection of soft hands, pairs, and blackjacks
4. **Shuffle Timing**: Deck shuffles when 15-20% of cards remain (not when 15-20% used)
5. **Payout Structure**: 
   - Blackjack pays 1.5x bet
   - Regular wins pay 1x bet
   - Double down is simplified to hit once then stand
   - Split is simplified to hit (full split not implemented)

## Game Rules

1. The game rules will follow typical 6 deck blackjack rules, such as blackjack earns 1.5x the bet and dealer hits soft 17.
2. If the number of decks is 2 then double down after split is not allowed.

## Player Tracking

The player object tracks:
- Current bankroll and bet amounts
- Win streak for betting strategy
- Total wins, losses, and pushes (32-bit integers)
- No hand history is stored to prevent memory leaks

## Output Format

Each hand displays:
- Hand number and result (WIN/LOSS/PUSH)
- Bet amount and winnings
- New bet amount (for betting strategy tracking)
- Updated bankroll
- Final player and dealer hand values

Final summary includes:
- Total wins, losses, and pushes
- Final bankroll amount
