#!/usr/bin/env python3
"""Merge debug-only struct layouts into the generated Flecs bindings.

The release and debug builds of Flecs differ in the layout of a handful of structs: the debug
build (FLECS_DEBUG) appends extra fields. `odin-c-bindgen` cannot express that, so this script
compares the release output (`flecs.odin`) with the debug output (`build/flecs_debug/flecs.odin`)
and wraps every struct that differs in

    when ODIN_DEBUG {
        <debug definition>
    } else {
        <release definition>
    }

The whole struct is duplicated because the fields are not simply appended - the generator also
re-aligns the field names - so a full definition is needed for each flavour.

Usage: merge_debug_structs.py <release.odin> <debug.odin>
"""

import re
import sys

STRUCT_HEADER = re.compile(r"(?m)^([A-Za-z_][A-Za-z0-9_]*) :: struct(?: #raw_union)? \{")


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


def main():
    if len(sys.argv) != 3:
        print(__doc__, file=sys.stderr)
        return 2

    release_path, debug_path = sys.argv[1], sys.argv[2]
    release = read_text(release_path)
    debug = read_text(debug_path)
    if release is None or debug is None:
        return 1

    release_structs = find_structs(release)
    debug_structs = find_structs(debug)

    names = [
        name
        for name, (_, _, body) in release_structs.items()
        if name in debug_structs and debug_structs[name][2] != body
    ]

    if not names:
        print("No differing structs found; nothing to do.")
        return 0

    # Replace from the end so earlier offsets stay valid.
    for name in sorted(names, key=lambda n: release_structs[n][0], reverse=True):
        start, end, body = release_structs[name]
        debug_body = debug_structs[name][2]
        replacement = (
            "when ODIN_DEBUG {\n"
            + indent(debug_body)
            + "} else {\n"
            + indent(body)
            + "}\n"
        )
        release = release[:start] + replacement + release[end:]

    if not write_text(release_path, release):
        return 1

    print(f"Made {len(names)} struct(s) conditional on ODIN_DEBUG:")
    for name in sorted(names):
        print("  - " + name)
    return 0


if __name__ == "__main__":
    sys.exit(main())
