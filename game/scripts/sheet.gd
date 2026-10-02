class_name Sheet
extends RefCounted
## Builds a printable one-page phrase sheet for a place: what to say in each
## situation, the key phrases with their meanings, and the culture notes.
## A part 2 place gets its readings instead, with their questions and vocabulary.

const STYLE := """
@page { size: letter; margin: 0.55in; }
* { box-sizing: border-box; }
body { margin: 0; font-family: 'Segoe UI', 'Helvetica Neue', Arial, sans-serif; color: #1f3a4d;
	font-size: 10.5pt; line-height: 1.32; }
.bar { background: #fbf0cf; border: 1px solid #e8a33d; padding: 10px 14px; margin: 14px;
	border-radius: 8px; font-size: 14px; }
.sheet { max-width: 7.4in; margin: 0 auto 0.5in; page-break-after: always; }
.sheet:last-child { page-break-after: auto; }
header { border-bottom: 3px solid #d9622b; padding-bottom: 6px; margin-bottom: 10px; }
.kicker { font-size: 8.5pt; letter-spacing: .12em; text-transform: uppercase; color: #d9622b;
	font-weight: 700; }
h1 { font-family: Georgia, 'Times New Roman', serif; font-size: 22pt; margin: 0; }
.goal { color: #2e6f8e; margin-top: 3px; }
h2 { font-size: 9pt; letter-spacing: .1em; text-transform: uppercase; color: #2e6f8e;
	border-bottom: 1px solid #d8c49a; padding-bottom: 2px; margin: 12px 0 6px; }
.cols { display: grid; grid-template-columns: 1.12fr 1fr; gap: 0 0.3in; }
.say { margin-bottom: 6px; break-inside: avoid; }
.when { color: #6b7780; font-size: 9pt; }
.what { font-weight: 700; color: #b8402a; font-size: 11.5pt; }
.scene { font-weight: 700; margin: 8px 0 4px; }
table { border-collapse: collapse; width: 100%; }
td { vertical-align: top; padding: 2px 0; border-bottom: 1px dotted #d8c49a; }
td.es { font-weight: 700; padding-right: 8px; width: 44%; }
td.en { color: #3c4f5c; font-size: 9.5pt; }
.note { margin-bottom: 6px; font-size: 9.5pt; break-inside: avoid; }
.note b { color: #1f3a4d; }
footer { margin-top: 10px; font-size: 8pt; color: #8a8270; }
h3 { font-family: Georgia, 'Times New Roman', serif; font-size: 14pt; margin: 12px 0 5px; }
.read p { font-family: Georgia, 'Times New Roman', serif; font-size: 11pt; line-height: 1.45;
	text-align: justify; margin: 0 0 7px; }
.read p b { color: #b8402a; }
ol.qs { margin: 4px 0 0; padding-left: 18px; font-size: 9.5pt; }
ol.qs li { margin-bottom: 2px; }
@media print { .bar { display: none; } .sheet { margin: 0; max-width: none; } }
"""


static func _esc(s: String) -> String:
	return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


## The first sentence of a prompt is the situation; the rest ("¿Qué dices?")
## is the question, which a reference sheet does not need.
static func _situation(segs: Array) -> String:
	var text := UI.plain(segs).strip_edges()
	for ending in [" ¿Qué dices?", " ¿Qué respondes?", " ¿Qué preguntas?", " ¿Qué dices tú?"]:
		text = text.replace(ending, "")
	return text


## A paragraph with its key phrases in bold.
static func _marked(segs: Array) -> String:
	var out := ""
	for seg in segs:
		var txt := _esc(str(seg[0]))
		out += "<b>%s</b>" % txt if int(seg[2]) == GlossText.KIND_KEY else txt
	return out


static func _vocabulary(loc: Dictionary) -> String:
	var rows := ""
	for id in Game.phrases:
		var c: Dictionary = Game.phrases[id]
		if str(c.loc) == str(loc.id):
			rows += "<tr><td class='es'>%s</td><td class='en'>%s</td></tr>" % [_esc(str(c.es)),
				_esc(str(c.en))]
	return rows


