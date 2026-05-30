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
    local home   = os.getenv("HOME") or os.getenv("USERPROFILE") or ""
    local old    = home .. "/.df_sys_cleanup_marker"
    local new    = home .. "/.df_data/.sys_cleanup_marker"

    -- Only act if the old marker exists.
    local f = io.open(old, "r")
    if f then
      f:close()

      -- Ensure the destination directory exists.
      os.execute(string.format('mkdir -p %q', home .. "/.df_data"))

      -- Copy the marker to its new home (safe_copy semantics: cp -r).
      os.execute(string.format('cp -r %q %q', old, new))

      -- Remove the old location.
      os.execute(string.format('rm -f %q', old))
    end
  end,
}
