const std = @import("std");
const print = std.debug.print;

const Card = struct {
    suit: u8,
    rank: u8,

    pub fn getValue(self: Card) u8 {
        if (self.rank == 1) return 11;
        if (self.rank > 10) return 10;
        return self.rank;
    }

    pub fn isAce(self: Card) bool {
        return self.rank == 1;
    }
};

const Hand = struct {
    cards: std.ArrayList(Card),
    is_split: bool = false,
    is_doubled: bool = false,

    pub fn init(allocator: std.mem.Allocator) Hand {
        return Hand{
            .cards = std.ArrayList(Card).init(allocator),
        };
    }

    pub fn deinit(self: *Hand) void {
        self.cards.deinit();
    }

    pub fn getValue(self: Hand) u8 {
        var value: u8 = 0;
        var aces: u8 = 0;

        for (self.cards.items) |card| {
            if (card.isAce()) {
                aces += 1;
                value += 11;
            } else {
                value += card.getValue();
            }
        }

        while (value > 21 and aces > 0) {
            value -= 10;
            aces -= 1;
        }

        return value;
    }

    pub fn isBlackjack(self: Hand) bool {
        return self.cards.items.len == 2 and self.getValue() == 21;
    }

    pub fn isBust(self: Hand) bool {
        return self.getValue() > 21;
    }
};

const BettingStrategy = enum {
    flat,
    increase_after_win,
    high_increase_after_win,
};

const Player = struct {
    bankroll: f64,
    bet: f64,
    wins_streak: u32 = 0,
    wins: u32 = 0,
    losses: u32 = 0,
    pushes: u32 = 0,
    betting_strategy: BettingStrategy,
    table_minimum: f64,

    pub fn init(starting_bankroll: f64, table_minimum: f64, betting_strategy: BettingStrategy) Player {
        return Player{
            .bankroll = starting_bankroll,
            .bet = table_minimum,
            .betting_strategy = betting_strategy,
            .table_minimum = table_minimum,
        };
    }

    pub fn updateBetAfterWin(self: *Player) void {
        self.wins_streak += 1;
        self.wins += 1;

        switch (self.betting_strategy) {
            .flat => {},
            .increase_after_win => {
                const increase = self.table_minimum * 0.5;
                const rounded_increase = @ceil(increase / 5.0) * 5.0;
                self.bet = self.table_minimum + rounded_increase;
            },
            .high_increase_after_win => {
                if (self.wins_streak <= 2) {
                    self.bet *= 2;
                } else {
                    self.bet += self.table_minimum;
                }
            },
        }
    }

    pub fn resetBetAfterLoss(self: *Player) void {
        self.wins_streak = 0;
        self.bet = self.table_minimum;
        self.losses += 1;
    }

    pub fn recordPush(self: *Player) void {
        self.wins_streak = 0;
        self.bet = self.table_minimum;
        self.pushes += 1;
    }
};

const Deck = struct {
    cards: std.ArrayList(Card),
    num_decks: u8 = 6,
    shuffle_point: usize,
    rng: std.Random.DefaultPrng,

    pub fn init(allocator: std.mem.Allocator, num_decks: u8) !Deck {
        var deck = Deck{
            .num_decks = num_decks,
            .cards = std.ArrayList(Card).init(allocator),
            .shuffle_point = 0,
            .rng = std.Random.DefaultPrng.init(@intCast(std.time.timestamp())),
        };

        // try deck.createDecks(num_decks);
        // Creates and shuffles the deck immediately.
        try deck.shuffle();

        return deck;
    }

    pub fn deinit(self: *Deck) void {
        self.cards.deinit();
    }

    fn createDecks(self: *Deck, num_decks: u8) !void {
        for (0..num_decks) |_| {
            for (1..5) |suit| {
                for (1..14) |rank| {
                    try self.cards.append(Card{
                        .suit = @intCast(suit),
                        .rank = @intCast(rank),
                    });
                }
            }
        }
    }

    pub fn shuffle(self: *Deck) !void {
        self.cards.clearAndFree();
        try self.createDecks(self.num_decks);
        const total_cards = self.cards.items.len;
        
        // Calculate shuffle point: shuffle when 15-20% of cards remain
        const min_remaining = total_cards * 15 / 100;  // 15% remaining
        const max_remaining = total_cards * 20 / 100;  // 20% remaining
        const range = max_remaining - min_remaining;
        self.shuffle_point = min_remaining + self.rng.random().uintLessThan(usize, range + 1);

        for (0..total_cards) |i| {
            const j = self.rng.random().uintLessThan(usize, total_cards);
            const temp = self.cards.items[i];
            self.cards.items[i] = self.cards.items[j];
            self.cards.items[j] = temp;
        }
    }

    pub fn needsShuffle(self: Deck) bool {
        return self.cards.items.len <= self.shuffle_point;
    }

    pub fn dealCard(self: *Deck) ?Card {
        if (self.cards.items.len == 0) return null;
        return self.cards.pop();
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

        while (dealer_hand.getValue() < 17 or (dealer_hand.getValue() == 17 and dealer_hand.cards.items.len >= 2 and dealer_hand.cards.items[0].isAce())) {
            if (deck.dealCard()) |card| {
                try dealer_hand.cards.append(card);
            } else break;
        }

        const player_value = player_hand.getValue();
        const dealer_value = dealer_hand.getValue();
        const player_blackjack = player_hand.isBlackjack();
        const dealer_blackjack = dealer_hand.isBlackjack();

        var result: []const u8 = "UNKNOWN";
        var original_bet = player.bet;
        var winnings: f64 = 0;

        if (player_hand.isBust()) {
            result = "LOSS";
            player.resetBetAfterLoss();
        } else if (dealer_hand.isBust()) {
            result = "WIN";
            if (player_blackjack) {
                winnings = player.bet * 1.5;
            } else {
                winnings = player.bet * 1;
            }
            player.updateBetAfterWin();
        } else if (player_blackjack and dealer_blackjack) {
            result = "PUSH";
            player.recordPush();
        } else if (player_blackjack) {
            result = "WIN";
            winnings = player.bet * 1.5;
            player.updateBetAfterWin();
        } else if (dealer_blackjack) {
            result = "LOSS";
            original_bet = 0;
            player.resetBetAfterLoss();
        } else if (player_value > dealer_value) {
            result = "WIN";
            winnings = player.bet;
            player.updateBetAfterWin();
        } else if (player_value < dealer_value) {
            result = "LOSS";
            original_bet = 0;
            player.resetBetAfterLoss();
        } else {
            result = "PUSH";
            winnings = player.bet;
            player.recordPush();
        }

        player.bankroll += winnings + original_bet;
        hands_played += 1;

        print("Hand {}: {s} - Bet: ${d:.2}, Winnings: ${d:.2}, Bankroll: ${d:.2} (Player: {}, Dealer: {})\n", .{ hands_played, result, player.bet, winnings, player.bankroll, player_value, dealer_value });

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
