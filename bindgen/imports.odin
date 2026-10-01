// Library selection for the generated bindings.
//
// Flecs is shipped in three flavours. Each one changes the layout of a few structs, so
// `flecs.odin` also switches those struct definitions with the same conditions. Keep them in
// sync:
//
//   default                          -> flecs.lib          (release, FLECS_NDEBUG)
//   odin build/run ... -debug        -> flecs_d.lib        (debug, FLECS_DEBUG)
//   ... -define:FLECS_SANITIZE=true  -> flecs_sanitize.lib (FLECS_SANITIZE, implies FLECS_DEBUG)
//
// `FLECS_SANITIZE` is the "debug++" build: expensive checks (for example outstanding allocation
// tracking). It is slower but catches more mistakes.

FLECS_SANITIZE :: #config(FLECS_SANITIZE, false)

when FLECS_SANITIZE {
	foreign import lib "flecs_sanitize.lib"
} else when ODIN_DEBUG {
	foreign import lib "flecs_d.lib"
} else {
	foreign import lib "flecs.lib"
}
