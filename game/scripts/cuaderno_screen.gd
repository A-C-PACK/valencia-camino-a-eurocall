extends Control
## The notebook: browse, filter and select phrases; review them (spaced
## repetition, or a hand-picked set); print them as flashcards.

const CARDS_PER_SHEET := 8

var start_review := false
var body: VBoxContainer
var queue: Array = []
var done := 0
var total := 0

var show_all := false           # every key phrase in the game, not only those met so far
var place := ""                 # "" = everywhere, "w" = looked-up words, else a location id
var search := ""
var selected: Dictionary = {}   # card id -> true
var _list: VBoxContainer
var _practice: Button
var _print: Button
var _status: Label


func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for m in ["margin_left", "margin_right"]:
		margin.add_theme_constant_override(m, 50)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	margin.add_child(v)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	var back := UI.button("← Mapa", "small", UI.INK)
	back.pressed.connect(func(): Game.main.show_map())
	top.add_child(back)
	top.add_child(UI.label("Mi cuaderno", 32, UI.INK, "serif"))
	top.add_child(UI.spacer(0, 0, true))
	var sheets := UI.button("Hojas de frases de todos los lugares", "small", UI.TEAL)
	sheets.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sheets.pressed.connect(func():
		var msg := Game.open_html(Sheet.html(range(Game.locations.size())), "hojas-de-frases.html")
		if _status:
			_status.text = msg)
	top.add_child(sheets)
	v.add_child(top)

	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)
	if start_review and not Game.srs_due().is_empty():
		_begin_review(Game.srs_due(), 20)
	else:
		_show_list()


func _clear() -> void:
	for c in body.get_children():
		body.remove_child(c)
		c.queue_free()
	Game.stop_voice()


func _when(id: String) -> String:
	if not Game.save.srs.has(id):
		return "nueva"
	var days := int(Game.save.srs[id].due) - Game.today()
	if days <= 0:
		return "hoy"
	return "mañana" if days == 1 else "en %d días" % days


func _loc_index(id: String) -> int:
	var loc := str(Game.card(id).get("loc", ""))
	for i in Game.locations.size():
		if Game.locations[i].id == loc:
			return i
	return 99


# ----------------------------------------------------------------------- list

func _visible_ids() -> Array:
	var ids: Array = Game.save.srs.keys()
	if show_all:
		for id in Game.phrases.keys():
			if not ids.has(id):
				ids.append(id)
	var needle := UI.norm(search, true)
	var out: Array = []
	for id in ids:
		var c: Dictionary = Game.card(id)
		if c.is_empty():
			continue
		var is_word := str(id).begins_with("w:")
		if place == "w" and not is_word:
			continue
		if place != "" and place != "w" and (is_word or str(c.loc) != place):
			continue
		if needle != "" and not (UI.norm(str(c.es), true).contains(needle)
				or str(c.en).to_lower().contains(needle)):
			continue
		out.append(id)
	out.sort_custom(func(a, b):
		var la := _loc_index(a)
		var lb := _loc_index(b)
		if la != lb:
			return la < lb
		return str(Game.card(a).es).to_lower() < str(Game.card(b).es).to_lower())
	return out


