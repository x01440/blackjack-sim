pub const GameConstants = struct {
    // Default values for command line parameters
    pub const default_starting_bankroll: f64 = 1000.0;
    pub const default_table_minimum: f64 = 10.0;
    pub const default_max_spots: u8 = 5;
    pub const default_num_decks: u8 = 6;
    pub const default_attempts: u32 = 1;

    // Game behavior constants
    pub const quit_threshold: f64 = 2000.0;

    // Valid deck options
    pub const valid_deck_counts = [_]u8{ 2, 6 };

    // Betting strategy multipliers
    pub const blackjack_payout: f64 = 2.5;
    pub const standard_win_payout: f64 = 2.0;
    pub const push_payout: f64 = 1.0; // Return original bet

    // Simulation parameters
    pub const verbose: bool = false;
};
