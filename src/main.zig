const std = @import("std");
const print = std.debug.print;

const Card = @import("card.zig").Card;
const Hand = @import("card.zig").Hand;
const Player = @import("player.zig").Player;
const BettingStrategy = @import("player.zig").BettingStrategy;
const Deck = @import("deck.zig").Deck;
const Strategy = @import("strategy.zig").Strategy;

const GameConfig = struct {
    attempts: u32 = 1,
    num_hands: u32,
    starting_bankroll: f64 = 1000.0,
    table_minimum: f64 = 10.0,
    max_spots: u8 = 5,
    num_decks: u8 = 6,
    betting_strategy: BettingStrategy = .increase_after_win,
};

fn printHelp() void {
    print("Blackjack Simulator\n", .{});
    print("Usage: blackjack-sim --hands <number> [options]\n\n", .{});
    print("Required arguments:\n", .{});
    print("  --hands <number>       Number of hands to simulate\n\n", .{});
    print("Optional arguments:\n", .{});
    print("  --bankroll <amount>    Starting bankroll amount (default: $1000.00)\n", .{});
    print("  --minimum <amount>     Table minimum bet (default: $10.00)\n", .{});
    print("  --spots <number>       Maximum spots at table (default: 5)\n", .{});
    print("  --decks <2|6>          Number of decks (default: 6)\n", .{});
    print("  --attempts <attempts>  Number of simulation runs\n", .{});
    print("  --strategy <strategy>  Betting strategy (default: increase)\n", .{});
    print("  --help                 Show this help message\n\n", .{});
    print("Betting strategies:\n", .{});
    print("  flat                   Always bet table minimum\n", .{});
    print("  increase               Increase bet by 50%% of table minimum after win\n", .{});
    print("                         (rounded up to nearest $5)\n", .{});
    print("  high_increase          Double bet after first two wins, then increase\n", .{});
    print("                         by table minimum for each subsequent win\n", .{});
}

fn parseArgs() !GameConfig {
    var args = std.process.args();
    _ = args.skip();

    var config = GameConfig{ .num_hands = 0 };

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--help")) {
            printHelp();
            std.process.exit(0);
        } else if (std.mem.eql(u8, arg, "--hands")) {
            if (args.next()) |hands_str| {
                config.num_hands = try std.fmt.parseInt(u32, hands_str, 10);
            }
        } else if (std.mem.eql(u8, arg, "--bankroll")) {
            if (args.next()) |bankroll_str| {
                config.starting_bankroll = try std.fmt.parseFloat(f64, bankroll_str);
            }
        } else if (std.mem.eql(u8, arg, "--minimum")) {
            if (args.next()) |min_str| {
                config.table_minimum = try std.fmt.parseFloat(f64, min_str);
            }
        } else if (std.mem.eql(u8, arg, "--spots")) {
            if (args.next()) |spots_str| {
                config.max_spots = try std.fmt.parseInt(u8, spots_str, 10);
            }
        } else if (std.mem.eql(u8, arg, "--decks")) {
            if (args.next()) |decks_str| {
                const decks = try std.fmt.parseInt(u8, decks_str, 10);
                if (decks != 2 and decks != 6) {
                    print("Error: Number of decks must be 2 or 6\n", .{});
                    std.process.exit(1);
                }
                config.num_decks = decks;
            }
        } else if (std.mem.eql(u8, arg, "--attempts")) {
            if (args.next()) |attempts_str| {
                const attempts = try std.fmt.parseInt(u8, attempts_str, 10);
                if (attempts < 1) {
                    print("Error: Number of attempts must be at least 1\n", .{});
                    std.process.exit(1);
                }
                config.attempts = attempts;
            }
        } else if (std.mem.eql(u8, arg, "--strategy")) {
            if (args.next()) |strategy_str| {
                if (std.mem.eql(u8, strategy_str, "flat")) {
                    config.betting_strategy = .flat;
                } else if (std.mem.eql(u8, strategy_str, "increase")) {
                    config.betting_strategy = .increase_after_win;
                } else if (std.mem.eql(u8, strategy_str, "high_increase")) {
                    config.betting_strategy = .high_increase_after_win;
                } else {
                    print("Error: Unknown betting strategy '{s}'\n", .{strategy_str});
                    std.process.exit(1);
                }
            }
        }
    }

    if (config.num_hands == 0) {
        print("Error: --hands argument is required\n", .{});
        print("Use --help for usage information\n", .{});
        std.process.exit(1);
    }

    return config;
}

