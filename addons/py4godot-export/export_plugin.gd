@tool
extends EditorExportPlugin

var export_path := ""

func _get_name() -> String:
	return "py4godot_export"

func _export_begin(_p_features: PackedStringArray, _is_debug: bool, path: String, _flags: int) -> void:
	export_path = path

func _export_end() -> void:
	if export_path.is_empty():
		return
	var dest_root := export_path.get_base_dir()
	var src_root := ProjectSettings.globalize_path("res://")
	for nome in ["carro.gd", "ryan.png", "ignacio.png", "icon.svg"]:
		_copy_file(src_root.path_join(nome), dest_root.path_join(nome))

func _copy_file(src: String, dst: String) -> void:
	if not FileAccess.file_exists(src):
		return
	DirAccess.make_dir_recursive_absolute(dst.get_base_dir())
	DirAccess.copy_absolute(src, dst)
