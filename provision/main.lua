-- provision/main.lua
--
-- Entrypoint for the Lua provisioner.
--
-- Usage:
--   lua provision/main.lua <platform> [mode-flag]
--
--   platform : mac | windows | win
--   mode-flag: --tools-only | --scripts-only | --configurators-only | --migrate
--              (default: run tools, scripts, configurators, then migrations)
--
-- Exit codes:
--   0  all steps succeeded (or nothing to do)
--   1  one or more steps failed
--   2  bad arguments / unsupported platform

-- ---------------------------------------------------------------------------
-- Resolve the directory that contains main.lua so all require paths are
-- anchored to the repo root regardless of the caller's cwd.
-- ---------------------------------------------------------------------------

-- arg[0] is the path to this script (e.g. "provision/main.lua").
-- Strip the filename to get the parent directory ("provision").
local script_dir = (arg[0] or "provision/main.lua"):match("^(.*)/[^/]+$") or "."

-- Extend package.path so modules are discoverable as "provision.lib.foo".
-- We derive the repo root as the parent of script_dir.
local repo_root = script_dir:match("^(.*)/[^/]+$") or "."
package.path = repo_root .. "/provision/?.lua;"
            .. repo_root .. "/provision/?/init.lua;"
            .. package.path

-- ---------------------------------------------------------------------------
-- Require library modules (after package.path is set)
-- ---------------------------------------------------------------------------

local platform   = require("provision.lib.platform")
local log        = require("provision.lib.log")
local state_mod  = require("provision.lib.state")
local backend    = require("provision.lib.backend")
local scripts    = require("provision.lib.scripts")
local migrations = require("provision.lib.migrations")

-- ---------------------------------------------------------------------------
-- Parse arguments
-- ---------------------------------------------------------------------------

local platform_arg = arg[1]
local mode_arg     = arg[2]  -- optional mode flag

-- Initialize and validate platform (exits on invalid input).
platform.init(platform_arg)

-- Parse mode flag.
local RUN_TOOLS         = true
local RUN_SCRIPTS       = true
local RUN_CONFIGURATORS = true
local RUN_MIGRATIONS    = true

if mode_arg then
  RUN_TOOLS         = (mode_arg == "--tools-only")
  RUN_SCRIPTS       = (mode_arg == "--scripts-only")
  RUN_CONFIGURATORS = (mode_arg == "--configurators-only")
  RUN_MIGRATIONS    = (mode_arg == "--migrate")

  if mode_arg ~= "--tools-only"
  and mode_arg ~= "--scripts-only"
  and mode_arg ~= "--configurators-only"
  and mode_arg ~= "--migrate" then
    io.stderr:write("[main] ERROR: unknown mode flag: " .. mode_arg .. "\n")
    io.stderr:write("       Valid flags: --tools-only | --scripts-only | --configurators-only | --migrate\n")
    os.exit(2)
  end
end

-- ---------------------------------------------------------------------------
-- Load manifest and state
-- ---------------------------------------------------------------------------

local manifest = require("provision.manifest")
local state    = state_mod.load()

-- ---------------------------------------------------------------------------
-- Failure accumulator
-- ---------------------------------------------------------------------------

local failures = {}

local function record_failure(name, msg)
  log.error(name, msg)
  table.insert(failures, { name = name, msg = msg })
end

-- ---------------------------------------------------------------------------
-- Counters for the summary table
-- ---------------------------------------------------------------------------

local counts = {
  tools_installed = 0,
  tools_skipped   = 0,
  tools_failed    = 0,
  scripts_run     = 0,
  scripts_failed  = 0,
  configs_run     = 0,
  configs_skipped = 0,
  configs_failed  = 0,
  migrations_run  = 0,
  migrations_skip = 0,
  migrations_fail = 0,
}

-- ---------------------------------------------------------------------------
-- Tools
-- ---------------------------------------------------------------------------

