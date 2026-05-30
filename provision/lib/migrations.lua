-- provision/lib/migrations.lua
--
-- Ordered migration runner for the Lua provisioner.
-- Migrations are discovered from manifest.migrations (an ordered list of
-- module names). Each migration module must return:
--   { description = "...", up = function() ... end }
--
-- State key conventions:
--   Public migrations  → bare name (e.g. "20250830_124338_setup_df_data_directory")
--   Private migrations → recorded with a "private:" prefix, but this runner does
--                        not apply the prefix itself; that is handled by the
--                        legacy-history-import migration in sub-plan 03.
--
-- On failure, execution STOPS (unlike tools/scripts/configurators which continue).

local state_mod = require("provision.lib.state")
local log       = require("provision.lib.log")

local M = {}

--- Return an ISO 8601 UTC timestamp.
local function iso_timestamp()
  return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

--- Run all pending migrations listed in manifest.migrations.
-- Stops on the first failure.
-- @param s         table   The mutable state table (loaded by state.load()).
-- @param manifest  table   The full manifest table (uses manifest.migrations).
-- @return boolean, string  true on full success; false + error message on failure.
function M.run_pending(s, manifest)
  local migration_list = (manifest and manifest.migrations) or {}

  if #migration_list == 0 then
    log.info("migrations", "nothing to run")
    return true, nil
  end

  for _, name in ipairs(migration_list) do
    -- Check state (bare name is the key regardless of prefix convention).
    if state_mod.has_run(s, "migrations_run", name) then
      log.ok(name, "already run — skipping")
    else
      log.info(name, "running migration…")

      -- Require the migration module; module path = name (dots replace slashes).
      local ok, mod = pcall(require, name)
      if not ok then
        local msg = "failed to load migration module " .. name .. ": " .. tostring(mod)
        log.error(name, msg)
        return false, msg
      end

      if type(mod) ~= "table" or type(mod.up) ~= "function" then
        local msg = "migration module " .. name .. " must return { description, up() }"
        log.error(name, msg)
        return false, msg
      end

      -- Run the migration; pass the live state table so migrations that
      -- modify migrations_run directly (e.g. the legacy-history importer)
      -- can write into the same table the runner will stamp and save.
      -- Any error stops execution.
      local run_ok, run_err = pcall(mod.up, s)
      if not run_ok then
        local msg = "migration " .. name .. " failed: " .. tostring(run_err)
        log.error(name, msg)
        return false, msg
      end

      -- Stamp success.
      state_mod.mark_done(s, "migrations_run", name)
      state_mod.save(s)
      log.ok(name, "migration complete")
    end
  end

  return true, nil
end

return M
