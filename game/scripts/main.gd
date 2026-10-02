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


func _ready() -> void:
	Game.main = self
	theme = UI.theme()
	var bg := ColorRect.new()
	bg.color = UI.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_build_gloss()
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
	var s := MapScreen.new()
	s.selected = last_location
	_swap(s)


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
	var pos := at + Vector2(-sz.x / 2.0, 18)
	if pos.y + sz.y > size.y - 8:
		pos.y = at.y - sz.y - 18
	pos.x = clamp(pos.x, 8, size.x - sz.x - 8)
	gloss.position = pos


func hide_gloss() -> void:
	if gloss:
		gloss.visible = false


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and gloss.visible:
		hide_gloss()
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full
			else DisplayServer.WINDOW_MODE_FULLSCREEN)


# ------------------------------------------------------------ debug snapshots
# godot --path game -- --shot=map --out=C:/tmp/x.png
# shot = title | map[:index] | scene:<loc>:<scene>[:steps] | play:<li>:<si> | gloss | cuaderno | review

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
