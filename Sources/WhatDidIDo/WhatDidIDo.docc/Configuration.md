# Configuration

Customise `whatdidido` to fit your shell setup.

## Overview

Config is stored at `~/.whatdidido/config.plist` as an Apple property list and is created
automatically on first use. All settings are optional — sensible defaults apply out of the box
and you never need to touch the config file directly.

Use the `config` subcommands to read and write settings:

```bash
whatdidido config set   # Set one or more values
whatdidido config show  # Print the current config
whatdidido config reset # Restore all defaults
whatdidido config open-config # Open the config folder in Finder / file manager
```

---

## Available Settings

### `--path`

A custom path to your history file. Overrides the shell's default location for every
command. Useful when you maintain multiple shell profiles or store your history on an
external volume.

```bash
whatdidido config set --path ~/.config/my_custom_history
```

To go back to the auto-detected default:

```bash
whatdidido config reset
```

**Default:** auto-detected from your shell and OS — see <doc:ShellSupport> for the exact paths.

---

### `--color`

Enables or disables ANSI colour codes in all output. Disable this when piping output to
files or other tools that don't understand escape codes.

```bash
whatdidido config set --color false
whatdidido summary > standup.txt
whatdidido config set --color true
```

**Default:** `true`

---

### `--updateWarn`

Controls whether a one-line update reminder is printed when a newer release is detected.
The check runs at most once per 24 hours, in the background, after `whatdidido recent`.

```bash
whatdidido config set --updateWarn false
```

**Default:** `true`

---

### `--locale`

The locale used to format the date header in `whatdidido summary`. Accepts any BCP 47
locale identifier.

```bash
whatdidido config set --locale en_GB
whatdidido config set --locale fr_FR
```

**Default:** your system locale (`Locale.current`)

---

### `--summaryDate`

Controls whether `whatdidido summary` prints a date header above its output.

```bash
whatdidido config set --summaryDate false
```

**Default:** `true`

---

## Viewing Your Current Config

```bash
whatdidido config show
# color:          true
# path:           (default — auto-detected from shell)
# updateReminders: true
# locale:         en_US
# summaryDate:    true
```

---

## Resetting to Defaults

```bash
whatdidido config reset
# ✔ Configuration reset to defaults.
```

This clears `customPath`, re-enables color, resets the locale to `Locale.current`,
and re-enables `summaryDate`. It does **not** reset `checkUpdateTimeout`, which can
only be changed by editing the plist directly.

---

## Config File Location

The plist lives at:

```
~/.whatdidido/config.plist
```

You can open the containing folder directly:

```bash
whatdidido config open-config
```

On macOS this opens Finder. On Linux it uses `xdg-open`. The file is standard plist
format and can be edited by hand or inspected with `plutil` on macOS if needed —
though the `config set` commands are the intended interface.
