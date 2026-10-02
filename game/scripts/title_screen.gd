extends Control
## Opening screen: the two parts of the game, both open from the start.

const NUMBERS := ["cero", "un", "dos", "tres", "cuatro", "cinco", "seis", "siete", "ocho", "nueve",
	"diez", "once", "doce", "trece", "catorce", "quince", "dieciséis", "diecisiete", "dieciocho",
	"diecinueve", "veinte", "veintiún", "veintidós", "veintitrés", "veinticuatro"]


func _ready() -> void:
	var art := TextureRect.new()
	art.texture = Game.art("val_title")
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.position = Vector2.ZERO
	art.size = Vector2(520, 720)
	art.clip_contents = true
	add_child(art)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 570)
	margin.add_theme_constant_override("margin_right", 50)
	margin.add_theme_constant_override("margin_top", 34)
	margin.add_theme_constant_override("margin_bottom", 28)
	add_child(margin)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	margin.add_child(v)

	v.add_child(UI.label("CAMINO A EUROCALL", 18, UI.ORANGE, "bold"))
	v.add_child(UI.label("Valencia", 70, UI.INK, "serif"))
	var sub := UI.label("Practica el español que vas a necesitar antes de llegar "
		+ "y lee la historia de la ciudad en los lugares donde pasó.", 19, UI.INK)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(sub)
	v.add_child(UI.spacer(0, 2))

	var first := _part(1, "El viaje", "%s lugares, %s conversaciones",
		"Escucha a la gente de Valencia y responde: eliges o escribes tú.",
		"Empezar el viaje", "Continuar el viaje", UI.ORANGE)
	v.add_child(first[0])
	var second := _part(2, "La historia", "%s lugares, %s lecturas",
		"De la Valentia romana al Cabanyal de hoy: textos para leer con calma "
		+ "sobre lugares que vas a poder visitar.",
		"Empezar a leer", "Seguir leyendo", UI.TEAL)
	if not Game.part_indices(2).is_empty():
		v.add_child(second[0])

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_SHRINK_END
	var due := Game.srs_due().size()
	var book := UI.button("Mi cuaderno" + (" (%d)" % due if due > 0 else ""), "ghost", UI.TEAL)
	book.custom_minimum_size = Vector2(170, 44)
	book.pressed.connect(func(): Game.main.show_cuaderno())
	row.add_child(book)
	var tip := UI.label("Toca cualquier palabra para ver qué significa: va a tu cuaderno "
		+ "y vuelve otro día para repasarla.", 15, UI.MUTED)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(tip)
	v.add_child(row)
	UI.focus(first[1])


## One part's card. Returns [panel, its button].
func _part(part: int, title: String, counts: String, about: String, start: String,
		resume: String, color: Color) -> Array:
	var places := Game.part_indices(part)
	var scenes := 0
	for i in places:
		scenes += Game.locations[i].scenes.size()
	var panel := UI.panel(UI.PAPER, 12, UI.LINE, 1, 14)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 2)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	text.add_child(UI.label("PARTE %d · %s" % [part, title.to_upper()], 13, color, "bold"))
	var line := counts % [_number(places.size()), _number(scenes)]
	text.add_child(UI.label(line.left(1).to_upper() + line.substr(1), 23, UI.INK, "serif"))
	var l := UI.label(about, 16, UI.INK)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(l)
	text.add_child(UI.label("★ %d / %d" % [Game.total_stars(part), Game.max_stars(part)], 15,
		UI.GOLD.darkened(0.25), "bold"))
	var go := UI.button(resume if Game.total_stars(part) > 0 else start, "primary", color)
	go.custom_minimum_size = Vector2(190, 50)
	go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	go.pressed.connect(func(): Game.main.show_part(part))
	row.add_child(go)
	return [panel, go]


func _number(n: int) -> String:
	return NUMBERS[n] if n < NUMBERS.size() else str(n)
