extends CharacterBody3D


func _ready():
	# Initialize mouse capture
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	print("[Player] Initialized")


func _physics_process(_delta):
	move_and_slide()

