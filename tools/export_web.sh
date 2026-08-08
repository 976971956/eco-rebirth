#!/bin/sh
set -eu

PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
OUTPUT_DIR="$PROJECT_DIR/build/web"

mkdir -p "$OUTPUT_DIR"
/opt/homebrew/bin/godot --headless --path "$PROJECT_DIR" --export-release Web "$OUTPUT_DIR/index.html"
touch "$OUTPUT_DIR/.nojekyll"

if [ ! -f "$OUTPUT_DIR/index.html" ]; then
	echo "Web export failed: index.html was not created." >&2
	exit 1
fi

echo "Web build ready: $OUTPUT_DIR/index.html"
