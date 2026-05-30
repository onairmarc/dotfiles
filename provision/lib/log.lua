-- provision/lib/log.lua
--
-- Colored logging helpers for the Lua provisioner.
-- Colors are emitted only when stdout is a TTY and $NO_COLOR is unset.

local M = {}

-- ANSI escape codes
local RESET  = "\27[0m"
local BOLD   = "\27[1m"
local RED    = "\27[31m"
local GREEN  = "\27[32m"
local YELLOW = "\27[33m"
local CYAN   = "\27[36m"
local WHITE  = "\27[37m"

-- Detect whether colored output should be used.
-- io.stdout:isatty() is available in Lua 5.3+.
local function use_color()
  if os.getenv("NO_COLOR") then
    return false
  end
  -- isatty may not exist on all platforms; fall back to no-color if unavailable.
  local ok, result = pcall(function() return io.stdout:isatty() end)
  return ok and result == true
end

local COLOR_ENABLED = use_color()

local function colorize(color, text)
  if COLOR_ENABLED then
    return color .. text .. RESET
  end
  return text
end

--- Print a step header (bold cyan) — used for section separators.
-- @param label string
function M.step(label)
  io.write(colorize(BOLD .. CYAN, "==> " .. label) .. "\n")
end

--- Print an informational message (white).
-- @param label string  Short tag shown before the message.
-- @param msg   string  (optional) Detail message.
function M.info(label, msg)
  local line = msg and (label .. ": " .. msg) or label
  io.write(colorize(WHITE, "    " .. line) .. "\n")
end

--- Print a success / already-done message (green).
-- @param label string
-- @param msg   string  (optional)
function M.ok(label, msg)
  local line = msg and (label .. ": " .. msg) or label
  io.write(colorize(GREEN, "  ✓ " .. line) .. "\n")
end

--- Print a warning message (yellow) to stderr.
-- @param label string
-- @param msg   string  (optional)
function M.warn(label, msg)
  local line = msg and (label .. ": " .. msg) or label
  io.stderr:write(colorize(YELLOW, "  ! " .. line) .. "\n")
end

--- Print an error message (red) to stderr.
-- @param label string
-- @param msg   string  (optional)
function M.error(label, msg)
  local line = msg and (label .. ": " .. msg) or label
  io.stderr:write(colorize(RED, "  ✗ " .. line) .. "\n")
end

return M
