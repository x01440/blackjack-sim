const std = @import("std");
const Card = @import("card.zig").Card;

pub const Deck = struct {
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
        const min_remaining = total_cards * 15 / 100; // 15% remaining
        const max_remaining = total_cards * 20 / 100; // 20% remaining
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