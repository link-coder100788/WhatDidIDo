# Getting Started

Install `whatdidido` and have it running in under a minute.

## Overview

`whatdidido` is distributed as a prebuilt binary via Homebrew, or you can build it from source using Swift Package Manager or Make. Once installed, no configuration is required — shell and OS are detected automatically.

## Requirements

- **Swift 6.2 or later** (source builds only)
- **macOS 10.15+** or a recent Linux distribution
- One of: zsh, bash, fish, or PowerShell

## Installation

### Homebrew (recommended)

The fastest path on macOS or Linux:

```bash
brew tap link-coder100788/whatdidido
brew install whatdidido
```

Or in a single command:

```bash
brew install link-coder100788/whatdidido/whatdidido
```

### Make

Clone the repository and build from source:

```bash
git clone https://github.com/link-coder100788/WhatDidIDo
cd WhatDidIDo
make install
```

To install to a custom prefix (e.g. `~/.local/bin`):

```bash
make install PREFIX=~/.local
```

### Swift Package Manager (manual)

```bash
swift build -c release
cp .build/release/whatdidido /usr/local/bin/whatdidido
```

## Verifying Your Installation

Run the `version` command to confirm the binary is on your `PATH`:

```bash
whatdidido version
# whatdidido 1.5.6
```

Then run `debug` to confirm your shell and history file were detected correctly:

```bash
whatdidido debug
# shell:   zsh
# os:      MacOS
# history: /Users/you/.zsh_history
# color:   true
```

If the history path looks wrong, see <doc:Configuration> for how to set a custom path.

## Your First Commands

Running `whatdidido` with no arguments is the same as `whatdidido recent` — it shows your last 20 commands:

```bash
whatdidido
```

From there, try:

```bash
whatdidido top           # See your most-used commands
whatdidido summary       # A digest for standup notes
whatdidido for docker    # Every docker command you've run
```

For the full list of commands and their options, see <doc:Commands>.

## Updating

```bash
brew update
brew upgrade whatdidido
```

## Uninstalling

```bash
# Homebrew
brew uninstall whatdidido
brew untap link-coder100788/whatdidido

# Make
make uninstall
```
