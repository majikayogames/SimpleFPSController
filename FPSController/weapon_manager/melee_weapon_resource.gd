class_name MeleeWeaponResource
extends WeaponResource

@export var max_hit_dist = 2.3

@export var miss_sound : AudioStream

func fire_shot():
	weapon_manager.trigger_weapon_shoot_world_anim()
	weapon_manager.play_anim(view_shoot_anim)
	weapon_manager.queue_anim(view_idle_anim)
	
	var raycast = weapon_manager.bullet_raycast
	raycast.target_position = Vector3(0,0,-abs(max_hit_dist))
	raycast.force_raycast_update()
	
	var bullet_target_pos = raycast.global_transform * raycast.target_position
	var raycast_dir = (bullet_target_pos - raycast.global_position).normalized()
	if raycast.is_colliding():
		weapon_manager.play_sound(shoot_sound)
		var obj = raycast.get_collider()
		var nrml = raycast.get_collision_normal()
		var pt = raycast.get_collision_point()
		bullet_target_pos = pt
		BulletDecalPool.spawn_bullet_decal(pt, nrml, obj, raycast.global_basis, preload("res://FPSController/weapon_manager/knifedecal.png"))
		if obj is RigidBody3D:
			obj.apply_impulse(-nrml * 5.0 / obj.mass, pt - obj.global_position)
		
		if obj.has_method("take_backstab_damage") and raycast_dir.dot(-obj.global_basis.z) > 0.4 and (obj.global_transform.affine_inverse() * raycast.global_position).z > 0.0:
			obj.take_backstab_damage(self.damage)
			var blood_splatter = preload("res://FPSController/weapon_manager/knife/blood_splatter.tscn").instantiate()
			obj.add_sibling(blood_splatter)
			blood_splatter.global_position = pt
		elif obj.has_method("take_damage"):
			obj.take_damage(self.damage)
	else:
		weapon_manager.play_sound(miss_sound)
	
	last_fire_time = Time.get_ticks_msec()
