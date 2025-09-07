extends CharacterBody2D

@export var speed: float = 500.0
@export var jump_velocity: float = -1000.0
@export var gravity: float = 4000.0
@export var friction: float = 0.1
@export var acceleration: float = 0.25

func _physics_process(delta: float) -> void:
	# Apply gravity
	if not is_on_floor():
		velocity.y += gravity * delta

	# Horizontal movement
	var dir = Input.get_axis("ui_left", "ui_right")
	if dir != 0:
		velocity.x = lerp(velocity.x, dir * speed, acceleration)
	else:
		velocity.x = lerp(velocity.x, 0.0, friction)

	move_and_slide()

	# Jumping
	if Input.is_action_just_pressed("ui_up") and is_on_floor():
		velocity.y = jump_velocity
