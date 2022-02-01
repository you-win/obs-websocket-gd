tool
extends EditorPlugin

const PLUGIN_NAME := "OBS Websocket GD"

var obs_websocket: Node
var obs_ui: Control

func _enter_tree():
	obs_websocket = load("res://addons/obs_websocket_gd/obs_websocket.tscn").instance()
	inject_tool(obs_websocket)
	
	obs_ui = load("res://addons/obs_websocket_gd/obs_ui.tscn").instance()
	inject_tool(obs_ui)
	
	add_child(obs_websocket)
	add_control_to_bottom_panel(obs_ui, "OBS")

func _exit_tree():
	if obs_websocket:
		obs_websocket.queue_free()
	if obs_ui:
		remove_control_from_bottom_panel(obs_ui)
		obs_ui.queue_free()

func get_plugin_name():
	return PLUGIN_NAME

func get_plugin_icon():
	return get_editor_interface().get_base_control().get_icon("CanvasLayer", "EditorIcons")

func inject_tool(node: Node) -> void:
	"""
	Inject `tool` at the top of the plugin script
	"""
	var script: Script = node.get_script().duplicate()
	script.source_code = "tool\n%s" % script.source_code
	script.reload(false)
	node.set_script(script)
