class_name JumpscareOverlay
extends CanvasLayer

@onready var _root: Control = $Root
@onready var _visual: Control = %Visual
@onready var _image: TextureRect = %JumpscareImage
@onready var _placeholder: Control = %PlaceholderFace
@onready var _flash: ColorRect = %Flash
@onready var _audio: AudioStreamPlayer = $Audio

var _placeholder_sound: AudioStreamWAV


func _ready() -> void:
	SchoolGameManager.player_caught.connect(_on_player_caught)
	_root.hide()


func _exit_tree() -> void:
	_audio.stop()
	_audio.stream = null


func _on_player_caught(teacher_name: String, jumpscare_image: Texture2D, jumpscare_sound: AudioStream) -> void:
	%TeacherName.text = teacher_name.to_upper()
	_image.texture = jumpscare_image
	_image.visible = jumpscare_image != null
	_placeholder.visible = jumpscare_image == null
	_root.show()
	_animate.call_deferred()
	if DisplayServer.get_name() == "headless":
		return
	if jumpscare_sound != null:
		_audio.stream = jumpscare_sound
	else:
		if _placeholder_sound == null:
			_placeholder_sound = _create_placeholder_scream()
		_audio.stream = _placeholder_sound
	_audio.play()


func _animate() -> void:
	_visual.pivot_offset = _visual.size * 0.5
	_visual.scale = Vector2(0.55, 0.55)
	_visual.rotation = deg_to_rad(-4.0)
	_flash.modulate = Color(1, 1, 1, 0.9)
	var tween := create_tween()
	tween.tween_property(_visual, "scale", Vector2(1.18, 1.18), 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_visual, "rotation", deg_to_rad(4.0), 0.09)
	tween.parallel().tween_property(_flash, "modulate:a", 0.0, 0.16)
	tween.tween_property(_visual, "rotation", deg_to_rad(-2.5), 0.06)
	tween.tween_property(_visual, "rotation", deg_to_rad(2.0), 0.06)
	tween.tween_property(_visual, "rotation", 0.0, 0.08)


func _create_placeholder_scream() -> AudioStreamWAV:
	const MIX_RATE := 22050
	const DURATION := 1.25
	var sample_count := int(MIX_RATE * DURATION)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	for index in sample_count:
		var time := float(index) / MIX_RATE
		var sweep := 420.0 + 760.0 * (1.0 - time / DURATION)
		var sample := sin(TAU * sweep * time) * 0.55 + sin(TAU * 93.0 * time) * 0.25 + sin(TAU * 1733.0 * time) * 0.2
		var envelope := minf(1.0, time * 35.0) * minf(1.0, (DURATION - time) * 5.0)
		bytes.encode_s16(index * 2, int(clampf(sample, -1.0, 1.0) * 14500.0 * envelope))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = bytes
	return stream
