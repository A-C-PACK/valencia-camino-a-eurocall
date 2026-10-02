extends Node
## Autoload: content, save file, spaced repetition and voice playback.

var save_path := "user://save.json"
const VOICE_DIR := "res://audio/voice/"
const ART_DIR := "res://art/"
const SLOW := 0.8

var cast: Dictionary = {}
var locations: Array = []
var phrases: Dictionary = {}
var save: Dictionary = {}

var main: Control
var voice: AudioStreamPlayer
var _voice_bus := 0
var _art_cache: Dictionary = {}

var recording := false
var _mic: AudioStreamPlayer
var _rec_effect: AudioEffectRecord
var _take_player: AudioStreamPlayer
var _queued_take: AudioStreamWAV


func _ready() -> void:
	# Debug snapshot runs must never touch the player's real progress.
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			save_path = "user://debug_save.json"
	_load_content()
	_load_save()
	_setup_audio()


func _load_content() -> void:
	var f := FileAccess.open("res://data/content.json", FileAccess.READ)
	if f == null:
		push_error("data/content.json is missing: run tools/build_content.py")
		return
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	cast = data.get("cast", {})
	locations = data.get("locations", [])
	phrases = data.get("phrases", {})


# ------------------------------------------------------------------ save file

func _load_save() -> void:
	save = {"scenes": {}, "srs": {}, "words": {}, "settings": {}}
	if FileAccess.file_exists(save_path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(save_path))
		if parsed is Dictionary:
			for k in save.keys():
				if parsed.get(k) is Dictionary:
					save[k] = parsed[k]


func write_save() -> void:
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(save))


func setting(key: String, default: Variant) -> Variant:
	return save.settings.get(key, default)


func set_setting(key: String, value: Variant) -> void:
	save.settings[key] = value
	write_save()


# ------------------------------------------------------------------- progress

func scene_key(loc: Dictionary, scene: Dictionary) -> String:
	return "%s/%s" % [loc.id, scene.id]


func scene_stars(loc: Dictionary, scene: Dictionary) -> int:
	return int(save.scenes.get(scene_key(loc, scene), {}).get("stars", 0))


func record_scene(loc: Dictionary, scene: Dictionary, stars: int) -> void:
	var key := scene_key(loc, scene)
	var best: int = max(stars, scene_stars(loc, scene))
	save.scenes[key] = {"stars": best, "plays": int(save.scenes.get(key, {}).get("plays", 0)) + 1}
	write_save()


func location_done(loc: Dictionary) -> int:
	var n := 0
	for s in loc.scenes:
		if scene_stars(loc, s) > 0:
			n += 1
	return n


## Part 1 is the trip (conversations); part 2 is the history of the city (readings).
## Each part has its own itinerary, numbered from 1 and open from the start.
func part_of(index: int) -> int:
	return int(locations[index].get("part", 1))


func part_indices(part: int) -> Array:
	var out: Array = []
	for i in locations.size():
		if part_of(i) == part:
			out.append(i)
	return out


func number_in_part(index: int) -> int:
	return part_indices(part_of(index)).find(index) + 1


func location_unlocked(index: int) -> bool:
	if setting("unlock_all", false):
		return true
	var n := number_in_part(index)
	return n == 1 or location_done(locations[part_indices(part_of(index))[n - 2]]) > 0


## The place to open a part on: the first one with a scene still to do.
func next_in_part(part: int) -> int:
	var all := part_indices(part)
	for i in all:
		if location_done(locations[i]) < locations[i].scenes.size():
			return i if location_unlocked(i) else all[max(0, all.find(i) - 1)]
	return all[0]


## part 0 = the whole game
func total_stars(part := 0) -> int:
	var n := 0
	for i in locations.size():
		if part == 0 or part_of(i) == part:
			for s in locations[i].scenes:
				n += scene_stars(locations[i], s)
	return n


func max_stars(part := 0) -> int:
	var n := 0
	for i in locations.size():
		if part == 0 or part_of(i) == part:
			n += locations[i].scenes.size() * 3
	return n


# ---------------------------------------------------------- spaced repetition
# A card is a key phrase from the script (id from content.json) or a word the
# player looked up (id "w:<word>", stored in save.words).

func today() -> int:
	return int(Time.get_unix_time_from_system() / 86400.0)


func card(id: String) -> Dictionary:
	if phrases.has(id):
		return phrases[id]
	return save.words.get(id, {})


func srs_add(id: String) -> bool:
	if save.srs.has(id) or card(id).is_empty():
		return false
	save.srs[id] = {"iv": 0, "ease": 2.5, "reps": 0, "lapses": 0, "due": today()}
	return true


func srs_remove(id: String) -> void:
	save.srs.erase(id)
	save.words.erase(id)
	write_save()


func add_word(word: String, gloss: String, ctx: String, audio: String) -> void:
	var id := "w:" + word.to_lower()
	if not save.words.has(id):
		save.words[id] = {"es": word.to_lower(), "en": gloss, "ctx": ctx, "audio": audio, "loc": ""}
	srs_add(id)
	write_save()


func srs_due() -> Array:
	var out: Array = []
	var t := today()
	for id in save.srs.keys():
		if int(save.srs[id].due) <= t and not card(id).is_empty():
			out.append(id)
	return out


