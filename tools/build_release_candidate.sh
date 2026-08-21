#!/bin/sh

set -eu

REPORT_ROOT="${1:-/tmp/eco-rebirth-v168-rc}"
GODOT_COMMAND="${GODOT_COMMAND:-godot}"
PROJECT_ROOT="$(pwd)"
XCODEBUILD_COMMAND="/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild"
DERIVED_ROOT="$REPORT_ROOT/ios-derived"

mkdir -p "$REPORT_ROOT"

run_godot_check() {
	NAME="$1"
	shift
	"$GODOT_COMMAND" --headless --log-file "$REPORT_ROOT/$NAME.log" --path "$PROJECT_ROOT" "$@"
}

printf '《生态轮回》V1.68 发布候选验证\n'
run_godot_check parse --editor --quit
run_godot_check species --script res://tools/validate_species.gd
run_godot_check release --script res://tools/validate_release.gd
run_godot_check runtime --quit-after 1200 -- --autoplay

"$PROJECT_ROOT/tools/run_performance_baseline.sh" "$REPORT_ROOT/performance"
run_godot_check performance-gate --script res://tools/validate_performance_baseline.gd -- --report-dir="$REPORT_ROOT/performance"

SOAK_STATUS="not_requested"
if [ "${ECO_RC_SOAK:-0}" = "1" ]; then
	run_godot_check soak-level-1 -- --batch-sim=2 --batch-level=1 --world-seed=141001 --report-dir="$REPORT_ROOT/soak"
	run_godot_check soak-level-10 -- --batch-sim=2 --batch-level=10 --world-seed=141010 --report-dir="$REPORT_ROOT/soak"
	SOAK_STATUS="passed_2x_level_1_and_10"
fi

"$PROJECT_ROOT/tools/check_platform_toolchain.sh" web >"$REPORT_ROOT/web-toolchain.log"
run_godot_check web-export --export-release Web "$PROJECT_ROOT/build/web/index.html"
test -s "$PROJECT_ROOT/build/web/index.html"
test -s "$PROJECT_ROOT/build/web/index.js"
test -s "$PROJECT_ROOT/build/web/index.wasm"
test -s "$PROJECT_ROOT/build/web/index.pck"
WEB_STATUS="passed"
WEB_SHA="$(shasum -a 256 "$PROJECT_ROOT/build/web/index.pck" | awk '{print $1}')"

"$PROJECT_ROOT/tools/check_platform_toolchain.sh" ios >"$REPORT_ROOT/ios-toolchain.log"
run_godot_check ios-export --export-release iOS "$PROJECT_ROOT/build/ios/EcoRebirth"
"$XCODEBUILD_COMMAND" -project "$PROJECT_ROOT/build/ios/EcoRebirth.xcodeproj" -scheme EcoRebirth -configuration Release -sdk iphoneos -derivedDataPath "$DERIVED_ROOT" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build >"$REPORT_ROOT/ios-build.log" 2>&1
test -x "$DERIVED_ROOT/Build/Products/Release-iphoneos/EcoRebirth.app/EcoRebirth"
IOS_STATUS="passed_unsigned_arm64"
IOS_SHA="$(shasum -a 256 "$DERIVED_ROOT/Build/Products/Release-iphoneos/EcoRebirth.app/EcoRebirth" | awk '{print $1}')"

ANDROID_STATUS="blocked_toolchain"
ANDROID_SHA=""
if "$PROJECT_ROOT/tools/check_platform_toolchain.sh" android >"$REPORT_ROOT/android-toolchain.log" 2>&1; then
	run_godot_check android-export --export-debug Android "$PROJECT_ROOT/build/android/EcoRebirth.apk"
	test -s "$PROJECT_ROOT/build/android/EcoRebirth.apk"
	ANDROID_STATUS="passed_debug_apk"
	ANDROID_SHA="$(shasum -a 256 "$PROJECT_ROOT/build/android/EcoRebirth.apk" | awk '{print $1}')"
fi

SOURCE_REF="$(git -C "$PROJECT_ROOT" describe --always --dirty 2>/dev/null || printf 'unknown')"
GODOT_VERSION="$($GODOT_COMMAND --version | tr -d '\n')"
GENERATED_AT="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
MANIFEST_PATH="$REPORT_ROOT/release_candidate_manifest.json"
printf '{\n  "game_version": "1.68",\n  "build_number": 800,\n  "source_ref": "%s",\n  "godot_version": "%s",\n  "generated_at_utc": "%s",\n  "checks": {"parse": "passed", "species": "passed", "release": "passed", "runtime_1200_frames": "passed", "performance_gate": "passed", "performance_levels": [1, 5, 10], "ecology_soak": "%s"},\n  "artifacts": {"web": {"status": "%s", "pck_sha256": "%s"}, "ios": {"status": "%s", "binary_sha256": "%s"}, "android": {"status": "%s", "apk_sha256": "%s"}},\n  "device_validation": "required_separately"\n}\n' "$SOURCE_REF" "$GODOT_VERSION" "$GENERATED_AT" "$SOAK_STATUS" "$WEB_STATUS" "$WEB_SHA" "$IOS_STATUS" "$IOS_SHA" "$ANDROID_STATUS" "$ANDROID_SHA" >"$MANIFEST_PATH"

printf '发布候选验证完成：%s\n' "$MANIFEST_PATH"
printf 'Web=%s · iOS=%s · Android=%s\n' "$WEB_STATUS" "$IOS_STATUS" "$ANDROID_STATUS"
