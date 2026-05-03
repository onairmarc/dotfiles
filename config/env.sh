# Portable env.sh — works in bash and zsh

# Herd (PHP 8.3)
export HERD_PHP_83_INI_SCAN_DIR="/Users/marcbeinder/Library/Application Support/Herd/config/php/83/"

# Java / Android
export JAVA_HOME="$HOME/Library/Java/JavaVirtualMachines/graalvm-jdk-21.0.4/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
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

# Appended (lower priority than system PATH)
_append_path "/Users/marcbeinder/Library/Application Support/Herd/bin"
_append_path "/usr/local/bin/node"
_append_path "/usr/local/opt/openjdk@11/bin"
_append_path "/Library/Java/JavaVirtualMachines/microsoft-11.jdk/Contents/Home"

# Prepended (higher priority — last call wins highest)
_prepend_path "$ANDROID_HOME/build-tools"
_prepend_path "$ANDROID_HOME/platform-tools"
_prepend_path "$ANDROID_HOME/cmdline-tools/latest/bin"
_prepend_path "$JAVA_HOME/bin"

export PATH
unset -f _append_path _prepend_path

# Homebrew
export HOMEBREW_NO_AUTO_UPDATE=1

# zsh colorize
export ZSH_COLORIZE_TOOL="pygmentize"
export ZSH_COLORIZE_STYLE="colorful"

# Xdebug
export XDEBUG_MODE="coverage"