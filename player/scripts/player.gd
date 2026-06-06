extends CharacterBody3D

var spawn_point: Vector3

func _ready():
	# Initialize mouse capture
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	print("[Player] Initialized")
	spawn_point = self.global_position

func _physics_process(_delta):
	move_and_slide()
	check_fall()
	
	
func check_fall() -> void:
	if self.global_position.y  < -15:
		global_position = spawn_point
		global_position.y += 5
		velocity = Vector3.ZERO
