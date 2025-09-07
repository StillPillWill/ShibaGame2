extends Node2D

var player
var numCol = 3
var layer_index = 0
var layers = [2, 4, 8]  # first 3 collision layers
var layerColor = [
	Color8(255, 255, 255), # white
	Color8(0, 255, 0),     # green
	Color8(0, 255, 255)    # cyan
]

@onready var border = get_parent().get_node("CanvasLayer/TextureRect")
var fade_speed = 3.0
var target_alpha = 0.0

func _ready() -> void:
	player = get_parent().get_node("Player")
	var body = player.get_node("CollisionShape2D").get_parent()

	# Start at white (index 0)
	layer_index = 0
	body.collision_mask = layers[layer_index]
	body.collision_layer = layers[layer_index]

	# Set starting color to white and visible
	border.modulate = layerColor[layer_index]
	border.modulate.a = 1.0
	target_alpha = 1.0


func _process(delta: float) -> void:
	# Press F to switch collision layer and set new fade color
	if Input.is_action_just_pressed("F"):
		var body = player.get_node("CollisionShape2D").get_parent()
		layer_index = (layer_index + 1) % numCol
		body.collision_mask = layers[layer_index]
		body.collision_layer = layers[layer_index]

		# Set new color and reset alpha
		border.modulate = layerColor[layer_index]
		border.modulate.a = 1.0
		target_alpha = 1.0

	# Smooth fade out toward alpha 0
	if border.modulate.a > 0.0:
		border.modulate.a = lerp(border.modulate.a, 0.0, fade_speed * delta)
		if border.modulate.a < 0.01:
			border.modulate.a = 0.0
