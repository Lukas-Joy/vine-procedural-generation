extends Control

@onready var label: Label = $LabelContainer/TickerLabel
@onready var container: Control = $LabelContainer

var scroll_speed: float = 120.0  # pixels per second
var messages: Array[String] = [
	"[WASD - MOVEMENT]  |  ",
	"[MOUSE - LOOK]  |  ",
	"[R - RESTART]  |  ",
	"[ESC - QUIT]  |  ",
	"[SCROLL - ZOOM]  |  "
]

var _full_text: String = ""
var _x_pos: float = 0.0

func _ready() -> void:
	_full_text = "  ".join(messages)  # join all headlines
	label.text = _full_text + "    " + _full_text  # double it for seamless loop
	label.reset_size()
	# Start offscreen to the right
	_x_pos = container.size.x

func _process(delta: float) -> void:
	_x_pos -= scroll_speed * delta
	
	# Get width of ONE copy of the text
	var single_width: float = label.size.x / 2.0
	
	# When we've scrolled one full copy, reset seamlessly
	if _x_pos <= -single_width:
		_x_pos += single_width
	
	label.position.x = _x_pos
