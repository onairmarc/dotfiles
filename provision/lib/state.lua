-- provision/lib/state.lua
--
-- Idempotency state management for the Lua provisioner.
-- Loads and saves ~/.df_data/state.json using the vendored rxi/json.lua.
--
-- State schema (schema_version 1):
-- {
--   "schema_version": 1,
--   "tools_installed":   { "gh": true, ... },
--   "configurators_run": { "iterm": "2026-05-29T10:00:00Z" },
--   "migrations_run":    { "20250830_124338_setup_df_data_directory": "2026-05-29T..." }
-- }
--
-- Source-of-truth rules:
--   tools        — state is an optimization; live backend is always queried.
--   configurators — state IS the source of truth (one-shot, timestamp-only).
--   migrations   — state IS the source of truth.
--   scripts      — not tracked; always re-run.

local json    = require("provision.lib.vendor.json")
local platform = require("provision.lib.platform")

local M = {}

local SCHEMA_VERSION = 1

--- Build a blank state table with the correct schema.
local function blank_state()
  return {
    schema_version   = SCHEMA_VERSION,
    tools_installed  = {},
    configurators_run = {},
    migrations_run   = {},
  }
end

--- Return the full path to state.json.
local function state_path()
  return platform.data_dir() .. "/state.json"
end

--- Ensure the data directory exists.
local function ensure_data_dir()
  local dir = platform.data_dir()
  -- mkdir -p is portable enough for our supported platforms.
  os.execute('mkdir -p "' .. dir .. '"')
end

--- Load state from disk.
-- Creates the data directory and an empty state.json if they do not exist.
-- @return table  The mutable state table.
function M.load()
  ensure_data_dir()

  local path = state_path()
  local f = io.open(path, "r")
  if not f then
    -- First run: write the blank state immediately so it exists on disk.
    local initial = blank_state()
    M.save(initial)
    return initial
  end

  local content = f:read("*a")
  f:close()

  if not content or content == "" then
    local initial = blank_state()
    M.save(initial)
    return initial
  end

  local ok, decoded = pcall(json.decode, content)
  if not ok or type(decoded) ~= "table" then
    io.stderr:write("[state] WARNING: state.json is corrupt — resetting to blank state\n")
    local initial = blank_state()
    M.save(initial)
    return initial
  end

  -- Migrate missing keys (forward-compat for older files).
  decoded.schema_version   = decoded.schema_version   or SCHEMA_VERSION
  decoded.tools_installed  = decoded.tools_installed  or {}
  decoded.configurators_run = decoded.configurators_run or {}
  decoded.migrations_run   = decoded.migrations_run   or {}

  return decoded
end

--- Persist state to disk (pretty-printed JSON).
-- @param s table  The state table returned by load().
function M.save(s)
  ensure_data_dir()
  local path = state_path()
  local encoded = json.encode(s)

  local f, err = io.open(path, "w")
  if not f then
    error("[state] Cannot write state.json: " .. (err or "unknown error"))
  end
  f:write(encoded)
  f:close()
end

--- Return an ISO 8601 UTC-like timestamp string for the current moment.
-- Lua's os.date with "!%Y-%m-%dT%H:%M:%SZ" produces UTC if the C runtime
-- supports it (it does on macOS and Linux; on Windows it may be local time).
local function iso_timestamp()
  return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

--- Mark a category entry as done in state.
-- @param s        table   The state table.
-- @param category string  "tools_installed" | "configurators_run" | "migrations_run"
-- @param name     string  The key (tool id, configurator name, migration name).
function M.mark_done(s, category, name)
  local cat = s[category]
  assert(cat, "Unknown state category: " .. tostring(category))
  if category == "tools_installed" then
    cat[name] = true
  else
    -- configurators_run and migrations_run store an ISO timestamp.
    cat[name] = iso_timestamp()
  end
end

--- Check whether a category entry has already been run.
-- @param s        table
-- @param category string
-- @param name     string
-- @return boolean
function M.has_run(s, category, name)
  local cat = s[category]
  assert(cat, "Unknown state category: " .. tostring(category))
  return cat[name] ~= nil
end

return M
