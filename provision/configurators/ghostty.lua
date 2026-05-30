-- provision/configurators/ghostty.lua
--
-- Configures Ghostty terminal by symlinking the dotfiles config file.
-- Replicates install.sh:47-66 (configure_ghostty function).
--
-- Logic:
--   1. Create ~/.config/ghostty/ if missing.
--   2. If a real file (not a symlink) exists at ~/.config/ghostty/config,
--      rename it to config.bak.
--   3. If the symlink does not exist yet, create it pointing to
--      $DF_ROOT_DIRECTORY/ghostty/config.
--
-- Returns a module table with a run() function (one-shot configurator API).

local platform = require("provision.lib.platform")
local log      = require("provision.lib.log")

local function shell_ok(cmd)
  local code = os.execute(cmd)
  if type(code) == "boolean" then return code end
  return code == 0
end

local function run()
  local home        = os.getenv("HOME") or ""
  local df_root     = platform.dotfiles_root()
  local config_dir  = home .. "/.config/ghostty"
  local config_link = config_dir .. "/config"
  local config_src  = df_root .. "/ghostty/config"

  -- 1. Ensure config directory exists.
  os.execute(string.format('mkdir -p %q', config_dir))

  -- 2. If a real file exists (not a symlink), back it up.
  --    test -f is true for regular files; test -L is true for symlinks.
  --    We want: regular file exists AND is NOT a symlink → back up.
  if shell_ok(string.format('test -f %q && ! test -L %q', config_link, config_link)) then
    log.info("ghostty", "backing up existing config to config.bak")
    os.execute(string.format('mv %q %q', config_link, config_dir .. "/config.bak"))
  end

  -- 3. Create symlink if not already present.
  if shell_ok(string.format('test -L %q', config_link)) then
    log.info("ghostty", "config symlink already exists — skipping")
  else
    os.execute(string.format('ln -s %q %q', config_src, config_link))
    log.info("ghostty", "config symlinked")
  end
end

return { run = run }
