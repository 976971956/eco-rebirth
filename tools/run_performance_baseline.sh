#!/bin/sh

set -eu

REPORT_ROOT="${1:-/tmp/eco-rebirth-performance}"
GODOT_COMMAND="${GODOT_COMMAND:-godot}"

mkdir -p "$REPORT_ROOT"

run_level() {
	LEVEL="$1"
	SEED="$2"
	LOG_PATH="$REPORT_ROOT/benchmark_level_$(printf '%02d' "$LEVEL").log"
	"$GODOT_COMMAND" --headless --log-file "$LOG_PATH" --path . -- \
		--benchmark-level="$LEVEL" \
		--benchmark-duration=20 \
		--benchmark-quality=medium \
		--benchmark-species=rabbit \
		--world-seed="$SEED" \
		--report-dir="$REPORT_ROOT"
}

run_level 1 133701
run_level 5 133705
run_level 10 133710

printf '性能基线已写入：%s\n' "$REPORT_ROOT"
