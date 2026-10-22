class_name Card
extends RefCounted
## The card pool (sections 7 and 8). A card id is either a unit card
## (`UnitType.CARDS`) or a support card (`SUPPORT` below). Static data only.

## Support cards in the pool now. The rest of section 8's support cards come
## with their effects in M6. Columns: id, name, faction, cost.
const SUPPORT: Array = [
	[&"supply_convoy", "運補車隊", &"common", 1],
]
## 運補車隊: 4 supply after 3 s.
const CONVOY_DELAY_SEC: float = 3.0
const CONVOY_SUPPLY: float = 4.0

const FACTIONS: Array[StringName] = [&"common", &"alliance", &"federation", &"armor_corps"]
const FACTION_NAMES: Dictionary[StringName, String] = {
	&"common": "通用", &"alliance": "聯盟", &"federation": "聯邦", &"armor_corps": "裝甲軍團",
}


## Every card a deck may hold, unit cards first. Air units wait for M7.
static func pool() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in UnitType.ids():
		if UnitType.of(id).kind != UnitType.Kind.AIR:
			out.append(id)
	for row: Array in SUPPORT:
		out.append(row[0])
	return out


static func is_unit(id: StringName) -> bool:
	return UnitType.ids().has(id)


static func is_support(id: StringName) -> bool:
	return _support_row(id) != null


static func cost(id: StringName) -> int:
	if is_unit(id):
		return UnitType.of(id).cost
	var row: Variant = _support_row(id)
	return 0 if row == null else row[3]


## Support cards weigh nothing.
static func weight(id: StringName) -> int:
	return UnitType.of(id).weight if is_unit(id) else 0


static func display_name(id: StringName) -> String:
	if is_unit(id):
		return UnitType.of(id).display_name
	var row: Variant = _support_row(id)
	return "" if row == null else row[1]


static func faction(id: StringName) -> StringName:
	if is_unit(id):
		return UnitType.of(id).faction
	var row: Variant = _support_row(id)
	return &"" if row == null else row[2]


## Section 7: a unit card that died waits cost × 3 s before going back.
static func cooldown_sec(id: StringName) -> float:
	return cost(id) * 3.0


## "" when `deck` is a legal deck of `size` cards, else why not. Any mix of
## factions; each card at most once.
static func validate_deck(deck: Array[StringName], size: int) -> String:
	if deck.size() != size:
		return "牌組要 %d 張，目前 %d 張" % [size, deck.size()]
	var p: Array[StringName] = pool()
	var seen: Dictionary[StringName, bool] = {}
	for id: StringName in deck:
		if not p.has(id):
			return "卡池沒有 %s" % id
		if seen.has(id):
			return "%s 重複" % display_name(id)
		seen[id] = true
	return ""


static func _support_row(id: StringName) -> Variant:
	for row: Array in SUPPORT:
		if row[0] == id:
			return row
	return null
