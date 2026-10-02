extends Control
## Opening screen.


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
	margin.add_theme_constant_override("margin_left", 580)
	margin.add_theme_constant_override("margin_right", 60)
	margin.add_theme_constant_override("margin_top", 70)
	margin.add_theme_constant_override("margin_bottom", 50)
	add_child(margin)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	margin.add_child(v)

	v.add_child(UI.label("CAMINO A EUROCALL", 18, UI.ORANGE, "bold"))
	v.add_child(UI.label("Valencia", 84, UI.INK, "serif"))
	var sub := UI.label("Doce lugares, doce conversaciones. Practica el español que vas a "
		+ "necesitar antes de llegar.", 21, UI.INK)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(sub)
	v.add_child(UI.spacer(0, 14))

	var how := UI.panel(UI.PAPER, 12, UI.LINE, 1, 16)
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 6)
	how.add_child(hv)
	hv.add_child(UI.label("Cómo funciona", 17, UI.TEAL, "bold"))
	for line in [
		"Escucha a la gente de Valencia y responde: eliges o escribes tú.",
		"Toca cualquier palabra para ver qué significa.",
		"Las frases clave van a tu cuaderno y vuelven otro día para repasarlas.",
	]:
		var l := UI.label("·  " + line, 17, UI.INK)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hv.add_child(l)
	v.add_child(how)
	v.add_child(UI.spacer(0, 14))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var started: bool = not Game.save.scenes.is_empty()
	var play := UI.button("Continuar el viaje" if started else "Empezar el viaje")
	play.custom_minimum_size = Vector2(230, 52)
	play.pressed.connect(func(): Game.main.show_map())
	row.add_child(play)
	var due := Game.srs_due().size()
	var book := UI.button("Mi cuaderno" + (" (%d)" % due if due > 0 else ""), "ghost", UI.TEAL)
	book.custom_minimum_size = Vector2(170, 52)
	book.pressed.connect(func(): Game.main.show_cuaderno())
	row.add_child(book)
	v.add_child(row)

	v.add_child(UI.spacer(0, 0))
	var foot := UI.label("%d de %d estrellas" % [Game.total_stars(), Game.max_stars()],
		15, UI.MUTED)
	foot.size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_SHRINK_END
	v.add_child(foot)
	UI.focus(play)
