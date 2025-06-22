# Blackjack Simulator
We're going to create a blackjack simulator that can simulate thousands of hands.

## Architecture

1. We're writing this in Zig, but may switch languages later.
2. It should be a command line tool.
3. The result of each hand should be logged to the console indicating a win, loss, or push for the player, the bet, how much the player won/lost, and the total bankroll remaining.
4. The simulation is over if the player's bankroll reaches zero.
5. The cards should be shuffled once a random amount of the cards are leftover in the queue, between 15% and 20%, decided at the time of shuffle.

## Parameters

1. The number of hands to simulate. Required.
2. The starting amount of money for the player. Default to $1000.
3. The betting minimum on the table. Default to $10.
4. The number of spots at the table. Default to 5.
5. The number of decks, can be 2 or 6.

## Strategy input files
Each strategy should have an input file in the directory "strategies". Each input file will be a CSV with the first column the player's hand and the rest of the columns the dealer's hand for blackjack basic strategy. Generate this file. Results will be "H" for hit, "S" for stand, "D" for double down, "SP" for split. If there are other outcomes for blackjack basic strategy choose a capital letter for the outcome.

## Number of players
The number of players in each hand may vary. The game will start off with the "player", which is the last position to receive cards and a random number of other players up to the maximum number of spots a the table. Each additional hand will have a chance of adding or removing other players. Only add players if the maximum number of players is at the table. Never remove the "player" for whom we're recording the wins, losses, and bankroll.

## Betting strategies

### Increase after win
This strategy is to increase the bet by the table minimum after a win. When a streak of wins is over, the bet goes back to table minimum.

### High increase after win
This strategy is to double the bet after the first two wins, then increase the bet by 50% of the bet each win therafter. When a streak of wins is over, the bet goes back to table minimum.

## Game rules

1. The game rules will follow typical 6 deck blackjack rules, such as blackjack earns 1.5x the bet and dealer hits soft 17.

2. If the number of decks is 2 then double down after split is not allowed.
