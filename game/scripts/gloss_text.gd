class_name GlossText
extends RichTextLabel
## Spanish text in which every glossed word or chunk can be clicked for its
## meaning. Pieces come from content.json as [text, gloss, kind, phrase_id].

const KIND_WORD := 1
const KIND_CHUNK := 2
const KIND_KEY := 3

var ctx := ""    # the full sentence, kept with a looked-up word for later review
var audio := ""
var quiet := false    # draw key phrases like ordinary text (answer options must not give themselves away)
var by_sentence := false    # a long paragraph: a looked-up word keeps only its own sentence
var _store: Array = []
var _at: Array = []    # where each stored piece starts in the plain text


func _init() -> void:
	bbcode_enabled = true
	fit_content = true
	scroll_active = false
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	meta_underlined = false
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# PASS so the mouse wheel still scrolls the conversation behind the text.
	mouse_filter = Control.MOUSE_FILTER_PASS
	meta_clicked.connect(_on_meta)
	set_style(19, UI.INK)


func set_style(size: int, color: Color) -> void:
	for key in ["normal_font_size", "bold_font_size", "italics_font_size",
			"bold_italics_font_size"]:
		add_theme_font_size_override(key, size)
	add_theme_color_override("default_color", color)


func set_segs(segs: Array, prefix := "", italic := false) -> void:
	_store.clear()
	_at.clear()
	if ctx == "":
		ctx = UI.plain(segs)
	var bb := prefix
	var offset := 0
	for seg in segs:
		var txt := UI.esc(str(seg[0]))
		var kind := int(seg[2])
		offset += str(seg[0]).length()
		if kind == 0:
			bb += txt
			continue
		var idx := _store.size()
		_store.append(seg)
		_at.append(offset - str(seg[0]).length())
		if quiet:
			bb += "[url=%d]%s[/url]" % [idx, txt]
		elif kind == KIND_KEY:
			bb += "[url=%d][color=#b8402a][b]%s[/b][/color][/url]" % [idx, txt]
		elif kind == KIND_CHUNK:
			bb += "[url=%d][color=#2e6f8e]%s[/color][/url]" % [idx, txt]
		else:
			bb += "[url=%d]%s[/url]" % [idx, txt]
	text = "[i]%s[/i]" % bb if italic else bb


func set_plain(s: String, italic := false) -> void:
	_store.clear()
	text = "[i]%s[/i]" % UI.esc(s) if italic else UI.esc(s)


func _on_meta(meta: Variant) -> void:
	var idx := int(str(meta))
	if idx >= 0 and idx < _store.size():
		Game.main.show_gloss(_store[idx], get_global_mouse_position(),
			UI.sentence_at(ctx, _at[idx]) if by_sentence else ctx, audio)
