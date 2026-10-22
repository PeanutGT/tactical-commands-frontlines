class_name SimRng
extends RefCounted
## Seeded PRNG for the simulation (design doc section 3: every random number
## comes from here so a match replays from its seed and command log).
## xorshift32, kept to 32 bits so results never depend on integer width.

const MASK: int = 0xFFFFFFFF

var state: int = 1


func _init(seed_value: int = 1) -> void:
	state = seed_value & MASK
	if state == 0:
		state = 0x9E3779B9


func next_u32() -> int:
	var x: int = state
	x = (x ^ (x << 13)) & MASK
	x = x ^ (x >> 17)
	x = (x ^ (x << 5)) & MASK
	state = x
	return x


## Uniform integer in [0, n).
func next_int(n: int) -> int:
	return next_u32() % n


## Uniform float in [0, 1).
func next_float() -> float:
	return float(next_u32()) / 4294967296.0
