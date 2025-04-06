extends CharacterBody2D
class_name Boss

const SPEED = 100.0
const JUMP_VELOCITY = -400.0
const DODGE_SPEED = 200.0
const DODGE_DURATION = 0.5  # Should match your roll animation length
const DODGE_COOLDOWN = 0  # Prevent spamming
const MAX_HEALTH = 100
const ATTACK_DAMAGE = 20
const KNOCKBACK_FORCE = 300.0
const GRAVITY = 980  # Define gravity as a constant instead

@onready var health_bar: ProgressBar = $HealthBar
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitarea: Area2D = $hitarea
@onready var camera: Camera2D = $"../Camera2D"

var is_attacking := false
var is_dodging := false
var can_dodge := true
var dodge_direction := 1.0  # Default to right if no input
var current_health := MAX_HEALTH
var is_invulnerable := false
var hit_boss_this_frame := false
var can_flip := true

func _ready():
	health_bar.max_value = MAX_HEALTH
	health_bar.value = current_health
	hitarea.monitoring = false
	add_to_group("boss")

func _physics_process(delta: float) -> void:
	# Death handling
	if current_health <= 0:
		die()
		return
	
	# Handle collision layers based on dodge state
	if is_dodging:
		$".".collision_layer = 2
		$".".collision_mask = 4
	else:
		$".".collision_layer = 1
		$".".collision_mask = 1
		
	# Get movement input
	var direction := Input.get_axis("move_left", "move_right")
	
	# Update facing direction
	if direction != 0 and can_flip:
		animated_sprite.flip_h = direction < 0
		if direction < 0:
			hitarea.scale = Vector2(-1, 1)
		else:  # Changed from if direction > 0 to else for reliability
			hitarea.scale = Vector2(1, 1)
		dodge_direction = direction  # Store last direction for dodge

	# Apply gravity if not dodging
	if not is_on_floor() and not is_dodging:
		velocity.y += GRAVITY * delta  # Use our constant instead of calling get_gravity()

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
		start_attack()

	# Dodge/Roll logic
	if Input.is_action_just_pressed("dodge") and not is_dodging and not is_attacking and can_dodge:
		start_dodge()

	# Apply movement
	move_and_slide()
	
	# Reset frame-specific flags at the end of the frame
	hit_boss_this_frame = false

func start_dodge():
	is_dodging = true
	can_dodge = false
	can_flip = false
	velocity.x = dodge_direction * DODGE_SPEED
	velocity.y = 0  # Optional: disable gravity during dodge
	animated_sprite.play("roll")
	
	# Make boss invulnerable during dodge
	is_invulnerable = true
	
	# Wait for dodge to complete
	await get_tree().create_timer(DODGE_DURATION).timeout
	is_dodging = false
	is_invulnerable = false
	can_flip = true
	
	# Start cooldown
	await get_tree().create_timer(DODGE_COOLDOWN).timeout
	can_dodge = true

func start_attack():
	is_attacking = true
	can_flip = false
	velocity.x = 0
	animated_sprite.play("attack")
	
	# Wait a brief moment before activating hitbox
	await get_tree().create_timer(0.5).timeout
	
	# Only activate if we're still attacking (animation wasn't interrupted)
	if is_attacking:
		hitarea.monitoring = true
	
	# Wait for animation to finish
	await animated_sprite.animation_finished
	
	# Deactivate hitbox when attack completes
	hitarea.monitoring = false
	is_attacking = false
	can_flip = true

func take_damage(damage: int, attacker_position: Vector2):
	if is_invulnerable or is_dodging:
		return
		
	current_health -= damage
	health_bar.value = current_health
	
	# Apply knockback
	var knockback_direction = sign(position.x - attacker_position.x)
	velocity.x = knockback_direction * KNOCKBACK_FORCE * 0.1
	
	# Flash effect when hit
	modulate = Color.RED
	
	# Pause before playing hit animation
	set_physics_process(false)
	animated_sprite.play("hit")
	
	await get_tree().create_timer(0.1).timeout
	modulate = Color.WHITE
	
	await animated_sprite.animation_finished
	set_physics_process(true)

func _on_hitarea_body_entered(body):
	if body.has_method("take_damage") and body != self:
		body.take_damage(ATTACK_DAMAGE, position)
		# No need to set hit_boss_this_frame here as this is the boss's attack
		camera.start_shake(5)
		
func die():
	set_physics_process(false)
	animated_sprite.play("death")
	await animated_sprite.animation_finished
	set_physics_process(true)
	position = Vector2(85, 83)
	current_health = MAX_HEALTH
	health_bar.value = current_health
