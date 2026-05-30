-- provision/configurators/iterm.lua
--
-- Configures iTerm2 font settings.
-- Replicates install.sh:25-45 (configure_iterm function).
--
-- Sets JetBrainsMono-Regular 18pt as both the normal and non-ASCII font
-- using `defaults write` and `/usr/libexec/PlistBuddy`.
--
-- Returns a module table with a run() function (one-shot configurator API).

local function run()
  local font_name = "JetBrainsMono-Regular"
  local font_size = "18"
  local font_spec = font_name .. " " .. font_size

  local home      = os.getenv("HOME") or ""
  local prefs_dir = home .. "/Library/Preferences"
  local plist     = prefs_dir .. "/com.googlecode.iterm2.plist"

  -- Ensure the preferences directory exists.
  os.execute(string.format('mkdir -p %q', prefs_dir))

  -- Configure via defaults(1).
  os.execute(string.format(
    'defaults write com.googlecode.iterm2 "Normal Font" -string %q',
    font_spec
  ))
  os.execute(string.format(
    'defaults write com.googlecode.iterm2 "Non Ascii Font" -string %q',
    font_spec
  ))
  os.execute('defaults write com.googlecode.iterm2 UseNonASCIIFont -bool true')

  -- Update the plist bookmarks profile (best-effort; ignore errors if no
  -- profile exists yet — PlistBuddy returns non-zero in that case).
  os.execute(string.format(
    '/usr/libexec/PlistBuddy -c "Set :New\\ Bookmarks:0:Normal\\ Font %s" %q 2>/dev/null || true',
    font_spec, plist
  ))
  os.execute(string.format(
    '/usr/libexec/PlistBuddy -c "Set :New\\ Bookmarks:0:Non\\ Ascii\\ Font %s" %q 2>/dev/null || true',
    font_spec, plist
  ))
  os.execute(string.format(
    '/usr/libexec/PlistBuddy -c "Set :New\\ Bookmarks:0:Use\\ Non-ASCII\\ Font true" %q 2>/dev/null || true',
    plist
  ))
end

return { run = run }
