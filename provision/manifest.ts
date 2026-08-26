// provision/manifest.ts
//
// Declarative list of tools, scripts, configurators, and migrations to run.
//
// Tool / script entries use per-platform sub-objects keyed by "mac" or "win":
//   { name: "gh", mac: { backend: "brew", id: "gh" },
//                 win: { backend: "choco", id: "gh" } }
// A missing platform key means the entry does not apply to that platform.
//
// Configurator entries carry an imported run() plus a "platforms" array.
// Migration entries are imported migration objects, ordered.
import * as capslock from "./configurators/capslock.ts";
import * as ghostty from "./configurators/ghostty.ts";
import * as iterm from "./configurators/iterm.ts";
import * as opencode from "./configurators/opencode.ts";
import * as stripeCompletion from "./configurators/stripe_completion.ts";
import type {BackendOpts} from "./lib/backend.ts";
import type {Migration} from "./lib/migrations.ts";
import type {ScriptEntry} from "./lib/scripts.ts";
import setupDfDataDirectory from "./migrations/20250830_124338_setup_df_data_directory.ts";
import moveSysCleanupMarker from "./migrations/20250830_124630_move_sys_cleanup_marker.ts";
import importLegacyMigrationHistory from "./migrations/20251201_000000_import_legacy_migration_history.ts";

export interface ConfiguratorEntry {
    name: string;
    run: () => void;
    platforms: string[];
}

export interface ToolPlatformEntry extends BackendOpts {
    backend: string;
    id: string;
}

export interface ToolEntry {
    name: string;
    mac?: ToolPlatformEntry;
    win?: ToolPlatformEntry;
}

export interface ScriptManifestEntry {
    name: string;
    mac?: ScriptEntry;
    win?: ScriptEntry;
}

export interface Manifest {
    tools: ToolEntry[];
    scripts: ScriptManifestEntry[];
    configurators: ConfiguratorEntry[];
    migrations: Migration[];
}

// Shared post-step for the Grok CLI installer: drop rc bak files and strip the
// `# >>> grok installer >>>` block from shell rc files. PATH/completions are
// owned by shell/92_grok.plugin.zsh, not the upstream installer.
const grokInstallPost = `sh -c '
df="\${DF_ROOT_DIRECTORY:-$HOME/Documents/GitHub/dotfiles}"
rm -f "$HOME"/.zshrc.bak.* "$HOME"/.bashrc.bak.* "$df"/.zshrc.bak.* "$df"/.bashrc.bak.*
strip_grok_block() {
  f="$1"
  [ -e "$f" ] || [ -L "$f" ] || return 0
  target="$f"
  if [ -L "$f" ]; then
    link=$(readlink "$f") || return 0
    case "$link" in
      /*) target="$link" ;;
      *) target="$(cd "$(dirname "$f")" && pwd)/$link" ;;
    esac
  fi
  [ -f "$target" ] || return 0
  grep -qs "grok installer" "$target" || return 0
  tmp="$target.tmp.$$"
  awk "
    /# >>> grok installer >>>/ { skip=1; next }
    /# <<< grok installer <<</ { skip=0; next }
    !skip { print }
  " "$target" > "$tmp" && mv "$tmp" "$target"
}
strip_grok_block "$HOME/.zshrc"
strip_grok_block "$HOME/.bashrc"
strip_grok_block "$df/.zshrc"
'`;

