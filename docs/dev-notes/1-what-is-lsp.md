# What is LSP?
- Language Server Protocol (LSP) is just a standardized protocol created by Microsoft. It defines a set of rules for client (editors) communicate with server (implemented LSP program).
- The first time I heard about "LSP", I imagined it was a program created by Microsoft, so I try to explain clearly to you that it is not a program, just a set of rules and we can call it a specification. LSP of every programming languages follows exactly what is defined in [Microsoft specification](https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#languageServerProtocol), so editors like VS Code, Neovim can easily rely on it to request methods in LSP.
- A LSP can provide features:
  - Code completion.
  - Go to definition, go to references.
  - Documentation on hover.
  - ...
