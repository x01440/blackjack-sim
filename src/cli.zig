const std = @import("std");
const print = std.debug.print;
const BettingStrategy = @import("player.zig").BettingStrategy;
const GameConstants = @import("constants.zig").GameConstants;

pub const GameConfig = struct {
    attempts: u32 = GameConstants.default_attempts,
    num_hands: u32,
    starting_bankroll: f64 = GameConstants.default_starting_bankroll,
    table_minimum: f64 = GameConstants.default_table_minimum,
    max_spots: u8 = GameConstants.default_max_spots,
    num_decks: u8 = GameConstants.default_num_decks,
    quit_threshold: f64 = GameConstants.quit_threshold,
    betting_strategy: BettingStrategy = .increase_after_win,
    seed: ?[]const u8 = null,
};

pub fn printHelp() void {
    print("Blackjack Simulator\n", .{});
    print("Usage: blackjack-sim --hands <number> [options]\n\n", .{});
    print("Required arguments:\n", .{});
    print("  --hands <number>       Number of hands to simulate\n\n", .{});
    print("Optional arguments:\n", .{});
    print("  --bankroll <amount>    Starting bankroll amount (default: ${d:.2})\n", 
          .{GameConstants.default_starting_bankroll});
    print("  --minimum <amount>     Table minimum bet (default: ${d:.2})\n", 
          .{GameConstants.default_table_minimum});
    print("  --spots <number>       Maximum spots at table (default: {})\n", 
          .{GameConstants.default_max_spots});
    print("  --decks <2|6>          Number of decks (default: {})\n", 
          .{GameConstants.default_num_decks});
    print("  --attempts <attempts>  Number of simulation runs (default: {})\n", 
          .{GameConstants.default_attempts});
    print("  --quit_threshold <amount> Stop when bankroll reaches this amount " ++
          "(default: ${d:.2})\n", .{GameConstants.quit_threshold});
    print("  --strategy <strategy>  Betting strategy (default: increase)\n", .{});
    print("  --seed <string>        Seed for random number generation (optional)\n", .{});
    print("  --help                 Show this help message\n\n", .{});
    print("Betting strategies:\n", .{});
    print("  flat                   Always bet table minimum\n", .{});
    print("  increase               Increase bet by 50%% of table minimum after win\n", .{});
    print("                         (rounded up to nearest $5)\n", .{});
    print("  high_increase          Double bet after first two wins, then increase\n", .{});
    print("                         by table minimum for each subsequent win\n", .{});
}

pub fn parseArgs() !GameConfig {
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
                var valid = false;
                for (GameConstants.valid_deck_counts) |valid_count| {
                    if (decks == valid_count) {
                        valid = true;
                        break;
                    }
                }
                if (!valid) {
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
        } else if (std.mem.eql(u8, arg, "--quit_threshold")) {
            if (args.next()) |threshold_str| {
                config.quit_threshold = try std.fmt.parseFloat(f64, threshold_str);
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
        } else if (std.mem.eql(u8, arg, "--seed")) {
            if (args.next()) |seed_str| {
                config.seed = seed_str;
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