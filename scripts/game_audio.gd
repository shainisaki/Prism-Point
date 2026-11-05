extends Node

const TRACKS := {"sternenlauf": "Sternenlauf Protokoll", "broken": "Broken Docking Bay", "lightspeed": "Lightspeed Galaxy"}
const FREQUENCIES = {"shot": 640.0, "hit": 320.0, "kill": 880.0, "hurt": 110.0, "collect": 1100.0, "boss": 75.0, "ui": 440.0}
const GROUPS = {"shot": "shot_volume", "hit": "hit_volume", "kill": "hit_volume", "hurt": "warning_volume", "boss": "warning_volume", "collect": "collect_volume", "ui": "ui_volume"}
var music: AudioStreamPlayer
var sounds: Array[AudioStreamPlayer] = []
var settings: Dictionary
var current_song := ""
var sound_index := 0
var focused := true
var effect_streams: Dictionary = {}

func _exit_tree() -> void:
	# Explicitly release looping decoders, including with the headless audio driver.
	if is_instance_valid(music):
		music.stop()
		music.stream = null
	for voice in sounds:
		if is_instance_valid(voice):
			voice.stop()
			voice.stream = null
	effect_streams.clear()

func _ready() -> void:
	music = AudioStreamPlayer.new()
	add_child(music)
	for i in 8:
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		sounds.append(voice)
	for kind in FREQUENCIES: effect_streams[kind] = make_effect(kind)

func apply_settings(value: Dictionary) -> void:
	settings = value.duplicate(true)
	var song := str(settings.get("song", "sternenlauf"))
	if not TRACKS.has(song):
		song = "sternenlauf"
	if song != current_song:
		current_song = song
		var stream := load("res://assets/audio/%s.mp3" % song) as AudioStreamMP3
		stream.loop = true
		music.stream = stream
		music.play()
	update_music_gain()

func set_focus(value: bool) -> void:
	focused = value
	if is_instance_valid(music): update_music_gain()
	if not focused and settings.get("mute_unfocused", true):
		for voice in sounds: voice.stop()

func update_music_gain() -> void:
	var gain = float(settings.get("master_volume", 1.0)) * float(settings.get("volume", 0.7))
	music.volume_db = linear_to_db(maxf(gain, 0.00001)) - 10.0
	music.stream_paused = not settings.get("music", true) or gain <= 0 or (not focused and settings.get("mute_unfocused", true))

func effect_gain(kind: String) -> float:
	var group = GROUPS.get(kind, "sfx_volume")
	return float(settings.get("master_volume", 1.0)) * float(settings.get("sfx_volume", 0.8)) * float(settings.get(group, 1.0))

func effect(kind: String) -> void:
	if not settings.get("sound", true) or sounds.is_empty() or effect_gain(kind) <= 0 or (not focused and settings.get("mute_unfocused", true)):
		return
	var voice := sounds[sound_index % sounds.size()]
	sound_index += 1
	voice.stream = effect_streams.get(kind, effect_streams.ui)
	voice.volume_db = linear_to_db(maxf(effect_gain(kind), 0.00001)) - 8.0
	voice.play()

func make_effect(kind: String) -> AudioStreamWAV:
	var frequency := FREQUENCIES.get(kind, 440.0) as float
	var duration := 0.07 if kind != "boss" else 0.4
	var samples := PackedByteArray()
	var count := int(22050 * duration)
	samples.resize(count * 2)
	for i in count:
		var t := float(i) / 22050.0
		var envelope := pow(1.0 - float(i) / count, 2.0)
		var sample := int(sin(TAU * frequency * t * (1.0 - 0.4 * t / duration)) * envelope * 9000)
		samples.encode_s16(i * 2, sample)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.data = samples
	return stream
