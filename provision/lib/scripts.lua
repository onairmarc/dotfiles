-- provision/lib/scripts.lua
--
-- curl-pipe-bash (or similar) script runner for the Lua provisioner.
-- Scripts are NOT tracked in state.json and always re-run on each provision.
-- The expectation is that the target installer script is itself idempotent.
--
-- Supported entry kinds:
--   { kind = "curl", url = "https://...", pipe_to = "bash" }
--
-- Additional optional fields:
--   args     string   Extra arguments appended to pipe_to (e.g. "-- --no-modify-path")
--   env      table    Environment variable overrides applied to pipe_to (the installer),
--                     not to curl. Written as KEY=VALUE prefixes on the right side of
--                     the pipe so the installer process actually receives them.
--   post     string   Shell command run after the primary install succeeds (e.g. cleanup).

local M = {}

local function shell_failed(ok)
  if type(ok) == "boolean" then
    return not ok
  end
  return ok ~= 0
end

local function run_post(entry)
  if not entry.post or entry.post == "" then
    return
  end
  local ok = os.execute(entry.post)
  if shell_failed(ok) then
    error("script post-step failed: " .. entry.post)
  end
end

--- Run a script entry.
-- Raises an error if the command exits non-zero.
-- @param entry table  A manifest script entry.
function M.run(entry)
  assert(entry and type(entry) == "table", "scripts.run: entry must be a table")

  if entry.kind == "curl" then
    assert(entry.url,     "scripts.run: curl entry must have a url field")
    assert(entry.pipe_to, "scripts.run: curl entry must have a pipe_to field")

    -- Env must apply to pipe_to (the installer). Prefixing curl alone is a no-op for
    -- the script: `VAR=x curl | bash` only sets VAR on curl, not bash.
    local env_prefix = ""
    if entry.env and type(entry.env) == "table" then
      for k, v in pairs(entry.env) do
        env_prefix = env_prefix .. string.format("%s=%q ", k, v)
      end
    end

    -- Build optional trailing args
    local trailing = ""
    if entry.args and entry.args ~= "" then
      trailing = " " .. entry.args
    end

    local cmd = string.format(
      "curl -fsSL %q | %s%s%s",
      entry.url,
      env_prefix,
      entry.pipe_to,
      trailing
    )

    local ok = os.execute(cmd)
    if shell_failed(ok) then
      error("script failed (curl|" .. entry.pipe_to .. "): " .. entry.url)
    end

    run_post(entry)

  else
    error("scripts.run: unsupported kind: " .. tostring(entry.kind))
  end
end

return M
