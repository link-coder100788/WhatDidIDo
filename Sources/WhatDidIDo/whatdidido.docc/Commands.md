# Commands

A reference for every `whatdidido` command, grouped by what question they answer.

## Overview

Every command follows the same pattern:

```bash
whatdidido <command> [options] [--shell zsh] [--os macos]
```

The `--shell` and `--os` flags are available on every command but rarely needed — see <doc:ShellSupport> for details.

---

## Browsing History

### `recent` — What did I just do?

The default command. Shows your last N commands, numbered and formatted.
Session-break commands (`clear`, `exit`, `reset`, `logout`) are filtered out automatically.

```bash
whatdidido recent
whatdidido recent -c 30
```

| Flag | Default | Description |
|---|---|---|
| `-c, --count` | `20` | Number of commands to show |

Running bare `whatdidido` is identical to `whatdidido recent`.

---

### `top` — What do I type most?

Ranks your most-used base commands by frequency with a proportional ASCII bar chart.
Only the first token of each command is counted, so `git status` and `git push` both
contribute to the `git` tally.

```bash
whatdidido top
whatdidido top -c 20
```

| Flag | Default | Description |
|---|---|---|
| `-c, --count` | `10` | How many top commands to show |

---

### `dirs` — Where have I been?

Extracts all `cd` commands from your history, deduplicates them (keeping the most recent
occurrence of each path), and shows the result newest-last.

```bash
whatdidido dirs
whatdidido dirs -l 5
```

| Flag | Default | Description |
|---|---|---|
| `-l, --limit` | `10` | Number of directories to show |

---

### `summary` — What was I working on?

A de-duplicated digest of recent activity. Each unique base command appears once, in order,
making it ideal for standup notes or end-of-day recaps.

```bash
whatdidido summary
whatdidido summary --last 100
```

| Flag | Default | Description |
|---|---|---|
| `--last` | `50` | How many recent commands to consider |

When `summaryDate` is enabled in your config (the default), a header line with the current
date is printed above the results.

---

## Searching

### `search` — Did I already do this?

Searches your full history for a keyword or phrase. Matches are case-insensitive and
highlighted in the output.

```bash
whatdidido search "docker run"
whatdidido search kubectl
```

| Argument | Description |
|---|---|
| `query` | The term to search for |

---

### `for` — How do I use X again?

Pulls every command whose base token exactly matches `tool`. Great for recalling the
specific flags and patterns you've used before.

```bash
whatdidido for git
whatdidido for docker -l 30
whatdidido for kubectl
```

| Argument/Flag | Default | Description |
|---|---|---|
| `tool` | — | The tool name to filter by |
| `-l, --limit` | `20` | Max results to show |

---

### `check` — Have I run this before?

Returns a clear yes/no on whether a command exists in your history.
By default it matches the base command token; `--exact` requires the full string to match.

```bash
whatdidido check "make build"
whatdidido check "rm -rf dist" --exact
```

| Argument/Flag | Default | Description |
|---|---|---|
| `command` | — | The command to check for |
| `--exact` | `false` | Require a full string match |

> Note: The most recent history entry (typically the `whatdidido` invocation itself) is
> always excluded from the check.

---

### `after` — What did I do next?

Shows the commands that followed a match — useful for reconstructing multi-step workflows
you can only half-remember.

```bash
whatdidido after "git clone"
whatdidido after "brew install" -w 8
```

| Argument/Flag | Default | Description |
|---|---|---|
| `query` | — | The command or keyword to look up |
| `-w, --window` | `5` | How many subsequent commands to show |

---

## AI Commands (macOS 26+ only)

These commands use the on-device `SystemLanguageModel` from `FoundationModels` to generate
a plain-English explanation of your terminal activity. No data leaves your device.

### `ai summary`

Generates a 2–4 sentence summary of the output that `whatdidido summary` would produce.

```bash
whatdidido ai summary
whatdidido ai summary --last 100
```

### `ai recent`

Generates a 2–4 sentence summary of your most recent commands.

```bash
whatdidido ai recent
whatdidido ai recent --count 30
```

---

## Utility Commands

### `version`

Prints the currently installed version.

```bash
whatdidido version
# whatdidido 1.5.6
```

### `check-update`

Queries the GitHub Releases API and reports whether a newer version is available.
Times out after `checkUpdateTimeout` seconds (default 15).

```bash
whatdidido check-update
```

### `debug`

Prints the auto-detected environment — useful for diagnosing history file issues.

```bash
whatdidido debug
# shell:   zsh
# os:      MacOS
# history: /Users/you/.zsh_history
# color:   true
# locale:  en_US
```

### `completion`

Generates shell completion scripts for zsh, bash, or fish.

```bash
whatdidido completion zsh  >> ~/.zshrc
whatdidido completion bash >> ~/.bashrc
whatdidido completion fish >> ~/.config/fish/completions/whatdidido.fish
```

---

## Tips

**Pipe to grep for further filtering:**
```bash
whatdidido for git | grep "push"
```

**Save a standup summary to a file:**
```bash
whatdidido config set --color false
whatdidido summary > standup.txt
whatdidido config set --color true
```

**Reconstruct a forgotten workflow:**
```bash
whatdidido after "brew install" -w 10
```
