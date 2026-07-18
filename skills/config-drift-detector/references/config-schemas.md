# Config Schemas

Reference schemas for all config files managed by the config-drift-detector skill.

## config.json (Claude Desktop)

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Claude Desktop Config",
  "type": "object",
  "required": ["mcpServers", "permissions"],
  "properties": {
    "mcpServers": {
      "type": "object",
      "description": "Map of MCP server configurations",
      "patternProperties": {
        "^[a-zA-Z0-9_-]+$": {
          "type": "object",
          "required": ["command", "args"],
          "properties": {
            "command": {
              "type": "string",
              "minLength": 1,
              "description": "Path or command name to launch the MCP server"
            },
            "args": {
              "type": "array",
              "items": { "type": "string" },
              "description": "Arguments passed to the command"
            },
            "env": {
              "type": "object",
              "description": "Environment variables for the server process",
              "patternProperties": {
                "^[A-Z_][A-Z0-9_]*$": { "type": "string" }
              }
            },
            "cwd": {
              "type": "string",
              "description": "Working directory for the server process"
            }
          },
          "additionalProperties": false
        }
      }
    },
    "permissions": {
      "type": "object",
      "description": "Permission grants and restrictions",
      "patternProperties": {
        "^[a-z][a-z0-9.]*$": {
          "type": "string",
          "enum": ["allow", "deny", "ask"]
        }
      }
    },
    "theme": {
      "type": "string",
      "enum": ["dark", "light", "system"],
      "default": "system"
    },
    "autoUpdate": {
      "type": "boolean",
      "default": true
    },
    "contextWindow": {
      "type": "number",
      "minimum": 1000,
      "default": 200000
    },
    "debug": {
      "type": "boolean",
      "default": false
    },
    "logLevel": {
      "type": "string",
      "enum": ["error", "warn", "info", "debug", "trace"]
    }
  },
  "additionalProperties": false
}
```

## claude_desktop_config.json

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Claude Desktop Config (Legacy)",
  "type": "object",
  "required": ["mcpServers"],
  "properties": {
    "mcpServers": {
      "type": "object",
      "patternProperties": {
        "^[a-zA-Z0-9_-]+$": {
          "type": "object",
          "required": ["command"],
          "properties": {
            "command": {
              "type": "string",
              "minLength": 1
            },
            "args": {
              "type": "array",
              "items": { "type": "string" },
              "default": []
            },
            "env": {
              "type": "object"
            }
          }
        }
      }
    },
    "permissions": {
      "type": "object"
    }
  },
  "additionalProperties": true
}
```

## window-state.json

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Window State",
  "type": "object",
  "properties": {
    "x": {
      "type": "number",
      "minimum": 0,
      "maximum": 7680,
      "description": "Window X position in pixels"
    },
    "y": {
      "type": "number",
      "minimum": 0,
      "maximum": 4320,
      "description": "Window Y position in pixels"
    },
    "width": {
      "type": "number",
      "minimum": 400,
      "maximum": 3840,
      "description": "Window width in pixels"
    },
    "height": {
      "type": "number",
      "minimum": 300,
      "maximum": 2160,
      "description": "Window height in pixels"
    },
    "maximized": {
      "type": "boolean",
      "default": false
    },
    "minimized": {
      "type": "boolean",
      "default": false
    },
    "fullscreen": {
      "type": "boolean",
      "default": false
    },
    "panelWidth": {
      "type": "number",
      "minimum": 50,
      "maximum": 800,
      "description": "Side panel width in pixels"
    },
    "panelVisible": {
      "type": "boolean",
      "default": true
    },
    "theme": {
      "type": "string",
      "enum": ["dark", "light", "system"]
    }
  },
  "additionalProperties": true
}
```

## bridge-state.json

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Bridge State",
  "type": "object",
  "required": ["sessionId", "connectedAt", "status"],
  "properties": {
    "sessionId": {
      "type": "string",
      "minLength": 1,
      "description": "Unique session identifier"
    },
    "connectedAt": {
      "type": "string",
      "format": "date-time",
      "description": "ISO 8601 timestamp of connection"
    },
    "status": {
      "type": "string",
      "enum": ["connected", "disconnected", "error"],
      "description": "Current bridge connection status"
    },
    "lastActivity": {
      "type": "string",
      "format": "date-time"
    },
    "errorCount": {
      "type": "integer",
      "minimum": 0,
      "default": 0
    },
    "lastError": {
      "type": "string",
      "description": "Last error message if status is error"
    },
    "retryCount": {
      "type": "integer",
      "minimum": 0,
      "default": 0
    }
  },
  "additionalProperties": false
}
```

## git-worktrees.json

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Git Worktrees",
  "type": "object",
  "required": ["worktrees"],
  "properties": {
    "worktrees": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["path", "branch"],
        "properties": {
          "path": {
            "type": "string",
            "minLength": 1,
            "description": "Absolute path to the worktree directory"
          },
          "branch": {
            "type": "string",
            "minLength": 1,
            "description": "Git branch name for this worktree"
          },
          "head": {
            "type": "string",
            "description": "Git commit SHA at last sync"
          },
          "createdAt": {
            "type": "string",
            "format": "date-time"
          },
          "lastActive": {
            "type": "string",
            "format": "date-time"
          }
        }
      },
      "uniqueItems": true
    },
    "activeWorktree": {
      "type": "string",
      "description": "Path of the currently active worktree (must exist in worktrees[].path)"
    },
    "defaultBranch": {
      "type": "string",
      "default": "main"
    }
  },
  "additionalProperties": false
}
```

## extensions-installations.json

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Extension Installations",
  "type": "object",
  "required": ["extensions"],
  "properties": {
    "extensions": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["id", "version", "enabled"],
        "properties": {
          "id": {
            "type": "string",
            "minLength": 1,
            "pattern": "^[a-z][a-z0-9.-]*$",
            "description": "Unique extension identifier"
          },
          "version": {
            "type": "string",
            "pattern": "^\\d+\\.\\d+\\.\\d+$",
            "description": "Semantic version string"
          },
          "enabled": {
            "type": "boolean",
            "default": true
          },
          "config": {
            "type": "object",
            "description": "Extension-specific configuration overrides"
          },
          "installedAt": {
            "type": "string",
            "format": "date-time"
          },
          "updatedAt": {
            "type": "string",
            "format": "date-time"
          }
        }
      },
      "uniqueItems": true
    },
    "lastChecked": {
      "type": "string",
      "format": "date-time",
      "description": "Last time extension registry was queried"
    }
  },
  "additionalProperties": false
}
```
