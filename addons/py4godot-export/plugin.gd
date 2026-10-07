@tool
extends EditorPlugin

var export_plugin

func _enter_tree() -> void:
	export_plugin = preload("res://addons/py4godot-export/export_plugin.gd").new()
	add_export_plugin(export_plugin)

func _exit_tree() -> void:
	remove_export_plugin(export_plugin)
	export_plugin = null
