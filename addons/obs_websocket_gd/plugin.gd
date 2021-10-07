tool
extends EditorPlugin

var obs_ui

func _enter_tree():
	obs_ui = load("res://addons/obs_websocket_gd/obs_ui.tscn").instance()
	
	add_control_to_bottom_panel(obs_ui, "OBS")

func _exit_tree():
	remove_control_from_bottom_panel(obs_ui)
	
	obs_ui.free()
