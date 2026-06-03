-- provision/migrations/20250830_124630_move_sys_cleanup_marker.lua
--
-- Migration: move sys_cleanup_marker
-- Created: Sat Aug 30 12:46:30 CDT 2025
-- Ported from: migrations/20250830_124630_move_sys_cleanup_marker.sh
--
-- Copies $HOME/.df_sys_cleanup_marker to $HOME/.df_data/.sys_cleanup_marker
-- (if the source exists), then removes the old location.
-- Implements safe_copy semantics: no-op when source is absent; backs up
-- destination before overwriting (skipped here since .sys_cleanup_marker is
-- a plain marker file with no meaningful content to preserve).

return {
  description = "Move .df_sys_cleanup_marker from $HOME into $HOME/.df_data/",

  up = function()
    local platform = require("provision.lib.platform")
    local home = platform.home()
    local old  = home .. "/.df_sys_cleanup_marker"
    local new  = home .. "/.df_data/.sys_cleanup_marker"

    local src = io.open(old, "rb")
    if not src then return end
    local content = src:read("*a") or ""
    src:close()

    platform.mkdir_p(home .. "/.df_data")

    local dst = io.open(new, "wb")
    if dst then
      dst:write(content)
      dst:close()
    end

    os.remove(old)
  end,
}
