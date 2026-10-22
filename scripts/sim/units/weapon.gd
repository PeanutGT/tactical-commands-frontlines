class_name Weapon
extends RefCounted
## A unit's gun (section 9). Range and blast radius are in metres; damage and
## cooldown do not scale with the map.

var damage: float = 0.0
var range_m: float = 0.0
var cooldown_sec: float = 1.0
## Damage multiplier against each UnitType.Kind.
var vs_infantry: float = 1.0
var vs_armor: float = 1.0
## Blast radius around the impact; 0 means a direct hit on the target only.
var splash_m: float = 0.0


func _init(p_damage: float = 0.0, p_range_m: float = 0.0, p_cooldown_sec: float = 1.0, p_vs_infantry: float = 1.0, p_vs_armor: float = 1.0) -> void:
	damage = p_damage
	range_m = p_range_m
	cooldown_sec = p_cooldown_sec
	vs_infantry = p_vs_infantry
	vs_armor = p_vs_armor


func is_area() -> bool:
	return splash_m > 0.0


func multiplier(kind: UnitType.Kind) -> float:
	return vs_armor if kind == UnitType.Kind.ARMOR else vs_infantry
