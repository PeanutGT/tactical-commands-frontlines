class_name Card
extends RefCounted
## The card pool (sections 7 and 8). A card id is either a unit card
## (`UnitType.CARDS`) or a support card (`SUPPORT` below). Static data only.

## Where a support card must be dropped.
## ANYWHERE: any cell on the map. SEEN: a cell the side can see now.
## OWN_POINT: next to a point the side holds (運補車隊 starts there).
## ENEMY: on or next to an enemy unit the side can see, or on a bridge.
## OWN_ARMOR: on or next to one of the side's own armoured units.
enum Aim { ANYWHERE, SEEN, OWN_POINT, ENEMY, OWN_ARMOR }

## Section 8 support cards. Air strikes, minefields and jamming wait for M7.
## Columns: id, name, faction, cost, aim.
const SUPPORT: Array = [
	[&"supply_convoy", "運補車隊", &"common", 1, Aim.OWN_POINT],
	[&"smoke", "煙霧彈", &"common", 2, Aim.ANYWHERE],
	[&"artillery", "砲擊", &"common", 4, Aim.SEEN],
	[&"drone_recon", "無人機偵察", &"alliance", 2, Aim.ANYWHERE],
	[&"precision_missile", "精準飛彈", &"alliance", 3, Aim.ENEMY],
	[&"aps", "主動防護系統", &"alliance", 3, Aim.ANYWHERE],
	[&"call_reserves", "召集預備隊", &"federation", 2, Aim.ANYWHERE],
	[&"barrage", "彈幕射擊", &"federation", 5, Aim.SEEN],
	[&"armored_assault", "裝甲突擊", &"armor_corps", 3, Aim.ANYWHERE],
	[&"field_repair", "戰場維修", &"armor_corps", 2, Aim.OWN_ARMOR],
	[&"addon_armor", "附加裝甲", &"armor_corps", 3, Aim.OWN_ARMOR],
]
## One-line effect per support card, for tooltips.
const SUPPORT_TEXT: Dictionary[StringName, String] = {
	&"supply_convoy": "派一輛卡車從己方據點開到另一個己方據點或總部，抵達才給補給：每 10 格 +1（1～6）；被打掉就沒有",
	&"smoke": "半徑 4 格擋視線 12 秒",
	&"artillery": "3 秒後落彈，半徑 3 格、120 傷害；要落在己方視野內",
	&"drone_recon": "指定區域開視野 15 秒，半徑 10 格",
	&"precision_missile": "視野內單一目標 250 傷害（也能打橋）",
	&"aps": "半徑 6 格友軍裝甲受反裝甲傷害 −50%，10 秒",
	&"call_reserves": "所有冷卻中的卡剩餘冷卻減半",
	&"barrage": "4 秒後沿 12 格直線落彈，90 傷害",
	&"armored_assault": "半徑 10 格友軍裝甲移速 +40%，10 秒",
	&"field_repair": "指定友軍裝甲立即回 300 血",
	&"addon_armor": "指定友軍裝甲獲得 200 護盾，打破或 30 秒後消失",
}

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


static func aim(id: StringName) -> Aim:
	var row: Variant = _support_row(id)
	return Aim.ANYWHERE if row == null else row[4]


static func faction(id: StringName) -> StringName:
	if is_unit(id):
		return UnitType.of(id).faction
	var row: Variant = _support_row(id)
	return &"" if row == null else row[2]


## A played unit card waits cost × 3 s before going back to the deck.
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