func _show_list() -> void:
	_clear()
	var due := Game.srs_due()

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	var summary := "%d en tu cuaderno · %d para repasar hoy" % [Game.save.srs.size(), due.size()]
	var sl := UI.label(summary, 17, UI.MUTED)
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sl)
	var go := UI.button("Repasar las de hoy (%d)" % due.size())
	go.disabled = due.is_empty()
	go.pressed.connect(func(): _begin_review(Game.srs_due(), 20))
	head.add_child(go)
	body.add_child(head)

	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 12)
	var where := OptionButton.new()
	where.custom_minimum_size = Vector2(250, 38)
	where.add_item("Todos los lugares")
	where.set_item_metadata(0, "")
	for loc in Game.locations:
		where.add_item(loc.name)
		where.set_item_metadata(where.item_count - 1, loc.id)
	where.add_item("Palabras que he buscado")
	where.set_item_metadata(where.item_count - 1, "w")
	for i in where.item_count:
		if where.get_item_metadata(i) == place:
			where.select(i)
	where.item_selected.connect(func(i: int):
		place = where.get_item_metadata(i)
		_fill_list())
	filters.add_child(where)
	var find := LineEdit.new()
	find.placeholder_text = "Buscar en español o en inglés…"
	find.text = search
	find.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	find.add_theme_font_size_override("font_size", 16)
	find.text_changed.connect(func(t: String):
		search = t
		_fill_list())
	filters.add_child(find)
	WebField.attach(find)
	var all := CheckBox.new()
	all.text = "Ver todas las frases del juego"
	all.button_pressed = show_all
	all.add_theme_font_size_override("font_size", 15)
	all.toggled.connect(func(on: bool):
		show_all = on
		_fill_list())
	filters.add_child(all)
	body.add_child(filters)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	var pick_all := UI.button("Seleccionar todas", "small", UI.INK)
	pick_all.pressed.connect(func():
		for id in _visible_ids():
			selected[id] = true
		_fill_list())
	actions.add_child(pick_all)
	var pick_none := UI.button("Ninguna", "small", UI.INK)
	pick_none.pressed.connect(func():
		selected.clear()
		_fill_list())
	actions.add_child(pick_none)
	_status = UI.label("", 14, UI.MUTED, "italic")
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.clip_text = true
	actions.add_child(_status)
	_practice = UI.button("", "ghost", UI.ORANGE)
	_practice.pressed.connect(func(): _begin_review(selected.keys(), 0))
	actions.add_child(_practice)
	_print = UI.button("", "ghost", UI.TEAL)
	_print.pressed.connect(func(): _print_cards(selected.keys()))
	actions.add_child(_print)
	body.add_child(actions)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 5)
	scroll.add_child(_list)
	_fill_list()


func _update_actions() -> void:
	var n := selected.size()
	_practice.text = "Practicar seleccionadas (%d)" % n
	_practice.disabled = n == 0
	_print.text = "Imprimir tarjetas (%d)" % n
	_print.disabled = n == 0


func _fill_list() -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	var ids := _visible_ids()
	# A selection only ever covers what is on screen, so nothing hidden gets printed.
	for id in selected.keys():
		if not ids.has(id):
			selected.erase(id)
	_update_actions()
	if ids.is_empty():
		var msg := "Nada por aquí. Las frases clave de cada escena aparecerán en tu cuaderno."
		if search != "" or place != "":
			msg = "Ninguna frase coincide con el filtro."
		_list.add_child(UI.label(msg, 17, UI.MUTED, "italic"))
		return

	var last_loc := -2
	for id in ids:
		var li := _loc_index(id)
		if li != last_loc:
			last_loc = li
			var title: String = Game.locations[li].name if li < 99 else "Palabras que he buscado"
			_list.add_child(UI.label(title.to_upper(), 12, UI.ORANGE, "bold"))
		_list.add_child(_row(id))


func _row(id: String) -> Control:
	var c: Dictionary = Game.card(id)
	var mine: bool = Game.save.srs.has(id)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var box := CheckBox.new()
	box.button_pressed = selected.has(id)
	box.toggled.connect(func(on: bool):
		if on:
			selected[id] = true
		else:
			selected.erase(id)
		_update_actions())
	row.add_child(box)
	var es := UI.label(c.es, 17, UI.RED if not id.begins_with("w:") else UI.INK, "bold")
	es.custom_minimum_size = Vector2(300, 0)
	es.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(es)
	var en := UI.label(c.en, 16, UI.INK)
	en.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	en.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(en)
	var when := UI.label(_when(id), 13, UI.MUTED if mine else UI.TEAL)
	when.custom_minimum_size = Vector2(76, 0)
	row.add_child(when)
	if Game.has_voice(str(c.audio)):
		var play := UI.button("Oír", "small", UI.TEAL)
		play.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		play.pressed.connect(func(): Game.play_voice(str(c.audio)))
		row.add_child(play)
	if mine:
		var drop := UI.button("Quitar", "small", UI.MUTED)
		drop.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		drop.tooltip_text = "Quitar del cuaderno: no volverá a salir en los repasos"
		drop.pressed.connect(func():
			Game.srs_remove(id)
			selected.erase(id)
			_fill_list())
		row.add_child(drop)
	var p := UI.panel(Color.WHITE if mine else Color("f7f1e1"), 8, UI.LINE, 1, 7)
	p.add_child(row)
	return p


