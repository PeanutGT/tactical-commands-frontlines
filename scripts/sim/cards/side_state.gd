class_name SideState
extends RefCounted
## One side's supply and card cycle (sections 6 and 7). A card is in exactly
## one place: the draw pile, a hand slot, on the field (a living unit), in a
## running support effect, or cooling down.

## Hand slot with no card in it.
const EMPTY: StringName = &""

var supply: float = 0.0
## Draw pile, top first.
var deck: Array[StringName] = []
## Fixed slots; a played card's slot is refilled from the top of the deck.
var hand: Array[StringName] = []
## Cards waiting to go back to the bottom of the deck: [card id, ticks left].
var cooldowns: Array = []
## Support cards whose effect is still running: [card id, ticks left].
var effects: Array = []


## Shuffles `cards` with `rng` and deals the hand.
func setup(cards: Array[StringName], hand_size: int, start_supply: float, rng: SimRng) -> void:
	deck = cards.duplicate()
	for i: int in range(deck.size() - 1, 0, -1):
		var j: int = rng.next_int(i + 1)
		var tmp: StringName = deck[i]
		deck[i] = deck[j]
		deck[j] = tmp
	hand = []
	hand.resize(hand_size)
	hand.fill(EMPTY)
	supply = start_supply
	refill()


## Fills empty hand slots from the top of the deck, left to right.
func refill() -> void:
	for i: int in hand.size():
		if hand[i] == EMPTY and not deck.is_empty():
			hand[i] = deck.pop_front()


## Takes the card out of hand slot `slot` and draws a replacement.
func play(slot: int) -> StringName:
	var id: StringName = hand[slot]
	hand[slot] = EMPTY
	refill()
	return id


## Puts a card at the bottom of the deck, straight into an empty hand slot
## when the deck had run dry.
func return_card(id: StringName) -> void:
	deck.append(id)
	refill()


func start_cooldown(id: StringName, ticks: int) -> void:
	if ticks <= 0:
		return_card(id)
	else:
		cooldowns.append([id, ticks])


## Counts cooldowns down one tick; returns finished cards to the deck in the
## order they started cooling.
func tick_cooldowns() -> void:
	var still: Array = []
	for c: Array in cooldowns:
		c[1] -= 1
		if c[1] <= 0:
			return_card(c[0])
		else:
			still.append(c)
	cooldowns = still


func gain(amount: float, cap: float) -> void:
	supply = minf(cap, supply + amount)
