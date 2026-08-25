// provision/configurators/capslock.ts
//
// Remaps Caps Lock to Escape via the dedicated shell tool.
// Delegates to tools/remap_capslock.sh --enable (kept as a shell tool because
// it uses hidutil(1) which is macOS-only and simpler in bash).

import * as platform from "../lib/platform.ts";
import { runAssert } from "../lib/shell.ts";

export function run(): void {
  const script = platform.dotfilesRoot() + "/tools/remap_capslock.sh";
  runAssert(["bash", script, "--enable"], "remap_capslock.sh --enable failed");
}
