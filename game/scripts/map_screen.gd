extends Control
## The city map on the left, the selected place and its scenes on the right.

const MapView := preload("res://scripts/map_view.gd")
const PART_NAMES := {1: "Parte 1 · El viaje", 2: "Parte 2 · La historia"}
const THUMB_WIDTH := 372.0    # the side panel, less its margins

var selected := 0
var part := 1
var map: Control
var card: VBoxContainer


func _ready() -> void:
	part = Game.part_of(selected)
	map = MapView.new()
	map.selected = selected
	map.part = part
	map.position = Vector2.ZERO
	map.size = Vector2(860, 720)
	map.picked.connect(_select)
	add_child(map)

	var side := UI.panel(UI.PAPER, 0, UI.LINE, 0, 0)
	side.position = Vector2(860, 0)
	side.size = Vector2(420, 720)
	add_child(side)
	var margin := MarginContainer.new()
	for m in ["margin_left", "margin_right"]:
		margin.add_theme_constant_override(m, 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 18)
	side.add_child(margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	margin.add_child(v)

	var top := HBoxContainer.new()
	var title_btn := UI.button("Inicio", "small", UI.MUTED)
	title_btn.pressed.connect(func(): Game.main.show_title())
	top.add_child(title_btn)
	top.add_child(UI.spacer(0, 0, true))
	top.add_child(UI.label("★ %d / %d" % [Game.total_stars(part), Game.max_stars(part)], 17,
		UI.GOLD.darkened(0.25), "bold"))
	top.add_child(UI.spacer(10, 0))
	var due := Game.srs_due().size()
	var book := UI.button("Cuaderno" + (" (%d)" % due if due > 0 else ""), "small", UI.TEAL)
	book.pressed.connect(func(): Game.main.show_cuaderno())
	top.add_child(book)
	v.add_child(top)

	var parts := HBoxContainer.new()
	parts.add_theme_constant_override("separation", 8)
	for p in [1, 2]:
		var tab := UI.button(PART_NAMES[p], "primary" if p == part else "ghost", UI.INK)
		tab.add_theme_font_size_override("font_size", 15)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.disabled = Game.part_indices(p).is_empty()
		if p != part:
			tab.pressed.connect(func(): Game.main.show_part(p))
		parts.add_child(tab)
	v.add_child(parts)

	card = VBoxContainer.new()
	card.add_theme_constant_override("separation", 7)
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(card)

	var listen := CheckBox.new()
	listen.text = "Modo escucha: oír antes de leer"
	listen.button_pressed = Game.setting("listen_mode", false)
	listen.add_theme_font_size_override("font_size", 15)
	listen.toggled.connect(func(on: bool): Game.set_setting("listen_mode", on))
	listen.visible = part == 1    # the readings of part 2 have no recording to hear first
	v.add_child(listen)
	var unlock := CheckBox.new()
	unlock.text = "Abrir todos los lugares"
	unlock.button_pressed = Game.setting("unlock_all", false)
	unlock.add_theme_font_size_override("font_size", 15)
	unlock.toggled.connect(func(on: bool):
		Game.set_setting("unlock_all", on)
		map.refresh()
		_fill())
	v.add_child(unlock)
	_fill()


func _select(i: int) -> void:
	selected = i
	Game.main.last_location = i
	map.selected = i
	if map.place_view(i) != map.view:
		map.set_view(map.place_view(i))
	map.refresh()
	_fill()


func _fill() -> void:
	for c in card.get_children():
		c.queue_free()
	var loc: Dictionary = Game.locations[selected]
	var open := Game.location_unlocked(selected)

	# A strip of the place's tall illustration, cut at the height its script asks
	# for (@focus) so that it shows faces rather than the middle of the picture.
	# A reading's card carries more text (what to see, where it is): thinner strip.
	var art := Game.art("val_" + str(loc.id))
	if art:
		var strip := Vector2(THUMB_WIDTH, 60 if Game.part_of(selected) == 2 else 96)
		var cut := AtlasTexture.new()
		cut.atlas = art
		var h: float = art.get_width() * strip.y / strip.x
		var top: float = clamp(float(loc.get("focus", 0.5)) * art.get_height() - h / 2.0, 0.0,
			art.get_height() - h)
		cut.region = Rect2(0, top, art.get_width(), h)
		var thumb := TextureRect.new()
		thumb.texture = cut
		thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumb.stretch_mode = TextureRect.STRETCH_SCALE
		thumb.custom_minimum_size = Vector2(0, strip.y)
		card.add_child(thumb)

	var reading := part == 2
	card.add_child(UI.label("%d · %s" % [Game.number_in_part(selected),
		str(loc.get("era" if reading else "zone", "")).to_upper()], 13, UI.ORANGE, "bold"))
	var place := UI.label(loc.name, 27, UI.INK, "serif")
	place.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(place)

	var blurb := GlossText.new()
	blurb.set_style(17, UI.INK)
	blurb.set_segs(loc.get("blurb", []))
	card.add_child(blurb)

	if loc.has("visit"):
		var visit := GlossText.new()
		visit.set_style(15, UI.TEAL)
		visit.set_segs(loc.visit, "[b]Qué ver hoy:[/b] ")
		card.add_child(visit)

	if loc.has("route"):
		var route := GlossText.new()
		route.set_style(15, UI.MUTED)
		route.set_segs(loc.route, "[b]Dónde está:[/b] " if reading else "[b]Cómo llegar:[/b] ")
		card.add_child(route)

	if loc.has("goal"):
		var goal := GlossText.new()
		goal.set_style(15, UI.TEAL)
		goal.set_segs(loc.goal, "[b]Objetivo:[/b] ")
		card.add_child(goal)

	var sheet_row := HBoxContainer.new()
	var sheet := UI.button("Lecturas para imprimir" if reading
		else "Hoja de frases para imprimir", "small", UI.TEAL)
	sheet.tooltip_text = ("Los textos de este lugar, con su vocabulario" if reading
		else "Qué decir, frases clave y notas de este lugar, en una hoja")
	var sheet_note := UI.label("", 12, UI.MUTED, "italic")
	sheet_note.clip_text = true
	sheet_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sheet.pressed.connect(func():
		sheet_note.text = "  " + Game.open_html(Sheet.html([selected]),
			"hoja-%s.html" % str(loc.id)).get_slice(":", 0))
	sheet_row.add_child(sheet)
	sheet_row.add_child(sheet_note)
	card.add_child(sheet_row)

	if not open:
		var lock := UI.label(("Cerrado. Termina una lectura del lugar anterior para abrirlo."
			if reading else "Cerrado. Termina una escena del lugar anterior para abrirlo."),
			16, UI.MUTED, "italic")
		lock.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_child(lock)
		return

	for si in loc.scenes.size():
		var scene: Dictionary = loc.scenes[si]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 0)
		var t := UI.label(scene.title, 17, UI.INK, "bold")
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(t)
		var st := Game.scene_stars(loc, scene)
		info.add_child(UI.label(UI.stars(st), 16, UI.GOLD.darkened(0.15) if st > 0 else UI.LINE))
		row.add_child(info)
		var go := UI.button(("Releer" if reading else "Repetir") if st > 0
			else ("Leer" if reading else "Entrar"), "ghost" if st > 0 else "primary")
		go.custom_minimum_size = Vector2(104, 40)
		go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		go.pressed.connect(func(): Game.main.show_scene(selected, si))
		row.add_child(go)
		var p := UI.panel(Color.WHITE, 10, UI.LINE, 1, 10)
		p.add_child(row)
		card.add_child(p)
