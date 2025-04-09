extends CharacterBody2D
class_name AIPlayer

@onready var boss: Boss = $"../Boss"

const SPEED = 100.0 #300
const JUMP_VELOCITY = -400.0
const DODGE_SPEED = 150.0 #500
const DODGE_DURATION = 0.5  # Should match your roll animation length
const KNOCKBACK_FORCE = 300.0
const HIT_COOLDOWN = 0.2
const MAX_HEALTH = 100
const ATTACK_DAMAGE = 10
const DODGE_INVULNERABILITY_DURATION = 0.5
const GRAVITY = 980  # Define gravity as a constant instead

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_hitbox: Area2D = $hitarea
@onready var health_bar: ProgressBar = $HealthBar
@onready var ai_controller: Node2D = $AIController2D
@onready var camera: Camera2D = $"../Camera2D"
@onready var healthbar: ProgressBar = $CanvasLayer/Healthbar

var is_attacking := false
var is_dodging := false
var can_dodge := true
var dodge_direction := 1.0  # Default to right if no input
var current_health := MAX_HEALTH
var is_invulnerable := false
var took_damage_this_frame := false
var successful_dodge_this_frame := false
var can_flip := true
var is_close_to_boss := false

var last_attack_time := 0.0
var last_dodge_time := 0.0
const ATTACK_COOLDOWN = 0.8  # Minimum time between attacks
const DODGE_COOLDOWN = 1.2   # Minimum time between dodges

func _ready():
	animated_sprite.animation_finished.connect(_on_animation_finished)
	animated_sprite.frame_changed.connect(_on_frame_changed)
	health_bar.max_value = MAX_HEALTH
	health_bar.value = current_health
	healthbar.init_health(current_health)
	attack_hitbox.monitoring = false
	ai_controller.init(self)

func _physics_process(delta: float) -> void:
	last_attack_time += delta
	last_dodge_time += delta
	# Handle collision layers based on dodge state
	if is_dodging:
		$".".collision_layer = 2
		$".".collision_mask = 5
	else:
		$".".collision_layer = 1
		$".".collision_mask = 1
		
	# Death handling
	if current_health <= 0:
		die()
		return
		
	# Get movement input
	var direction: float = ai_controller.move
	
	# Update facing direction
	if direction != 0 and can_flip:
		animated_sprite.flip_h = direction < 0
		dodge_direction = direction  # Store last direction for dodge
		if direction < 0:
			$hitarea.scale = Vector2(-1, 1)
		else:  # Changed from if direction > 0 to else for reliability
			$hitarea.scale = Vector2(1, 1)

	# Apply gravity if not dodging
	if not is_on_floor() and not is_dodging:
		velocity.y += GRAVITY * delta  # Use our constant instead of calling get_gravity()

	# Normal movement (when not attacking or dodging)
	if not (is_attacking or is_dodging):
		if direction == 0:
			animated_sprite.play("Idle")
			velocity.x = move_toward(velocity.x, 0, SPEED)
		else:
			start_run(direction)

	# Attack logic
	if ai_controller.attack and not is_attacking and not is_dodging:
		start_attack()

	# Dodge/Roll logic
	if ai_controller.dodge and not is_dodging and not is_attacking and can_dodge:
		start_dodge()
		
	# Check for successful dodge
	if (position.distance_to(boss.position) < 30) and is_dodging:
		successful_dodge_this_frame = true

	# Apply movement
	move_and_slide()
	
	# Reset frame-specific flags at the end
	took_damage_this_frame = false
	successful_dodge_this_frame = false

func start_run(direction):
	animated_sprite.play("Run") 
	velocity.x = direction * SPEED
	
func start_dodge():
	is_dodging = true
	can_dodge = false
	can_flip = false
	velocity.x = dodge_direction * DODGE_SPEED
	velocity.y = 0  # Optional: disable gravity during dodge
	animated_sprite.play("roll") 
	
	# Make player invulnerable during dodge
	is_invulnerable = true
	
	# Wait for dodge to complete
	await get_tree().create_timer(DODGE_DURATION).timeout
	is_dodging = false
	
	# Keep invulnerable for the designated duration
	await get_tree().create_timer(DODGE_INVULNERABILITY_DURATION - DODGE_DURATION).timeout
	is_invulnerable = false
	
	# Start cooldown
	await get_tree().create_timer(DODGE_COOLDOWN).timeout
	can_dodge = true
	can_flip = true

func start_attack():
	is_attacking = true
	can_flip = false
	velocity.x = 0
	animated_sprite.play("Attack2")
	
	# Wait a brief moment before activating hitbox
	await get_tree().create_timer(0.2).timeout
	
	# Only activate if we're still attacking (animation wasn't interrupted)
	if is_attacking:
		attack_hitbox.monitoring = true
		
	# Wait for animation to finish
	await animated_sprite.animation_finished
	
	# Deactivate hitbox when attack completes
	attack_hitbox.monitoring = false
	is_attacking = false
	can_flip = true
	
func take_damage(damage: int, attacker_position: Vector2):
	if is_invulnerable or is_dodging:
		return
	
	took_damage_this_frame = true  # Moved to here to ensure it's set properly
	current_health -= damage
	health_bar.value = current_health
	healthbar.health = current_health
	
	# Apply knockback
	var knockback_direction = sign(position.x - attacker_position.x)
	velocity.x = knockback_direction * KNOCKBACK_FORCE * 0.1
	
	# Flash effect when hit
	modulate = Color.RED
	animated_sprite.play("hit")
	await get_tree().create_timer(0.1).timeout
	modulate = Color.WHITE
	await animated_sprite.animation_finished  # Wait for hit animation to complete

func die():
	set_physics_process(false)
	attack_hitbox.monitoring = false
	is_attacking = false
	is_dodging = false
	
	# Play death animation and wait
	animated_sprite.play("death")
	await animated_sprite.animation_finished
	
	# Reset player stats
	position = Vector2(-113, 82)  # Player respawn position
	current_health = MAX_HEALTH
	health_bar.value = current_health
	healthbar.health = current_health

	set_physics_process(true)

func _on_hitarea_body_entered(body):
	if body.has_method("take_damage") and body != self:
		body.take_damage(ATTACK_DAMAGE, position)
		# Move this after successful damage application
		if body.is_in_group("boss"):
			body.hit_boss_this_frame = true
		camera.start_shake(5)

func _on_looker_body_entered(body):
	if body.has_method("take_damage") and body != self:
		is_close_to_boss = true

func _on_looker_body_exited(body):
	if body.has_method("take_damage") and body != self:
		is_close_to_boss = false

func _on_frame_changed():
	if animated_sprite.animation == "attack" and animated_sprite.frame == 2: # Adjust frame
		attack_hitbox.monitoring = true  # Activate hitbox on specific frame

func _on_animation_finished():
	attack_hitbox.monitoring = false 
