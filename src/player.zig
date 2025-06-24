const std = @import("std");

pub const BettingStrategy = enum {
    flat,
    increase_after_win,
    high_increase_after_win,
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
        self.wins += 1;

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