-- provision/configurators/capslock.lua
--
-- Remaps Caps Lock to Escape via the dedicated shell tool.
-- Delegates to tools/remap_capslock.sh --enable (kept as a shell tool because
-- it uses hidutil(1) which is macOS-only and simpler in bash).
--
-- Returns a module table with a run() function (one-shot configurator API).

local platform = require("provision.lib.platform")

local function shell_ok(cmd)
  local code = os.execute(cmd)
  if type(code) == "boolean" then return code end
  return code == 0
end

local function run()
  local df_root  = platform.dotfiles_root()
  local script   = df_root .. "/tools/remap_capslock.sh"
  local cmd      = string.format('bash %q --enable', script)

  if not shell_ok(cmd) then
    error("remap_capslock.sh --enable failed")
  end
end

return { run = run }
