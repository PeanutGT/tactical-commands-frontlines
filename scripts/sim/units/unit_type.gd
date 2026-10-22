class_name UnitType
extends RefCounted
## Static stats of a unit card (section 8). One card is one formation: HP is
## its strength, drawn as `figures` soldiers or vehicles. Distances are stored
## in metres (section 4.3) and converted per map by the simulation.

enum Kind { INFANTRY, ARMOR, AIR }
## 班 squad, 排 platoon, 連 company or battery.
enum Echelon { SQUAD, PLATOON, COMPANY }

var id: StringName = &""
var display_name: String = ""
var faction: StringName = &""
var kind: Kind = Kind.INFANTRY
## Vehicles use the vehicle columns of the terrain table (no fords, slow in forest).
var vehicle: bool = false
var echelon: Echelon = Echelon.SQUAD
## Soldiers or vehicles drawn at full strength.
var figures: int = 1
var speed_mps: float = 0.0
var vision_m: float = 0.0
var max_hp: float = 100.0
var armor: int = 0
## Organization (組織度) at full rest.
var max_org: float = 100.0
var cost: int = 0
## Deployment weight; killing a friendly costs weight × 5 score (section 11).
var weight: int = 1
## Null for unarmed units.
var weapon: Weapon = null
## Infantry weight it can carry (section 9 搭載), 0 for none.
var transport_capacity: int = 0


func _init(p_id: StringName = &"", p_name: String = "", p_kind: Kind = Kind.INFANTRY, p_speed_mps: float = 0.0) -> void:
	id = p_id
	display_name = p_name
	kind = p_kind
	vehicle = p_kind != Kind.INFANTRY
	speed_mps = p_speed_mps


## Only infantry can hold position (section 9).
func can_hold() -> bool:
	return kind == Kind.INFANTRY


## Soldiers or vehicles still standing at `hp`; a scratched formation keeps all.
func figures_at(hp: float) -> int:
	if hp <= 0.0:
		return 0
	return clampi(ceili(hp / max_hp * figures), 1, figures)


# --- Card data --------------------------------------------------------------
# Section 8 starting values, distances in standard cells (20 m). Columns:
# id, name, faction, cost, weight, kind, echelon, figures, hp, armour, org,
# speed, vision, weapon. Weapon: damage, range, cooldown s, penetration,
# suppression, targets, splash cells, burst. Formation, armour, org,
# penetration, suppression and cooldown are invented starting values.

const I: Kind = Kind.INFANTRY
const A: Kind = Kind.ARMOR
const AIR: Kind = Kind.AIR
const SQ: Echelon = Echelon.SQUAD
const PL: Echelon = Echelon.PLATOON
const CO: Echelon = Echelon.COMPANY
const G: Weapon.Targets = Weapon.Targets.GROUND
const AO: Weapon.Targets = Weapon.Targets.ARMOR_ONLY
const IO: Weapon.Targets = Weapon.Targets.INFANTRY_ONLY
const AA: Weapon.Targets = Weapon.Targets.AIR_ONLY

