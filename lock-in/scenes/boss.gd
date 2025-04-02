extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0
const DODGE_SPEED = 500.0
const DODGE_DURATION = 0.5  # Should match your roll animation length
const DODGE_COOLDOWN = 1.0  # Prevent spamming

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var is_attacking := false
var is_dodging := false
var can_dodge := true
var dodge_direction := 1.0  # Default to right if no input

func _physics_process(delta: float) -> void:
	# Get movement input
	var direction := Input.get_axis("move_left", "move_right")
	
	# Update facing direction
	if direction != 0:
		animated_sprite.flip_h = direction < 0
		dodge_direction = direction  # Store last direction for dodge

	# Apply gravity if not dodging
	if not is_on_floor() and not is_dodging:
		velocity += get_gravity() * delta

	# Normal movement (when not attacking or dodging)
	if not (is_attacking or is_dodging):
		if direction == 0:
			animated_sprite.play("idle")
			velocity.x = move_toward(velocity.x, 0, SPEED)
		else:
			animated_sprite.play("run")
			velocity.x = direction * SPEED

	# Attack logic
	if Input.is_action_just_pressed("attack") and not is_attacking and not is_dodging:
		is_attacking = true
		velocity.x = 0
		animated_sprite.play("attack")
		await animated_sprite.animation_finished
		is_attacking = false

	# Dodge/Roll logic
	if Input.is_action_just_pressed("dodge") and not is_dodging and not is_attacking and can_dodge:
		is_dodging = true
		can_dodge = false
		velocity.x = dodge_direction * DODGE_SPEED
		velocity.y = 0  # Optional: disable gravity during dodge
		animated_sprite.play("roll")
		
		# Wait for dodge to complete
		await get_tree().create_timer(DODGE_DURATION).timeout
		is_dodging = false
		
		# Start cooldown
		await get_tree().create_timer(DODGE_COOLDOWN).timeout
		can_dodge = true

	move_and_slide()
