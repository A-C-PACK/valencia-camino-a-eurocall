extends Control
## Root node: swaps screens and owns the gloss popup that sits above them.

const TitleScreen := preload("res://scripts/title_screen.gd")
const MapScreen := preload("res://scripts/map_screen.gd")
const SceneScreen := preload("res://scripts/scene_screen.gd")
const CuadernoScreen := preload("res://scripts/cuaderno_screen.gd")

var screen: Control
var gloss: PanelContainer
var gloss_word: Label
var gloss_meaning: Label
var gloss_note: Label
var last_location := 0

const ZOOM_MAX := 3.0
const ZOOM_STEP := 0.5
const DRAG_START := 14.0          # a finger must move this far before it drags the view
const FAR := Vector2(-9999, -9999)    # where the "let go" events below are sent
var zoom := 1.0
var _pan := Vector2.ZERO          # top-left corner of what is on screen, in game pixels
var _touches: Dictionary = {}     # finger index -> where it is on the screen
var _pinching := false
var _letting_go := false          # true while our own "let go" events pass through
var _drag_index := -1             # the single finger that may drag the view
var _drag_from := Vector2.ZERO
var _drag_last := Vector2.ZERO
var _dragging := false
var _drag_scroll: ScrollContainer # the scrolling text under that finger, if any
var _scroll_rest := 0.0
var _mouse_down := false          # the left button is held and may drag the view
var _mouse_dragging := false
var _zoom_out: Button
var _last_in_part: Dictionary = {}    # part -> the place last looked at there


func _ready() -> void:
	Game.main = self
	theme = UI.theme()
	var bg := ColorRect.new()
	bg.color = UI.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_build_gloss()
	_build_zoom()
	var shot := _arg("shot")
	if shot != "":
		_debug_shot(shot)
	else:
		show_title()


func _swap(next: Control) -> void:
	if screen:
		screen.queue_free()
	Game.stop_voice()
	hide_gloss()
	screen = next
	next.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(next)
	move_child(gloss, -1)


func show_title() -> void:
	_swap(TitleScreen.new())


func show_map(select := -1) -> void:
	if select >= 0:
		last_location = select
	_last_in_part[Game.part_of(last_location)] = last_location
	var s := MapScreen.new()
	s.selected = last_location
	_swap(s)


## Open the map on one part of the game, where the player left off in it.
func show_part(part: int) -> void:
	show_map(_last_in_part.get(part, Game.next_in_part(part)))


func show_scene(loc_index: int, scene_index: int) -> void:
	last_location = loc_index
	var s := SceneScreen.new()
	s.loc_index = loc_index
	s.scene_index = scene_index
	_swap(s)


func show_cuaderno(review := false) -> void:
	var s := CuadernoScreen.new()
	s.start_review = review
	_swap(s)


# ---------------------------------------------------------------- gloss popup

