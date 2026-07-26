-- provision/lib/scripts.lua
--
-- Script runner for the Lua provisioner.
-- Scripts are NOT tracked in state.json and always re-run on each provision.
-- The expectation is that the target installer script is itself idempotent.
--
-- Supported entry kinds:
--   { kind = "curl", url = "https://...", pipe_to = "bash" }
--     → curl -fsSL <url> | <env> <pipe_to> <args>
--   { kind = "powershell", url = "https://..." }
--     → powershell -NoProfile -ExecutionPolicy Bypass -Command "irm '<url>' | iex"
--       (Windows PowerShell installers, e.g. irm https://x.ai/cli/install.ps1 | iex)
--
-- Additional optional fields:
--   args              string   Extra arguments appended to pipe_to (curl kind only)
--   env               table    Environment variable overrides for the installer process.
--                              curl: KEY=VALUE prefixes on the right side of the pipe.
--                              powershell: $env:KEY='VALUE'; prefixes inside -Command.
--   post              string   Shell command run after the primary install succeeds (e.g. cleanup).
--   skip_if_env_set   string   Skip this script when the named env var is set and non-empty
--                              (e.g. "ZSH" — OMZ installer errors if $ZSH points at an
--                              existing install directory).

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

--- Return whether a script entry should be skipped, plus a short reason.
-- @param entry table  A platform-specific script sub-table (e.g. entry.mac).
-- @return boolean, string|nil
function M.should_skip(entry)
  if not entry or type(entry) ~= "table" then
    return false
  end
  local name = entry.skip_if_env_set
  if name and name ~= "" then
    local v = os.getenv(name)
    if v and v ~= "" then
      return true, string.format("$%s is set (%s)", name, v)
    end
  end
  return false
end

--- Run a script entry.
-- Raises an error if the command exits non-zero.
-- Callers should check should_skip() first if they want a clean skip path.
-- @param entry table  A manifest script entry.
function M.run(entry)
  assert(entry and type(entry) == "table", "scripts.run: entry must be a table")

  local skip, reason = M.should_skip(entry)
  if skip then
    return "skipped", reason
  end

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

  elseif entry.kind == "powershell" then
    assert(entry.url, "scripts.run: powershell entry must have a url field")

    -- Build $env:KEY='VALUE'; prefixes so the installer process receives them.
    -- Escape single quotes in values for PowerShell single-quoted strings.
    local env_prefix = ""
    if entry.env and type(entry.env) == "table" then
      for k, v in pairs(entry.env) do
        local val = tostring(v):gsub("'", "''")
        env_prefix = env_prefix .. string.format("$env:%s='%s'; ", k, val)
      end
    end

    -- irm | iex is the canonical Windows install pattern (e.g. xAI Grok CLI).
    -- URL is single-quoted inside -Command; escape any embedded single quotes.
    local url = entry.url:gsub("'", "''")
    local cmd = string.format(
      "powershell -NoProfile -ExecutionPolicy Bypass -Command \"%sirm '%s' | iex\"",
      env_prefix,
      url
    )

    local ok = os.execute(cmd)
    if shell_failed(ok) then
      error("script failed (powershell irm|iex): " .. entry.url)
    end

    run_post(entry)

  else
    error("scripts.run: unsupported kind: " .. tostring(entry.kind))
  end
end

return M
