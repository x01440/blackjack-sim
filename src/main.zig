const std = @import("std");
const print = std.debug.print;

const Card = @import("card.zig").Card;
const Hand = @import("card.zig").Hand;
const Player = @import("player.zig").Player;
const BettingStrategy = @import("player.zig").BettingStrategy;
const Deck = @import("deck.zig").Deck;
const Strategy = @import("strategy.zig").Strategy;
const GameConstants = @import("constants.zig").GameConstants;
const cli = @import("cli.zig");
const GameConfig = cli.GameConfig;

fn runSimulation(allocator: std.mem.Allocator, config: GameConfig) !void {
    var deck = try Deck.init(allocator, config.num_decks);
    defer deck.deinit();

    var strategy = Strategy.init(allocator);
    defer strategy.deinit();
    try strategy.loadFromFile("strategies/basic_strategy.csv");

    var player = Player.init(
        config.starting_bankroll,
        config.table_minimum,
        config.betting_strategy,
    );

    var hands_played: u32 = 0;

    while (hands_played < config.num_hands and 
           player.bankroll >= config.table_minimum and 
           player.bankroll < config.quit_threshold) {
        if (deck.needsShuffle()) {
            try deck.shuffle();
            print("Deck shuffled\n", .{});
        }

        if (player.bankroll < player.bet) {
            player.bet = player.bankroll;
        }
        
        var player_hand = Hand.init(allocator, player.bet);
        defer player_hand.deinit();
        
        // Deduct the initial bet from bankroll
        player.bankroll -= player.bet;

        var dealer_hand = Hand.init(allocator, 0.0); // Dealer doesn't bet
        defer dealer_hand.deinit();

        // Deal cards in proper alternating order: player, dealer, player, dealer
        if (deck.dealCard()) |card1| {
            try player_hand.addCard(0, card1);
        }
        if (deck.dealCard()) |dealer_card1| {
            try dealer_hand.addCard(0, dealer_card1);
        }
        if (deck.dealCard()) |card2| {
            try player_hand.addCard(0, card2);
        }
        if (deck.dealCard()) |dealer_card2| {
            try dealer_hand.addCard(0, dealer_card2);
        }

        // Player plays all hands using loaded strategy
        var hand_index: usize = 0;
        while (hand_index < player_hand.getHandCount()) {
            var hand_done = false;
            
            while (player_hand.getValue(hand_index) < 21 and !hand_done) {
                const player_strategy_key = player_hand.getStrategyKey(hand_index);
                var dealer_up_card = dealer_hand.getValue(0);
                if (dealer_hand.getHand(0)) |dealer_cards| {
                    if (dealer_cards.items.len > 0) {
                        dealer_up_card = dealer_cards.items[0].rank;
                        if (dealer_up_card > 10) dealer_up_card = 10; // Face cards = 10
                    }
                }

                const action = strategy.getAction(player_strategy_key, dealer_up_card);

                switch (action) {
                    .hit => {
                        if (deck.dealCard()) |hit_card| {
                            try player_hand.addCard(hand_index, hit_card);
                        } else break;
                    },
                    .stand => {
                        hand_done = true;
                    },
                    .double_down => {
                        // Double down: double the bet, hit once, then stop
                        const current_bet = player_hand.getBet(hand_index);
                        if (player.bankroll >= current_bet) {
                            player.bankroll -= current_bet; // Pay the additional bet amount
                            try player_hand.setDoubled(hand_index); // This doubles the bet
                        }
                        if (deck.dealCard()) |hit_card| {
                            try player_hand.addCard(hand_index, hit_card);
                        }
                        hand_done = true;
                    },
                    .split => {
                        // Split if possible and we haven't already split this hand
                        if (player_hand.canSplit(hand_index)) {
                            // Check if player has enough bankroll for the split bet
                            const split_bet = player_hand.getBet(hand_index);
                            if (player.bankroll >= split_bet) {
                                player.bankroll -= split_bet; // Pay for the split hand
                                try player_hand.split(hand_index);
                                
                                // Deal one card to each split hand
                                if (deck.dealCard()) |card1| {
                                    try player_hand.addCard(hand_index, card1);
                                }
                                if (deck.dealCard()) |card2| {
                                    try player_hand.addCard(player_hand.getHandCount() - 1, card2);
                                }
                            } else {
                                // Can't afford to split, treat as hit
                                if (deck.dealCard()) |hit_card| {
                                    try player_hand.addCard(hand_index, hit_card);
                                } else break;
                            }
                        } else {
                            // Can't split, treat as hit
                            if (deck.dealCard()) |hit_card| {
                                try player_hand.addCard(hand_index, hit_card);
                            } else break;
                        }
                    },
                }
            }
            hand_index += 1;
        }

        // Dealer plays only if at least one player hand didn't bust
        var any_hand_not_bust = false;
        for (0..player_hand.getHandCount()) |i| {
            if (!player_hand.isBust(i)) {
                any_hand_not_bust = true;
                break;
            }
        }
        
        if (any_hand_not_bust) {
            while (dealer_hand.getValue(0) < 17 or 
                   (dealer_hand.getValue(0) == 17 and dealer_hand.isSoft(0))) {
                if (deck.dealCard()) |card| {
                    try dealer_hand.addCard(0, card);
                } else break;
            }
        }

        const dealer_value = dealer_hand.getValue(0);
        const dealer_blackjack = dealer_hand.isBlackjack(0);
        
        var total_winnings: f64 = 0;
        var total_wins: u32 = 0;
        var total_losses: u32 = 0;
        var total_pushes: u32 = 0;
        
        // Evaluate each hand separately
        for (0..player_hand.getHandCount()) |i| {
            const player_value = player_hand.getValue(i);
            const player_blackjack = player_hand.isBlackjack(i);
            var result: []const u8 = "UNKNOWN";
            const hand_bet = player_hand.getBet(i);
            var hand_winnings: f64 = 0;

            if (player_hand.isBust(i)) {
                result = "LOSS";
                total_losses += 1;
            } else if (dealer_hand.isBust(0)) {
                result = "WIN";
                if (player_blackjack) {
                    hand_winnings = hand_bet * GameConstants.blackjack_payout;
                } else {
                    hand_winnings = hand_bet * GameConstants.standard_win_payout;
                }
                total_wins += 1;
            } else if (player_blackjack and dealer_blackjack) {
                result = "PUSH";
                hand_winnings = hand_bet * GameConstants.push_payout; // Return bet
                total_pushes += 1;
            } else if (player_blackjack) {
                result = "WIN";
                hand_winnings = hand_bet * GameConstants.blackjack_payout;
                total_wins += 1;
            } else if (dealer_blackjack) {
                result = "LOSS";
                total_losses += 1;
            } else if (player_value > dealer_value) {
                result = "WIN";
                hand_winnings = hand_bet * GameConstants.standard_win_payout;
                total_wins += 1;
            } else if (player_value < dealer_value) {
                result = "LOSS";
                total_losses += 1;
            } else {
                result = "PUSH";
                hand_winnings = hand_bet * GameConstants.push_payout; // Return bet
                total_pushes += 1;
            }

            total_winnings += hand_winnings;
            
            const double_indicator = if (player_hand.isDoubled(i)) " (DOUBLE)" else "";
            const split_indicator = if (player_hand.isSplit(i)) " (SPLIT)" else "";
            print("Hand {} ({}): {s}{s}{s} - Bet: ${d:.2}, Winnings: ${d:.2}, " ++
                  "Bankroll: ${d:.2} (Player: {}, Dealer: {})\n", 
                  .{ hands_played, i + 1, result, double_indicator, split_indicator, 
                     hand_bet, hand_winnings, player.bankroll + total_winnings, 
                     player_value, dealer_value });
        }

        // Show summary of this round
        const total_bet = player_hand.getTotalBetAmount();
        print("Round {} Summary: Total Bet: ${d:.2}, Total Winnings: ${d:.2}, " ++
              "Net: ${d:.2}\n", .{ hands_played, total_bet, total_winnings, 
              total_winnings - total_bet });

        // Update betting strategy and player stats based on overall round result
        if (total_wins > total_losses) {
            player.updateBetAfterWin();
            player.wins += 1; // Count this round as 1 win
        } else if (total_losses > total_wins) {
            player.resetBetAfterLoss();
            player.losses += 1; // Count this round as 1 loss
        } else {
            player.recordPush();
            player.pushes += 1; // Count this round as 1 push
        }
        
        player.bankroll += total_winnings;
        hands_played += 1;

        if (player.bankroll <= 0) {
            print("Player bankrupt after {} hands\n", .{hands_played});
            break;
        }
    }

    // Check why simulation ended
    if (player.bankroll >= config.quit_threshold) {
        print("Quit threshold of ${d:.2} reached after {} hands\n", 
              .{ config.quit_threshold, hands_played });
    } else if (player.bankroll < config.table_minimum and player.bankroll > 0) {
        print("Bankroll too low to continue after {} hands\n", .{hands_played});
    }

    print("\nSimulation complete. Final bankroll: ${d:.2}\n", .{player.bankroll});
    print("Results: {} wins, {} losses, {} pushes\n", 
          .{ player.wins, player.losses, player.pushes });
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const config = try cli.parseArgs();
    print("Blackjack Simulator - Running {} hands\n", .{config.num_hands});
    print("Starting bankroll: ${d:.2}\n", .{config.starting_bankroll});
    print("Table minimum: ${d:.2}\n", .{config.table_minimum});
    print("Quit threshold: ${d:.2}\n", .{config.quit_threshold});
    print("Max spots: {}\n", .{config.max_spots});
    print("Number of decks: {}\n", .{config.num_decks});
    print("\n", .{});

    for (0..config.attempts) |attempt| {
        print("Running simulation attempt {}/{}\n", .{ attempt + 1, config.attempts });
        try runSimulation(allocator, config);
    }

    print("{} simulations complete.\n", .{config.attempts});
}
