const std = @import("std");

pub const GameResult = struct {
    total_hands: u32,
    player_wins: u32,
    player_losses: u32,
    ties: u32,
    max_bet: f64,
    winnings: f64,
    final_bankroll: f64,
    starting_bankroll: f64,

    pub fn init(
        total_hands: u32,
        player_wins: u32,
        player_losses: u32,
        ties: u32,
        max_bet: f64,
        winnings: f64,
        final_bankroll: f64,
        starting_bankroll: f64,
    ) GameResult {
        return GameResult{
            .total_hands = total_hands,
            .player_wins = player_wins,
            .player_losses = player_losses,
            .ties = ties,
            .max_bet = max_bet,
            .winnings = winnings,
            .final_bankroll = final_bankroll,
            .starting_bankroll = starting_bankroll,
        };
    }

    pub fn getNetWinnings(self: GameResult) f64 {
        return self.final_bankroll - self.starting_bankroll;
    }

    pub fn getWinRate(self: GameResult) f64 {
        if (self.total_hands == 0) return 0.0;
        return @as(f64, @floatFromInt(self.player_wins)) / @as(f64, @floatFromInt(self.total_hands));
    }
};