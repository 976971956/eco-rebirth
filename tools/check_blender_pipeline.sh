#!/bin/sh

set -eu

PROJECT_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
BLENDER_COMMAND="${BLENDER_COMMAND:-blender}"

if ! command -v "$BLENDER_COMMAND" >/dev/null 2>&1; then
	printf 'Blender is required. Install it with: brew install --cask blender\n' >&2
	exit 1
fi

"$BLENDER_COMMAND" --background --factory-startup --python-exit-code 1 \
	--python "$PROJECT_ROOT/tools/blender/validate_pipeline.py" -- \
	--config "$PROJECT_ROOT/tools/blender/pipeline_config.json" \
	--smoke-output /tmp/eco-rebirth-blender-pipeline-smoke.glb
