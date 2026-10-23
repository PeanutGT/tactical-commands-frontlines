shader_type canvas_item;
// Ground for a StylePack with terrain textures. `cells` (also the sprite's
// texture, which sets its size) holds one texel per cell: R = Terrain.Type,
// G = height level, B = 1 where a bridge deck runs left-right. Ground
// pictures come from `ground`, one layer each.

uniform sampler2D cells : filter_nearest;
uniform sampler2DArray ground : filter_linear_mipmap, repeat_enable;
uniform vec2 map_size;
// Cells covered by one repeat of a ground picture.
uniform float tile_cells = 8.0;
// Texture layer and colour multiplier per Terrain.Type.
uniform int layer_of[11];
uniform vec4 tint_of[11];
// Brightness per height level 0..3.
uniform float height_shade[4];
uniform vec4 contour_color : source_color;
// Contour line width, in cells.
uniform float contour_width = 0.12;
// Width of the soft border between two terrain types, in cells.
uniform float blend_width = 0.3;
// How far borders wander from the cell grid, in cells.
uniform float edge_wobble = 0.22;

// Gap between buildings and their drop shadow, in cells.
uniform float alley = 0.09;
uniform vec2 roof_shadow = vec2(0.12, 0.14);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

vec3 cell_data(ivec2 c) {
	c = clamp(c, ivec2(0), ivec2(map_size) - 1);
	return texelFetch(cells, c, 0).rgb * 255.0;
}

// Ground colour of terrain `t` at `p` (cells). Two samples at different
// scales are mixed by a slow noise so the repeat is hard to spot.
vec3 ground_color(int t, vec2 p, bool across) {
	vec2 uv = p / tile_cells;
	if (t == 4) {
		// Ground between buildings: darkened pavement. Roofs go on top.
		return texture(ground, vec3(uv, float(layer_of[2]))).rgb * 0.78;
	}
	float layer = float(layer_of[t]);
	vec3 a;
	if (t == 9) {
		// Bridge decks are painted running up-down.
		a = texture(ground, vec3(across ? uv.yx : uv, layer)).rgb;
	} else {
		a = texture(ground, vec3(uv, layer)).rgb;
		vec3 b = texture(ground, vec3(uv * 0.71 + vec2(0.37, 0.59), layer)).rgb;
		a = mix(a, b, smoothstep(0.35, 0.65, value_noise(p * 0.09)));
	}
	return a * tint_of[t].rgb;
}

// Building cells pair up with a neighbour (across or down, picked per 2×2
// block) into one 20 × 40 m building, or stand alone. Writes the roof
// rectangle in cells and an id for the building; false if `c` is no building.
bool roof_of(ivec2 c, out vec2 rmin, out vec2 rmax, out vec2 id) {
	if (int(round(cell_data(c).r)) != 4) {
		return false;
	}
	vec2 block = vec2(c / 2);
	ivec2 partner = hash(block) < 0.5 ? ivec2(c.x ^ 1, c.y) : ivec2(c.x, c.y ^ 1);
	bool paired = hash(block + 7.3) < 0.75 && int(round(cell_data(partner).r)) == 4;
	vec2 lo = vec2(paired ? min(c, partner) : c);
	vec2 hi = vec2(paired ? max(c, partner) : c) + 1.0;
	rmin = lo + alley * 0.5;
	rmax = hi - alley * 0.5;
	id = lo * 1.37 + hi * 0.71;
	return true;
}

