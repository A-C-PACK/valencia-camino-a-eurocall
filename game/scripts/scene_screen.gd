extends Control
## Plays one scene: a conversation log on the right, and under it the panel
## where the player listens, chooses, or types.

const Compas := preload("res://scripts/compas.gd")

var loc_index := 0
var scene_index := 0
var loc: Dictionary
var scene: Dictionary
var steps: Array
var idx := -1

var scroll: ScrollContainer
var log_box: VBoxContainer
var action: VBoxContainer
var bar: ProgressBar
var counter: Label

var points := 0.0
var scorable := 0
var first_try := true
var attempts := 0
var listen_mode := false
var hidden_lines: Array = []    # callables that reveal a hidden line
var new_phrases: Array = []
var _continue: Callable
var _options: Array = []    # the A/B/C buttons currently on screen


func _ready() -> void:
	loc = Game.locations[loc_index]
	scene = loc.scenes[scene_index]
	steps = scene.steps
	listen_mode = Game.setting("listen_mode", false)
	_build()
	_next()


# --------------------------------------------------------------------- layout

func _build() -> void:
	var art := TextureRect.new()
	art.texture = Game.art("val_" + str(loc.id))
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.position = Vector2.ZERO
	art.size = Vector2(480, 720)
	art.clip_contents = true
	add_child(art)
	if art.texture == null:
		var fill := ColorRect.new()
		fill.color = UI.SAND
		fill.size = Vector2(480, 720)
		add_child(fill)

	var plate := UI.panel(Color(UI.INK, 0.86), 0, Color.TRANSPARENT, 0, 16)
	plate.position = Vector2(0, 620)
	plate.size = Vector2(480, 100)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 0)
	pv.add_child(UI.label(str(loc.name).to_upper(), 13, UI.GOLD, "bold"))
	var st := UI.label(scene.title, 24, Color.WHITE, "serif")
	st.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pv.add_child(st)
	plate.add_child(pv)
	add_child(plate)

	var back := UI.button("← Mapa", "small", UI.INK)
	back.position = Vector2(14, 14)
	back.pressed.connect(func(): Game.main.show_map(loc_index))
	add_child(back)

	var margin := MarginContainer.new()
	margin.position = Vector2(480, 0)
	margin.size = Vector2(800, 720)
	for m in ["margin_left", "margin_right"]:
		margin.add_theme_constant_override(m, 22)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	margin.add_child(v)

	var head := HBoxContainer.new()
	bar = ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 8)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.max_value = steps.size()
	bar.add_theme_stylebox_override("background", UI.box(UI.LINE, 4, Color.TRANSPARENT, 0, 0))
	bar.add_theme_stylebox_override("fill", UI.box(UI.ORANGE, 4, Color.TRANSPARENT, 0, 0))
	head.add_child(bar)
	head.add_child(UI.spacer(10, 0))
	counter = UI.label("", 14, UI.MUTED, "bold")
	head.add_child(counter)
	v.add_child(head)

	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	log_box = VBoxContainer.new()
	log_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_box.add_theme_constant_override("separation", 10)
	scroll.add_child(log_box)

	var panel := UI.panel(UI.PAPER, 12, UI.LINE, 2, 14)
	action = VBoxContainer.new()
	action.add_theme_constant_override("separation", 8)
	panel.add_child(action)
	v.add_child(panel)


func _clear_action() -> void:
	for c in action.get_children():
		action.remove_child(c)
		c.queue_free()
	_continue = Callable()
	_options = []


func _scroll_down() -> void:
	for i in 3:
		await get_tree().process_frame
	if is_instance_valid(scroll):
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)


func _note_phrases(segs: Array) -> void:
	for seg in segs:
		if int(seg[2]) == GlossText.KIND_KEY and Game.srs_add(str(seg[3])):
			new_phrases.append(str(seg[3]))


# ----------------------------------------------------------- log entry makers