# ----------------------------------------------------------------- flashcards

const CARD_PAGE := """<!doctype html>
<html lang="es"><head><meta charset="utf-8"><title>Tarjetas · Valencia</title>
<style>
@page { size: letter; margin: 0.5in; }
* { box-sizing: border-box; }
body { margin: 0; font-family: Georgia, 'Times New Roman', serif; color: #1f3a4d; }
.note { font-family: 'Segoe UI', sans-serif; background: #fbf0cf; border: 1px solid #e8a33d;
	padding: 12px 16px; margin: 16px; border-radius: 8px; font-size: 14px; }
.sheet { display: grid; grid-template-columns: 1fr 1fr; grid-template-rows: repeat(4, 2.45in);
	width: 7.5in; margin: 0 auto 0.4in; page-break-after: always; }
.card { border: 1px dashed #9a927e; padding: 0.18in; display: flex; flex-direction: column;
	justify-content: center; align-items: center; text-align: center; overflow: hidden; }
.es { font-size: 21pt; font-weight: bold; color: #b8402a; }
.en { font-size: 14pt; }
.ctx { font-size: 10.5pt; font-style: italic; color: #555; margin-top: 9pt; }
.loc { font-family: 'Segoe UI', sans-serif; font-size: 8pt; letter-spacing: .1em;
	text-transform: uppercase; color: #8a8270; margin-top: 9pt; }
@media print { .note { display: none; } .sheet { margin: 0; } }
</style></head><body>
<div class="note"><b>__COUNT__ tarjetas.</b> Imprime a doble cara, volteando por el
<b>borde largo</b> (Ctrl+P). Las páginas impares son las caras en español; las pares, el
significado. Corta por las líneas de puntos. Si imprimes a una cara, dobla o pega cada pareja.</div>
__PAGES__</body></html>
"""


func _esc(s: String) -> String:
	return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


## Writes a print-ready page of cut-out flashcards and opens it in the browser.
## Fronts and backs are on alternate pages, with the backs mirrored left-right
## so the two sides line up when printed double-sided.
func _print_cards(ids: Array) -> void:
	ids.sort_custom(func(a, b): return _loc_index(a) < _loc_index(b))
	var pages := ""
	for start in range(0, ids.size(), CARDS_PER_SHEET):
		var sheet: Array = ids.slice(start, start + CARDS_PER_SHEET)
		while sheet.size() < CARDS_PER_SHEET:
			sheet.append("")
		var front := ""
		var back := ""
		for r in range(0, CARDS_PER_SHEET, 2):
			front += _card_front(sheet[r]) + _card_front(sheet[r + 1])
			back += _card_back(sheet[r + 1]) + _card_back(sheet[r])
		pages += "<section class='sheet'>" + front + "</section>\n"
		pages += "<section class='sheet'>" + back + "</section>\n"
	var html := CARD_PAGE.replace("__COUNT__", str(ids.size())).replace("__PAGES__", pages)
	_status.text = Game.open_html(html, "tarjetas.html")


func _card_front(id: String) -> String:
	if id == "":
		return "<div class='card'></div>"
	return "<div class='card'><div class='es'>" + _esc(str(Game.card(id).es)) + "</div></div>"


func _card_back(id: String) -> String:
	if id == "":
		return "<div class='card'></div>"
	var c: Dictionary = Game.card(id)
	var li := _loc_index(id)
	var loc: String = Game.locations[li].name if li < 99 else ""
	return ("<div class='card'><div class='en'>" + _esc(str(c.en)) + "</div><div class='ctx'>"
		+ _esc(str(c.ctx)) + "</div><div class='loc'>" + _esc(loc) + "</div></div>")


# --------------------------------------------------------------------- review

## ids: the cards to go through; limit: cap the session (0 = no cap).
func _begin_review(ids: Array, limit: int) -> void:
	queue = ids.duplicate()
	for id in queue:
		Game.srs_add(id)     # a hand-picked phrase not met yet joins the cuaderno
	Game.write_save()
	queue.shuffle()
	if limit > 0:
		queue = queue.slice(0, limit)
	total = queue.size()
	done = 0
	_show_card()


