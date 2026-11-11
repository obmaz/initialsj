@tool
extends EditorPlugin
const VersionExport = preload("res://addons/app_version/version_export.gd")
var version_export: EditorExportPlugin


func _enter_tree() -> void:
	version_export = VersionExport.new()
	add_export_plugin(version_export)


func _exit_tree() -> void:
	remove_export_plugin(version_export)
