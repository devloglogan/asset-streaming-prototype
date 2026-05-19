extends CharacterBody3D


const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const ROTATION_SPEED = 10.0
const ZOOM_DISTANCE = 0.33

@onready var pivot_y: Node3D = $PivotY
@onready var pivot_x: Node3D = $PivotY/PivotX
@onready var camera: Camera3D = $PivotY/PivotX/Camera
@onready var skin = $GobotSkin


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		skin.jump()

	var input_dir := Vector2.ZERO
	if get_viewport().gui_get_focus_owner() == null:
		input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (pivot_y.global_transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()

	if direction:
		var target_angle := atan2(direction.x, direction.z)
		skin.rotation.y = lerp_angle(skin.rotation.y, target_angle, ROTATION_SPEED * delta)

	if is_on_floor():
		if direction:
			skin.run()
		else:
			skin.idle()
	elif velocity.y < 0.0:
		skin.fall()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_MIDDLE:
				if event.pressed:
					Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				else:
					Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:
					camera.position.z -= ZOOM_DISTANCE
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					camera.position.z += ZOOM_DISTANCE
		camera.position.z = clampf(camera.position.z, 0.5, 15.0)
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		pivot_y.rotate_y(-event.relative.x * .005)
		pivot_x.rotate_x(-event.relative.y * .005)
		pivot_x.rotation.x = clamp(pivot_x.rotation.x, -PI/2, -PI/16)
	elif event is InputEventKey:
		if event.key_label == Key.KEY_ESCAPE and event.pressed:
			get_tree().quit()
