//! First at all, we need to install the lsp server (tiny_zls)
//! ```zig
//! zig build
//! ```
//! Then
//! ```ts
//! node example/client/client.ts
//! ```
import { spawn } from "node:child_process";
import * as readline from "readline";

const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
});

interface RequestMessage {
    jsonrpc: string;
    id: number;
    method: string;
    params?: any;
}

rl.question("LSP exec path (e.g., ./zig-out/bin/tiny_zls): ", (answer: string) => {
    // Trim whitespace and validate path
    const execPath = answer.trim();
    if (!execPath) {
        console.error("Error: No path provided");
        rl.close();
        return;
    }

    // Spawn the LSP server
    const tiny_zls = spawn(execPath, {
        stdio: ["pipe", "pipe", "inherit"], // stdin: pipe, stdout: pipe, stderr: inherit
    });

    // Set encoding for stdout to receive strings
    tiny_zls.stdout.setEncoding("utf8");

    // Handle stdout data (server response)
    let responseBuffer = "";
    tiny_zls.stdout.on("data", (data: string) => {
        responseBuffer += data;
        const parts = responseBuffer.split("\r\n\r\n");
        if (parts.length > 1) {
            const headers = parts[0];
            const body = parts[1];
            const contentLengthMatch = headers.match(/Content-Length: (\d+)/);
            if (contentLengthMatch) {
                const contentLength = parseInt(contentLengthMatch[1], 10);
                if (body.length >= contentLength) {
                    try {
                        const json = JSON.parse(body);
                        console.log("Server response:", JSON.stringify(json, null, 2));
                        // Kill the server after receiving response
                        tiny_zls.kill();
                    } catch (err) {
                        console.error("Error parsing response:", err);
                    }
                }
            }
        }
    });

    // Handle stderr
    tiny_zls.stderr?.on("data", (data: string) => {
        console.error("Server error:", data);
    });

    // Handle process exit
    tiny_zls.on("close", (code: number | null) => {
        console.log(`Server exited with code ${code}`);
        rl.close();
    });

    // Handle spawn error
    tiny_zls.on("error", (err: Error) => {
        console.error("Failed to spawn server:", err.message);
        rl.close();
    });

    // Send initialize request
    const request: RequestMessage = {
        jsonrpc: "2.0",
        id: 1,
        method: "initialize",
        params: {
            capabilities: {},
        },
    };
    const requestBody = JSON.stringify(request);
    const message = `Content-Length: ${requestBody.length}\r\n\r\n${requestBody}`;
    tiny_zls.stdin.write(message);
    tiny_zls.stdin.end(); // Close stdin after sending (optional, depending on server)

    console.log("Sent request:", message);
});
