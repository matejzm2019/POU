class_name JumpscareOverlay
extends CanvasLayer

@onready var _root: Control = $Root
@onready var _flash: ColorRect = %Flash
@onready var _image: TextureRect = %JumpscareImage
@onready var _audio: AudioStreamPlayer = $Audio

var _placeholder_sound: AudioStreamWAV
var _target_teacher: Node3D
var _camera_target_position := Vector3.ZERO
var _sequence_active := false
var _camera: Camera3D


func _ready() -> void:
	SchoolGameManager.player_caught.connect(_on_player_caught)
	_camera = get_parent().get_node_or_null("Head/Camera3D") as Camera3D
	_root.hide()


func _exit_tree() -> void:
	_audio.stop()
	_audio.stream = null


func is_3d_sequence_active() -> bool:
	return _sequence_active


func get_target_teacher() -> Node3D:
	return _target_teacher


func get_camera_target_position() -> Vector3:
	return _camera_target_position


func _on_player_caught(teacher: Node3D, _teacher_name: String, jumpscare_image: Texture2D, jumpscare_sound: AudioStream) -> void:
	_target_teacher = teacher
	_sequence_active = true
	_image.texture = jumpscare_image
	_image.hide()
	var hud := get_parent().get_node_or_null("HUD") as CanvasLayer
	if hud != null:
		hud.hide()
	for other_teacher in get_tree().get_nodes_in_group("teacher_enemies"):
		if other_teacher is Node3D and other_teacher != teacher:
			(other_teacher as Node3D).hide()
	_root.show()
	_flash.modulate.a = 0.9
	if is_instance_valid(teacher) and _camera != null:
		teacher.call("prepare_jumpscare", _camera.global_position)
	_play_3d_sequence.call_deferred()
	if DisplayServer.get_name() == "headless":
		return
	_audio.stream = jumpscare_sound if jumpscare_sound != null else _get_placeholder_scream()
	_audio.play()


func _play_3d_sequence() -> void:
	if _camera == null or not is_instance_valid(_target_teacher):
		_flash.modulate.a = 0.0
		return
	var focus := _target_teacher.call("get_jumpscare_focus_position") as Vector3
	var view_direction := _camera.global_position - focus
	if view_direction.length_squared() < 0.001:
		view_direction = Vector3.BACK
	_camera_target_position = focus + view_direction.normalized() * 1.15
	var start_transform := _camera.global_transform
	var target_transform := Transform3D(_camera.global_transform.basis, _camera_target_position).looking_at(focus, Vector3.UP)
	var flashlight := _camera.get_node_or_null("Flashlight") as SpotLight3D
	if flashlight != null:
		flashlight.visible = true
		flashlight.light_color = Color("ff624a")
		flashlight.light_energy = 2.2
		flashlight.spot_range = 6.0

	var snap := create_tween().set_parallel(true)
	snap.tween_method(
		func(weight: float) -> void: _camera.global_transform = start_transform.interpolate_with(target_transform, weight),
		0.0,
		1.0,
		0.11
	).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	snap.tween_property(_camera, "fov", 58.0, 0.11).set_trans(Tween.TRANS_EXPO)
	snap.tween_property(_flash, "modulate:a", 0.0, 0.14)
	await snap.finished

	if not is_instance_valid(_target_teacher):
		return
	var lunge_direction := _camera.global_position - _target_teacher.global_position
	lunge_direction.y = 0.0
	var lunge_target := _target_teacher.global_position
	if not lunge_direction.is_zero_approx():
		lunge_target += lunge_direction.normalized() * 0.34
	var lunge := create_tween().set_parallel(true)
	lunge.tween_property(_target_teacher, "global_position", lunge_target, 0.075).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	lunge.tween_property(_camera, "fov", 52.0, 0.06).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	lunge.tween_property(_flash, "modulate:a", 0.72, 0.035)
	await lunge.finished

	if _image.texture != null:
		_image.show()
		await get_tree().create_timer(0.055).timeout
		_image.hide()
	_flash.modulate.a = 0.12
	var shake := create_tween()
	for offset in [Vector2(0.035, -0.025), Vector2(-0.04, 0.03), Vector2(0.025, 0.018), Vector2(-0.018, -0.012), Vector2.ZERO]:
		shake.tween_property(_camera, "h_offset", offset.x, 0.035)
		shake.parallel().tween_property(_camera, "v_offset", offset.y, 0.035)
	shake.parallel().tween_property(_flash, "modulate:a", 0.0, 0.18)


func _get_placeholder_scream() -> AudioStreamWAV:
	if _placeholder_sound != null:
		return _placeholder_sound
	const MIX_RATE := 22050
	const DURATION := 1.35
	var sample_count := int(MIX_RATE * DURATION)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	for index in sample_count:
		var time := float(index) / MIX_RATE
		var fall := 1080.0 - 720.0 * time / DURATION
		var sample := sin(TAU * fall * time) * 0.48 + sin(TAU * 86.0 * time) * 0.3 + sin(TAU * 1610.0 * time) * 0.22
		var envelope := minf(1.0, time * 45.0) * minf(1.0, (DURATION - time) * 4.5)
		bytes.encode_s16(index * 2, int(clampf(sample, -1.0, 1.0) * 15500.0 * envelope))
	_placeholder_sound = AudioStreamWAV.new()
	_placeholder_sound.format = AudioStreamWAV.FORMAT_16_BITS
	_placeholder_sound.mix_rate = MIX_RATE
	_placeholder_sound.stereo = false
	_placeholder_sound.data = bytes
	return _placeholder_sound
