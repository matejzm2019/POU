extends Node

const SCENES := [
	"res://main.tscn",
	"res://ui/main_menu.tscn",
	"res://ui/loading_screen.tscn",
	"res://ui/hud.tscn",
	"res://characters/player.tscn",
	"res://levels/props/classroom_door.tscn",
	"res://levels/test_school.tscn",
]


func _ready() -> void:
	_validate.call_deferred()


func _validate() -> void:
	for path in SCENES:
		var resource := load(path) as PackedScene
		if resource == null:
			push_error("Could not load %s" % path)
			get_tree().quit(1)
			return
		var instance := resource.instantiate()
		get_tree().root.add_child(instance)
		await get_tree().process_frame
		instance.queue_free()
		await get_tree().process_frame
	print("PHASE_1_SCENE_REGRESSION_OK: %d scenes loaded and instantiated." % SCENES.size())
	if "--phase2-test" in OS.get_cmdline_user_args():
		for suffix in ["", SaveManager.TEMP_SUFFIX, SaveManager.BACKUP_SUFFIX]:
			var path: String = SaveManager.save_path + str(suffix)
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	get_tree().quit()
