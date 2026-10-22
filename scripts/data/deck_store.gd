class_name DeckStore
extends RefCounted
## Remembers the player's last deck between runs, and supplies a starter deck.

const PATH: String = "user://deck.json"
## Starter picks, used in order until the deck is full.
const STARTER: Array[StringName] = [
	&"infantry", &"apc", &"tank", &"scout_car", &"javelin", &"bazooka", &"mortar", &"supply_convoy",
	&"conscripts", &"engineer", &"ifv", &"light_tank",
]


## The saved deck when it is still legal for `size`, else a starter deck.
static func load_deck(size: int) -> Array[StringName]:
	var saved: Array[StringName] = []
	var f: FileAccess = FileAccess.open(PATH, FileAccess.READ)
	if f != null:
		var data: Variant = JSON.parse_string(f.get_as_text())
		if data is Array:
			for id: Variant in data:
				saved.append(StringName(str(id)))
	if Card.validate_deck(saved, size) == "":
		return saved
	return starter(size)


static func save_deck(deck: Array[StringName]) -> void:
	var f: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(deck.map(func(id: StringName) -> String: return str(id))))


static func starter(size: int) -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in STARTER + Card.pool():
		if out.size() == size:
			break
		if not out.has(id):
			out.append(id)
	return out