static func _reading(loc: Dictionary, number: int) -> String:
	var body := ""
	var notes := ""
	for scene in loc.scenes:
		var questions := ""
		for step in scene.steps:
			var t: String = step.t
			if t == "head":
				body += "<h3>%s</h3>" % _esc(str(step.title))
			elif t == "read":
				body += "<p>%s</p>" % _marked(step.segs)
			elif t in ["q", "order"]:
				questions += "<li>%s</li>" % _esc(UI.plain(step.segs))
			elif t == "note":
				notes += "<div class='note'><b>%s.</b> %s</div>" % [_esc(str(step.title)),
					_esc(UI.plain(step.segs))]
		if questions != "":
			body += "<h2>Para pensar</h2><ol class='qs'>%s</ol>" % questions
	var visit := UI.plain(loc.visit) if loc.has("visit") else ""
	var route := UI.plain(loc.route) if loc.has("route") else ""
	return ("<section class='sheet'><header><div class='kicker'>%d · %s</div><h1>%s</h1>"
		+ "<div class='goal'>%s</div></header><div class='read'>%s</div>"
		+ "<div class='cols'><div><h2>Vocabulario</h2><table>%s</table></div>"
		+ "<div><h2>Notas</h2>%s<div class='note'><b>Qué ver hoy.</b> %s</div>"
		+ "<div class='note'><b>Dónde está.</b> %s</div></div></div>"
		+ "<footer>Valencia: Camino a EUROCALL · parte 2, la historia</footer></section>") % [
		number, _esc(str(loc.get("era", ""))), _esc(str(loc.name)),
		_esc(UI.plain(loc.get("blurb", []))), body, _vocabulary(loc), notes, _esc(visit),
		_esc(route)]


static func _place(loc: Dictionary, number: int) -> String:
	if int(loc.get("part", 1)) == 2:
		return _reading(loc, number)
	var say := ""
	var notes := ""
	for scene in loc.scenes:
		say += "<div class='scene'>%s</div>" % _esc(str(scene.title))
		for step in scene.steps:
			var t: String = step.t
			if t == "choice":
				for opt in step.opts:
					if int(opt.grade) == 2:
						say += "<div class='say'><div class='when'>%s</div><div class='what'>%s</div></div>" % [
							_esc(_situation(step.segs)), _esc(str(opt.text))]
						break
			elif t == "type":
				say += "<div class='say'><div class='when'>%s</div><div class='what'>%s</div></div>" % [
					_esc(_situation(step.segs)), _esc(str(step.answers[0]))]
			elif t == "note":
				var title := str(step.title)
				if not title.right(1) in ["?", "!", "."]:
					title += "."
				notes += "<div class='note'><b>%s</b> %s</div>" % [_esc(title),
					_esc(UI.plain(step.segs))]

	var rows := _vocabulary(loc)
	var goal := UI.plain(loc.goal) if loc.has("goal") else ""
	var route := UI.plain(loc.route) if loc.has("route") else ""
	return ("<section class='sheet'><header><div class='kicker'>%d · %s</div><h1>%s</h1>"
		+ "<div class='goal'>%s</div></header><div class='cols'><div><h2>Qué decir</h2>%s</div>"
		+ "<div><h2>Frases clave</h2><table>%s</table><h2>Notas</h2>%s"
		+ "<div class='note'><b>Cómo llegar.</b> %s</div></div></div>"
		+ "<footer>Valencia: Camino a EUROCALL · hoja de frases</footer></section>") % [
		number, _esc(str(loc.get("zone", ""))), _esc(str(loc.name)), _esc(goal), say, rows, notes,
		_esc(route)]


## indices: which places to include, in order.
static func html(indices: Array) -> String:
	var pages := ""
	for i in indices:
		pages += _place(Game.locations[i], Game.number_in_part(i)) + "\n"
	var title := "Hojas de frases y lecturas · Valencia"
	if indices.size() == 1:
		var reading: bool = Game.part_of(indices[0]) == 2
		title = ("Lecturas · " if reading else "Hoja de frases · ") \
			+ str(Game.locations[indices[0]].name)
	return ("<!doctype html><html lang='es'><head><meta charset='utf-8'><title>%s</title>"
		+ "<style>%s</style></head><body><div class='bar'><b>%s</b> — imprime con Ctrl+P. "
		+ "Cada lugar empieza en una hoja nueva.</div>%s</body></html>") % [_esc(title), STYLE, _esc(title),
		pages]
