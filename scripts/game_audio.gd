extends Node

const TRACKS := {"sternenlauf": "Sternenlauf Protokoll", "broken": "Broken Docking Bay", "lightspeed": "Lightspeed Galaxy"}
var music: AudioStreamPlayer
var sounds: Array[AudioStreamPlayer] = []
var settings: Dictionary
var current_song := ""
var sound_index := 0

func _exit_tree() -> void:
	# Explicitly release looping decoders, including with the headless audio driver.
	if is_instance_valid(music):
		music.stop()
		music.stream = null
	for voice in sounds:
		if is_instance_valid(voice):
			voice.stop()
			voice.stream = null

func _ready() -> void:
	music = AudioStreamPlayer.new()
	add_child(music)
	for i in 8:
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		sounds.append(voice)

func apply_settings(value: Dictionary) -> void:
	settings = value
	var song := str(settings.get("song", "sternenlauf"))
	if not TRACKS.has(song):
		song = "sternenlauf"
	if song != current_song:
		current_song = song
		var stream := load("res://assets/audio/%s.mp3" % song) as AudioStreamMP3
		stream.loop = true
		music.stream = stream
		music.play()
	music.volume_db = linear_to_db(clampf(float(settings.get("volume", 0.7)), 0.001, 1.0)) - 10.0
	music.stream_paused = not bool(settings.get("music", true))

func effect(kind: String) -> void:
	if not settings.get("sound", true) or sounds.is_empty():
		return
	var frequency := {"shot": 640.0, "hit": 320.0, "kill": 880.0, "hurt": 110.0, "collect": 1100.0, "boss": 75.0}.get(kind, 440.0) as float
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
	var voice := sounds[sound_index % sounds.size()]
	sound_index += 1
	voice.stream = stream
	voice.volume_db = linear_to_db(clampf(float(settings.get("sfx_volume", 0.8)), 0.001, 1.0)) - 8.0
	voice.play()
