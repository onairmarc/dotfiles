-- provision/configurators/stripe_completion.lua
--
-- Generates and installs the Stripe CLI shell completion script.
-- Replicates install.sh:196-204.
--
-- Steps:
--   1. Run `stripe completion` in $HOME to generate stripe-completion.zsh.
--   2. Ensure $HOME/.stripe/ directory exists (removing any non-directory at
--      that path first, mirroring the original `[ ! -f "$HOME/.stripe" ]` guard).
--   3. Copy the completion file to $ZSH/completions/stripe-completion.sh
--      (Oh My Zsh completions directory).
--   4. Move the completion file into $HOME/.stripe/.
--
-- Returns a module table with a run() function (one-shot configurator API).

local function shell_ok(cmd)
  local code = os.execute(cmd)
  if type(code) == "boolean" then return code end
  return code == 0
end

local function run()
  local home = os.getenv("HOME") or ""
  local zsh  = os.getenv("ZSH")  or (home .. "/.oh-my-zsh")

  -- Generate the completion file in $HOME so we have a predictable path.
  local completion_file = home .. "/stripe-completion.zsh"
  local gen_cmd = string.format(
    'cd %q && stripe completion 2>/dev/null',
    home
  )
  os.execute(gen_cmd)

  -- Ensure $HOME/.stripe is a directory.
  -- If it exists as a regular file, remove it first (mirrors install.sh logic).
  local stripe_dir = home .. "/.stripe"
  if shell_ok(string.format('test -f %q && ! test -L %q', stripe_dir, stripe_dir)) then
    os.execute(string.format('rm -f %q', stripe_dir))
  end
  os.execute(string.format('mkdir -p %q', stripe_dir))

  -- Copy to Oh My Zsh completions directory (best-effort).
  local zsh_completions = zsh .. "/completions"
  os.execute(string.format('mkdir -p %q', zsh_completions))
  if shell_ok(string.format('test -f %q', completion_file)) then
    os.execute(string.format('cp %q %q', completion_file, zsh_completions .. "/stripe-completion.sh"))
    -- Move the original into ~/.stripe/.
    os.execute(string.format('mv %q %q', completion_file, stripe_dir .. "/stripe-completion.zsh"))
  end
end

return { run = run }
