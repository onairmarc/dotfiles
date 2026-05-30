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
    local home = os.getenv("HOME") or os.getenv("USERPROFILE") or ""
    local data_dir = home .. "/.df_data"

    -- Create the base data directory and tokens subdir.
    os.execute(string.format('mkdir -p %q', data_dir))
    os.execute(string.format('mkdir -p %q', data_dir .. "/tokens"))

    -- Create the cleanup marker file if absent.
    os.execute(string.format('touch %q', data_dir .. "/.sys_cleanup_marker"))
  end,
}
