# Blackjack Simulator

This is a blackjack simulator written in zig. For details about how it was constructed, refer to the `.claude/CLAUDE.md` file. This simulator was written with Claude.

## Notes on Claude's mistakes
- Player didn't actually play at first, Claude was instructed to load the basic strategy from CSV and use that strategy matrix to execute basic strategy. Claude missed that and I had to prompt it a couple of times to do this work.
- Spliting pairs was implemented as a TODO initially.
- The betting strategy to increase the bet didn't actually increase the bet at first.
- I asked to shuffle when about 15-20% of the cards were remaining in the decks. Claude implemented this to shuffle when 80-85% of the cards were remaining.
- The shuffle function only shuffled the remaining cards, eventually resulting in a divide by zero error when not enough cards were remaining for a 15-20% remaining number to start shuffling.
- When fixed, the shuffle function added cards to the remaining queue instead of clearing the queue before shuffling.