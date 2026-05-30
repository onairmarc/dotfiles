-- provision/migrations/20251201_000000_import_legacy_migration_history.lua
--
-- Migration: import legacy shell-runner migration history into Lua state.
--
-- The old bash-based migration runner tracked completed migrations in a
-- flat text file (one migration name per line). This migration reads both
-- the public and private history files and imports each entry into the
-- Lua provisioner's state.migrations_run map so the Lua runner never
-- re-runs them.
--
-- Public entries  → state.migrations_run["<name>"] = "imported"
-- Private entries → state.migrations_run["private:<name>"] = "imported"
--
-- Both legacy files are left in place as audit trails; the Lua runner
-- ignores them going forward.
--
-- The migrations runner passes the live state table as the first argument
-- to up(); writing directly into it ensures the entries survive the
-- runner's own state_mod.save(s) call after this function returns.

return {
  description = "Import legacy bash migration history into Lua provisioner state",

  -- s: the live state table passed by migrations.run_pending (lib/migrations.lua).
  up = function(s)
    local home    = os.getenv("HOME") or os.getenv("USERPROFILE") or ""
    local df_root = os.getenv("DF_ROOT_DIRECTORY") or (home .. "/Documents/GitHub/dotfiles")

    -- Helper: read a history file and import entries with an optional prefix.
    local function import_history(path, prefix)
      local f = io.open(path, "r")
      if not f then
        return  -- file absent — nothing to import
      end

      for raw_line in f:lines() do
        -- Strip leading/trailing whitespace.
        local line = raw_line:match("^%s*(.-)%s*$")
        if line ~= "" then
          local key = (prefix or "") .. line
          -- Only set if not already recorded (preserve existing timestamps).
          if not s.migrations_run[key] then
            s.migrations_run[key] = "imported"
          end
        end
      end
      f:close()
    end

    -- Public dotfiles history.
    import_history(df_root .. "/migrations/.migration_history", nil)

    -- Private dotfiles history (optional — may not exist on all machines).
    local private_root = home .. "/Documents/GitHub/dotfiles-private"
    import_history(private_root .. "/.migrations/.migration_history", "private:")
  end,
}
