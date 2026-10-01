// Library selection for the generated bindings.
//
// Flecs is shipped as both a release and a debug build. The debug build (FLECS_DEBUG) changes
// the layout of a few structs, so `flecs.odin` also switches those struct definitions with
// `when ODIN_DEBUG`. Keep the two in sync: pass `-debug` to Odin to use `flecs_d.lib`.
when ODIN_DEBUG {
	foreign import lib "flecs_d.lib"
} else {
	foreign import lib "flecs.lib"
}
