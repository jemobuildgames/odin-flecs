package main

import "core:fmt"
import flecs ".."

Position :: struct {
	x, y: f32,
}

main :: proc() {
	// Create a world.
	world := flecs.ecs_init()
	defer _ = flecs.ecs_fini(world)

	// Register a component type. In C this is what the `ECS_COMPONENT` macro expands to.
	pos_entity := flecs.ecs_entity_init(world, &flecs.ecs_entity_desc_t{
		name   = "Position",
		symbol = "Position",
	})

	pos_id := flecs.ecs_component_init(world, &flecs.ecs_component_desc_t{
		entity = pos_entity,
		type   = {
			size      = size_of(Position),
			alignment = align_of(Position),
		},
	})

	// Spawn an entity and give it a Position.
	e := flecs.ecs_new_w_id(world, pos_id)
	value := Position{10, 20}
	flecs.ecs_set_id(world, e, pos_id, size_of(Position), rawptr(&value))

	// Read the component back.
	ptr := cast(^Position)flecs.ecs_get_id(world, e, pos_id)
	fmt.printfln("entity {} has Position {{ x = {}, y = {} }}", e, ptr.x, ptr.y)

	// Run a single frame.
	_ = flecs.ecs_progress(world, 0)
}
