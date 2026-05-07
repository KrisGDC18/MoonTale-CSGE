extends Node

func _ready():
	get_tree().root.connect("size_changed", _on_window_resized)
	_on_window_resized()

func _on_window_resized():
	var window_size : Vector2 = Vector2(DisplayServer.window_get_size())
	get_tree().root.content_scale_size = Vector2i(window_size)
