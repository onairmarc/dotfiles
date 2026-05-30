# Portable env.sh — works in bash and zsh

# Platform detection (set once)
case "$(uname -s)" in
  Darwin) _PLATFORM="mac" ;;
  CYGWIN*|MINGW*|MSYS*) _PLATFORM="windows" ;;
  *) _PLATFORM="other" ;;
esac

# Herd (PHP 8.3)
export HERD_PHP_83_INI_SCAN_DIR="$HOME/Library/Application Support/Herd/config/php/83/"

# Java / Android
if [ "$_PLATFORM" = "windows" ]; then
  export JAVA_HOME="$LOCALAPPDATA/Programs/graalvm-jdk-21.0.4"
  export ANDROID_HOME="$LOCALAPPDATA/Android/Sdk"
else
  export JAVA_HOME="$HOME/Library/Java/JavaVirtualMachines/graalvm-jdk-21.0.4/Contents/Home"
  export ANDROID_HOME="$HOME/Library/Android/sdk"
fi
export ANDROID_SDK_ROOT="$ANDROID_HOME"

# PATH helpers (idempotent)
_append_path() {
  case ":$PATH:" in
    *":$1:"*) ;;
    *) PATH="$PATH:$1" ;;
  esac
}
_prepend_path() {
  case ":$PATH:" in
    *":$1:"*) ;;
    *) PATH="$1:$PATH" ;;
  esac
}

# Platform-gated append helpers
_append_path_mac() {
  [ "$_PLATFORM" = "mac" ] && _append_path "$1"
}

_append_path_windows() {
  [ "$_PLATFORM" = "windows" ] && _append_path "$1"
}

_prepend_path_mac() {
  [ "$_PLATFORM" = "mac" ] && _prepend_path "$1"
}

_prepend_path_windows() {
  [ "$_PLATFORM" = "windows" ] && _prepend_path "$1"
}

# Appended (lower priority than system PATH)
_append_path_mac "$HOME/Library/Application Support/Herd/bin"
_append_path_mac "/usr/local/bin/node"
_append_path_mac "/usr/local/opt/openjdk@11/bin"
_append_path_mac "/Library/Java/JavaVirtualMachines/microsoft-11.jdk/Contents/Home"
_append_path_mac "/usr/local/opt/mysql-client/bin"

# Prepended (higher priority — last call wins highest)
_prepend_path "$ANDROID_HOME/build-tools"
_prepend_path "$ANDROID_HOME/platform-tools"
_prepend_path "$ANDROID_HOME/cmdline-tools/latest/bin"
_prepend_path "$JAVA_HOME/bin"

export PATH
unset -f _append_path _prepend_path \
  _append_path_mac _append_path_windows \
  _prepend_path_mac _prepend_path_windows
unset _PLATFORM

# Homebrew
export HOMEBREW_NO_AUTO_UPDATE=1

# zsh colorize
export ZSH_COLORIZE_TOOL="pygmentize"
export ZSH_COLORIZE_STYLE="colorful"

# Xdebug
export XDEBUG_MODE="coverage"