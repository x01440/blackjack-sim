const std = @import("std");
const print = std.debug.print;

const Card = @import("card.zig").Card;
const Hand = @import("card.zig").Hand;
const Player = @import("player.zig").Player;
const BettingStrategy = @import("player.zig").BettingStrategy;
const Deck = @import("deck.zig").Deck;

const Action = enum {
    hit,
    stand,
    double_down,
    split,

    pub fn fromChar(c: u8) ?Action {
        return switch (c) {
            'H' => .hit,
            'S' => .stand,
            'D' => .double_down,
            'P' => .split,
            else => null,
        };
    }
};

const Strategy = struct {
    lookup: std.HashMap([2]u8, Action, KeyContext, std.hash_map.default_max_load_percentage),
    allocator: std.mem.Allocator,

    const KeyContext = struct {
        pub fn hash(self: @This(), key: [2]u8) u64 {
            _ = self;
            return std.hash_map.hashString(&key);
        }
        pub fn eql(self: @This(), a: [2]u8, b: [2]u8) bool {
            _ = self;
            return std.mem.eql(u8, &a, &b);
        }
    };

    pub fn init(allocator: std.mem.Allocator) Strategy {
        return Strategy{
            .lookup = std.HashMap([2]u8, Action, KeyContext, std.hash_map.default_max_load_percentage).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Strategy) void {
        self.lookup.deinit();
    }

    pub fn loadFromFile(self: *Strategy, file_path: []const u8) !void {
        const file = std.fs.cwd().openFile(file_path, .{}) catch |err| {
            print("Error opening strategy file: {}\n", .{err});
            return err;
        };
        defer file.close();

        const file_size = try file.getEndPos();
        const contents = try self.allocator.alloc(u8, file_size);
        defer self.allocator.free(contents);
        _ = try file.readAll(contents);

        var lines = std.mem.splitScalar(u8, contents, '\n');

        // Skip header line
        _ = lines.next();

        while (lines.next()) |line| {
            if (line.len == 0) continue;

            var fields = std.mem.splitScalar(u8, line, ',');
            const player_hand_str = fields.next() orelse continue;

            // Parse player hand
            var player_hand: u8 = 0;
            if (std.mem.eql(u8, player_hand_str, "AA")) {
                player_hand = 1; // Special case for pair of aces
            } else if (player_hand_str.len >= 2 and player_hand_str[0] == 'A') {
                // Soft hands like A2, A3, etc.
                player_hand = 100 + (player_hand_str[1] - '0'); // 102 for A2, 103 for A3, etc.
            } else if (player_hand_str.len >= 2 and player_hand_str[0] == player_hand_str[1]) {
                // Pairs like 22, 33, etc.
                player_hand = 200 + (player_hand_str[0] - '0'); // 202 for 22, 203 for 33, etc.
            } else {
                // Hard totals
                player_hand = std.fmt.parseInt(u8, player_hand_str, 10) catch continue;
            }

            // Parse dealer up cards and actions
            var dealer_card: u8 = 2;
            while (fields.next()) |action_str| {
                if (action_str.len == 0) continue;

                if (Action.fromChar(action_str[0])) |action| {
                    const key = [2]u8{ player_hand, dealer_card };
                    try self.lookup.put(key, action);
                }

                dealer_card += 1;
                if (dealer_card == 11) dealer_card = 1; // 10 -> Ace
                if (dealer_card > 1 and dealer_card < 2) break;
            }
        }
    }

    pub fn getAction(self: *Strategy, player_hand_value: u8, dealer_up_card: u8) Action {
        const key = [2]u8{ player_hand_value, dealer_up_card };
        return self.lookup.get(key) orelse .stand; // Default to stand if not found
    }
};


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

        if (deck.dealCard()) |card1| {
            try player_hand.cards.append(card1);
        }
        if (deck.dealCard()) |card2| {
            try player_hand.cards.append(card2);
        }

        var dealer_hand = Hand.init(allocator);
        defer dealer_hand.deinit();

        if (deck.dealCard()) |dealer_card1| {
            try dealer_hand.cards.append(dealer_card1);
        }
        if (deck.dealCard()) |dealer_card2| {
            try dealer_hand.cards.append(dealer_card2);
        }

        // Player plays their hand using loaded strategy
        while (player_hand.getValue() < 21) {
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
                .stand => break,
                .double_down => {
                    // For simplicity, treat double down as hit once then stand
                    if (deck.dealCard()) |hit_card| {
                        try player_hand.cards.append(hit_card);
                    }
                    break;
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
        const original_bet = player.bet;
        var winnings: f64 = 0;

        if (player_hand.isBust()) {
            result = "LOSS";
            player.resetBetAfterLoss();
        } else if (dealer_hand.isBust()) {
            result = "WIN";
            if (player_blackjack) {
                winnings = player.bet * 2.5;
            } else {
                winnings = player.bet * 2;
            }
            player.updateBetAfterWin();
        } else if (player_blackjack and dealer_blackjack) {
            result = "PUSH";
            player.recordPush();
        } else if (player_blackjack) {
            result = "WIN";
            winnings = player.bet * 2.5;
            player.updateBetAfterWin();
        } else if (dealer_blackjack) {
            result = "LOSS";
            player.resetBetAfterLoss();
        } else if (player_value > dealer_value) {
            result = "WIN";
            winnings = player.bet * 2.0;
            player.updateBetAfterWin();
        } else if (player_value < dealer_value) {
            result = "LOSS";
            player.resetBetAfterLoss();
        } else {
            result = "PUSH";
            player.recordPush();
        }

        player.bankroll += winnings;
        hands_played += 1;

        print("Hand {}: {s} - Bet: ${d:.2}, Winnings: ${d:.2}, New Bet: ${d:.2}, Bankroll: ${d:.2} (Player: {}, Dealer: {})\n", .{ hands_played, result, original_bet, winnings, player.bet, player.bankroll, player_value, dealer_value });

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
