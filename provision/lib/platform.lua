-- provision/lib/platform.lua
--
-- Platform detection and helpers for the Lua provisioner.
-- Platform is read from the first CLI argument passed to main.lua ("mac" or
-- "windows"/"win"). Any other value causes an immediate error exit.

local M = {}

-- Allowlist of recognized platform strings → canonical name
local PLATFORM_ALIASES = {
  mac     = "mac",
  windows = "windows",
  win     = "windows",
}

-- Resolved platform, set by M.init()
local _platform = nil

--- Initialize platform from the CLI argument.
-- Must be called once at startup (main.lua). Exits with an error message if
-- the platform argument is missing or not in the allowlist.
-- @param arg string  The first CLI argument (arg[1]).
function M.init(arg_platform)
  if not arg_platform or arg_platform == "" then
    io.stderr:write("[platform] ERROR: platform argument is required (mac | windows)\n")
    os.exit(2)
  end

  local canonical = PLATFORM_ALIASES[arg_platform:lower()]
  if not canonical then
    io.stderr:write(string.format(
      "[platform] ERROR: unsupported platform %q — must be one of: mac, windows\n",
      arg_platform
    ))
    os.exit(2)
  end

  _platform = canonical
end

--- Return the canonical platform name ("mac" or "windows").
function M.current()
  assert(_platform, "platform.init() has not been called")
  return _platform
end

--- Return true when running on macOS.
function M.is_mac()
  return M.current() == "mac"
end

--- Return true when running on Windows.
function M.is_windows()
  return M.current() == "windows"
end

--- Return the user home directory.
-- Uses $HOME on mac/linux-style systems; $USERPROFILE on Windows.
function M.home()
  return os.getenv("HOME") or os.getenv("USERPROFILE") or ""
end

--- Return the dotfiles root directory.
-- Honors $DF_ROOT_DIRECTORY if set; otherwise defaults to
-- $HOME/Documents/GitHub/dotfiles.
function M.dotfiles_root()
  return os.getenv("DF_ROOT_DIRECTORY") or (M.home() .. "/Documents/GitHub/dotfiles")
end

--- Return the data directory used for state persistence (~/.df_data).
function M.data_dir()
  return M.home() .. "/.df_data"
end

--- Create a directory (and any missing parents) idempotently.
-- On mac uses `mkdir -p`. On Windows shells `mkdir -p` would create a literal
-- directory named "-p", so we use PowerShell's `New-Item -Force` which is the
-- native equivalent.
-- @param path string  Filesystem path to create.
-- @return boolean     true on success.
function M.mkdir_p(path)
  if M.is_windows() then
    local cmd = string.format(
      'powershell -NoProfile -Command "New-Item -ItemType Directory -Force -Path \'%s\' | Out-Null"',
      path:gsub("'", "''")
    )
    return os.execute(cmd)
  end
  return os.execute(string.format('mkdir -p %q', path))
end

--- Return true if an entry's platform list includes the current platform.
-- If entry.platforms is nil or empty, the entry applies to all platforms.
-- @param entry table  A manifest entry (tool/script/configurator).
function M.matches(entry)
  if not entry.platforms or #entry.platforms == 0 then
    return true
  end
  local cur = M.current()
  for _, p in ipairs(entry.platforms) do
    if PLATFORM_ALIASES[p:lower()] == cur then
      return true
    end
  end
  return false
end

return M
