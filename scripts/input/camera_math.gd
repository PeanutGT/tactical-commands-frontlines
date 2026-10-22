class_name CameraMath
extends RefCounted
## Pure camera maths for a centre-anchored Camera2D:
##   world = position + (screen - view / 2) / zoom


static func screen_to_world(cam_pos: Vector2, view: Vector2, zoom: float, screen: Vector2) -> Vector2:
	return cam_pos + (screen - view * 0.5) / zoom


## Camera position that keeps the world point under `screen` fixed when zoom
## changes from `zoom` to `next_zoom`.
static func position_for_zoom_at(cam_pos: Vector2, view: Vector2, zoom: float, next_zoom: float, screen: Vector2) -> Vector2:
	var world: Vector2 = screen_to_world(cam_pos, view, zoom, screen)
	return world - (screen - view * 0.5) / next_zoom


## Zoom that fits the whole world inside the view.
static func fit_zoom(view: Vector2, world: Vector2) -> float:
	return minf(view.x / world.x, view.y / world.y)


## Keeps the view inside the world; on an axis where the world is smaller
## than the view, centres the world instead.
static func clamp_position(cam_pos: Vector2, view: Vector2, zoom: float, world: Vector2) -> Vector2:
	var half: Vector2 = view * 0.5 / zoom
	var out: Vector2 = cam_pos
	for axis: int in 2:
		if world[axis] <= half[axis] * 2.0:
			out[axis] = world[axis] * 0.5
		else:
			out[axis] = clampf(cam_pos[axis], half[axis], world[axis] - half[axis])
	return out
