# How LSP works?
- The previous section, I said "LSP is not a program", so how can it run? Yeh, the implementation is created by developers, programmers and even by us. But before we create it, we must understand it.
# Server-Client Model
- LSP use JSON-RPC, you can read [the JSON-RPC specification](https://www.jsonrpc.org/specification), JSON is useful in networking, structured, easy to use. 
- How a client (editor) request to server (LSP)? TODO more clarification
- A request from a client (editor) can be:
```json
Content-Length: ...\r\n
\r\n
{
	"jsonrpc": "2.0",
	"id": 1,
	"method": "textDocument/completion",
	"params": {
		...
	}
}
```
