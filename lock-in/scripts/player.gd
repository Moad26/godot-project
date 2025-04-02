extends CharacterBody2D


const SPEED = 300.0
const JUMP_VELOCITY = -400.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var is_attacking := false

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
		
	if not is_attacking:
		var direction := Input.get_axis("move_left", "move_right")
		if direction < 0:
			animated_sprite.flip_h = 1
		elif direction > 0:
			animated_sprite.flip_h = 0
		if direction == 0:
			animated_sprite.play("Idle")
		elif direction != 0:
			animated_sprite.play("Run")
		if direction:
			velocity.x = direction * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
	
	
	if Input.is_action_just_pressed("attack") and not is_attacking:
		is_attacking = true
		velocity.x = 0
		animated_sprite.play("Attack")
		await  animated_sprite.animation_finished
		is_attacking=false

	move_and_slide()
