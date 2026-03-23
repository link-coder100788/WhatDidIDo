# Shell Support

How `whatdidido` detects your shell and finds your history file.

## Overview

`whatdidido` supports four shells across macOS, Linux, and Windows. In the vast majority
of cases everything is detected automatically — you just run the command and it works.
This article explains how detection works and what to do when it doesn't.

---

## Supported Shells and Platforms

| Shell | macOS | Linux | Windows |
|---|---|---|---|
| zsh | ✔ | ✔ | — |
| bash | ✔ | ✔ | — |
| fish | ✔ | ✔ | — |
| PowerShell | — | ✔ | ✔ |

---

## Auto-Detection

**Shell** is detected by inspecting the `$SHELL` environment variable. The value is
checked for the substrings `zsh`, `bash`, and `fish` in that order. If none match,
`zsh` is used as the fallback.

**OS** is determined at compile time using Swift's `#if os(...)` directives, so it
always reflects the platform the binary was built for.

Run `whatdidido debug` to see what was detected:

```bash
whatdidido debug
# shell:   zsh
# os:      MacOS
# history: /Users/you/.zsh_history
# color:   true
# locale:  en_US
```

---

## Default History File Paths

| Shell | macOS | Linux | Windows |
|---|---|---|---|
| zsh | `~/.zsh_history` | `~/.zsh_history` | — |
| bash | `~/.bash_history` | `~/.bash_history` | — |
| fish | `~/.local/share/fish/fish_history` | `~/.local/share/fish/fish_history` | — |
| PowerShell (macOS) | `~/Library/Application Support/PowerShell/PSReadLine/ConsoleHost_history.txt` | — | — |
| PowerShell (Linux) | — | `~/.local/share/powershell/PSReadLine/ConsoleHost_history.txt` | — |
| PowerShell (Windows) | — | — | `~/AppData/Roaming/Microsoft/Windows/PowerShell/PSReadLine/ConsoleHost_history.txt` |

---

## Overriding Shell or OS

Every command accepts `--shell` and `--os` flags:

```bash
whatdidido recent --shell bash
whatdidido top --os linux
```

Accepted values:

- `--shell`: `zsh`, `bash`, `fish`, `powershell`
- `--os`: `macos` (or `mac`), `linux`, `windows`

These are useful when you want to inspect a history file from a different shell — for
example, reading your bash history while running inside zsh.

---

## Using a Custom History File

If your history file lives in a non-standard location, set a custom path in your config:

```bash
whatdidido config set --path /Volumes/external/.zsh_history
```

This overrides the default path for all commands. To go back to the auto-detected path:

```bash
whatdidido config reset
```

---

## History File Encoding

History files are read as UTF-8. If UTF-8 decoding fails (common with older zsh history
files that contain non-UTF-8 byte sequences), `whatdidido` automatically retries with
ISO Latin-1 as a fallback — so mixed-encoding files are handled gracefully without any
configuration needed.

---

## Shell-Specific Notes

### zsh

zsh extended history format stores a timestamp and elapsed time alongside each command:

```
: 1714000000:0;git push origin main
```

`whatdidido` strips the metadata prefix automatically, so you only see the command itself.

### fish

Fish stores history as YAML with `cmd:` and `when:` entries interleaved:

```yaml
- cmd: git status
  when: 1714000000
- cmd: swift build
  when: 1714000001
```

Only `cmd:` lines are extracted; `when:` lines are discarded.

### bash

Plain one-command-per-line format with no metadata — no special handling needed.

### PowerShell

Plain one-command-per-line format, same as bash. The history file location varies by
platform — see the table above.