func _build_gloss() -> void:
	gloss = UI.panel(UI.INK, 10, UI.GOLD, 2, 12)
	gloss.visible = false
	gloss.z_index = 100
	gloss.custom_minimum_size = Vector2(120, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	gloss_word = UI.label("", 18, UI.GOLD, "bold")
	gloss_meaning = UI.label("", 18, Color.WHITE)
	gloss_meaning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	gloss_meaning.custom_minimum_size = Vector2(260, 0)
	gloss_note = UI.label("", 13, Color("b9c7cf"), "italic")
	v.add_child(gloss_word)
	v.add_child(gloss_meaning)
	v.add_child(gloss_note)
	gloss.add_child(v)
	add_child(gloss)


func show_gloss(seg: Array, at: Vector2, ctx: String, audio: String) -> void:
	gloss_word.text = str(seg[0])
	gloss_meaning.text = str(seg[1])
	if int(seg[2]) == GlossText.KIND_KEY:
		Game.srs_add(str(seg[3]))
		Game.write_save()
		gloss_note.text = "Frase clave · en tu cuaderno"
	else:
		Game.add_word(str(seg[0]), str(seg[1]), ctx, audio)
		gloss_note.text = "Guardada en tu cuaderno"
	gloss.visible = true
	gloss.reset_size()
	await get_tree().process_frame
	var sz := gloss.size
	# keep it inside the part of the game that is on screen (smaller when zoomed in)
	var seen := Rect2(_pan, size / zoom)
	var pos := at + Vector2(-sz.x / 2.0, 18)
	if pos.y + sz.y > seen.end.y - 8:
		pos.y = at.y - sz.y - 18
	pos.x = clamp(pos.x, seen.position.x + 8, max(seen.position.x + 8, seen.end.x - sz.x - 8))
	gloss.position = pos


func hide_gloss() -> void:
	if gloss:
		gloss.visible = false


# ----------------------------------------------------------------------- zoom
# On a phone the 1280x720 layout comes out small. Two fingers pinch to zoom, the
# + and - buttons zoom in steps, and once zoomed in one finger drags the view
# around. With a mouse: hold the button and drag, and Ctrl + wheel zooms.
# The whole canvas is scaled, so every screen gets it without knowing.

func _build_zoom() -> void:
	var layer := CanvasLayer.new()    # its own layer: the buttons do not zoom with the game
	layer.layer = 10
	add_child(layer)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.position = Vector2(8, 290)
	v.modulate = Color(1, 1, 1, 0.88)
	layer.add_child(v)
	for step in [ZOOM_STEP, -ZOOM_STEP]:
		var b := UI.button("+" if step > 0 else "−", "ghost", UI.INK)
		b.custom_minimum_size = Vector2(60, 60)
		b.add_theme_font_size_override("font_size", 42)
		b.focus_mode = Control.FOCUS_NONE
		b.tooltip_text = "Acercar" if step > 0 else "Alejar"
		b.pressed.connect(func():
			zoom_at(size / 2.0, zoom + step)
			Game.set_setting("zoom", zoom))
		v.add_child(b)
		if step < 0:
			_zoom_out = b
	if _arg("shot") == "":    # debug snapshots always start unzoomed
		zoom = clamp(float(Game.setting("zoom", 1.0)), 1.0, ZOOM_MAX)
	_apply_zoom()


## Zoom to `level`, keeping the game point under screen point `at` where it is.
func zoom_at(at: Vector2, level: float, moved_to := Vector2.INF) -> void:
	var under := at / zoom + _pan
	zoom = clamp(level, 1.0, ZOOM_MAX)
	_pan = under - (at if moved_to == Vector2.INF else moved_to) / zoom
	_apply_zoom()


func _apply_zoom() -> void:
	var room := size - size / zoom
	_pan = Vector2(clamp(_pan.x, 0.0, room.x), clamp(_pan.y, 0.0, room.y))
	get_viewport().canvas_transform = Transform2D(0.0, Vector2(zoom, zoom), 0.0, -_pan * zoom)
	if _zoom_out:
		_zoom_out.disabled = zoom <= 1.0
	hide_gloss()


## A finger that turns out to be dragging or pinching has already pressed
## whatever was under it: let go of it somewhere harmless, so nothing gets
## clicked or scrolled by it.
## index: the finger to lift, or -1 when it was the mouse.
func _let_go(index: int) -> void:
	_letting_go = true
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = FAR
	up.global_position = FAR
	get_viewport().push_input(up)
	if index >= 0:
		var lift := InputEventScreenTouch.new()
		lift.index = index
		lift.pressed = false
		lift.position = FAR
		get_viewport().push_input(lift)
	_letting_go = false


## A drag of the view has begun at screen point `from`.
func _drag_begin(from: Vector2) -> void:
	_drag_last = from
	_scroll_rest = 0.0
	_drag_scroll = _scroll_under(screen, from / zoom + _pan) if screen else null


## Move the view with the finger or the mouse. Where the view is already at its
## edge, the rest of an up/down drag scrolls the text under it instead.
func _drag_to(at: Vector2) -> void:
	var want: Vector2 = (_drag_last - at) / zoom
	_drag_last = at
	var before := _pan
	_pan += want
	_apply_zoom()
	_scroll_rest += want.y - (_pan.y - before.y)
	if is_instance_valid(_drag_scroll) and abs(_scroll_rest) >= 1.0:
		var whole := int(_scroll_rest)
		_drag_scroll.scroll_vertical += whole
		_scroll_rest -= whole


## A real mouse (not the one made up from a finger): hold the left button and
## drag to move the zoomed view; Ctrl + wheel zooms where the pointer is.
func _mouse_input(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		if event.ctrl_pressed and event.pressed and event.button_index in [
				MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			zoom_at(event.position, zoom * (1.1 if event.button_index == MOUSE_BUTTON_WHEEL_UP
				else 1.0 / 1.1))
			Game.set_setting("zoom", zoom)
			return true
		if event.button_index != MOUSE_BUTTON_LEFT:
			return false
		if event.pressed:
			# a scroll bar or a text box has its own use for a drag
			var over := get_viewport().gui_get_hovered_control()
			_mouse_down = zoom > 1.0 and not (over is ScrollBar or over is LineEdit)
			_mouse_dragging = false
			_drag_from = event.position
			return false
		var mine := _mouse_dragging
		_mouse_down = false
		_mouse_dragging = false
		return mine
	if event is InputEventMouseMotion and _mouse_down:
		if not _mouse_dragging:
			if event.position.distance_to(_drag_from) < DRAG_START:
				return false
			_mouse_dragging = true
			_drag_begin(_drag_from)
			_let_go.call_deferred(-1)
		_drag_to(event.position)
		return true
	return false


func _scroll_under(node: Node, at: Vector2) -> ScrollContainer:
	for c in node.get_children():
		var found := _scroll_under(c, at)
		if found:
			return found
	if node is ScrollContainer and node.is_visible_in_tree() and node.get_global_rect().has_point(at):
		return node
	return null


## Returns true when the event belonged to a pinch or a drag of the view and
## must go no further.
func _touch_input(event: InputEvent) -> bool:
	if _letting_go:
		return false
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
			if _touches.size() == 1:
				_drag_index = event.index
				_drag_from = event.position
				_dragging = false
			elif not _pinching:
				_pinching = true
				if not _dragging and _drag_index >= 0:
					_let_go.call_deferred(_drag_index)
				_drag_index = -1
				_dragging = false
			return _pinching
		_touches.erase(event.index)
		var mine: bool = _pinching or (_dragging and event.index == _drag_index)
		if event.index == _drag_index:
			_drag_index = -1
			_dragging = false
		if _pinching and _touches.is_empty():
			_pinching = false
			Game.set_setting("zoom", zoom)
		return mine
	if event is InputEventScreenDrag:
		if not _touches.has(event.index):
			return _pinching
		var keys := _touches.keys()
		if _pinching:
			if keys.size() >= 2:
				var a0: Vector2 = _touches[keys[0]]
				var b0: Vector2 = _touches[keys[1]]
				_touches[event.index] = event.position
				var a1: Vector2 = _touches[keys[0]]
				var b1: Vector2 = _touches[keys[1]]
				var spread: float = max(a0.distance_to(b0), 1.0)
				zoom_at((a0 + b0) / 2.0, zoom * a1.distance_to(b1) / spread, (a1 + b1) / 2.0)
			return true
		_touches[event.index] = event.position
		if event.index != _drag_index or zoom <= 1.0:
			return false
		if not _dragging:
			if event.position.distance_to(_drag_from) < DRAG_START:
				return false
			_dragging = true
			_drag_begin(_drag_from)
			_let_go.call_deferred(event.index)
		_drag_to(event.position)
		return true
	if event is InputEventMouse:
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			# made up from the first finger: drop it while that finger pinches or drags
			return _pinching or _dragging
		return _mouse_input(event)
	return false


func _input(event: InputEvent) -> void:
	if _touch_input(event):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed and gloss.visible:
		hide_gloss()
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full
			else DisplayServer.WINDOW_MODE_FULLSCREEN)


# ------------------------------------------------------------ debug snapshots
# godot --path game -- --shot=map --out=C:/tmp/x.png
# shot = title | map[:index] | scene:<loc>:<scene>[:steps] | play:<li>:<si> | gloss | cuaderno | review
#        | sheet:<index> (writes that place's printable page)
#        | pinch:<loc index>:<scene index> (a two-finger zoom, with made-up touches)
#        | drag:<loc index>:<scene index> (zoomed in, a one-finger drag up the text)

func _arg(name: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % name):
			return a.substr(name.length() + 3)
	return ""


func _debug_shot(spec: String) -> void:
	var parts := spec.split(":")
	match parts[0]:
		"map":
			show_map(int(parts[1]) if parts.size() > 1 else 0)
		"scene":
			var li := 0
			for i in Game.locations.size():
				if Game.locations[i].id == parts[1]:
					li = i
			var si := 0
			for i in Game.locations[li].scenes.size():
				if Game.locations[li].scenes[i].id == parts[2]:
					si = i
			show_scene(li, si)
			await get_tree().process_frame
			screen.debug_skip(int(parts[3]) if parts.size() > 3 else 0)
		"play":
			# play:<loc index>:<scene index> runs a scene through its real controls
			show_scene(int(parts[1]), int(parts[2]))
			await get_tree().process_frame
			await screen.debug_autoplay()
		"mic":
			show_scene(0, 0)
			print("input devices: ", AudioServer.get_input_device_list())
			var ok := Game.start_recording()
			await get_tree().create_timer(1.5).timeout
			var take := Game.stop_recording()
			print("mic test: started=%s take=%s length=%.2f" % [ok, take != null,
				take.get_length() if take else 0.0])
		"gloss":
			show_scene(0, 0)
			await get_tree().process_frame
			show_gloss(["atasco", "traffic jam", 3, Game.phrases.keys()[0]], Vector2(900, 300), "", "")
		"pinch":
			show_scene(int(parts[1]), int(parts[2]))
			await get_tree().process_frame
			screen.debug_skip(4)
			# two fingers land on the text and spread apart
			var from := [Vector2(820, 300), Vector2(900, 360)]
			var to := [Vector2(700, 200), Vector2(1020, 440)]
			for i in 2:
				var down := InputEventScreenTouch.new()
				down.index = i
				down.pressed = true
				down.position = from[i]
				Input.parse_input_event(down)
			await get_tree().process_frame
			for n in range(1, 9):
				for i in 2:
					var drag := InputEventScreenDrag.new()
					drag.index = i
					drag.position = from[i].lerp(to[i], n / 8.0)
					Input.parse_input_event(drag)
				await get_tree().process_frame
			for i in 2:
				var lift := InputEventScreenTouch.new()
				lift.index = i
				lift.pressed = false
				lift.position = to[i]
				Input.parse_input_event(lift)
			await get_tree().process_frame
			print("pinch: zoom=%.2f pan=%s pinching=%s" % [zoom, _pan, _pinching])
		"drag":
			# zoomed in on a reading, one finger drags up: first the view moves down
			# to its edge, then the text itself scrolls
			zoom_at(Vector2.ZERO, 1.5)
			show_scene(int(parts[1]), int(parts[2]))
			await get_tree().process_frame
			screen.debug_skip(4)
			for i in 6:
				await get_tree().process_frame
			var text: ScrollContainer = _scroll_under(screen, Vector2(900, 300))
			text.scroll_vertical = 0
			var start_scroll := text.scroll_vertical
			var down := InputEventScreenTouch.new()
			down.index = 0
			down.pressed = true
			down.position = Vector2(900, 600)
			Input.parse_input_event(down)
			await get_tree().process_frame
			for n in range(1, 13):
				var drag := InputEventScreenDrag.new()
				drag.index = 0
				drag.position = Vector2(900, 600 - n * 45)
				Input.parse_input_event(drag)
				await get_tree().process_frame
			var lift := InputEventScreenTouch.new()
			lift.index = 0
			lift.pressed = false
			lift.position = Vector2(900, 60)
			Input.parse_input_event(lift)
			await get_tree().process_frame
			print("drag: zoom=%.2f pan=%s text scrolled %d -> %d" % [zoom, _pan, start_scroll,
				text.scroll_vertical])
		"sheet":
			show_map(int(parts[1]))
			print("sheet: ", Game.open_html(Sheet.html([int(parts[1])]), "hoja-debug.html"))
		"sheets":
			show_map(0)
			print("sheets: ", Game.open_html(Sheet.html(range(Game.locations.size())),
				"hojas-de-frases.html"))
		"cards":
			# select the first twelve visible phrases and write the flashcard page
			show_cuaderno(false)
			await get_tree().process_frame
			for id in screen._visible_ids().slice(0, 12):
				screen.selected[id] = true
			screen._fill_list()
			screen._print_cards(screen.selected.keys())
			print("cards written: ", ProjectSettings.globalize_path("user://tarjetas.html"))
		"cuaderno":
			show_cuaderno(false)
		"review":
			show_cuaderno(true)
		_:
			show_title()
	await get_tree().create_timer(1.2).timeout
	var out := _arg("out")
	if out != "":
		get_viewport().get_texture().get_image().save_png(out)
	get_tree().quit()
