#!/usr/bin/env python3
"""Merge the build-variant struct layouts into the generated Flecs bindings.

The release, debug and sanitize builds of Flecs differ in the layout of a handful of structs:

* debug (`FLECS_DEBUG`) appends fields to `ecs_ref_t`, `ecs_map_t`, `ecs_map_iter_t`,
  `ecs_stack_t` and `ecs_stack_cursor_t`;
* sanitize (`FLECS_SANITIZE`, which implies `FLECS_DEBUG`) additionally appends fields to
  `ecs_vec_t` and `ecs_block_allocator_t`.

`odin-c-bindgen` cannot express that, so this script compares the three generated outputs and
wraps every struct that differs in `when` blocks:

    when FLECS_SANITIZE {
        <sanitize definition>
    } else when ODIN_DEBUG {
        <debug definition>
    } else {
        <release definition>
    }

The whole struct is duplicated because the fields are not simply appended - the generator also
re-aligns the field names - so a full definition is needed for each flavour. Two-way blocks are
emitted when only one flavour differs.

Usage: merge_build_variants.py <release.odin> <debug.odin> <sanitize.odin>
"""

import re
import sys

STRUCT_HEADER = re.compile(r"(?m)^([A-Za-z_][A-Za-z0-9_]*) :: struct(?: #raw_union)? \{")


def read_text(path):
    try:
        with open(path, encoding="utf-8") as f:
            return f.read()
    except OSError as e:
        print(f"Could not read {path}: {e}", file=sys.stderr)
        return None


def write_text(path, text):
    try:
        with open(path, "w", encoding="utf-8") as f:
            f.write(text)
    except OSError as e:
        print(f"Could not write {path}: {e}", file=sys.stderr)
        return False
    return True


def find_structs(text):
    """Return {name: (start, end, text)} for every top-level struct definition."""
    result = {}
    for match in STRUCT_HEADER.finditer(text):
        name = match.group(1)
        start = match.start()
        i = match.end() - 1  # index of the opening brace
        depth = 0
        j = i
        while j < len(text):
            if text[j] == "{":
                depth += 1
            elif text[j] == "}":
                depth -= 1
                if depth == 0:
                    break
            j += 1
        end = j + 1
        if text[end : end + 1] == "\n":
            end += 1
        result[name] = (start, end, text[start:end])
    return result


def indent(block):
    return "\n".join(("\t" + line) if line.strip() else line for line in block.split("\n"))


def conditional(release, debug, sanitize):
    """Return the replacement block for a struct, or None if all three are identical."""
    if release == debug == sanitize:
        return None

    if debug == release:
        # Only the sanitize build differs, so a two-way block is enough.
        return f"when FLECS_SANITIZE {{\n{indent(sanitize)}}} else {{\n{indent(release)}}}\n"

    # Debug and/or sanitize differ. Always emit the full three-way block: FLECS_SANITIZE implies
    # FLECS_DEBUG, so a `when ODIN_DEBUG`-only block would wrongly fall back to the release layout
    # when sanitize is enabled without -debug.
    return (
        f"when FLECS_SANITIZE {{\n{indent(sanitize)}}} "
        f"else when ODIN_DEBUG {{\n{indent(debug)}}} else {{\n{indent(release)}}}\n"
    )


def main():
    if len(sys.argv) != 4:
        print(__doc__, file=sys.stderr)
        return 2

    release_path, debug_path, sanitize_path = sys.argv[1], sys.argv[2], sys.argv[3]
    release = read_text(release_path)
    debug = read_text(debug_path)
    sanitize = read_text(sanitize_path)
    if release is None or debug is None or sanitize is None:
        return 1

    release_structs = find_structs(release)
    debug_structs = find_structs(debug)
    sanitize_structs = find_structs(sanitize)

    replacements = {}
    for name, (start, end, body) in release_structs.items():
        if name not in debug_structs or name not in sanitize_structs:
            continue
        block = conditional(body, debug_structs[name][2], sanitize_structs[name][2])
        if block is not None:
            replacements[name] = (start, end, block)

    if not replacements:
        print("No differing structs found; nothing to do.")
        return 0

    # Replace from the end so earlier offsets stay valid.
    for name in sorted(replacements, key=lambda n: replacements[n][0], reverse=True):
        start, end, block = replacements[name]
        release = release[:start] + block + release[end:]

    if not write_text(release_path, release):
        return 1

    print(f"Made {len(replacements)} struct(s) conditional on the build flavour:")
    for name in sorted(replacements):
        print("  - " + name)
    return 0


if __name__ == "__main__":
    sys.exit(main())
