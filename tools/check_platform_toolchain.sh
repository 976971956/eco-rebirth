#!/bin/sh

set -u

CHECK_MODE="${1:-all}"
GODOT_COMMAND="${GODOT_COMMAND:-godot}"
USER_NAME="$(id -un)"
TEMPLATE_ROOT="${GODOT_TEMPLATE_ROOT:-/Users/${USER_NAME}/Library/Application Support/Godot/export_templates/4.7.1.stable}"
ANDROID_SDK_ROOT_VALUE="${ANDROID_SDK_ROOT:-/Users/${USER_NAME}/Library/Android/sdk}"
JAVA_ROOT="${ANDROID_JAVA_HOME:-/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home}"
FAILURES=0

pass() {
	printf '✓ %s\n' "$1"
}

fail() {
	printf '✗ %s\n' "$1"
	FAILURES=$((FAILURES + 1))
}

check_file() {
	if [ -f "$1" ]; then
		pass "$2"
	else
		fail "$2（缺少 $1）"
	fi
}

check_command() {
	if command -v "$1" >/dev/null 2>&1; then
		pass "$2"
	else
		fail "$2（找不到 $1）"
	fi
}

resolve_xcodebuild() {
	if [ -x /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild ]; then
		printf '%s\n' /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild
	elif command -v xcodebuild >/dev/null 2>&1; then
		command -v xcodebuild
	else
		printf '%s\n' ""
	fi
}

printf '《生态轮回》平台工具链检查 · %s\n' "$CHECK_MODE"
if command -v "$GODOT_COMMAND" >/dev/null 2>&1; then
	GODOT_VERSION="$($GODOT_COMMAND --version 2>/dev/null)"
	case "$GODOT_VERSION" in
		4.7.1*) pass "Godot $GODOT_VERSION" ;;
		*) fail "Godot 版本应为 4.7.1，当前为 $GODOT_VERSION" ;;
	esac
else
	fail "找不到 Godot 命令：$GODOT_COMMAND"
fi

case "$CHECK_MODE" in
	all|web)
		check_file "$TEMPLATE_ROOT/web_nothreads_release.zip" "Web 单线程发布模板"
		;;
esac

case "$CHECK_MODE" in
	all|android)
		check_file "$TEMPLATE_ROOT/android_debug.apk" "Android 调试模板"
		check_file "$TEMPLATE_ROOT/android_release.apk" "Android 发布模板"
		check_file "$JAVA_ROOT/bin/java" "JDK 17"
		check_file "$ANDROID_SDK_ROOT_VALUE/platforms/android-36/android.jar" "Android Platform 36"
		check_file "$ANDROID_SDK_ROOT_VALUE/build-tools/35.0.1/apksigner" "Android Build Tools 35.0.1"
		check_file "$ANDROID_SDK_ROOT_VALUE/platform-tools/adb" "Android adb"
		;;
esac

case "$CHECK_MODE" in
	all|ios)
		check_file "$TEMPLATE_ROOT/ios.zip" "iOS 发布模板"
		if [ -d /Applications/Xcode.app ]; then
			pass "完整 Xcode 应用"
		else
			fail "缺少 /Applications/Xcode.app"
		fi
		XCODEBUILD_COMMAND="$(resolve_xcodebuild)"
		if [ -n "$XCODEBUILD_COMMAND" ] && "$XCODEBUILD_COMMAND" -version >/dev/null 2>&1; then
			pass "Xcode 原生构建器"
		else
			fail "Xcode 原生构建器不可用（不要只指向 CommandLineTools）"
		fi
		;;
esac

if [ "$FAILURES" -gt 0 ]; then
	printf '结果：%d 项未就绪。只代表本机工具链状态，不代表游戏逻辑失败。\n' "$FAILURES"
	exit 1
fi

printf '结果：所选平台工具链已就绪。\n'
