class_name Weapon
extends RefCounted
## A unit's gun (section 9). Range and blast radius are in metres; damage,
## penetration and cooldown do not scale with the map.

## What the weapon may shoot at. The doc's "（對裝甲）", "（對步兵）" and
## "（只對空）" are target limits, not damage multipliers.
enum Targets { GROUND, ARMOR_ONLY, INFANTRY_ONLY, AIR_ONLY }

## Each point of armour above the penetration takes a third off the damage,
## so this many points short does nothing.
const PEN_ZERO_AT: float = 3.0

var damage: float = 0.0
var range_m: float = 0.0
## Seconds between volleys.
var cooldown_sec: float = 1.0
var penetration: int = 0
## Organization taken off the target per hit (before cover and penetration).
var suppression: float = 0.0
var targets: Targets = Targets.GROUND
## Blast radius around the impact; 0 means a direct hit on the target only.
var splash_m: float = 0.0
## Shots per volley, `burst_interval_sec` apart (多管火箭車 fires 6).
var burst: int = 1
var burst_interval_sec: float = 0.5


func _init(p_damage: float = 0.0, p_range_m: float = 0.0, p_cooldown_sec: float = 1.0, p_penetration: int = 0, p_suppression: float = 0.0) -> void:
	damage = p_damage
	range_m = p_range_m
	cooldown_sec = p_cooldown_sec
	penetration = p_penetration
	suppression = p_suppression


func is_area() -> bool:
	return splash_m > 0.0


## Share of damage and suppression that gets through `armor`.
static func pen_factor(penetration: int, armor: int) -> float:
	var short: int = armor - penetration
	return clampf(1.0 - float(short) / PEN_ZERO_AT, 0.0, 1.0)


func may_target(kind: UnitType.Kind) -> bool:
	match targets:
		Targets.ARMOR_ONLY:
			return kind == UnitType.Kind.ARMOR
		Targets.INFANTRY_ONLY:
			return kind == UnitType.Kind.INFANTRY
		Targets.AIR_ONLY:
			return kind == UnitType.Kind.AIR
	return kind != UnitType.Kind.AIR
