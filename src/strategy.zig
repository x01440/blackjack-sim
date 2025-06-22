const std = @import("std");
const print = std.debug.print;

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

pub const Strategy = struct {
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