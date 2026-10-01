# odin-flecs

Unofficial [Odin](https://odin-lang.org/) bindings for the [Flecs](https://www.flecs.dev/) ECS,
generated with [odin-c-bindgen](https://github.com/karl-zylinski/odin-c-bindgen).

- Flecs version: `4.1.6` (pinned in the [`flecs`](flecs) submodule)
- Libraries: `flecs.lib` (release), `flecs_d.lib` (debug) and `flecs_sanitize.lib` (debug++), all x64 static libraries
- Latest tested Odin version: `dev-2026-09-nightly:a2fb372`
- Platform: Windows (x64)

## Layout

| Path | Description |
| --- | --- |
| `flecs.odin` | The generated Odin bindings (`package flecs`). |
| `flecs.lib` | Prebuilt release static library, so you do not need MSVC to use the bindings. |
| `flecs_d.lib` | Prebuilt debug static library (`FLECS_DEBUG`). Linked automatically with `-debug`. |
| `flecs_sanitize.lib` | Prebuilt "debug++" static library (`FLECS_SANITIZE`). Linked with `-define:FLECS_SANITIZE=true`. |
| `bindgen.sjson` | odin-c-bindgen configuration (release). |
| `bindgen_debug.sjson` | odin-c-bindgen configuration (debug), used for the debug struct layouts. |
| `bindgen_sanitize.sjson` | odin-c-bindgen configuration (sanitize), used for the sanitize-only struct layouts. |
| `bindgen/imports.odin` | Library import snippet that selects the library for the current build. |
| `flecs/` | Submodule: the Flecs C library, pinned to tag `v4.1.6`. |
| `odin-c-bindgen/` | Submodule: the binding generator (fork of odin-c-bindgen). |
| `patches/` | Patch that is applied to the generator before building it (see below). |
| `example/` | Example that creates a world, registers a component and shows the layout selection. |
| `scripts/` | Scripts to build the generator, regenerate the bindings and build the libraries. |

## How to use

1. Copy the bindings and the library into your project. Prebuilt `flecs.lib` (release),
   `flecs_d.lib` (debug) and `flecs_sanitize.lib` (debug++) are included, so this step is
   optional - only run it if you want to rebuild the libraries yourself:

   ```cmd
   scripts\build_flecs.cmd
   ```

   This compiles `flecs/distr/flecs.c` three times with the MSVC C++ tools and writes the
   libraries next to `flecs.odin`.

2. Copy `flecs.odin` and the library you want into your project (or add this repository as a
   submodule), then import it. The bindings select the library that matches the build flags
   (`-debug`, `-define:FLECS_SANITIZE=true`) and use the matching struct layouts automatically.

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

## Release, debug and debug++

Flecs is shipped in three flavours. The bindings pick the matching library and struct layouts
from the Odin build flags:

| Odin flags | Library | Flecs config |
| --- | --- | --- |
| (none) | `flecs.lib` | `FLECS_NDEBUG` (release) |
| `-debug` | `flecs_d.lib` | `FLECS_DEBUG` |
| `-define:FLECS_SANITIZE=true` | `flecs_sanitize.lib` | `FLECS_SANITIZE` (implies `FLECS_DEBUG`) |

```cmd
rem release
odin run example

rem debug
odin run example -debug

rem debug++ (sanitize)
odin run example -define:FLECS_SANITIZE=true
```

`FLECS_SANITIZE` is Flecs' "debug++" mode: it implies `FLECS_DEBUG` and adds expensive checks
(such as tracking outstanding allocations). It is slower but catches more mistakes.

[`example/example.odin`](example/example.odin) prints the selected layout, including `ecs_ref_t`
(which is returned by value, so a layout mismatch would corrupt the stack):

```text
# odin run example
ODIN_DEBUG                    = false
FLECS_SANITIZE                = false
size_of(ecs_ref_t)            = 32
size_of(ecs_map_t)            = 32
size_of(ecs_vec_t)            = 16
size_of(ecs_block_allocator_t)= 32

# odin run example -debug
ODIN_DEBUG                    = true
FLECS_SANITIZE                = false
size_of(ecs_ref_t)            = 40
size_of(ecs_map_t)            = 48
size_of(ecs_vec_t)            = 16
size_of(ecs_block_allocator_t)= 32

# odin run example -define:FLECS_SANITIZE=true
ODIN_DEBUG                    = false
FLECS_SANITIZE                = true
size_of(ecs_ref_t)            = 40
size_of(ecs_map_t)            = 48
size_of(ecs_vec_t)            = 32
size_of(ecs_block_allocator_t)= 48
```

## Regenerating the bindings

```cmd
scripts\generate.cmd
```

This builds `odin-c-bindgen` into `build\bindgen.exe` (if needed), generates the bindings three
times (`bindgen.sjson`, `bindgen_debug.sjson`, `bindgen_sanitize.sjson`) and merges the
variant-specific struct layouts into `flecs.odin` behind `when FLECS_SANITIZE` / `when ODIN_DEBUG`.

Requirements:

- Odin on `PATH`.
- Python 3 on `PATH` (for the merge step in `scripts\merge_build_variants.py`).
- libclang `16` or newer. `libclang.dll` must be on `PATH` (or `LIBCLANG_PATH` must point at the
  folder containing it), together with `libclang.lib` in the sibling `lib` folder - this is the
  layout of the official LLVM/Clang Windows builds.

### Generator patch

> You only need to care about this section if you regenerate the bindings. The prebuilt
> `flecs.odin` already contains the fix, and using the prebuilt `flecs.lib` requires no patch at
> all.

**The bug.** `odin-c-bindgen` has a bug in `create_type_recursive`
(`src/translate_collect.odin`). To collect a struct's fields it does
`c := clang.getTypeDeclaration(ct)` and then reads the children of `c`. For the very common C
pattern of forward declaring a type and defining it later:

```c
typedef struct ecs_query_t ecs_query_t;   /* forward declaration */
/* ... */
struct ecs_query_t { /* fields */ };      /* actual definition */
```

libclang returns the *forward declaration* cursor, which has no field children. The type is then
emitted as `ecs_query_t :: struct {}`, and because types are cached by `clang.Type` the later full
definition is skipped as well, so the struct stays empty forever.

**The impact.** Without the fix, 14 public Flecs types are generated as empty structs, including
some of the most important ones:

| Type | Fields | Notes |
| --- | --- | --- |
| `ecs_iter_t` | 40 | Iterator passed to every system/query - needs `entities`, `count`, `ptrs`, ... |
| `ecs_query_t` | 26 | Queries |
| `ecs_type_hooks_t` | 21 | Component type hooks |
| `ecs_observer_t` | 15 | Observers |
| `ecs_term_t` | 9 | Query terms |
| `ecs_observable_t` | 7 | |
| `ecs_block_allocator_t` | 6 | |
| `ecs_map_t` | 5 | |
| `ecs_ref_t` | 5 | |
| `ecs_type_info_t` | 5 | |
| `ecs_table_record_t` | 4 | |
| `ecs_record_t` | 3 | |
| `ecs_allocator_t` | 2 | |
| `ecs_table_cache_hdr_t` | 2 | |

The bindings would still compile, but any real use (systems, query iteration) would be
impossible, because code such as `it.entities` / `it.count` / `it.ptrs` would not exist.
Genuinely opaque types (e.g. `ecs_world_t`, `ecs_table_t`, `ecs_stage_t`) are correctly left
empty, before and after the fix.

**The workaround.** `patches/odin-c-bindgen-record-definition.patch` changes the generator to use
the record *definition* cursor:

```odin
if definition := clang.getCursorDefinition(c); clang.Cursor_isNull(definition) == 0 {
	c = definition
}
```

`scripts\build_bindgen.cmd` applies the patch, builds the generator, and then restores the
submodule, so it never shows up as modified. If the patch no longer applies after updating the
submodule, rebase it - or delete `patches/` and the apply block in the script once the fix lands
upstream.

## Toolchain

The prebuilt libraries and bindings were produced with:

| Tool | Version |
| --- | --- |
| Odin | `dev-2026-09-nightly:a2fb372` |
| MSVC C/C++ compiler (`cl.exe`) | `19.51.36260` for x64 |
| MSVC linker (`link.exe`) | `14.51.36260.0` |
| MSVC library manager (`lib.exe`) | `14.51.36260.0` |
| Visual Studio Build Tools | `18.10.3` (installation `18.10.12224.181`, MSVC toolset `14.51.36231`) |
| Windows SDK | `10.0.26100.0` |
| libclang (generator only) | `23.1.2` (any version `>= 16` works) |

Library build flags (see `scripts\build_flecs.cmd`):

| Library | Flags |
| --- | --- |
| `flecs.lib` | `/c /O2 /DNDEBUG` then `lib` - release, `FLECS_NDEBUG`, static CRT |
| `flecs_d.lib` | `/c /Od /Z7 /DFLECS_DEBUG` then `lib` - debug, `FLECS_DEBUG`, debug info embedded in the `.lib` |
| `flecs_sanitize.lib` | `/c /Od /Z7 /DFLECS_SANITIZE` then `lib` - debug++, `FLECS_SANITIZE`, debug info embedded in the `.lib` |

All three are MSVC x64 static libraries (COFF) that are linked statically into the final
executable - there is no `flecs.dll`.

## Notes

- The three builds change the layout of 7 structs in total, by appending fields:
  - debug: `ecs_ref_t`, `ecs_map_t`, `ecs_map_iter_t`, `ecs_stack_t`, `ecs_stack_cursor_t`;
  - sanitize (in addition): `ecs_vec_t`, `ecs_block_allocator_t`.
  Those structs are emitted with `when FLECS_SANITIZE` / `when ODIN_DEBUG` blocks in `flecs.odin`,
  so a single bindings file matches all three libraries correctly (see
  `scripts\merge_build_variants.py`).
- Function and type names keep their `ecs_` / `Ecs` prefixes so they match the C API and its
  documentation.

## License

The bindings and this repository are MIT licensed, see [LICENSE](LICENSE). Flecs is MIT licensed.
odin-c-bindgen is licensed under the zlib license, see its `LICENSE` file in the submodule.
