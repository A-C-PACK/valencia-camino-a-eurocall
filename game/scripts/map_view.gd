extends Control
## The map: real Valencia, drawn from OpenStreetMap by tools/make_map.py.
## Two views share this node -- the whole city, and Ciutat Vella street by
## street -- because the old-town places sit too close together to tell apart
## at city scale. Each place carries its latitude/longitude and its view.

signal picked(index: int)
signal view_changed(view: String)

const PIN := 46.0

var selected := 0
var view := "city"
var _cfg: Dictionary = {}
var _base: TextureRect
var _pins: Array = []
var _overlay: Control
var _zoom: Button       # city view: the frame around the old town
var _back: Button       # centre view: back out to the city


func _ready() -> void:
	clip_contents = true
	var f := FileAccess.open("res://data/map.json", FileAccess.READ)
	if f:
		_cfg = JSON.parse_string(f.get_as_text())
	_base = TextureRect.new()
	_base.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_base.stretch_mode = TextureRect.STRETCH_SCALE
	_base.size = size
	_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_base)

	_zoom = Button.new()
	_zoom.flat = true
	_zoom.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_zoom.focus_mode = Control.FOCUS_NONE
	_zoom.tooltip_text = "Ver el centro histórico de cerca"
	for state in ["normal", "pressed", "focus"]:
		_zoom.add_theme_stylebox_override(state, UI.box(Color(UI.INK, 0.06), 6, UI.INK, 2, 0))
	_zoom.add_theme_stylebox_override("hover", UI.box(Color(UI.ORANGE, 0.18), 6, UI.ORANGE, 3, 0))
	_zoom.pressed.connect(func(): set_view("centre"))
	add_child(_zoom)

	for i in Game.locations.size():
		var loc: Dictionary = Game.locations[i]
		var b := TextureButton.new()
		b.texture_normal = Game.art("pin_" + str(loc.id))
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_SCALE
		b.size = Vector2(PIN, PIN)
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.tooltip_text = loc.name
		b.pressed.connect(func(): picked.emit(i))
		add_child(b)
		_pins.append(b)

	_overlay = Control.new()
	_overlay.size = size
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)

	_back = UI.button("← Toda la ciudad", "small", UI.INK)
	_back.position = Vector2(12, 12)
	_back.pressed.connect(func(): set_view("city"))
	add_child(_back)

	set_view(place_view(selected))


func place_view(index: int) -> String:
	return str(Game.locations[index].get("view", "city"))


## Latitude/longitude -> pixels in the current view.
func project(lat: float, lon: float, in_view := "") -> Vector2:
	var v: Dictionary = _cfg.views[view if in_view == "" else in_view]
	return Vector2(size.x / 2.0 + (lon - float(v.lon0)) * float(_cfg.kx) * float(v.scale),
		size.y / 2.0 - (lat - float(v.lat0)) * float(_cfg.ky) * float(v.scale))


func _spot(index: int) -> Vector2:
	var loc: Dictionary = Game.locations[index]
	var p := project(float(loc.geo[0]), float(loc.geo[1]))
	# A place beyond the edge of the map (the airport) is pinned to the margin.
	return Vector2(clamp(p.x, 34.0, size.x - 34.0), clamp(p.y, 34.0, size.y - 34.0))


func _off_map(index: int) -> bool:
	var loc: Dictionary = Game.locations[index]
	var p := project(float(loc.geo[0]), float(loc.geo[1]))
	return p.x < 0 or p.x > size.x or p.y < 0 or p.y > size.y


func set_view(v: String) -> void:
	view = v
	_base.texture = Game.art("map_" + v)
	_back.visible = v == "centre"
	_zoom.visible = v == "city"
	var r: Array = _cfg.centre_on_city
	_zoom.position = Vector2(r[0], r[1])
	_zoom.size = Vector2(r[2], r[3])
	refresh()
	view_changed.emit(v)


func _status_color(i: int) -> Color:
	var loc: Dictionary = Game.locations[i]
	var done := Game.location_done(loc)
	if not Game.location_unlocked(i):
		return Color("a9a08c")
	if done == loc.scenes.size():
		return UI.GREEN
	return UI.GOLD if done > 0 else UI.ORANGE


func refresh() -> void:
	for i in _pins.size():
		var b: TextureButton = _pins[i]
		b.visible = place_view(i) == view
		b.position = _spot(i) - Vector2(PIN, PIN) / 2.0
		b.modulate = Color(0.72, 0.72, 0.72, 0.9) if not Game.location_unlocked(i) else Color.WHITE
	_overlay.queue_redraw()


func _draw_overlay() -> void:
	var f := UI.font("bold")
	if view == "city":
		# The old town, summarised: small dots for the places inside the frame.
		var r: Array = _cfg.centre_on_city
		var inside := 0
		for i in Game.locations.size():
			if place_view(i) == "centre":
				inside += 1
				var loc: Dictionary = Game.locations[i]
				var p := project(float(loc.geo[0]), float(loc.geo[1]))
				_overlay.draw_circle(p, 6.5, Color.WHITE)
				_overlay.draw_circle(p, 5.0, _status_color(i))
		var caption := "Centro histórico · %d lugares  →" % inside
		var cw := f.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		var cat := Vector2(float(r[0]) + float(r[2]) / 2.0 - cw / 2.0, float(r[1]) - 8.0)
		_overlay.draw_rect(Rect2(cat + Vector2(-6, -15), Vector2(cw + 12, 21)), UI.INK)
		_overlay.draw_string(f, cat, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)

	for i in Game.locations.size():
		if place_view(i) != view:
			continue
		var loc: Dictionary = Game.locations[i]
		var p := _spot(i)
		var col := _status_color(i)
		_overlay.draw_arc(p, PIN / 2.0 + 1.5, 0, TAU, 48, Color.WHITE, 6.0, true)
		_overlay.draw_arc(p, PIN / 2.0 + 1.5, 0, TAU, 48, col, 3.5, true)
		if i == selected:
			_overlay.draw_arc(p, PIN / 2.0 + 6.5, 0, TAU, 48, UI.INK, 3.0, true)

		# number badge
		var badge := p + Vector2(-PIN / 2.0 + 3, -PIN / 2.0 + 3)
		_overlay.draw_circle(badge, 11.0, Color.WHITE)
		_overlay.draw_circle(badge, 9.5, col)
		var num := str(i + 1)
		var nw := f.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		_overlay.draw_string(f, badge + Vector2(-nw / 2.0, 4.5), num, HORIZONTAL_ALIGNMENT_LEFT,
			-1, 12, Color.WHITE)

		# name beside the pin
		var place: String = loc.get("short", loc.name)
		if _off_map(i):
			place = "← " + place
		var w := f.get_string_size(place, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		var gap := PIN / 2.0 + 10.0
		var side: String = loc.get("side", "r")
		var at := p + Vector2(gap, 5)
		if side == "l":
			at = p + Vector2(-gap - w, 5)
		elif side == "t":
			at = p + Vector2(-w / 2.0, -gap - 2)
		elif side == "b":
			at = p + Vector2(-w / 2.0, gap + 12)
		at.x = clamp(at.x, 6.0, size.x - w - 6.0)
		var locked := not Game.location_unlocked(i)
		_overlay.draw_rect(Rect2(at + Vector2(-5, -15), Vector2(w + 10, 21)), Color(UI.PAPER, 0.94))
		_overlay.draw_string(f, at, place, HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
			UI.MUTED if locked else UI.INK)
