const std = @import("std");
const print = std.debug.print;

const Card = @import("card.zig").Card;
const Hand = @import("card.zig").Hand;
const Player = @import("player.zig").Player;
const BettingStrategy = @import("player.zig").BettingStrategy;
const Deck = @import("deck.zig").Deck;
const Strategy = @import("strategy.zig").Strategy;


const GameConfig = struct {
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

        var player_hand = Hand.init(allocator);
        defer player_hand.deinit();

        if (player.bankroll < player.bet) {
            player.bet = player.bankroll;
        }
        player.bankroll -= player.bet;

        var dealer_hand = Hand.init(allocator);
        defer dealer_hand.deinit();

        // Deal cards in proper alternating order: player, dealer, player, dealer
        if (deck.dealCard()) |card1| {
            try player_hand.cards.append(card1);
        }
        if (deck.dealCard()) |dealer_card1| {
            try dealer_hand.cards.append(dealer_card1);
        }
        if (deck.dealCard()) |card2| {
            try player_hand.cards.append(card2);
        }
        if (deck.dealCard()) |dealer_card2| {
            try dealer_hand.cards.append(dealer_card2);
        }

        // Player plays their hand using loaded strategy
        var player_done = false;
        var doubled_down = false;
        while (player_hand.getValue() < 21 and !player_done) {
            const player_strategy_key = player_hand.getStrategyKey();
            var dealer_up_card = dealer_hand.cards.items[0].rank;
            if (dealer_up_card > 10) dealer_up_card = 10; // Face cards = 10

            const action = strategy.getAction(player_strategy_key, dealer_up_card);

            switch (action) {
                .hit => {
                    if (deck.dealCard()) |hit_card| {
                        try player_hand.cards.append(hit_card);
                    } else break;
                },
                .stand => {
                    player_done = true;
                },
                .double_down => {
                    // Double down: double the bet, hit once, then stop
                    if (player.bankroll >= player.bet) {
                        player.bankroll -= player.bet;
                        player.bet *= 2;
                        doubled_down = true;
                    }
                    if (deck.dealCard()) |hit_card| {
                        try player_hand.cards.append(hit_card);
                    }
                    player_done = true;
                },
                .split => {
                    // For simplicity, treat split as hit (splitting not implemented yet)
                    if (deck.dealCard()) |hit_card| {
                        try player_hand.cards.append(hit_card);
                    } else break;
                },
            }
        }

        // Dealer plays only if player didn't bust
        if (!player_hand.isBust()) {
            while (dealer_hand.getValue() < 17 or (dealer_hand.getValue() == 17 and dealer_hand.isSoft())) {
                if (deck.dealCard()) |card| {
                    try dealer_hand.cards.append(card);
                } else break;
            }
        }

        const player_value = player_hand.getValue();
        const dealer_value = dealer_hand.getValue();
        const player_blackjack = player_hand.isBlackjack();
        const dealer_blackjack = dealer_hand.isBlackjack();

        var result: []const u8 = "UNKNOWN";
        const current_bet = player.bet;
        var winnings: f64 = 0;

        // Reset bet for betting strategy tracking (will be updated in win/loss methods)
        if (doubled_down) {
            player.bet = player.bet / 2; // Reset to original bet amount for strategy tracking
        }

        if (player_hand.isBust()) {
            result = "LOSS";
            player.resetBetAfterLoss();
        } else if (dealer_hand.isBust()) {
            result = "WIN";
            if (player_blackjack) {
                winnings = current_bet * 2.5;
            } else {
                winnings = current_bet * 2;
            }
            player.updateBetAfterWin();
        } else if (player_blackjack and dealer_blackjack) {
            result = "PUSH";
            winnings = current_bet * 2; // Assume even money on average.
            player.recordPush();
        } else if (player_blackjack) {
            result = "WIN";
            winnings = current_bet * 2.5;
            player.updateBetAfterWin();
        } else if (dealer_blackjack) {
            result = "LOSS";
            player.resetBetAfterLoss();
        } else if (player_value > dealer_value) {
            result = "WIN";
            winnings = current_bet * 2.0;
            player.updateBetAfterWin();
        } else if (player_value < dealer_value) {
            result = "LOSS";
            player.resetBetAfterLoss();
        } else {
            result = "PUSH";
            winnings = current_bet; // Return bet
            player.recordPush();
        }

        player.bankroll += winnings;
        hands_played += 1;

        const double_indicator = if (doubled_down) " (DOUBLE)" else "";
        print("Hand {}: {s}{s} - Bet: ${d:.2}, Winnings: ${d:.2}, New Bet: ${d:.2}, Bankroll: ${d:.2} (Player: {}, Dealer: {})\n", .{ hands_played, result, double_indicator, current_bet, winnings, player.bet, player.bankroll, player_value, dealer_value });

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

    try runSimulation(allocator, config);
}
