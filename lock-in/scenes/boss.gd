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

@onready var health_bar: ProgressBar = $HealthBar
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitarea: Area2D = $hitarea

var is_attacking := false
var is_dodging := false
var can_dodge := true
var dodge_direction := 1.0  # Default to right if no input
var current_health := MAX_HEALTH
var is_invulnerable := false
var hit_boss_this_frame := false

func _ready():
	health_bar.max_value = MAX_HEALTH
	health_bar.value = current_health
	hitarea.monitoring = false

func _physics_process(delta: float) -> void:
	if current_health <= 0:
		set_physics_process(false)
		animated_sprite.play("death")
		await animated_sprite.animation_finished
		die()
	# Get movement input
	if is_dodging:
		$".".collision_layer = 2
		$".".collision_mask = 4
	else:
		$".".collision_layer = 1
		$".".collision_mask = 1
	var direction := Input.get_axis("move_left", "move_right")
	
	# Update facing direction
	if direction != 0:
		animated_sprite.flip_h = direction < 0
		if direction < 0:
			hitarea.scale = Vector2(-1,1)
		if direction > 0:
			hitarea.scale = Vector2(1,1)
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
		start_attack()
		

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
func start_attack():
	is_attacking = true
	velocity.x = 0
	animated_sprite.play("attack")
	# Wait a brief moment before activating hitbox
	await get_tree().create_timer(0.5).timeout
	# Only activate if we're still attacking (animation wasn't interrupted)
	if is_attacking:
		hitarea.monitoring = true
		print("Hitbox activated: ", hitarea.monitoring)
	# Wait for animation to finish
	await animated_sprite.animation_finished
	# Deactivate hitbox when attack completes
	hitarea.monitoring = false
	is_attacking = false
	print("Hitbox deactivated: ", hitarea.monitoring)

func take_damage(damage: int, attacker_position: Vector2):
	if is_invulnerable or is_dodging:
		return
	
	current_health -= damage
	health_bar.value = current_health
	
	# Apply knockback
	var knockback_direction = sign(position.x - attacker_position.x)
	velocity.x = knockback_direction * KNOCKBACK_FORCE
	velocity.y = -KNOCKBACK_FORCE * 0.5
	
	# Flash effect when hit
	modulate = Color.RED
	await get_tree().create_timer(0.1).timeout
	modulate = Color.WHITE


func _on_hitarea_body_entered(body):
	if body.has_method("take_damage") and body != self:
		body.take_damage(ATTACK_DAMAGE, position)
		hit_boss_this_frame = true
		
func die():
	queue_free()