## grade: 0 otra vez, 1 difícil, 2 bien, 3 fácil
func srs_grade(id: String, grade: int) -> void:
	var c: Dictionary = save.srs[id]
	var iv := int(c.iv)
	var ease := float(c.ease)
	var reps := int(c.reps)
	match grade:
		0:
			iv = 0
			reps = 0
			ease = max(1.3, ease - 0.2)
			c.lapses = int(c.lapses) + 1
		1:
			iv = max(1, int(round(iv * 1.2)))
			ease = max(1.3, ease - 0.15)
			reps += 1
		2:
			iv = 1 if reps == 0 else (3 if reps == 1 else int(round(iv * ease)))
			reps += 1
		3:
			iv = 3 if reps == 0 else int(round(max(iv, 1) * ease * 1.3))
			ease += 0.15
			reps += 1
	c.iv = iv
	c.ease = ease
	c.reps = reps
	c.due = today() + iv
	write_save()


# ---------------------------------------------------------------------- audio

func _setup_audio() -> void:
	_voice_bus = AudioServer.bus_count
	AudioServer.add_bus(_voice_bus)
	AudioServer.set_bus_name(_voice_bus, "Voice")
	AudioServer.set_bus_send(_voice_bus, "Master")
	# Slowed playback drops the pitch; this shifts it back up so a slow line
	# still sounds like the same person.
	var shift := AudioEffectPitchShift.new()
	shift.pitch_scale = 1.0 / SLOW
	AudioServer.add_bus_effect(_voice_bus, shift)
	AudioServer.set_bus_effect_enabled(_voice_bus, 0, false)
	voice = AudioStreamPlayer.new()
	voice.bus = "Voice"
	add_child(voice)

	# Microphone -> a muted bus with a record effect, so the player never hears
	# themselves live. The mic stream only runs while a recording is being made.
	var rec_bus := AudioServer.bus_count
	AudioServer.add_bus(rec_bus)
	AudioServer.set_bus_name(rec_bus, "Record")
	AudioServer.set_bus_mute(rec_bus, true)
	_rec_effect = AudioEffectRecord.new()
	AudioServer.add_bus_effect(rec_bus, _rec_effect)
	_mic = AudioStreamPlayer.new()
	_mic.stream = AudioStreamMicrophone.new()
	_mic.bus = "Record"
	add_child(_mic)
	_take_player = AudioStreamPlayer.new()
	add_child(_take_player)
	voice.finished.connect(_on_voice_finished)


func _load_stream(id: String) -> AudioStream:
	if id == "":
		return null
	var path := VOICE_DIR + id + ".ogg"
	if ResourceLoader.exists(path):
		return load(path)
	# Not imported yet (fresh from the TTS run): read the file directly.
	var abs_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(abs_path):
		return AudioStreamOggVorbis.load_from_file(abs_path)
	return null


func has_voice(id: String) -> bool:
	return id != "" and (ResourceLoader.exists(VOICE_DIR + id + ".ogg")
		or FileAccess.file_exists(ProjectSettings.globalize_path(VOICE_DIR + id + ".ogg")))


func play_voice(id: String, slow := false) -> bool:
	var stream := _load_stream(id)
	_queued_take = null
	voice.stop()
	_take_player.stop()
	if stream == null:
		return false
	voice.stream = stream
	voice.pitch_scale = SLOW if slow else 1.0
	AudioServer.set_bus_effect_enabled(_voice_bus, 0, slow)
	voice.play()
	return true


func stop_voice() -> void:
	_queued_take = null
	voice.stop()
	_take_player.stop()


# ------------------------------------------------------------------ recording

func start_recording() -> bool:
	if AudioServer.get_input_device_list().is_empty():
		return false
	_mic.play()
	_rec_effect.set_recording_active(true)
	recording = true
	return true


func stop_recording() -> AudioStreamWAV:
	recording = false
	_rec_effect.set_recording_active(false)
	_mic.stop()
	return _rec_effect.get_recording()


func play_take(take: AudioStreamWAV) -> void:
	if take == null:
		return
	stop_voice()
	_take_player.stream = take
	_take_player.play()


## Model line first, then the player's own take, for a back-to-back comparison.
func play_voice_then_take(id: String, take: AudioStreamWAV) -> void:
	stop_voice()
	if play_voice(id):
		_queued_take = take
	else:
		play_take(take)


func _on_voice_finished() -> void:
	if _queued_take != null:
		var take := _queued_take
		_queued_take = null
		_take_player.stream = take
		_take_player.play()


# ----------------------------------------------------------- printable pages

## Show a generated HTML page (flashcards, phrase sheets) to the player: in a
## new browser tab on the web, in the default browser on the desktop.
## Returns a short status line for the screen.
func open_html(html: String, filename: String) -> String:
	if OS.has_feature("web"):
		var js := ("(function(){var b=new Blob([%s],{type:'text/html'});"
			+ "var w=window.open(URL.createObjectURL(b),'_blank');return w?1:0;})()") % JSON.stringify(html)
		if JavaScriptBridge.eval(js, true):
			return "Abierto en una pestaña nueva."
		# a pop-up blocker said no: hand it over as a download instead
		JavaScriptBridge.download_buffer(html.to_utf8_buffer(), filename, "text/html")
		return "Descargado: " + filename
	var path := "user://" + filename
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return "No se ha podido crear el archivo."
	f.store_string(html)
	f.close()
	var real := ProjectSettings.globalize_path(path)
	if not save_path.contains("debug"):
		OS.shell_open(real)
	return "Abierto en el navegador: " + real


# ------------------------------------------------------------------------ art

func art(art_name: String) -> Texture2D:
	if _art_cache.has(art_name):
		return _art_cache[art_name]
	var tex: Texture2D = null
	var path := ART_DIR + art_name + ".png"
	if ResourceLoader.exists(path):
		tex = load(path)
	else:
		var abs_path := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(abs_path):
			var img := Image.load_from_file(abs_path)
			if img:
				tex = ImageTexture.create_from_image(img)
	_art_cache[art_name] = tex
	return tex