fn runSimulation(allocator: std.mem.Allocator, config: GameConfig) !void {
    var deck = try Deck.init(allocator, config.num_decks);
    defer deck.deinit();

    var strategy = Strategy.init(allocator);
    defer strategy.deinit();
    try strategy.loadFromFile("strategies/basic_strategy.csv");

    var player = Player.init(config.starting_bankroll, config.table_minimum, config.betting_strategy);

    var hands_played: u32 = 0;

    while (hands_played < config.num_hands and player.bankroll >= config.table_minimum) {
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
                            try player_hand.setDoubled(hand_index); // This doubles the bet in the hand
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
            while (dealer_hand.getValue(0) < 17 or (dealer_hand.getValue(0) == 17 and dealer_hand.isSoft(0))) {
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
                    hand_winnings = hand_bet * 2.5;
                } else {
                    hand_winnings = hand_bet * 2;
                }
                total_wins += 1;
            } else if (player_blackjack and dealer_blackjack) {
                result = "PUSH";
                hand_winnings = hand_bet; // Return bet
                total_pushes += 1;
            } else if (player_blackjack) {
                result = "WIN";
                hand_winnings = hand_bet * 2.5;
                total_wins += 1;
            } else if (dealer_blackjack) {
                result = "LOSS";
                total_losses += 1;
            } else if (player_value > dealer_value) {
                result = "WIN";
                hand_winnings = hand_bet * 2.0;
                total_wins += 1;
            } else if (player_value < dealer_value) {
                result = "LOSS";
                total_losses += 1;
            } else {
                result = "PUSH";
                hand_winnings = hand_bet; // Return bet
                total_pushes += 1;
            }

            total_winnings += hand_winnings;
            
            const double_indicator = if (player_hand.isDoubled(i)) " (DOUBLE)" else "";
            const split_indicator = if (player_hand.isSplit(i)) " (SPLIT)" else "";
            print("Hand {} ({}): {s}{s}{s} - Bet: ${d:.2}, Winnings: ${d:.2}, Bankroll: ${d:.2} (Player: {}, Dealer: {})\n", .{ hands_played, i + 1, result, double_indicator, split_indicator, hand_bet, hand_winnings, player.bankroll + total_winnings, player_value, dealer_value });
        }

        // Show summary of this round
        const total_bet = player_hand.getTotalBetAmount();
        print("Round {} Summary: Total Bet: ${d:.2}, Total Winnings: ${d:.2}, Net: ${d:.2}\n", .{ hands_played, total_bet, total_winnings, total_winnings - total_bet });

        // Update betting strategy based on overall result
        if (total_wins > total_losses) {
            player.updateBetAfterWin();
        } else if (total_losses > total_wins) {
            player.resetBetAfterLoss();
        } else {
            player.recordPush();
        }

        // Update player stats
        player.wins += total_wins;
        player.losses += total_losses;
        player.pushes += total_pushes;
        
        player.bankroll += total_winnings;
        hands_played += 1;

        if (player.bankroll <= 0) {
            print("Player bankrupt after {} hands\n", .{hands_played});
            break;
        }
    }

    print("\nSimulation complete. Final bankroll: ${d:.2}\n", .{player.bankroll});
    print("Results: {} wins, {} losses, {} pushes\n", .{ player.wins, player.losses, player.pushes });
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const config = try parseArgs();
    print("Blackjack Simulator - Running {} hands\n", .{config.num_hands});
    print("Starting bankroll: ${d:.2}\n", .{config.starting_bankroll});
    print("Table minimum: ${d:.2}\n", .{config.table_minimum});
    print("Max spots: {}\n", .{config.max_spots});
    print("Number of decks: {}\n", .{config.num_decks});
    print("\n", .{});

    for (0..config.attempts) |attempt| {
        print("Running simulation attempt {}/{}\n", .{ attempt + 1, config.attempts });
        try runSimulation(allocator, config);
    }

    print("{} simulations complete.\n", .{config.attempts});
}
