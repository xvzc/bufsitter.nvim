# Security

Never hardcode absolute paths containing usernames or system-specific directories.
This applies to all files including source code, configuration, and settings files.

```lua
-- incorrect
local path = "/Users/kazusa/personal/bufsitter.nvim/doc"

-- correct
local path = vim.fn.stdpath("data") .. "/bufsitter"
```

```json
// incorrect
{ "command": "cd /Users/kazusa/personal/bufsitter.nvim && make test" }

// correct
{ "command": "make test" }
```
