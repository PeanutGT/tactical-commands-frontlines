class_name SupportEffect
extends RefCounted
## A support card in play (section 8 支援卡效果). Its card goes back to the
## bottom of the deck when the effect ends.

var card: StringName = &""
var side: int = GameMap.Side.PLAYER
## Cell the card was dropped on.
var cell: Vector2i = Vector2i.ZERO
## Ticks until the shells land (砲擊, 彈幕射擊); 0 once landed or for none.
var delay: int = 0
## Ticks the effect still runs after landing; at 0 it ends.
var ticks_left: int = 0
## Unit the card was played on (附加裝甲), 0 for none.
var target_id: int = 0
## 彈幕射擊: direction the line of shells runs along.
var dir: Vector2 = Vector2.RIGHT


## For replay checks.
func hash_parts() -> Array:
	return [card, side, cell, delay, ticks_left, target_id, dir]
