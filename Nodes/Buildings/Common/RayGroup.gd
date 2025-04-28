extends Node2D

func is_any_ray_solid() -> bool:
	for ray in get_children():
		if ray.get_raycast():
			return true
	
	return false