// Painted roof at `p` inside the roof [rmin, rmax]: flat with a lip and a
// rooftop unit, or pitched with the half facing the top-left light brighter.
vec3 roof_color(vec2 p, vec2 rmin, vec2 rmax, vec2 id) {
	float h = hash(id);
	vec3 base = h < 0.3 ? vec3(0.58, 0.58, 0.56) : (h < 0.55 ? vec3(0.40, 0.42, 0.46) : (h < 0.8 ? vec3(0.60, 0.40, 0.32) : vec3(0.33, 0.33, 0.35)));
	base *= 0.9 + 0.2 * hash(id + 3.1);
	// Grain from the painted rooftops picture.
	vec3 grain = texture(ground, vec3(p / tile_cells, float(layer_of[4]))).rgb;
	base *= 0.8 + 0.5 * (dot(grain, vec3(0.333)) - 0.35);
	vec2 size = rmax - rmin;
	vec2 l = (p - rmin) / size;
	float edge = min(min(p.x - rmin.x, rmax.x - p.x), min(p.y - rmin.y, rmax.y - p.y));
	vec3 col;
	if (hash(id + 11.7) < 0.6) {
		// Pitched: ridge along the long side.
		bool along_x = size.x >= size.y;
		float u = along_x ? l.y : l.x;
		col = base * (u < 0.5 ? 1.1 : 0.78);
		col = mix(col, base * 0.55, 1.0 - smoothstep(0.0, 0.025, abs(u - 0.5) * min(size.x, size.y)));
	} else {
		col = base * 0.95;
		col = mix(col, base * 1.15, 1.0 - smoothstep(0.03, 0.06, edge));
		vec2 unit = rmin + size * vec2(0.25 + 0.5 * hash(id + 5.0), 0.25 + 0.5 * hash(id + 6.0));
		vec2 d = abs(p - unit);
		if (max(d.x, d.y) < 0.09) {
			col = (p.x - unit.x + p.y - unit.y < 0.0) ? vec3(0.75) : vec3(0.5);
		}
	}
	return mix(col, vec3(0.12), 1.0 - smoothstep(0.0, 0.022, edge));
}

void fragment() {
	vec2 p = UV * map_size;
	// Borders between terrain types: blend the four nearest cells, with the
	// sample point nudged by noise so edges are not ruler-straight.
	vec2 q = p + (vec2(value_noise(p * 1.7), value_noise(p * 1.7 + 19.3)) - 0.5) * edge_wobble * 2.0;
	vec2 g = q - 0.5;
	ivec2 base = ivec2(floor(g));
	vec2 f = smoothstep(vec2(0.5 - blend_width * 0.5), vec2(0.5 + blend_width * 0.5), fract(g));
	vec3 c00 = cell_data(base);
	vec3 c10 = cell_data(base + ivec2(1, 0));
	vec3 c01 = cell_data(base + ivec2(0, 1));
	vec3 c11 = cell_data(base + ivec2(1, 1));
	int t00 = int(round(c00.r));
	int t10 = int(round(c10.r));
	int t01 = int(round(c01.r));
	int t11 = int(round(c11.r));
	vec4 w = vec4((1.0 - f.x) * (1.0 - f.y), f.x * (1.0 - f.y), (1.0 - f.x) * f.y, f.x * f.y);
	vec3 col;
	if (t00 == t10 && t00 == t01 && t00 == t11) {
		col = ground_color(t00, p, cell_data(ivec2(floor(p))).b > 0.5);
	} else {
		col = ground_color(t00, p, c00.b > 0.5) * w.x + ground_color(t10, p, c10.b > 0.5) * w.y
			+ ground_color(t01, p, c01.b > 0.5) * w.z + ground_color(t11, p, c11.b > 0.5) * w.w;
	}
	// Height shading, smoothed the same way.
	float shade = height_shade[int(round(c00.g))] * w.x + height_shade[int(round(c10.g))] * w.y
		+ height_shade[int(round(c01.g))] * w.z + height_shade[int(round(c11.g))] * w.w;
	col *= shade;

	// Buildings: drop shadow towards the bottom-right, then the roof.
	vec2 rmin;
	vec2 rmax;
	vec2 id;
	vec2 sp = p - roof_shadow;
	if (roof_of(ivec2(floor(sp)), rmin, rmax, id) && all(greaterThan(sp, rmin)) && all(lessThan(sp, rmax))) {
		col *= 0.55;
	}
	if (roof_of(ivec2(floor(p)), rmin, rmax, id) && all(greaterThan(p, rmin)) && all(lessThan(p, rmax))) {
		col = roof_color(p, rmin, rmax, id) * shade;
	}

	// Contour lines on cell edges where the height level changes.
	ivec2 c = ivec2(floor(p));
	vec2 l = fract(p);
	float e = cell_data(c).g;
	float d = 1.0;
	if (cell_data(c + ivec2(-1, 0)).g != e) d = min(d, l.x);
	if (cell_data(c + ivec2(1, 0)).g != e) d = min(d, 1.0 - l.x);
	if (cell_data(c + ivec2(0, -1)).g != e) d = min(d, l.y);
	if (cell_data(c + ivec2(0, 1)).g != e) d = min(d, 1.0 - l.y);
	float aa = fwidth(p.x);
	float line = 1.0 - smoothstep(contour_width * 0.5 - aa, contour_width * 0.5 + aa, d);
	col = mix(col, contour_color.rgb, line * contour_color.a);
	COLOR = vec4(col, 1.0);
}
