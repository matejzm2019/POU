class_name GameAudioData
extends Resource

@export var menu_music: AudioStream
@export var school_ambient: AudioStream
@export var default_teacher_footstep: AudioStream
@export_range(-40.0, 6.0, 0.5) var menu_volume_db := -15.0
@export_range(-40.0, 6.0, 0.5) var ambient_volume_db := -19.0
@export_range(-40.0, 6.0, 0.5) var footstep_volume_db := -7.0
