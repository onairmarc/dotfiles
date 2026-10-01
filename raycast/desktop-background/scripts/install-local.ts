const development = Bun.spawn([process.execPath, "run", "dev", "--", "--non-interactive"], {
    cwd: import.meta.dir + "/..",
    stdout: "pipe",
    stderr: "pipe",
});

let built = false;
const stdout = new TextDecoder();
const stderr = new TextDecoder();
const timeout = setTimeout(() => {
    development.kill("SIGINT");
}, 30_000);

async function waitForInitialBuild(stream: ReadableStream<Uint8Array>): Promise<void> {
    for await (const chunk of stream) {
        const text = stdout.decode(chunk, {stream: true});
        process.stdout.write(text);

        if (text.includes("built extension successfully")) {
            built = true;
            development.kill("SIGINT");
            return;
        }
    }
}

await Promise.all([
    waitForInitialBuild(development.stdout),
    (async () => {
        for await (const chunk of development.stderr) {
            process.stderr.write(stderr.decode(chunk, {stream: true}));
        }
    })(),
]);

clearTimeout(timeout);

await development.exited;

if (!built) {
    throw new Error("Raycast did not register the local desktop-background extension");
}
