extends Node2D

# state machine
enum {WAIT, MOVE}
var state

# grid
@export var width: int
@export var height: int
@export var x_start: int
@export var y_start: int
@export var offset: int
@export var y_offset: int

# piece array
var possible_pieces = [
	preload("res://scenes/blue_piece.tscn"),
	preload("res://scenes/green_piece.tscn"),
	preload("res://scenes/light_green_piece.tscn"),
	preload("res://scenes/pink_piece.tscn"),
	preload("res://scenes/yellow_piece.tscn"),
	preload("res://scenes/orange_piece.tscn"),
]

# current pieces in scene
var all_pieces = []

# row pieces
var horizontal_pieces = [
	preload("res://scenes/blue_row.tscn"),
	preload("res://scenes/green_row.tscn"),
	preload("res://scenes/light_green_row.tscn"),
	preload("res://scenes/pink_row.tscn"),
	preload("res://scenes/yellow_row.tscn"),
	preload("res://scenes/orange_row.tscn"),
]

# column pieces
var vertical_pieces = [
	preload("res://scenes/blue_column.tscn"),
	preload("res://scenes/green_column.tscn"),
	preload("res://scenes/light_green_column.tscn"),
	preload("res://scenes/pink_column.tscn"),
	preload("res://scenes/yellow_column.tscn"),
	preload("res://scenes/orange_column.tscn")
]

# adjacent pieces
var special_pieces = [
	preload("res://scenes/blue_adjacent.tscn"),
	preload("res://scenes/green_adjacent.tscn"),
	preload("res://scenes/light_green_adjacent.tscn"),
	preload("res://scenes/pink_adjacent.tscn"),
	preload("res://scenes/yellow_adjacent.tscn"),
	preload("res://scenes/orange_adjacent.tscn")
]

# index color
var color_index = {
	"blue": 0,
	"green": 1,
	"light_green": 2,
	"pink": 3,
	"yellow": 4,
	"orange": 5
}

# swap back
var piece_one = null
var piece_two = null
var last_place = Vector2.ZERO
var last_direction = Vector2.ZERO
var move_checked = false

# touch variables
var first_touch = Vector2.ZERO
var final_touch = Vector2.ZERO
var is_controlling = false

# score
var score: int = 0
@onready var score_label: Label = get_node("/root/Game/top_ui/MarginContainer/HBoxContainer/score_label")

# counter variables and signals
var time_left: int = 60
@onready var time_label: Label = get_node("/root/Game/top_ui/MarginContainer/HBoxContainer/counter_label")
var timer: Timer

var min_score: int = 200
@onready var min_score_label: Label = get_node("/root/Game/top_ui/MarginContainer/HBoxContainer/min_score_label")

func add_score(points: int) -> void:
	score += points
	if score_label:
		score_label.text = str(score)
	else:
		print("Error: ScoreLabel no encontrado")

# counter variables and signals
func update_time_label():
	if time_label:
		time_label.text = str(time_left)

func _on_timer_timeout():
	if time_left > 0:
		time_left -= 1
		update_time_label()
	else:
		timer.stop()
		game_over()

# Called when the node enters the scene tree for the first time.
func _ready():
	state = MOVE
	randomize()
	all_pieces = make_2d_array()
	spawn_pieces()
	timer = Timer.new()
	timer.wait_time = 1.0
	timer.one_shot = false
	timer.autostart = true
	add_child(timer)
	timer.connect("timeout", Callable(self, "_on_timer_timeout"))
	update_time_label()
	
	if min_score_label:
		min_score_label.text = "Meta: " + str(min_score)

func make_2d_array():
	var array = []
	for i in width:
		array.append([])
		for j in height:
			array[i].append(null)
	return array
	
func grid_to_pixel(column, row):
	var new_x = x_start + offset * column
	var new_y = y_start - offset * row
	return Vector2(new_x, new_y)
	
func pixel_to_grid(pixel_x, pixel_y):
	var new_x = round((pixel_x - x_start) / offset)
	var new_y = round((pixel_y - y_start) / -offset)
	return Vector2(new_x, new_y)
	
func in_grid(column, row):
	return column >= 0 and column < width and row >= 0 and row < height
	
func spawn_pieces():
	for i in width:
		for j in height:
			# random number
			var rand = randi_range(0, possible_pieces.size() - 1)
			# instance 
			var piece = possible_pieces[rand].instantiate()
			# repeat until no matches
			var max_loops = 100
			var loops = 0
			while (match_at(i, j, piece.color) and loops < max_loops):
				rand = randi_range(0, possible_pieces.size() - 1)
				loops += 1
				piece = possible_pieces[rand].instantiate()
			add_child(piece)
			piece.position = grid_to_pixel(i, j)
			# fill array with pieces
			all_pieces[i][j] = piece

func match_at(i, j, color):
	# check left
	if i > 1:
		if all_pieces[i - 1][j] != null and all_pieces[i - 2][j] != null:
			if all_pieces[i - 1][j].color == color and all_pieces[i - 2][j].color == color:
				return true
	# check down
	if j> 1:
		if all_pieces[i][j - 1] != null and all_pieces[i][j - 2] != null:
			if all_pieces[i][j - 1].color == color and all_pieces[i][j - 2].color == color:
				return true

