#!/bin/bash

# Script to remap Caps Lock to Escape on macOS
# Usage: ./remap_capslock.sh --install | --uninstall

set -e
set -u

# Color codes
COL_RED='\033[0;31m'
COL_GREEN='\033[0;32m'
COL_YELLOW='\033[1;33m'
COL_CYAN='\033[0;36m'
COL_RESET='\033[0m'

LAUNCH_AGENT_PLIST="$HOME/Library/LaunchAgents/com.user.capslock-escape.plist"

enable_remapping() {
  echo -e "${COL_CYAN}Enabling Caps Lock to Escape remapping...${COL_RESET}"

  # Use hidutil to remap immediately
  # Caps Lock: 0x700000039, Escape: 0x700000029
  hidutil property --set '{"UserKeyMapping":[{"HIDKeyboardModifierMappingSrc":0x700000039,"HIDKeyboardModifierMappingDst":0x700000029}]}' > /dev/null 2>&1

  # Update System Settings to reflect the change in UI
  # Get keyboard identifiers
  VENDOR_ID=$(ioreg -c AppleEmbeddedKeyboard -r | grep "VendorID" | awk -F'= ' '{print $2}' | head -1)
  PRODUCT_ID=$(ioreg -c AppleEmbeddedKeyboard -r | grep '"ProductID"' | awk -F'= ' '{print $2}' | head -1)

  # Set defaults for System Settings UI
  # Key codes: Caps Lock = 0, Escape = 53
  if [ -n "$VENDOR_ID" ] && [ -n "$PRODUCT_ID" ]; then
    # First, delete any existing mapping for this keyboard
    defaults -currentHost delete -g "com.apple.keyboard.modifiermapping.${VENDOR_ID}-${PRODUCT_ID}-0" 2>/dev/null || true

    # Now set the new mapping using the correct integer values
    defaults -currentHost write -g "com.apple.keyboard.modifiermapping.${VENDOR_ID}-${PRODUCT_ID}-0" -array \
      '<dict><key>HIDKeyboardModifierMappingDst</key><integer>53</integer><key>HIDKeyboardModifierMappingSrc</key><integer>0</integer></dict>'

    # Force write the preferences to disk
    defaults -currentHost read -g >/dev/null 2>&1

    # Kill all preference-related daemons to force reload
    killall -HUP cfprefsd 2>/dev/null || true
    killall SystemUIServer 2>/dev/null || true

    # Also try to notify the system about the keyboard change
    /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u 2>/dev/null || true
  fi

  # Create LaunchAgent to make the remapping persistent across reboots
  mkdir -p "$HOME/Library/LaunchAgents"

  cat > "$LAUNCH_AGENT_PLIST" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.capslock-escape</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/hidutil</string>
        <string>property</string>
        <string>--set</string>
        <string>{"UserKeyMapping":[{"HIDKeyboardModifierMappingSrc":0x700000039,"HIDKeyboardModifierMappingDst":0x700000029}]}</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOF

  # Load the LaunchAgent
  launchctl unload "$LAUNCH_AGENT_PLIST" 2>/dev/null || true
  launchctl load "$LAUNCH_AGENT_PLIST"

  if launchctl list | grep -q "com.user.capslock-escape"; then
    echo -e "${COL_GREEN}Caps Lock successfully remapped to Escape.${COL_RESET}"
    echo -e "${COL_YELLOW}Note: The macOS keyboard shortcut settings UI will not reflect these changes. ${COL_RESET}"
  else
    echo -e "${COL_YELLOW}Caps Lock remapped for current session.${COL_RESET}"
    echo -e "${COL_YELLOW}LaunchAgent created at: $LAUNCH_AGENT_PLIST${COL_RESET}"
  fi
}

disable_remapping() {
  echo -e "${COL_CYAN}Disabling Caps Lock to Escape remapping...${COL_RESET}"

  # Clear hidutil mapping
  hidutil property --set '{"UserKeyMapping":[]}' > /dev/null 2>&1

  # Get keyboard identifiers
  VENDOR_ID=$(ioreg -c AppleEmbeddedKeyboard -r | grep "VendorID" | awk -F'= ' '{print $2}' | head -1)
  PRODUCT_ID=$(ioreg -c AppleEmbeddedKeyboard -r | grep '"ProductID"' | awk -F'= ' '{print $2}' | head -1)

  # Remove defaults mapping
  if [ -n "$VENDOR_ID" ] && [ -n "$PRODUCT_ID" ]; then
    defaults -currentHost delete -g "com.apple.keyboard.modifiermapping.${VENDOR_ID}-${PRODUCT_ID}-0" 2>/dev/null || true

    # Kill all preference-related daemons to force reload
    killall -HUP cfprefsd 2>/dev/null || true
    killall SystemUIServer 2>/dev/null || true
  fi

  # Unload and remove LaunchAgent
  if [ -f "$LAUNCH_AGENT_PLIST" ]; then
    launchctl unload "$LAUNCH_AGENT_PLIST" 2>/dev/null || true
    rm -f "$LAUNCH_AGENT_PLIST"
    echo -e "${COL_GREEN}LaunchAgent removed.${COL_RESET}"
  fi

  echo -e "${COL_GREEN}Caps Lock remapping has been removed.${COL_RESET}"
}

show_usage() {
  echo "Usage: $0 [--enable|--disable]"
  echo ""
  echo "Options:"
  echo "  --enable      Enable Caps Lock to Escape remapping"
  echo "  --disable     Disable Caps Lock to Escape remapping"
  exit 1
}

# Main script
# Default to --enable if no arguments provided
if [ $# -eq 0 ]; then
  set -- "--enable"
fi

case "$1" in
  --enable)
    enable_remapping
    ;;
  --disable)
    disable_remapping
    ;;
  --help)
    show_usage
    ;;
  *)
    show_usage
    ;;
esac