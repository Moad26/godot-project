extends Camera2D

var shake_amount = 0.0
var shake_decay = 0.9  # How fast it fades
var rng = RandomNumberGenerator.new()

func _ready():
	rng.randomize()

func _process(delta):
	if shake_amount > 0:
		offset = Vector2(
			rng.randf_range(-1, 1),
			rng.randf_range(-1, 1)
		) * shake_amount
		shake_amount *= shake_decay
	else:
		offset = Vector2.ZERO

func start_shake(intensity = 5.0):
	shake_amount = intensity