func touch_input():
	var mouse_pos = get_global_mouse_position()
	var grid_pos = pixel_to_grid(mouse_pos.x, mouse_pos.y)
	if Input.is_action_just_pressed("ui_touch") and in_grid(grid_pos.x, grid_pos.y):
		first_touch = grid_pos
		is_controlling = true
		
	# release button
	if Input.is_action_just_released("ui_touch") and in_grid(grid_pos.x, grid_pos.y) and is_controlling:
		is_controlling = false
		final_touch = grid_pos
		touch_difference(first_touch, final_touch)

func swap_pieces(column, row, direction: Vector2):
	var first_piece = all_pieces[column][row]
	var other_piece = all_pieces[column + direction.x][row + direction.y]
	if first_piece == null or other_piece == null:
		return
	# swap
	state = WAIT
	store_info(first_piece, other_piece, Vector2(column, row), direction)
	all_pieces[column][row] = other_piece
	all_pieces[column + direction.x][row + direction.y] = first_piece
	#first_piece.position = grid_to_pixel(column + direction.x, row + direction.y)
	#other_piece.position = grid_to_pixel(column, row)
	first_piece.move(grid_to_pixel(column + direction.x, row + direction.y))
	other_piece.move(grid_to_pixel(column, row))
	if not move_checked:
		find_matches()

func store_info(first_piece, other_piece, place, direction):
	piece_one = first_piece
	piece_two = other_piece
	last_place = place
	last_direction = direction

func swap_back():
	if piece_one != null and piece_two != null:
		swap_pieces(last_place.x, last_place.y, last_direction)
	state = MOVE
	move_checked = false

func touch_difference(grid_1, grid_2):
	var difference = grid_2 - grid_1
	# should move x or y?
	if abs(difference.x) > abs(difference.y):
		if difference.x > 0:
			swap_pieces(grid_1.x, grid_1.y, Vector2(1, 0))
		elif difference.x < 0:
			swap_pieces(grid_1.x, grid_1.y, Vector2(-1, 0))
	if abs(difference.y) > abs(difference.x):
		if difference.y > 0:
			swap_pieces(grid_1.x, grid_1.y, Vector2(0, 1))
		elif difference.y < 0:
			swap_pieces(grid_1.x, grid_1.y, Vector2(0, -1))

func _process(delta):
	if state == MOVE:
		touch_input()

