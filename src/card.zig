const std = @import("std");

pub const Card = struct {
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

pub const Hand = struct {
    hands: std.ArrayList(std.ArrayList(Card)),
    split_flags: std.ArrayList(bool),
    double_flags: std.ArrayList(bool),
    bets: std.ArrayList(f64),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, initial_bet: f64) Hand {
        var hand = Hand{
            .hands = std.ArrayList(std.ArrayList(Card)).init(allocator),
            .split_flags = std.ArrayList(bool).init(allocator),
            .double_flags = std.ArrayList(bool).init(allocator),
            .bets = std.ArrayList(f64).init(allocator),
            .allocator = allocator,
        };
        // Start with one hand
        hand.hands.append(std.ArrayList(Card).init(allocator)) catch unreachable;
        hand.split_flags.append(false) catch unreachable;
        hand.double_flags.append(false) catch unreachable;
        hand.bets.append(initial_bet) catch unreachable;
        return hand;
    }

    pub fn deinit(self: *Hand) void {
        for (self.hands.items) |*hand| {
            hand.deinit();
        }
        self.hands.deinit();
        self.split_flags.deinit();
        self.double_flags.deinit();
        self.bets.deinit();
    }
    
    pub fn getHandCount(self: Hand) usize {
        return self.hands.items.len;
    }
    
    pub fn getHand(self: *Hand, index: usize) ?*std.ArrayList(Card) {
        if (index >= self.hands.items.len) return null;
        return &self.hands.items[index];
    }
    
    pub fn canSplit(self: Hand, hand_index: usize) bool {
        if (hand_index >= self.hands.items.len) return false;
        const hand = &self.hands.items[hand_index];
        return hand.items.len == 2 and 
               hand.items[0].rank == hand.items[1].rank and 
               !self.split_flags.items[hand_index];
    }
    
    pub fn split(self: *Hand, hand_index: usize) !void {
        if (!self.canSplit(hand_index)) return error.CannotSplit;
        
        var original_hand = &self.hands.items[hand_index];
        
        // Create new hand and move second card
        var new_hand = std.ArrayList(Card).init(self.allocator);
        const second_card = original_hand.pop() orelse return error.CannotSplit;
        try new_hand.append(second_card);
        
        // Get the original bet amount for the split hand
        const original_bet = self.bets.items[hand_index];
        
        // Add the new hand with same bet amount
        try self.hands.append(new_hand);
        try self.split_flags.append(true);
        try self.double_flags.append(false);
        try self.bets.append(original_bet);
        
        // Mark original hand as split too
        self.split_flags.items[hand_index] = true;
    }
    
    pub fn addCard(self: *Hand, hand_index: usize, card: Card) !void {
        if (hand_index >= self.hands.items.len) return error.InvalidHandIndex;
        try self.hands.items[hand_index].append(card);
    }
    
    pub fn setDoubled(self: *Hand, hand_index: usize) !void {
        if (hand_index >= self.double_flags.items.len) return error.InvalidHandIndex;
        self.double_flags.items[hand_index] = true;
        // Double the bet for this hand
        self.bets.items[hand_index] *= 2;
    }
    
    pub fn isDoubled(self: Hand, hand_index: usize) bool {
        if (hand_index >= self.double_flags.items.len) return false;
        return self.double_flags.items[hand_index];
    }
    
    pub fn isSplit(self: Hand, hand_index: usize) bool {
        if (hand_index >= self.split_flags.items.len) return false;
        return self.split_flags.items[hand_index];
    }
    
    pub fn getBet(self: Hand, hand_index: usize) f64 {
        if (hand_index >= self.bets.items.len) return 0.0;
        return self.bets.items[hand_index];
    }
    
    pub fn getTotalBetAmount(self: Hand) f64 {
        var total: f64 = 0.0;
        for (self.bets.items) |bet| {
            total += bet;
        }
        return total;
    }

    pub fn getValue(self: Hand, hand_index: usize) u8 {
        if (hand_index >= self.hands.items.len) return 0;
        
        var value: u8 = 0;
        var aces: u8 = 0;

        for (self.hands.items[hand_index].items) |card| {
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

    pub fn isBlackjack(self: Hand, hand_index: usize) bool {
        if (hand_index >= self.hands.items.len) return false;
        return self.hands.items[hand_index].items.len == 2 and self.getValue(hand_index) == 21;
    }

    pub fn isBust(self: Hand, hand_index: usize) bool {
        return self.getValue(hand_index) > 21;
    }
    
    pub fn isSoft(self: Hand, hand_index: usize) bool {
        if (hand_index >= self.hands.items.len) return false;
        
        var aces: u8 = 0;
        var value: u8 = 0;
        
        for (self.hands.items[hand_index].items) |card| {
            if (card.isAce()) {
                aces += 1;
                value += 11;
            } else {
                value += card.getValue();
            }
        }
        
        // It's soft if we have at least one ace counting as 11
        return aces > 0 and value <= 21;
    }
    
    pub fn isPair(self: Hand, hand_index: usize) bool {
        if (hand_index >= self.hands.items.len) return false;
        const hand = &self.hands.items[hand_index];
        if (hand.items.len != 2) return false;
        return hand.items[0].rank == hand.items[1].rank;
    }
    
    pub fn getStrategyKey(self: Hand, hand_index: usize) u8 {
        if (hand_index >= self.hands.items.len) return 0;
        
        if (self.isPair(hand_index)) {
            // Pairs: 200 + rank (202 for 22, 210 for TT, 201 for AA)
            var rank = self.hands.items[hand_index].items[0].rank;
            if (rank > 10) rank = 10; // Face cards become 10
            return 200 + rank;
        } else if (self.isSoft(hand_index) and self.hands.items[hand_index].items.len == 2) {
            // Soft hands: 100 + non-ace card value
            for (self.hands.items[hand_index].items) |card| {
                if (!card.isAce()) {
                    var value = card.rank;
                    if (value > 10) value = 10; // Face cards = 10
                    return 100 + value;
                }
            }
            return 101; // A-A case, but this should be handled as pair
        } else {
            // Hard totals: just the total value
            return self.getValue(hand_index);
        }
    }
};