if RUN_TOOLS then
  log.step("Installing tools")

  local tools = manifest.tools or {}
  for _, entry in ipairs(tools) do
    if platform.matches(entry) then
      local id = entry.id
      local b  = backend.get(entry.backend)
      local opts = {
        tap = entry.tap,
        app = entry.app,
      }

      local installed_ok, check_err = pcall(b.is_installed, id, opts)
      if not installed_ok then
        record_failure(id, "is_installed check error: " .. tostring(check_err))
        counts.tools_failed = counts.tools_failed + 1
      elseif check_err then
        -- is_installed returned true (check_err holds the return value here
        -- because pcall returns ok, val)
        -- NOTE: pcall(f, ...) returns true, <return values>; so "check_err"
        -- is actually the boolean returned by is_installed.
        log.ok(id, "already installed — skipping")
        counts.tools_skipped = counts.tools_skipped + 1
        state_mod.mark_done(state, "tools_installed", id)
      else
        log.info(id, "installing…")
        local install_ok, install_err = pcall(b.install, id, opts)
        if not install_ok then
          record_failure(id, "install failed: " .. tostring(install_err))
          counts.tools_failed = counts.tools_failed + 1
        else
          log.ok(id, "installed")
          counts.tools_installed = counts.tools_installed + 1
          state_mod.mark_done(state, "tools_installed", id)
        end
      end
    end
  end

  state_mod.save(state)
end

-- ---------------------------------------------------------------------------
-- Scripts
-- ---------------------------------------------------------------------------

if RUN_SCRIPTS then
  log.step("Running scripts")

  local script_list = manifest.scripts or {}
  for _, entry in ipairs(script_list) do
    if platform.matches(entry) then
      local label = entry.url or entry.kind or "unknown"
      log.info(label, "running…")
      local ok, err = pcall(scripts.run, entry)
      if not ok then
        record_failure(label, tostring(err))
        counts.scripts_failed = counts.scripts_failed + 1
      else
        log.ok(label, "done")
        counts.scripts_run = counts.scripts_run + 1
      end
    end
  end
end

-- ---------------------------------------------------------------------------
-- Configurators
-- ---------------------------------------------------------------------------

if RUN_CONFIGURATORS then
  log.step("Running configurators")

  local configurator_list = manifest.configurators or {}
  for _, entry in ipairs(configurator_list) do
    if platform.matches(entry) then
      local name = entry.name or entry.module or "unknown"

      if state_mod.has_run(state, "configurators_run", name) then
        log.ok(name, "already configured — skipping")
        counts.configs_skipped = counts.configs_skipped + 1
      else
        log.info(name, "configuring…")
        local mod_ok, mod = pcall(require, entry.module)
        if not mod_ok then
          record_failure(name, "failed to load configurator: " .. tostring(mod))
          counts.configs_failed = counts.configs_failed + 1
        else
          local run_ok, run_err
          if type(mod) == "function" then
            run_ok, run_err = pcall(mod)
          elseif type(mod) == "table" and type(mod.run) == "function" then
            run_ok, run_err = pcall(mod.run)
          else
            run_ok, run_err = false, "configurator module must return a function or { run() }"
          end

          if not run_ok then
            record_failure(name, tostring(run_err))
            counts.configs_failed = counts.configs_failed + 1
          else
            state_mod.mark_done(state, "configurators_run", name)
            state_mod.save(state)
            log.ok(name, "configured")
            counts.configs_run = counts.configs_run + 1
          end
        end
      end
    end
  end
end

-- ---------------------------------------------------------------------------
-- Migrations
-- ---------------------------------------------------------------------------

if RUN_MIGRATIONS then
  log.step("Running migrations")

  local mig_ok, mig_err = migrations.run_pending(state, manifest)
  if not mig_ok then
    record_failure("migrations", mig_err or "migration run failed")
    counts.migrations_fail = 1
  end

  -- Save state after migrations (run_pending already saves on each success;
  -- this is a belt-and-suspenders final save).
  state_mod.save(state)
end

-- ---------------------------------------------------------------------------
-- Summary
-- ---------------------------------------------------------------------------

io.write("\n")
log.step("Summary")
io.write(string.format(
  "  Tools      : %d installed, %d skipped, %d failed\n",
  counts.tools_installed, counts.tools_skipped, counts.tools_failed
))
io.write(string.format(
  "  Scripts    : %d run, %d failed\n",
  counts.scripts_run, counts.scripts_failed
))
io.write(string.format(
  "  Configurators: %d run, %d skipped, %d failed\n",
  counts.configs_run, counts.configs_skipped, counts.configs_failed
))
io.write(string.format(
  "  Migrations : %d run, %d skipped, %d failed\n",
  counts.migrations_run, counts.migrations_skip, counts.migrations_fail
))

if #failures > 0 then
  io.write("\n")
  log.warn("failures", tostring(#failures) .. " failure(s) during this run:")
  for i, f in ipairs(failures) do
    io.stderr:write(string.format("    [%d] %s: %s\n", i, f.name, f.msg))
  end
  os.exit(1)
end

os.exit(0)
