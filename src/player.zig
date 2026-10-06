const std = @import("std");

pub const BettingStrategy = enum {
    flat,
    increase_after_win,
    high_increase_after_win,
    random,

    /// The command line name for this strategy (as passed to --strategy).
    pub fn name(self: BettingStrategy) []const u8 {
        return switch (self) {
            .flat => "flat",
            .increase_after_win => "increase",
            .high_increase_after_win => "high_increase",
            .random => "random",
        };
    }
};

pub const Player = struct {
    bankroll: f64,
    bet: f64,
    wins_streak: u32 = 0,
    wins: u32 = 0,
    losses: u32 = 0,
    pushes: u32 = 0,
    betting_strategy: BettingStrategy,
    table_minimum: f64,

    pub fn init(
        starting_bankroll: f64, 
        table_minimum: f64, 
        betting_strategy: BettingStrategy
    ) Player {
        return Player{
            .bankroll = starting_bankroll,
            .bet = table_minimum,
            .betting_strategy = betting_strategy,
            .table_minimum = table_minimum,
        };
    }

    pub fn updateBetAfterWin(self: *Player) void {
        self.wins_streak += 1;

        switch (self.betting_strategy) {
            .flat => {},
            .increase_after_win => {
                self.bet += self.table_minimum;
            },
            .high_increase_after_win => {
                if (self.wins_streak <= 2) {
                    self.bet *= 2;
                } else {
                    const rounded_increase = @ceil(self.bet / 2.0);
                    self.bet += rounded_increase;
                }
            },
            .random => {},
        }
    }

    /// Sets the bet for the upcoming hand. Only the random strategy changes
    /// the bet here: 1-8 units, where a unit is the table minimum.
    pub fn prepareBet(self: *Player, rng: std.Random) void {
        if (self.betting_strategy == .random) {
            const units = rng.intRangeAtMost(u32, 1, 8);
            self.bet = self.table_minimum * @as(f64, @floatFromInt(units));
        }
    }

    pub fn resetBetAfterLoss(self: *Player) void {
        self.wins_streak = 0;
        self.bet = self.table_minimum;
    }

    pub fn recordPush(self: *Player) void {
        self.wins_streak = 0;
        self.bet = self.table_minimum;
    }

    pub fn reset(self: *Player, starting_bankroll: f64) void {
        self.bankroll = starting_bankroll;
        self.bet = self.table_minimum;
        self.wins_streak = 0;
        self.wins = 0;
        self.losses = 0;
        self.pushes = 0;
    }
};