-- provision/manifest.lua
--
-- Declarative list of tools, scripts, configurators, and migrations to run.
-- Populated by sub-plan 03-populate-manifest-and-configurators.md.
--
-- Each entry supports a `platforms` array ({"mac"}, {"windows"}, {"mac","windows"}).
-- Omitting `platforms` means the entry applies to all platforms.

return {
  -- tools = {
  --   { id = "gh", backend = "brew", platforms = {"mac"} },
  --   { id = "git", backend = "choco", platforms = {"windows"} },
  -- },

  tools = {},

  -- scripts = {
  --   { kind = "curl", url = "https://...", pipe_to = "bash", platforms = {"mac"} },
  -- },

  scripts = {},

  -- configurators = {
  --   { name = "iterm", module = "provision.configurators.iterm", platforms = {"mac"} },
  -- },

  configurators = {},

  -- migrations = {
  --   "20250830_124338_setup_df_data_directory",
  -- },

  migrations = {},
}