func find_matches():
	for i in width:
		for j in height:
			if all_pieces[i][j] != null:
				var current_color = all_pieces[i][j].color
				if (
					i > 0 and i < width - 2
					and all_pieces[i - 1][j] != null and all_pieces[i + 1][j] != null and all_pieces[i + 2][j] != null
					and all_pieces[i - 1][j].color == current_color
					and all_pieces[i + 1][j].color == current_color
					and all_pieces[i + 2][j].color == current_color
				):
					print("Match de 4 horizontal")
					var idx = color_index[current_color]
					all_pieces[i - 1][j].queue_free()
					all_pieces[i + 1][j].queue_free()
					all_pieces[i + 2][j].queue_free()
					all_pieces[i][j].queue_free()
					all_pieces[i - 1][j] = null
					all_pieces[i + 1][j] = null
					all_pieces[i + 2][j] = null
					all_pieces[i][j] = null

					var special = horizontal_pieces[idx].instantiate()
					add_child(special)
					special.position = grid_to_pixel(i, j)
					all_pieces[i][j] = special
					collapse_columns()

				if (
					j > 0 and j < height - 2
					and all_pieces[i][j - 1] != null and all_pieces[i][j + 1] != null and all_pieces[i][j + 2] != null
					and all_pieces[i][j - 1].color == current_color
					and all_pieces[i][j + 1].color == current_color
					and all_pieces[i][j + 2].color == current_color
				):
					print("Match de 4 vertical")
					var idx = color_index[current_color]
					all_pieces[i][j - 1].queue_free()
					all_pieces[i][j + 1].queue_free()
					all_pieces[i][j + 2].queue_free()
					all_pieces[i][j].queue_free()
					all_pieces[i][j - 1] = null
					all_pieces[i][j + 1] = null
					all_pieces[i][j + 2] = null
					all_pieces[i][j] = null

					var special = vertical_pieces[idx].instantiate()
					add_child(special)
					special.position = grid_to_pixel(i, j)
					all_pieces[i][j] = special
					collapse_columns()

				if (
					i > 1 and i < width - 2
					and all_pieces[i - 2][j] != null and all_pieces[i - 1][j] != null
					and all_pieces[i + 1][j] != null and all_pieces[i + 2][j] != null
					and all_pieces[i - 2][j].color == current_color
					and all_pieces[i - 1][j].color == current_color
					and all_pieces[i + 1][j].color == current_color
					and all_pieces[i + 2][j].color == current_color
				):
					print("Match de 5 horizontal")
					var idx = color_index[current_color]
					all_pieces[i - 2][j].queue_free()
					all_pieces[i - 1][j].queue_free()
					all_pieces[i][j].queue_free()
					all_pieces[i + 1][j].queue_free()
					all_pieces[i + 2][j].queue_free()
					all_pieces[i - 2][j] = null
					all_pieces[i - 1][j] = null
					all_pieces[i][j] = null
					all_pieces[i + 1][j] = null
					all_pieces[i + 2][j] = null

					var special = special_pieces[idx].instantiate()
					add_child(special)
					special.position = grid_to_pixel(i, j)
					all_pieces[i][j] = special
					collapse_columns()

				if (
					j > 1 and j < height - 2
					and all_pieces[i][j - 2] != null and all_pieces[i][j - 1] != null
					and all_pieces[i][j + 1] != null and all_pieces[i][j + 2] != null
					and all_pieces[i][j - 2].color == current_color
					and all_pieces[i][j - 1].color == current_color
					and all_pieces[i][j + 1].color == current_color
					and all_pieces[i][j + 2].color == current_color
				):
					print("Match de 5 vertical")
					var idx = color_index[current_color]
					all_pieces[i][j - 2].queue_free()
					all_pieces[i][j - 1].queue_free()
					all_pieces[i][j].queue_free()
					all_pieces[i][j + 1].queue_free()
					all_pieces[i][j + 2].queue_free()
					all_pieces[i][j - 2] = null
					all_pieces[i][j - 1] = null
					all_pieces[i][j] = null
					all_pieces[i][j + 1] = null
					all_pieces[i][j + 2] = null

					var special = special_pieces[idx].instantiate()
					add_child(special)
					special.position = grid_to_pixel(i, j)
					all_pieces[i][j] = special
					collapse_columns()

				# detect horizontal matches (3)
				if (
					i > 0 and i < width -1 
					and 
					all_pieces[i - 1][j] != null and all_pieces[i + 1][j]
					and 
					all_pieces[i - 1][j].color == current_color and all_pieces[i + 1][j].color == current_color
				):
					all_pieces[i - 1][j].matched = true
					all_pieces[i - 1][j].dim()
					all_pieces[i][j].matched = true
					all_pieces[i][j].dim()
					all_pieces[i + 1][j].matched = true
					all_pieces[i + 1][j].dim()
				# detect vertical matches
				if (
					j > 0 and j < height -1 
					and 
					all_pieces[i][j - 1] != null and all_pieces[i][j + 1]
					and 
					all_pieces[i][j - 1].color == current_color and all_pieces[i][j + 1].color == current_color
				):
					all_pieces[i][j - 1].matched = true
					all_pieces[i][j - 1].dim()
					all_pieces[i][j].matched = true
					all_pieces[i][j].dim()
					all_pieces[i][j + 1].matched = true
					all_pieces[i][j + 1].dim()
					
	get_parent().get_node("destroy_timer").start()

func destroy_matched():
	var was_matched = false
	#var points_to_add = 0
	for i in width:
		for j in height:
			if all_pieces[i][j] != null and all_pieces[i][j].matched:
				was_matched = true
				all_pieces[i][j].queue_free()
				all_pieces[i][j] = null
	move_checked = true
	if was_matched:
		add_score(10)
		get_parent().get_node("collapse_timer").start()
	else:
		swap_back()

func collapse_columns():
	for i in width:
		for j in height:
			if all_pieces[i][j] == null:
				print(i, j)
				# look above
				for k in range(j + 1, height):
					if all_pieces[i][k] != null:
						all_pieces[i][k].move(grid_to_pixel(i, j))
						all_pieces[i][j] = all_pieces[i][k]
						all_pieces[i][k] = null
						break
	get_parent().get_node("refill_timer").start()

func refill_columns():
	
	for i in width:
		for j in height:
			if all_pieces[i][j] == null:
				# random number
				var rand = randi_range(0, possible_pieces.size() - 1)
				# instance 
				var piece = possible_pieces[rand].instantiate()
				# repeat until no matches
				var max_loops = 100
				var loops = 0
				while (match_at(i, j, piece.color) and loops < max_loops):
					rand = randi_range(0, possible_pieces.size() - 1)
					loops += 1
					piece = possible_pieces[rand].instantiate()
				add_child(piece)
				piece.position = grid_to_pixel(i, j - y_offset)
				piece.move(grid_to_pixel(i, j))
				# fill array with pieces
				all_pieces[i][j] = piece
				
	check_after_refill()

func check_after_refill():
	for i in width:
		for j in height:
			if all_pieces[i][j] != null and match_at(i, j, all_pieces[i][j].color):
				find_matches()
				get_parent().get_node("destroy_timer").start()
				return
	state = MOVE
	
	move_checked = false

func _on_destroy_timer_timeout():
	print("destroy")
	destroy_matched()

func _on_collapse_timer_timeout():
	print("collapse")
	collapse_columns()

func _on_refill_timer_timeout():
	refill_columns()
	
func game_over():
	state = WAIT
	if score >= min_score:
		print("Ganaste! Obtuviste puntos: ", score)
	else:
		print("Perdiste. Obtuviste puntos: ", score, " de  meta: ", min_score)
	get_tree().paused = true