const manifest: Manifest = {
// -------------------------------------------------------------------------
// Tools
// Master list derived from install.sh:148-175 (mac) and install.ps1:102-116
// (win). install.sh is the superset; mac-only entries omit the "win" key.
// -------------------------------------------------------------------------
    tools: [
        // 1Password password manager (cask / choco)
        {
            name: "1password",
            mac: {backend: "cask", id: "1password", app: "/Applications/1Password.app"},
            win: {backend: "choco", id: "1password"},
        },

        // 1Password CLI (distributed as a cask on macOS)
        {
            name: "1password-cli",
            mac: {backend: "cask", id: "1password-cli"},
            win: {backend: "choco", id: "1password-cli"},
        },

        // Bash (mac-only — system bash is ancient; win uses Git Bash)
        {name: "bash", mac: {backend: "brew", id: "bash"}},

        // Chroma syntax highlighter (mac-only — used in CLI tools)
        {name: "chroma", mac: {backend: "brew", id: "chroma"}},

        // Google Chrome browser (different ids per platform)
        {
            name: "chrome",
            mac: {backend: "cask", id: "google-chrome", app: "/Applications/Google Chrome.app"},
            win: {backend: "choco", id: "googlechrome"},
        },

        // cliclick — keyboard/mouse automation (mac-only)
        {name: "cliclick", mac: {backend: "brew", id: "cliclick"}},

        // doctl — DigitalOcean CLI (mac-only — no Chocolatey package available)
        {name: "doctl", mac: {backend: "brew", id: "doctl"}},

        // JetBrains Mono font (mac-only cask)
        {name: "font-jetbrains-mono", mac: {backend: "cask", id: "font-jetbrains-mono"}},

        // GitHub CLI (mac-only — win users use choco gh if needed separately)
        {name: "gh", mac: {backend: "brew", id: "gh"}},

        // git-extras — extra git commands (mac-only — no Chocolatey package available)
        {name: "git-extras", mac: {backend: "brew", id: "git-extras"}},

        // git-filter-repo — history rewriting tool (mac-only)
        {name: "git-filter-repo", mac: {backend: "brew", id: "git-filter-repo"}},

        // Laravel Herd (mac-only cask)
        {name: "herd", mac: {backend: "cask", id: "herd", app: "/Applications/Herd.app"}},

        // htop — interactive process viewer (mac-only — no Chocolatey package available)
        {name: "htop", mac: {backend: "brew", id: "htop"}},

        // JetBrains Toolbox (cask / choco)
        {
            name: "jetbrains-toolbox",
            mac: {backend: "cask", id: "jetbrains-toolbox", app: "/Applications/JetBrains Toolbox.app"},
            win: {backend: "choco", id: "jetbrainstoolbox"},
        },

        // jq — JSON processor
        {
            name: "jq",
            mac: {backend: "brew", id: "jq"},
            win: {backend: "choco", id: "jq"},
        },

        // nano — text editor
        {
            name: "nano",
            mac: {backend: "brew", id: "nano"},
            win: {backend: "choco", id: "nano"},
        },

        // Pygments — syntax highlighter (Python, mac-only)
        {name: "pygments", mac: {backend: "brew", id: "pygments"}},

        // Raycast — launcher (mac-only cask)
        {name: "raycast", mac: {backend: "cask", id: "raycast", app: "/Applications/Raycast.app"}},

        // rsync — file synchronization
        {
            name: "rsync",
            mac: {backend: "brew", id: "rsync"},
            win: {backend: "choco", id: "rsync"},
        },

        // saml2aws — AWS SAML login
        {
            name: "saml2aws",
            mac: {backend: "brew", id: "saml2aws"},
            win: {backend: "choco", id: "saml2aws"},
        },

        // Shottr — screenshot tool (mac-only cask)
        {name: "shottr", mac: {backend: "cask", id: "shottr", app: "/Applications/Shottr.app"}},

        // Stripe CLI (mac-only — win users get it via other means)
        {name: "stripe-cli", mac: {backend: "brew", id: "stripe-cli"}},

        // Terraform via HashiCorp tap (mac brew tap; win choco)
        {
            name: "terraform",
            mac: {backend: "brew", id: "hashicorp/tap/terraform", tap: "hashicorp/tap"},
            win: {backend: "choco", id: "terraform"},
        },

        // tmux — terminal multiplexer (mac-only — no Chocolatey package available)
        {name: "tmux", mac: {backend: "brew", id: "tmux"}},

        // Trivy — vulnerability scanner (mac-only)
        {name: "trivy", mac: {backend: "brew", id: "trivy"}},

        // Ghostty terminal emulator (mac-only cask)
        {name: "ghostty", mac: {backend: "cask", id: "ghostty", app: "/Applications/Ghostty.app"}},

        // Zsh shell (mac-only — no Chocolatey package available; Windows uses bash)
        {name: "zsh", mac: {backend: "brew", id: "zsh"}},

        // antidote — zsh plugin manager (mac-only; win uses bash_loader.sh)
        {name: "antidote", mac: {backend: "brew", id: "antidote"}},

        // NOTE: zsh-autosuggestions and zsh-syntax-highlighting are intentionally
        // omitted. antidote clones them from zsh_plugins.txt; keeping brew copies
        // would leave unsourced duplicates.
    ],

// -------------------------------------------------------------------------
// Scripts
// Remote installers (curl|bash on mac, irm|iex PowerShell on win where needed).
// Scripts are NOT idempotency-tracked; they always re-run on each provision
// and rely on the upstream installer's own short-circuit logic.
//
// Bun itself is NOT listed here: it is the provisioner runtime and is
// installed by install.sh / install.ps1 before this manifest ever loads.
// -------------------------------------------------------------------------
    scripts: [
        // Oh My Zsh — non-interactive install (RUNZSH/CHSH/KEEP_ZSHRC flags prevent
        // shell change, default-shell modification, and .zshrc overwrite).
        // When $ZSH is set, the upstream installer errors if that directory already
        // exists — skip instead. Without $ZSH, it short-circuits cleanly if
        // ~/.oh-my-zsh exists.
        {
            name: "ohmyzsh",
            mac: {
                kind: "curl",
                url: "https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh",
                pipe_to: "RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh",
                skip_if_env_set: "ZSH",
            },
        },

        // OpenCode AI coding assistant (mac + win)
        {
            name: "opencode",
            mac: {kind: "curl", url: "https://opencode.ai/install", pipe_to: "bash"},
            win: {kind: "curl", url: "https://opencode.ai/install", pipe_to: "bash"},
        },

        // Syft SBOM / vulnerability scanner (mac-only)
        {
            name: "syft",
            mac: {
                kind: "curl",
                url: "https://get.anchore.io/syft",
                pipe_to: "sudo sh -s -- -b /usr/local/bin",
            },
        },

        // Grok CLI (xAI).
        // mac: curl install.sh | bash. SHELL is cleared so the installer does not
        // rewrite ~/.zshrc / ~/.bashrc (PATH/completions live in shell/92_grok.plugin.zsh).
        // post: strip any installer block that still got written, and remove bak files.
        // win: irm install.ps1 | iex (native PowerShell installer; manages User PATH itself).
        {
            name: "grok",
            mac: {
                kind: "curl",
                url: "https://x.ai/cli/install.sh",
                pipe_to: "bash",
                env: {SHELL: ""},
                post: grokInstallPost,
            },
            win: {kind: "powershell", url: "https://x.ai/cli/install.ps1"},
        },
    ],

// -------------------------------------------------------------------------
// Configurators
// One-shot, state-tracked via state.configurators_run.
// Re-apply by removing the key from ~/.df_data/state.json.
// -------------------------------------------------------------------------
    configurators: [
        {name: "iterm", run: iterm.run, platforms: ["mac"]},
        {name: "ghostty", run: ghostty.run, platforms: ["mac"]},
        {name: "capslock", run: capslock.run, platforms: ["mac"]},
        {name: "stripe_completion", run: stripeCompletion.run, platforms: ["mac", "win"]},
        {name: "opencode", run: opencode.run, platforms: ["mac", "win"]},
    ],

// -------------------------------------------------------------------------
// Migrations
// Ordered; each must be run exactly once. Tracked in state.migrations_run.
// -------------------------------------------------------------------------
    migrations: [
        setupDfDataDirectory,
        moveSysCleanupMarker,
        importLegacyMigrationHistory,
    ],
};

export default manifest;