const CARDS: Array = [
	# 通用
	[&"infantry", "步兵班", &"common", 2, 2, I, SQ, 9, 100, 0, 100, 1.5, 7, [10, 5, 1.0, 1, 15, G, 0, 1]],
	[&"engineer", "工兵班", &"common", 3, 2, I, SQ, 8, 90, 0, 100, 1.5, 7, [8, 4, 1.0, 1, 12, G, 0, 1]],
	[&"scout_car", "偵察車", &"common", 2, 2, A, PL, 4, 110, 2, 90, 3.5, 12, [8, 5, 0.5, 3, 8, G, 0, 1]],
	[&"apc", "裝甲運兵車", &"common", 3, 3, A, PL, 4, 260, 5, 100, 2.6, 8, [15, 6, 1.0, 5, 12, G, 0, 1]],
	[&"tank", "主戰坦克", &"common", 6, 5, A, PL, 4, 520, 14, 130, 2.0, 8, [50, 8, 3.0, 18, 30, G, 0, 1]],
	[&"spg", "自走砲", &"common", 5, 5, A, CO, 6, 150, 3, 80, 1.5, 5, [60, 18, 6.0, 6, 50, G, 2.0, 1]],
	[&"aa_vehicle", "防空車", &"common", 4, 3, A, PL, 4, 200, 3, 90, 2.5, 9, [35, 10, 1.5, 6, 10, AA, 0, 1]],
	# 聯盟
	[&"sf_recon", "特種偵察組", &"alliance", 3, 2, I, SQ, 4, 70, 0, 130, 1.8, 12, [8, 5, 1.0, 1, 10, G, 0, 1]],
	[&"sniper", "狙擊組", &"alliance", 3, 2, I, SQ, 2, 60, 0, 120, 1.4, 10, [35, 12, 4.0, 2, 30, IO, 0, 1]],
	[&"javelin", "標槍反坦克組", &"alliance", 4, 3, I, SQ, 3, 80, 0, 110, 1.3, 7, [45, 8, 4.0, 24, 25, AO, 0, 1]],
	[&"loitering", "遊蕩彈藥小組", &"alliance", 4, 3, I, SQ, 3, 70, 0, 100, 1.3, 7, [70, 14, 8.0, 22, 35, AO, 0, 1]],
	[&"ifv", "步兵戰車", &"alliance", 5, 4, A, PL, 4, 300, 7, 110, 2.5, 8, [20, 6, 1.0, 8, 15, G, 0, 1]],
	[&"attack_heli", "攻擊直升機", &"alliance", 7, 5, AIR, PL, 2, 250, 3, 110, 4.0, 10, [40, 7, 2.0, 18, 30, G, 0, 1]],
	# 聯邦
	[&"conscripts", "動員步兵", &"federation", 1, 1, I, SQ, 10, 70, 0, 60, 1.5, 6, [7, 4, 1.0, 1, 10, G, 0, 1]],
	[&"bazooka", "火箭筒小組", &"federation", 3, 3, I, SQ, 4, 90, 0, 90, 1.3, 7, [40, 5, 4.0, 16, 25, AO, 0, 1]],
	[&"thermobaric", "溫壓火箭組", &"federation", 4, 3, I, SQ, 3, 80, 0, 100, 1.3, 7, [50, 7, 6.0, 4, 60, G, 1.0, 1]],
	[&"heavy_tank", "重型坦克", &"federation", 8, 7, A, CO, 3, 800, 18, 140, 1.4, 7, [60, 7, 3.5, 20, 35, G, 0, 1]],
	[&"mrl", "多管火箭車", &"federation", 6, 5, A, CO, 4, 120, 1, 80, 1.5, 5, [35, 20, 10.0, 4, 30, G, 1.5, 6]],
	[&"transport_heli", "運輸直升機", &"federation", 4, 3, AIR, PL, 2, 300, 2, 80, 4.5, 8, []],
	# 裝甲軍團
	[&"mech_infantry", "機械化步兵班", &"armor_corps", 3, 2, I, SQ, 9, 120, 0, 110, 1.5, 7, [12, 5, 1.0, 1, 15, G, 0, 1]],
	[&"light_tank", "輕型坦克", &"armor_corps", 4, 3, A, PL, 4, 300, 8, 110, 3.0, 9, [30, 7, 2.0, 12, 20, G, 0, 1]],
	[&"tank_destroyer", "坦克殲擊車", &"armor_corps", 5, 4, A, PL, 4, 280, 10, 120, 2.2, 7, [70, 10, 4.0, 22, 25, AO, 0, 1]],
	[&"mortar", "自走迫擊砲", &"armor_corps", 4, 3, A, CO, 4, 160, 3, 90, 2.2, 6, [40, 12, 4.0, 4, 35, G, 1.5, 1]],
	[&"breakthrough_tank", "重型突破坦克", &"armor_corps", 9, 8, A, CO, 3, 1000, 20, 150, 1.2, 7, [65, 7, 3.5, 20, 35, G, 0, 1]],
	[&"bridge_layer", "架橋車", &"armor_corps", 4, 3, A, PL, 2, 250, 6, 80, 2.0, 7, []],
	[&"recovery_vehicle", "戰車救濟車", &"armor_corps", 3, 2, A, PL, 2, 300, 8, 90, 2.4, 7, []],
]


## Artillery that fires over buildings; everything else needs a clear line.
const INDIRECT_FIRE: Array[StringName] = [&"spg", &"mrl", &"mortar"]
## Section 9: infantry weight each transport carries.
const TRANSPORT_CAPACITY: Dictionary[StringName, int] = {&"apc": 4, &"ifv": 2, &"transport_heli": 3}


static func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for row: Array in CARDS:
		out.append(row[0])
	return out


## A fresh copy of a card's stats; null for an unknown id.
static func of(card_id: StringName) -> UnitType:
	for row: Array in CARDS:
		if row[0] == card_id:
			return _from_row(row)
	return null


static func _from_row(row: Array) -> UnitType:
	var t: UnitType = UnitType.new(row[0], row[1], row[5], MapScale.standard_cells_to_meters(row[11]))
	t.faction = row[2]
	t.cost = row[3]
	t.weight = row[4]
	t.echelon = row[6]
	t.figures = row[7]
	t.max_hp = row[8]
	t.armor = row[9]
	t.max_org = row[10]
	t.vision_m = MapScale.standard_cells_to_meters(row[12])
	t.transport_capacity = TRANSPORT_CAPACITY.get(t.id, 0)
	var w: Array = row[13]
	if not w.is_empty():
		t.weapon = Weapon.new(w[0], MapScale.standard_cells_to_meters(w[1]), w[2], w[3], w[4])
		t.weapon.targets = w[5]
		t.weapon.splash_m = MapScale.standard_cells_to_meters(w[6])
		t.weapon.burst = w[7]
		t.weapon.indirect = INDIRECT_FIRE.has(t.id)
	return t


static func infantry() -> UnitType:
	return of(&"infantry")


static func scout_car() -> UnitType:
	return of(&"scout_car")


static func tank() -> UnitType:
	return of(&"tank")


## Area weapon; hits friendlies inside the blast too.
static func mortar() -> UnitType:
	return of(&"mortar")
