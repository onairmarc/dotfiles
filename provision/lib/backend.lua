-- provision/lib/backend.lua
--
-- Package manager backends for the Lua provisioner.
-- Supported backends: brew (formula), cask (Homebrew cask), choco (Chocolatey).
--
-- Each backend exposes:
--   is_installed(id, opts) -> boolean
--   install(id, opts)      -> nil  (raises on failure)
--
-- opts fields (all optional):
--   tap      string  Homebrew tap to add before installing (brew/cask only).
--   app      string  Absolute path to a .app bundle; if the path exists the
--                    tool is considered installed (cask only, mirrors install.sh:15).

local M = {}

--- Execute a shell command and return true if it exits 0.
local function shell_ok(cmd)
  local code = os.execute(cmd)
  -- os.execute returns true/false in Lua 5.2+, or an integer in Lua 5.1.
  if type(code) == "boolean" then
    return code
  end
  return code == 0
end

--- Execute a shell command, raising an error if it fails.
local function shell_assert(cmd, errmsg)
  if not shell_ok(cmd) then
    error(errmsg or ("command failed: " .. cmd))
  end
end

-------------------------------------------------------------------------------
-- brew (Homebrew formula)
-------------------------------------------------------------------------------

local brew = {}

--- Check whether a Homebrew formula is installed.
-- Queries `brew list --formula` and matches the exact package name.
-- For tap-qualified IDs (e.g. "hashicorp/tap/terraform"), both the full
-- form and the bare formula name (last path component) are tried because
-- `brew list` reports the bare name only.
-- @param id   string  Formula name or tap-qualified name (e.g. "gh" or
--                     "hashicorp/tap/terraform").
-- @param opts table   (unused for formulae; present for API symmetry).
function brew.is_installed(id, opts)
  opts = opts or {}
  -- Try the full id first.
  if shell_ok(string.format("brew list --formula 2>/dev/null | grep -qx %q", id)) then
    return true
  end
  -- For tap-qualified ids, also check the bare formula name.
  local bare = id:match("[^/]+$")
  if bare and bare ~= id then
    return shell_ok(string.format("brew list --formula 2>/dev/null | grep -qx %q", bare))
  end
  return false
end

--- Install a Homebrew formula.
-- Taps `opts.tap` first when provided.
-- @param id   string
-- @param opts table  { tap?: string }
function brew.install(id, opts)
  opts = opts or {}
  if opts.tap then
    shell_assert(
      string.format("brew tap %q", opts.tap),
      "brew tap failed: " .. opts.tap
    )
  end
  shell_assert(
    string.format("brew install %q", id),
    "brew install failed: " .. id
  )
end

M.brew = brew

-------------------------------------------------------------------------------
-- cask (Homebrew cask)
-------------------------------------------------------------------------------

local cask = {}

--- Check whether a Homebrew cask is installed.
-- If opts.app is provided and the path exists as a directory, returns true
-- immediately (mirrors install.sh:15 `[ -d "$app_path" ]` check).
-- Otherwise queries `brew list --cask`.
-- @param id   string
-- @param opts table  { app?: string }
function cask.is_installed(id, opts)
  opts = opts or {}
  -- .app existence check (pre-install shortcut)
  if opts.app and opts.app ~= "" then
    -- Use a stat call: if the path exists, treat as installed.
    if shell_ok(string.format('test -d %q', opts.app)) then
      return true
    end
  end
  return shell_ok(
    string.format("brew list --cask 2>/dev/null | grep -qx %q", id)
  )
end

--- Install a Homebrew cask.
-- Taps `opts.tap` first when provided.
-- @param id   string
-- @param opts table  { tap?: string, app?: string }
function cask.install(id, opts)
  opts = opts or {}
  if opts.tap then
    shell_assert(
      string.format("brew tap %q", opts.tap),
      "brew tap failed: " .. opts.tap
    )
  end
  shell_assert(
    string.format("brew install --cask %q", id),
    "brew install --cask failed: " .. id
  )
end

M.cask = cask

-------------------------------------------------------------------------------
-- choco (Chocolatey — Windows)
-------------------------------------------------------------------------------

local choco = {}

--- Check whether a Chocolatey package is installed.
-- Uses `choco list <id> --exact --limit-output` (Chocolatey v2 syntax).
-- The command exits 0 and prints "<id>|<version>" when the package is found.
-- @param id   string
-- @param opts table  (unused)
function choco.is_installed(id, opts)
  -- choco list exits 0 regardless; we check whether output is non-empty.
  -- Redirect output to a temp variable via a subshell check.
  local cmd = string.format(
    'choco list %q --exact --limit-output 2>nul | findstr /i %q >nul 2>&1',
    id, id
  )
  return shell_ok(cmd)
end

--- Install a Chocolatey package.
-- @param id   string
-- @param opts table  (unused)
function choco.install(id, opts)
  opts = opts or {}
  shell_assert(
    string.format("choco install %q -y", id),
    "choco install failed: " .. id
  )
end

M.choco = choco

-------------------------------------------------------------------------------
-- Dispatch helper
-------------------------------------------------------------------------------

--- Resolve a backend by name string.
-- @param name string  "brew" | "cask" | "choco"
-- @return table  The backend module.
function M.get(name)
  local b = M[name]
  if not b then
    error("Unknown backend: " .. tostring(name))
  end
  return b
end

return M
