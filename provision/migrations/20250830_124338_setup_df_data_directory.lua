-- provision/migrations/20250830_124338_setup_df_data_directory.lua
--
-- Migration: setup df_data directory
-- Created: Sat Aug 30 12:43:38 CDT 2025
-- Ported from: migrations/20250830_124338_setup_df_data_directory.sh
--
-- Creates ~/.df_data/, ~/.df_data/tokens/, and ~/.df_data/.sys_cleanup_marker.
-- Idempotent: mkdir -p and touch are no-ops when targets already exist.

return {
  description = "Create the ~/.df_data directory structure",

  up = function()
    local platform = require("provision.lib.platform")
    local data_dir = platform.data_dir()

    platform.mkdir_p(data_dir)
    platform.mkdir_p(data_dir .. "/tokens")

    -- Create the cleanup marker file if absent. Lua-native to avoid shell
    -- portability concerns (no `touch` on cmd.exe).
    local marker = data_dir .. "/.sys_cleanup_marker"
    local f = io.open(marker, "a")
    if f then f:close() end
  end,
}
