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
    
    pub fn isSoft(self: Hand) bool {
        var aces: u8 = 0;
        var value: u8 = 0;
        
        for (self.cards.items) |card| {
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
    
    pub fn isPair(self: Hand) bool {
        if (self.cards.items.len != 2) return false;
        return self.cards.items[0].rank == self.cards.items[1].rank;
    }
    
    pub fn getStrategyKey(self: Hand) u8 {
        if (self.isPair()) {
            // Pairs: 200 + rank (202 for 22, 210 for TT, 201 for AA)
            var rank = self.cards.items[0].rank;
            if (rank > 10) rank = 10; // Face cards become 10
            return 200 + rank;
        } else if (self.isSoft() and self.cards.items.len == 2) {
            // Soft hands: 100 + non-ace card value
            for (self.cards.items) |card| {
                if (!card.isAce()) {
                    var value = card.rank;
                    if (value > 10) value = 10; // Face cards = 10
                    return 100 + value;
                }
            }
            return 101; // A-A case, but this should be handled as pair
        } else {
            // Hard totals: just the total value
            return self.getValue();
        }
    }
};