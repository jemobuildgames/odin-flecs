// Basic Flecs + Odin example.
//
//   odin run example          -> links flecs.lib   (release layout)
//   odin run example -debug   -> links flecs_d.lib (debug layout)
//
// The structs whose layout depends on FLECS_DEBUG are switched inside flecs.odin with
// `when ODIN_DEBUG` (see scripts/merge_debug_structs.py), so this program is ABI-correct in
// both modes.
package main

import "core:fmt"
import flecs ".."

Position :: struct {
	x, y: f32,
}

main :: proc() {
	// ODIN_DEBUG mirrors the `-debug` flag of `odin build/run`; FLECS_SANITIZE is set with
	// `-define:FLECS_SANITIZE=true`.
	fmt.println("ODIN_DEBUG                   =", ODIN_DEBUG)
	fmt.println("FLECS_SANITIZE               =", flecs.FLECS_SANITIZE)
	fmt.println("size_of(ecs_ref_t)           =", size_of(flecs.ecs_ref_t))
	fmt.println("size_of(ecs_map_t)           =", size_of(flecs.ecs_map_t))
	fmt.println("size_of(ecs_vec_t)           =", size_of(flecs.ecs_vec_t))
	fmt.println("size_of(ecs_block_allocator_t)=", size_of(flecs.ecs_block_allocator_t))

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

	// ecs_ref_t is one of the structs with a debug-only field, and it is returned by value,
	// so a mismatched layout here would corrupt the stack. This exercises the exact case the
	// `when ODIN_DEBUG` structs exist for.
	ref := flecs.ecs_ref_init_id(world, e, pos_id)
	ref_ptr := cast(^Position)flecs.ecs_ref_get_id(world, &ref, pos_id)
	fmt.printfln("ecs_ref_t -> Position {{ x = {}, y = {} }}", ref_ptr.x, ref_ptr.y)

	// Run a single frame.
	_ = flecs.ecs_progress(world, 0)
}