func _show_card() -> void:
	_clear()
	if queue.is_empty():
		var l := UI.label("¡Repaso terminado! Has repasado %d tarjetas." % total, 24, UI.INK,
			"serif")
		body.add_child(UI.spacer(0, 60))
		body.add_child(l)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var again := UI.button("Volver al cuaderno", "ghost", UI.TEAL)
		again.pressed.connect(_show_list)
		row.add_child(again)
		var b := UI.button("Volver al mapa")
		b.pressed.connect(func(): Game.main.show_map())
		row.add_child(b)
		body.add_child(row)
		UI.focus(b)
		return

	var id: String = queue[0]
	var c: Dictionary = Game.card(id)
	body.add_child(UI.label("Tarjeta %d de %d" % [done + 1, total], 14, UI.MUTED, "bold"))

	var card := UI.panel(Color.WHITE, 14, UI.LINE, 2, 26)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	card.add_child(v)
	body.add_child(card)

	v.add_child(UI.label("¿CÓMO SE DICE EN ESPAÑOL?", 13, UI.ORANGE, "bold"))
	var en := UI.label(c.en, 30, UI.INK, "serif")
	en.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(en)
	var gap := str(c.ctx).replacen(str(c.es), "_____")
	var ctx := UI.label(gap, 20, UI.MUTED, "italic")
	ctx.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(ctx)

	var edit := LineEdit.new()
	edit.placeholder_text = "Escribe la frase (o pulsa Mostrar)…"
	edit.custom_minimum_size = Vector2(0, 46)
	v.add_child(edit)
	WebField.attach(edit, true)
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 8)
	tools.add_child(UI.accent_row(edit))
	tools.add_child(UI.spacer(0, 0, true))
	var show_btn := UI.button("Mostrar")
	tools.add_child(show_btn)
	v.add_child(tools)

	var answer := VBoxContainer.new()
	answer.add_theme_constant_override("separation", 10)
	v.add_child(answer)

	var reveal := func():
		if answer.get_child_count() > 0:
			return
		show_btn.disabled = true
		edit.editable = false
		var typed := edit.text.strip_edges()
		var verdict := ""
		if typed != "":
			verdict = UI.check(typed, [str(c.es)]).verdict
		var es := UI.label(c.es, 28, UI.RED, "bold")
		es.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		answer.add_child(es)
		var full := UI.label(c.ctx, 19, UI.INK)
		full.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		answer.add_child(full)
		if verdict != "":
			var msg: String = {"exact": "¡Perfecto!", "accent": "Bien, pero revisa las tildes.",
				"close": "Casi.", "no": "No es lo mismo. Compara."}[verdict]
			answer.add_child(UI.label(msg, 17,
				UI.GREEN.darkened(0.15) if verdict in ["exact", "accent"] else UI.ORANGE, "bold"))
		Game.play_voice(str(c.audio))
		var grades := HBoxContainer.new()
		grades.add_theme_constant_override("separation", 10)
		if Game.has_voice(str(c.audio)):
			var play := UI.button("Oír", "ghost", UI.TEAL)
			play.pressed.connect(func(): Game.play_voice(str(c.audio)))
			grades.add_child(play)
		var rec := Recorder.new(str(c.audio))
		rec.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		grades.add_child(rec)
		grades.add_child(UI.spacer(0, 0, true))
		var defs := [["Otra vez", UI.RED, 0], ["Difícil", UI.ORANGE, 1], ["Bien", UI.GREEN, 2],
			["Fácil", UI.TEAL, 3]]
		var suggested := 2
		if verdict in ["no", "close"]:
			suggested = 0 if verdict == "no" else 1
		for d in defs:
			var b := UI.button(d[0], "primary" if d[2] == suggested else "ghost", d[1])
			b.custom_minimum_size = Vector2(120, 46)
			b.pressed.connect(func(): _grade(id, d[2]))
			grades.add_child(b)
			if d[2] == suggested:
				UI.focus(b)
		answer.add_child(grades)
	show_btn.pressed.connect(reveal)
	edit.text_submitted.connect(func(_t: String): reveal.call())
	UI.focus(edit)


func _grade(id: String, grade: int) -> void:
	Game.srs_grade(id, grade)
	queue.pop_front()
	if grade == 0:
		queue.append(id)    # missed cards come round again before the session ends
	else:
		done += 1
	_show_card()
