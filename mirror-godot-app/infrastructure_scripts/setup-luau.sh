#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LUAU_ROOT="$ROOT/GodotLuau"
PACKAGE="$LUAU_ROOT/GodotLuau.zip"
DEST="$ROOT"
if [[ ! -f "$PACKAGE" ]]; then
  echo "RageBlox Luau package is missing: $PACKAGE"
  echo "Initialize submodules recursively with: git submodule update --init --recursive"
  exit 1
fi
if [[ ! -f "$DEST/godot_luau.gdextension" ]]; then
  unzip -q -o "$PACKAGE" -d "$DEST"
fi
if [[ ! -f "$DEST/godot_luau.gdextension" ]]; then
  echo "Luau runtime extraction failed: godot_luau.gdextension was not found."
  exit 1
fi
echo "RageBlox Luau runtime is ready."