func _bubble(who: String, segs: Array, audio: String, hidden: bool) -> void:
	var me := who == "YO"
	var info: Dictionary = Game.cast.get(who, {"name": who, "role": "", "color": "#555555"})
	var row := HBoxContainer.new()
	var panel := UI.panel(Color("e3eff3") if me else Color.WHITE, 12,
		Color("b9d4de") if me else UI.LINE, 1, 12)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if me:
		row.add_child(UI.spacer(120, 0))
	row.add_child(panel)
	if not me:
		row.add_child(UI.spacer(120, 0))

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	panel.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.add_child(UI.label(info.name, 15, Color(str(info.color)), "bold"))
	if str(info.role) != "":
		head.add_child(UI.label(info.role, 13, UI.MUTED))
	head.add_child(UI.spacer(0, 0, true))
	v.add_child(head)

	var text := GlossText.new()
	text.audio = audio
	text.ctx = UI.plain(segs)
	v.add_child(text)

	if Game.has_voice(audio):
		var play := UI.button("Oír", "small", UI.TEAL)
		play.focus_mode = Control.FOCUS_NONE
		play.pressed.connect(func(): Game.play_voice(audio))
		head.add_child(play)
		var slow := UI.button("Lento", "small", UI.TEAL)
		slow.focus_mode = Control.FOCUS_NONE
		slow.pressed.connect(func(): Game.play_voice(audio, true))
		head.add_child(slow)

	if hidden and Game.has_voice(audio):
		text.set_plain("Escucha…  (texto oculto)", true)
		text.set_style(17, UI.MUTED)
		var show_btn := UI.button("Ver texto", "small", UI.MUTED)
		show_btn.focus_mode = Control.FOCUS_NONE
		head.add_child(show_btn)
		var reveal := func():
			if not is_instance_valid(text) or not show_btn.visible:
				return
			show_btn.visible = false
			text.set_style(19, UI.INK)
			text.set_segs(segs)
			_note_phrases(segs)
		show_btn.pressed.connect(reveal)
		hidden_lines.append(reveal)
	else:
		text.set_segs(segs)
		_note_phrases(segs)

	log_box.add_child(row)
	_scroll_down()


func _reveal_hidden() -> void:
	for r in hidden_lines:
		r.call()
	hidden_lines.clear()


func _add_narr(segs: Array) -> void:
	var t := GlossText.new()
	t.set_style(16, UI.MUTED)
	t.set_segs(segs, "", true)
	log_box.add_child(t)
	_scroll_down()


func _add_note(s: Dictionary) -> void:
	var panel := UI.panel(Color("fbf0cf"), 12, UI.GOLD, 2, 14)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.add_child(UI.label("NOTA CULTURAL", 12, UI.ORANGE, "bold"))
	var title := UI.label(s.title, 20, UI.INK, "serif")
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(title)
	var t := GlossText.new()
	t.set_style(17, UI.INK)
	t.set_segs(s.segs)
	_note_phrases(s.segs)
	v.add_child(t)
	panel.add_child(v)
	log_box.add_child(panel)
	_scroll_down()


# ------------------------------------------------------------------ the steps

func _next() -> void:
	idx += 1
	bar.value = idx
	counter.text = "%d / %d" % [min(idx + 1, steps.size()), steps.size()]
	if idx >= steps.size():
		_finish()
		return
	var s: Dictionary = steps[idx]
	match s.t:
		"narr":
			_add_narr(s.segs)
			_next()
		"line":
			var conceal: bool = (s.hidden or listen_mode) and s.who != "YO"
			_bubble(s.who, s.segs, s.audio, conceal)
			Game.play_voice(s.audio)
			_show_continue("Continuar", s.audio)
		"note":
			_add_note(s)
			_show_continue()
		"q":
			_ask(s, false)
		"choice":
			_ask(s, true)
		"type":
			_ask_typed(s)
		"compas":
			_show_compas(s)


func _tag(text: String, color: Color) -> void:
	action.add_child(UI.label(text.to_upper(), 12, color, "bold"))


func _feedback(segs: Array, good: bool, lead: String) -> GlossText:
	var t := GlossText.new()
	t.set_style(17, UI.GREEN.darkened(0.15) if good else UI.RED)
	t.set_segs(segs, "[b]%s[/b] " % lead)
	action.add_child(t)
	return t


