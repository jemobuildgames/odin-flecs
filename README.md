# odin-flecs

Unofficial [Odin](https://odin-lang.org/) bindings for the [Flecs](https://www.flecs.dev/) ECS,
generated with [odin-c-bindgen](https://github.com/karl-zylinski/odin-c-bindgen).

- Flecs version: `4.1.6` (pinned in the [`flecs`](flecs) submodule)
- Latest tested Odin version: `dev-2026-09-nightly:a2fb372`
- Platform: Windows (x64)

## Layout

| Path | Description |
| --- | --- |
| `flecs.odin` | The generated Odin bindings (`package flecs`). |
| `flecs.lib` | Prebuilt release static library, so you do not need MSVC to use the bindings. |
| `bindgen.sjson` | odin-c-bindgen configuration. |
| `flecs/` | Submodule: the Flecs C library, pinned to tag `v4.1.6`. |
| `odin-c-bindgen/` | Submodule: the binding generator (fork of odin-c-bindgen). |
| `patches/` | Patch that is applied to the generator before building it (see below). |
| `example/` | Small example that creates a world, registers a component and iterates. |
| `scripts/` | Scripts to build the generator, regenerate the bindings and build `flecs.lib`. |

## How to use

1. Copy the bindings and the library into your project. A prebuilt release `flecs.lib` is
   included, so this step is optional - only run it if you want to rebuild the library yourself:

   ```cmd
   scripts\build_flecs.cmd
   ```

   This compiles `flecs/distr/flecs.c` with the MSVC C++ tools and writes `flecs.lib` next to
   `flecs.odin`.

2. Copy `flecs.odin` and `flecs.lib` into your project (or add this repository as a submodule),
   then import it:

   ```odin
   import flecs "../odin-flecs"
   ```

   ```odin
   world := flecs.ecs_init()
   defer _ = flecs.ecs_fini(world)
   ```

3. See [`example/example.odin`](example/example.odin) for a complete example. Run it with:

   ```cmd
   odin run example
   ```

Components are registered at runtime, exactly like the C `ECS_COMPONENT` macro does:

```odin
Position :: struct { x, y: f32 }

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
```

## Regenerating the bindings

```cmd
scripts\generate.cmd
```

This builds `odin-c-bindgen` into `build\bindgen.exe` (if needed) and runs it with
`bindgen.sjson`, overwriting `flecs.odin`.

Requirements:

- Odin on `PATH`.
- libclang `16` or newer. `libclang.dll` must be on `PATH` (or `LIBCLANG_PATH` must point at the
  folder containing it), together with `libclang.lib` in the sibling `lib` folder - this is the
  layout of the official LLVM/Clang Windows builds.

### Generator patch

`odin-c-bindgen` currently emits structs as empty when a type is forward declared with
`typedef struct X X;` before being defined as `struct X { ... }`. Flecs does this for several
public types (for example `ecs_iter_t` and `ecs_query_t`), which would otherwise leave those
structs without any fields.

`patches/odin-c-bindgen-record-definition.patch` fixes this by making the generator use the
record definition cursor. `scripts\build_bindgen.cmd` applies the patch, builds the generator and
then restores the submodule, so it never shows up as modified. If the patch no longer applies
after updating the submodule, rebase it - or drop it once the fix lands upstream.

## Notes

- The bindings are generated twice with a release configuration (`FLECS_NDEBUG`), so the struct
  layouts match a release build of Flecs. If you build Flecs in debug mode you must regenerate the
  bindings with the `FLECS_NDEBUG` define removed from `bindgen.sjson`.
- Function and type names keep their `ecs_` / `Ecs` prefixes so they match the C API and its
  documentation.

## License

The bindings and this repository are MIT licensed, see [LICENSE](LICENSE). Flecs is MIT licensed.
odin-c-bindgen is licensed under the zlib license, see its `LICENSE` file in the submodule.
