extends CharacterBody3D

@export var look_sensitivity : float = 0.006
@export var controller_look_sensitivity := 0.05

@export var jump_velocity := 6.0
@export var auto_bhop := true

const HEADBOB_MOVE_AMOUNT = 0.06
const HEADBOB_FREQUENCY = 2.4
var headbob_time := 0.0

# Ground movement settings
@export var walk_speed := 7.0
@export var sprint_speed := 8.5
@export var ground_accel := 14.0
@export var ground_decel := 10.0
@export var ground_friction := 6.0
@export var crouch_friction := 3.0

# Air movement settings. Need to tweak these to get the feeling dialed in.
@export var air_cap := 0.85 # Can surf steeper ramps if this is higher, makes it easier to stick and bhop
@export var air_accel := 800.0
@export var air_move_speed := 500.0

var wish_dir := Vector3.ZERO
var cam_aligned_wish_dir := Vector3.ZERO

var noclip_speed_mult := 3.0
var noclip := false

func get_move_speed() -> float:
	return sprint_speed if Input.is_action_pressed("sprint") else walk_speed

func _ready():
	for child in %WorldModel.find_children("*", "VisualInstance3D"):
		child.set_layer_mask_value(1, false)
		child.set_layer_mask_value(2, true)

func _unhandled_input(event):
	if event is InputEventMouseButton:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	elif event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseMotion:
			rotate_y(-event.relative.x * look_sensitivity)
			%Camera3D.rotate_x(-event.relative.y * look_sensitivity)
			%Camera3D.rotation.x = clamp(%Camera3D.rotation.x, deg_to_rad(-90), deg_to_rad(90))
	
	if event is InputEventMouseButton and event.is_pressed():
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			noclip_speed_mult = min(100.0, noclip_speed_mult * 1.1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			noclip_speed_mult = max(0.1, noclip_speed_mult * 0.9)

func _headbob_effect(delta):
	headbob_time += delta * self.velocity.length()
	%Camera3D.transform.origin = Vector3(
		cos(headbob_time * HEADBOB_FREQUENCY * 0.5) * HEADBOB_MOVE_AMOUNT,
		sin(headbob_time * HEADBOB_FREQUENCY) * HEADBOB_MOVE_AMOUNT,
		0
	)

# Smoothly interpolated controller look with acceleration and deceleration
var _cur_controller_look = Vector2()
func _handle_controller_look_input(delta):
	var target_look = Input.get_vector("look_left", "look_right", "look_down", "look_up").normalized()
	
	if target_look.length() < _cur_controller_look.length():
		_cur_controller_look = target_look
	else:
		_cur_controller_look = _cur_controller_look.lerp(target_look, 5.0 * delta)
	
	rotate_y(-_cur_controller_look.x * controller_look_sensitivity) # turn left and right
	%Camera3D.rotate_x(_cur_controller_look.y * controller_look_sensitivity) # look up and down
	%Camera3D.rotation.x = clamp(%Camera3D.rotation.x, deg_to_rad(-90), deg_to_rad(90)) # clamp up and down range

func _process(delta):
	_handle_controller_look_input(delta)
	
func _handle_noclip(delta) -> bool:
	if Input.is_action_just_pressed("_noclip") and OS.has_feature("debug"):
		noclip = !noclip
		noclip_speed_mult = 3.0
	
	$CollisionShape3D.disabled = noclip
	
	if not noclip:
		return false
	
	var speed = get_move_speed() * noclip_speed_mult
	if Input.is_action_pressed("sprint"):
		speed *= 3.0
	
	self.velocity = cam_aligned_wish_dir * speed#Vector3.ZERO # GMod style where you can fly w/ noclip
	global_position += self.velocity * delta
	
	return true

func clip_velocity(normal: Vector3, overbounce : float, delta : float) -> void:
	# When strafing into wall, + gravity, velocity will be pointing much in the opposite direction of the normal
	# So with this code, we will back up and off of the wall, cancelling out our strafe + gravity, allowing surf.
	var backoff := self.velocity.dot(normal) * overbounce
	# Not in original recipe. Maybe because of the ordering of the loop, in original source it
	# shouldn't be the case that velocity can be away away from plane while also colliding.
	# Without this, it's possible to get stuck in ceilings
	if backoff >= 0: return
	
	var change := normal * backoff
	self.velocity -= change
	
	# Second iteration to make sure not still moving through plane
	# Not sure why this is necessary but it was in the original recipe so keeping it.
	var adjust := self.velocity.dot(normal)
	if adjust < 0.0:
		self.velocity -= normal * adjust

func is_surface_too_steep(normal : Vector3) -> bool:
	var max_slope_ang_dot = Vector3(0,1,0).rotated(Vector3(1.0,0,0), self.floor_max_angle).dot(Vector3(0,1,0))
	if normal.dot(Vector3(0,1,0)) < max_slope_ang_dot:
		return true
	return false

func _handle_air_physics(delta) -> void:
	self.velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta
	
	# Classic battle tested & fan favorite source/quake air movement recipe.
	# CSS players gonna feel their gamer instincts kick in with this one
	var cur_speed_in_wish_dir = self.velocity.dot(wish_dir)
	# Wish speed (if wish_dir > 0 length) capped to air_cap
	var capped_speed = min((air_move_speed * wish_dir).length(), air_cap)
	# How much to get to the speed the player wishes (in the new dir)
	# Notice this allows for infinite speed. If wish_dir is perpendicular, we always need to add velocity
	#  no matter how fast we're going. This is what allows for things like bhop in CSS & Quake.
	# Also happens to just give some very nice feeling movement & responsiveness when in the air.
	var add_speed_till_cap = capped_speed - cur_speed_in_wish_dir
	if add_speed_till_cap > 0:
		var accel_speed = air_accel * air_move_speed * delta # Usually is adding this one.
		accel_speed = min(accel_speed, add_speed_till_cap) # Works ok without this but sticking to the recipe
		self.velocity += accel_speed * wish_dir
	
	if is_on_wall():
		# The floating mode is much better and less jittery for surf
		# This bit of code is tricky. Will toggle floating mode in air
		# is_on_floor() never triggers in floating mode, and instead is_on_wall() does.
		if is_surface_too_steep(get_wall_normal()):
			self.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
		else:
			self.motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
		clip_velocity(get_wall_normal(), 1, delta) # Allows surf

func _handle_ground_physics(delta) -> void:
	# Similar to the air movement. Acceleration and friction on ground.
	var cur_speed_in_wish_dir = self.velocity.dot(wish_dir)
	var add_speed_till_cap = get_move_speed() - cur_speed_in_wish_dir
	if add_speed_till_cap > 0:
		var accel_speed = ground_accel * delta * get_move_speed()
		accel_speed = min(accel_speed, add_speed_till_cap)
		self.velocity += accel_speed * wish_dir
	
	# Apply friction
	var control = max(self.velocity.length(), ground_decel)
	var drop = control * ground_friction * delta
	var new_speed = max(self.velocity.length() - drop, 0.0)
	if self.velocity.length() > 0:
		new_speed /= self.velocity.length()
	self.velocity *= new_speed
	
	_headbob_effect(delta)

func _physics_process(delta):
	var input_dir = Input.get_vector("left", "right", "up", "down").normalized()
	# Depending on which way you have you character facing, you may have to negate the input directions
	wish_dir = self.global_transform.basis * Vector3(input_dir.x, 0., input_dir.y)
	cam_aligned_wish_dir = %Camera3D.global_transform.basis * Vector3(input_dir.x, 0., input_dir.y)
	
	if not _handle_noclip(delta):
		if is_on_floor():
			if Input.is_action_just_pressed("jump") or (auto_bhop and Input.is_action_pressed("jump")):
				self.velocity.y = jump_velocity
			_handle_ground_physics(delta)
		else:
			_handle_air_physics(delta)
		
		move_and_slide()