## After every line the player "says", nudge them to actually say it.
func _say_it(audio: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(UI.label("Ahora dilo tú en voz alta:", 15, UI.TEAL, "italic"))
	row.add_child(Recorder.new(audio))
	action.add_child(row)


func _show_continue(label := "Continuar", shadow := "") -> void:
	if action.get_child_count() == 0:
		_tag("Escucha, lee y repite" if shadow != "" else "Lee", UI.MUTED)
	var row := HBoxContainer.new()
	if shadow != "" and Game.has_voice(shadow):
		var rec := Recorder.new(shadow)
		rec.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(rec)
	row.add_child(UI.spacer(0, 0, true))
	var b := UI.button(label)
	b.custom_minimum_size = Vector2(160, 44)
	row.add_child(b)
	action.add_child(row)
	_continue = func():
		_clear_action()
		_next()
	b.pressed.connect(func(): _continue.call())
	UI.focus(b)
	_scroll_down()


func _ask(s: Dictionary, is_choice: bool) -> void:
	_clear_action()
	scorable += 1
	first_try = true
	_tag("¿Qué dices tú?" if is_choice else "¿Has entendido?", UI.ORANGE if is_choice else UI.TEAL)
	var prompt := GlossText.new()
	prompt.set_style(19, UI.INK)
	prompt.set_segs(s.segs)
	action.add_child(prompt)

	var order: Array = range(s.opts.size())
	order.shuffle()
	var rows: Array = []
	var fb_slot := VBoxContainer.new()
	for n in order.size():
		var opt: Dictionary = s.opts[order[n]]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var pick := UI.button("ABCD"[n], "ghost", UI.INK)
		pick.custom_minimum_size = Vector2(42, 38)
		pick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(pick)
		var t := GlossText.new()
		t.set_style(18, UI.INK)
		t.quiet = true
		t.set_segs(opt.segs)
		t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(t)
		action.add_child(row)
		rows.append(pick)
		pick.pressed.connect(func(): _picked(s, opt, pick, t, rows, fb_slot, is_choice))
	action.add_child(fb_slot)
	_options = rows
	_scroll_down()


func _picked(s: Dictionary, opt: Dictionary, pick: Button, text: GlossText, rows: Array,
		fb_slot: VBoxContainer, is_choice: bool) -> void:
	for c in fb_slot.get_children():
		c.queue_free()
	var grade: int = int(opt.grade) if is_choice else (2 if opt.ok else 0)
	if grade == 0:
		first_try = false
		pick.disabled = true
		text.set_style(18, UI.MUTED)
		var t := GlossText.new()
		t.set_style(17, UI.RED)
		t.set_segs(opt.fb, "[b]No del todo.[/b] ")
		fb_slot.add_child(t)
		_scroll_down()
		return

	if grade == 2:
		points += 1.0 if first_try else 0.5
	else:
		points += 0.5 if first_try else 0.25
	_clear_action()
	_reveal_hidden()
	if is_choice:
		_bubble("YO", opt.segs, opt.audio, false)
		Game.play_voice(opt.audio)
		_feedback(opt.fb, grade == 2, "¡Muy bien!" if grade == 2 else "Vale, se entiende.")
		if grade == 1:
			# Show the reply a local would most likely use, so it is not lost.
			for other in s.opts:
				if int(other.grade) == 2:
					var better := GlossText.new()
					better.set_style(17, UI.INK)
					better.audio = other.audio
					better.set_segs(other.segs, "[b]Más natural:[/b] ")
					action.add_child(better)
					_note_phrases(other.segs)
					break
		_say_it(opt.audio)
	else:
		var recap := GlossText.new()
		recap.set_style(17, UI.INK)
		recap.set_segs(opt.segs, "[b]%s[/b]  " % UI.esc(UI.plain(s.segs)))
		action.add_child(recap)
		_feedback(opt.fb, true, "¡Correcto!")
	_show_continue()


func _ask_typed(s: Dictionary) -> void:
	_clear_action()
	scorable += 1
	first_try = true
	attempts = 0
	_tag("Escribe lo que dirías", UI.ORANGE)
	var prompt := GlossText.new()
	prompt.set_style(19, UI.INK)
	prompt.set_segs(s.segs)
	action.add_child(prompt)

	var edit := LineEdit.new()
	edit.placeholder_text = "Escribe en español…"
	edit.custom_minimum_size = Vector2(0, 44)
	action.add_child(edit)
	WebField.attach(edit, true)

	var fb_slot := VBoxContainer.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(UI.accent_row(edit))
	row.add_child(UI.spacer(0, 0, true))
	var hint := UI.button("Pista", "ghost", UI.TEAL)
	hint.visible = not s.hint.is_empty()
	hint.pressed.connect(func():
		first_try = false
		hint.disabled = true
		for c in fb_slot.get_children():
			c.queue_free()
		var t := GlossText.new()
		t.set_style(17, UI.TEAL)
		t.set_segs(s.hint, "[b]Pista:[/b] ")
		fb_slot.add_child(t)
		UI.focus(edit))
	row.add_child(hint)
	var check := UI.button("Comprobar")
	row.add_child(check)
	action.add_child(row)
	action.add_child(fb_slot)

	var submit := func():
		if edit.text.strip_edges() == "":
			return
		_typed(s, edit.text, fb_slot)
	check.pressed.connect(submit)
	edit.text_submitted.connect(func(_t: String): submit.call())
	UI.focus(edit)
	_scroll_down()


func _typed(s: Dictionary, input: String, fb_slot: VBoxContainer) -> void:
	attempts += 1
	var res: Dictionary = UI.check(input, s.answers)
	var verdict: String = res.verdict
	if verdict == "no" and attempts < 2:
		first_try = false
		for c in fb_slot.get_children():
			c.queue_free()
		fb_slot.add_child(UI.label("Todavía no. Prueba otra vez" +
			(" o pide una pista." if not s.hint.is_empty() else "."), 17, UI.RED, "bold"))
		return

	_clear_action()
	_reveal_hidden()
	_bubble("YO", s.model, s.get("audio", ""), false)
	Game.play_voice(s.get("audio", ""))
	_note_phrases(s.hint)
	var typed := UI.label("Tú has escrito:  " + input.strip_edges(), 16, UI.MUTED)
	typed.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	action.add_child(typed)
	match verdict:
		"exact":
			points += 1.0 if first_try else 0.5
			action.add_child(UI.label("¡Perfecto!", 18, UI.GREEN.darkened(0.15), "bold"))
		"accent":
			points += 1.0 if first_try else 0.5
			var l := UI.label("¡Bien! Solo faltan tildes o signos:  " + str(res.best), 17,
				UI.GREEN.darkened(0.15), "bold")
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			action.add_child(l)
		"close":
			points += 0.5 if first_try else 0.25
			var l := UI.label("Casi. Compara con:  " + str(res.best), 17, UI.ORANGE, "bold")
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			action.add_child(l)
		_:
			var l := UI.label("Una forma de decirlo está arriba, en azul. Escúchala.", 17,
				UI.RED, "bold")
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			action.add_child(l)
	if s.answers.size() > 1:
		var alts: Array = s.answers.slice(1, 4)
		var also := UI.label("También vale:  " + "  ·  ".join(PackedStringArray(alts)), 15,
			UI.MUTED)
		also.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		action.add_child(also)
	_say_it(s.get("audio", ""))
	if verdict == "no":
		# The accepted list cannot hold every good sentence; trust the learner.
		var mine := UI.button("Mi respuesta también vale", "small", UI.TEAL)
		mine.pressed.connect(func():
			points += 0.5
			mine.disabled = true
			mine.text = "Anotado")
		action.add_child(mine)
	_show_continue()


func _show_compas(s: Dictionary) -> void:
	_clear_action()
	_tag("El compás", UI.RED)
	var c := Compas.new()
	c.palo = s.palo
	action.add_child(c)
	_show_continue()


## A/B/C (or 1/2/3) pick an option without reaching for the mouse.
func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var n := -1
	if event.keycode >= KEY_A and event.keycode <= KEY_D:
		n = event.keycode - KEY_A
	elif event.keycode >= KEY_1 and event.keycode <= KEY_4:
		n = event.keycode - KEY_1
	if n >= 0 and n < _options.size() and not _options[n].disabled:
		get_viewport().set_input_as_handled()
		_options[n].pressed.emit()


# ------------------------------------------------------------------------ end

func _finish() -> void:
	_clear_action()
	var ratio := 1.0 if scorable == 0 else points / scorable
	var stars := 3 if ratio >= 0.85 else (2 if ratio >= 0.6 else 1)
	Game.record_scene(loc, scene, stars)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	head.add_child(UI.label("¡Escena completada!", 24, UI.INK, "serif"))
	head.add_child(UI.label(UI.stars(stars), 26, UI.GOLD.darkened(0.1)))
	action.add_child(head)
	if scorable > 0:
		action.add_child(UI.label("Aciertos: %d %%" % int(round(ratio * 100)), 16, UI.MUTED))
	if not new_phrases.is_empty():
		var names: Array = []
		for id in new_phrases.slice(0, 6):
			names.append(str(Game.card(id).es))
		var l := UI.label("Nuevas en tu cuaderno (%d):  %s" % [new_phrases.size(),
			"  ·  ".join(PackedStringArray(names))], 16, UI.RED)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		action.add_child(l)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var again := UI.button("Repetir", "ghost", UI.MUTED)
	again.pressed.connect(func(): Game.main.show_scene(loc_index, scene_index))
	row.add_child(again)
	row.add_child(UI.spacer(0, 0, true))
	var to_map := UI.button("Volver al mapa", "ghost", UI.TEAL)
	to_map.pressed.connect(func(): Game.main.show_map(loc_index))
	row.add_child(to_map)
	var focus: Button = to_map
	if scene_index + 1 < loc.scenes.size():
		var nxt := UI.button("Siguiente escena")
		nxt.pressed.connect(func(): Game.main.show_scene(loc_index, scene_index + 1))
		row.add_child(nxt)
		focus = nxt
	elif loc_index + 1 < Game.locations.size():
		var nxt := UI.button("Siguiente lugar")
		nxt.pressed.connect(func(): Game.main.show_map(loc_index + 1))
		row.add_child(nxt)
		focus = nxt
	action.add_child(row)
	UI.focus(focus)
	_scroll_down()


## Debug: play forward n steps without waiting for input.
func debug_skip(n: int) -> void:
	for i in n:
		if idx >= steps.size():
			return
		var s: Dictionary = steps[idx]
		if s.t in ["q", "choice"]:
			for opt in s.opts:
				if (s.t == "q" and opt.ok) or (s.t == "choice" and int(opt.grade) == 2):
					_clear_action()
					if s.t == "choice":
						_bubble("YO", opt.segs, opt.audio, false)
					break
		elif s.t == "type":
			_clear_action()
			_bubble("YO", s.model, "", false)
		_clear_action()
		_next()
	Game.stop_voice()


## Debug: play the whole scene through the real buttons and text box, so the
## answer handlers get exercised. Types one deliberately imperfect answer.
func debug_autoplay() -> void:
	var typed_count := 0
	var guard := 0
	while idx < steps.size() and guard < 400:
		guard += 1
		await get_tree().create_timer(0.05).timeout
		if not _options.is_empty():
			for b in _options.duplicate():
				if is_instance_valid(b) and not b.disabled and not _options.is_empty():
					b.pressed.emit()
			continue
		var edit := _find_edit(action)
		if edit != null and edit.editable:
			var s: Dictionary = steps[idx]
			typed_count += 1
			var answer: String = s.answers[0]
			if typed_count == 1:
				answer = UI.norm(answer, true)
			elif typed_count == 2:
				answer = "no lo sé"
			edit.text = answer
			edit.text_submitted.emit(answer)
			if typed_count == 2:
				edit.text_submitted.emit(answer)
			continue
		if _continue.is_valid():
			_continue.call()
	Game.stop_voice()
	print("autoplay finished: idx=%d/%d points=%.2f scorable=%d new_phrases=%d" % [idx,
		steps.size(), points, scorable, new_phrases.size()])


func _find_edit(node: Node) -> LineEdit:
	for c in node.get_children():
		if c is LineEdit:
			return c
		var found := _find_edit(c)
		if found:
			return found
	return null
