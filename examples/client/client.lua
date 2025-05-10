-- Get server executable path from command-line argument
local exec_path = arg[1] and arg[1]:gsub("%s+", "") or ""
if exec_path == "" then
	print("Error: No executable path provided. Usage: lua client.lua <path>")
	os.exit(1)
end

local request_body = [[
{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "initialize",
    "params": {
        "capabilities": {}
    }
}
]]
local message = string.format("Content-Length: %d\r\n\r\n%s", #request_body, request_body)

-- Escape quotes for shell command
local escaped_message = message:gsub('"', '\\"')

-- Construct shell command to pipe request to server and capture stdout
local command = string.format('echo -e "%s" | %s', escaped_message, exec_path)

-- Open pipe to read server's stdout
local pipe = io.popen(command, "r")
if not pipe then
	print("Error: Failed to spawn server")
	os.exit(1)
end

-- Read response
local response = pipe:read("*all")
pipe:close()

-- Parse response
local headers, body = response:match("^(.-)\r\n\r\n(.*)$")
if not headers or not body then
	print("Error: Invalid response format")
	os.exit(1)
end
local content_length = headers:match("Content%-Length: (%d+)")
if not content_length or #body < tonumber(content_length) then
	print("Error: Incomplete response")
	os.exit(1)
end

-- Print response
print("Server response: " .. body)

-- Exit
os.exit(0)
