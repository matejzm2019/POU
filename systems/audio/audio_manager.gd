extends Node

const AUDIO_DATA_PATH := "res://data/audio/game_audio.tres"

var _data: Resource
var _menu := AudioStreamPlayer.new()
var _ambient := AudioStreamPlayer.new()


func _ready() -> void:
	_data = load(AUDIO_DATA_PATH)
	_menu.name = "MenuMusic"
	_ambient.name = "SchoolAmbient"
	add_child(_menu)
	add_child(_ambient)
	_menu.finished.connect(_replay.bind(_menu))
	_ambient.finished.connect(_replay.bind(_ambient))


func play_menu() -> void:
	_ambient.stop()
	_play_loop(_menu, _data.menu_music if _data != null else null, _data.menu_volume_db if _data != null else -15.0, true)


func play_ambient() -> void:
	_menu.stop()
	_play_loop(_ambient, _data.school_ambient if _data != null else null, _data.ambient_volume_db if _data != null else -19.0, false)


func stop_all() -> void:
	_menu.stop()
	_ambient.stop()


func get_teacher_footstep() -> AudioStream:
	if _data != null and _data.default_teacher_footstep != null:
		return _data.default_teacher_footstep
	return _create_footstep()


func get_footstep_volume_db() -> float:
	return _data.footstep_volume_db if _data != null else -7.0


func _play_loop(player: AudioStreamPlayer, custom_stream: AudioStream, volume_db: float, menu: bool) -> void:
	var next_stream := custom_stream if custom_stream != null else _create_placeholder_loop(menu)
	if player.stream != next_stream:
		player.stream = next_stream
	player.volume_db = volume_db
	if not player.playing and DisplayServer.get_name() != "headless":
		player.play()


func _replay(player: AudioStreamPlayer) -> void:
	if player.stream != null and DisplayServer.get_name() != "headless":
		player.play()


func _create_placeholder_loop(menu: bool) -> AudioStreamWAV:
	const MIX_RATE := 22050
	const DURATION := 6.0
	var sample_count := int(MIX_RATE * DURATION)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	for index in sample_count:
		var time := float(index) / MIX_RATE
		var value := sin(TAU * (55.0 if menu else 42.0) * time) * 0.2
		value += sin(TAU * (82.5 if menu else 63.0) * time) * 0.1
		if menu:
			value += sin(TAU * 220.0 * time) * maxf(0.0, sin(TAU * time / 3.0)) * 0.04
		else:
			value += sin(TAU * 0.17 * time) * sin(TAU * 118.0 * time) * 0.035
		bytes.encode_s16(index * 2, int(value * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = sample_count
	stream.data = bytes
	return stream


func _create_footstep() -> AudioStreamWAV:
	const MIX_RATE := 22050
	const DURATION := 0.16
	var sample_count := int(MIX_RATE * DURATION)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	for index in sample_count:
		var time := float(index) / MIX_RATE
		var envelope := pow(1.0 - time / DURATION, 3.0)
		var value := (sin(TAU * 92.0 * time) + sin(TAU * 137.0 * time) * 0.35) * envelope
		bytes.encode_s16(index * 2, int(value * 9000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = bytes
	return stream
