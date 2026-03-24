# Extending whatdidido

Add your own commands and custom history logic by building on top of the existing codebase.

## Overview

`whatdidido` is designed to be cloned and extended. The core types — ``HistoryParser``,
``HistoryFormatter``, and ``HistoryBarFormatter`` — are all available to your own code.
Adding a new command is a two-step process:

1. Write a new `ParsableCommand` struct
2. Register it in `WhatDidIDo.swift`

No other changes are needed.

---

## Adding a Basic Command

Create a new Swift file anywhere under `Sources/whatdidido/`. A command is just a struct
that conforms to `ParsableCommand`:

```swift
import Foundation
import ArgumentParser

struct MyCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "mine",
        abstract: "My custom command."
    )

    @OptionGroup var shellOpts: ShellOptions

    func run() throws {
        let history = try loadHistory(options: shellOpts)
        let parser = HistoryParser(history: history)

        // Use any built-in method
        let lines = parser.recent(10)
        printLines(lines)
    }
}
```

Then register it in `WhatDidIDo.swift` by adding it to the `subcommands` array:

```swift
static let configuration = CommandConfiguration(
    subcommands: [
        Recent.self,
        // ... existing commands ...
        MyCommand.self,  // ← add here
    ]
)
```

Your command is now available as `whatdidido mine`.

---

## Using the Queryable API

The methods in `HistoryParser+Queryable.swift` return plain strings with no ANSI colour
codes, giving you full control over filtering and formatting.

### Filtering recent commands

```swift
// Only show commands that touch the filesystem
let lines = parser.recentFiltered(count: 30) { line in
    ["cp", "mv", "rm", "mkdir", "touch"].contains(
        line.components(separatedBy: .whitespaces).first ?? ""
    )
}
```

### Filtering the frequency table

```swift
// Exclude navigation noise from the top chart
let lines = parser.topFiltered(count: 10) { base in
    !["cd", "ls", "pwd", "clear"].contains(base)
}
```

### Custom search formatting

```swift
// Format matches as "L<lineNumber>: <command>"
let lines = parser.searchTransformed(query: "docker") { lineNumber, command in
    "L\(lineNumber): \(command)"
}
```

### Filtered summary

```swift
// Only include git commands in the summary
let lines = parser.summaryFiltered(last: 100) { line in
    line.hasPrefix("git")
}
```

### Fully custom logic

```swift
// Access the raw History directly
let lines = parser.query(where: { history in
    history.content
        .filter { $0.contains("sudo") }
        .suffix(5)
        .map { "⚠️  \($0)" }
})
```

---

## Formatting Output

Use ``HistoryFormatter`` and ``HistoryBarFormatter`` to apply consistent formatting
to the plain strings returned by the queryable API.

> Warning: Always check `WhatDidIDoConfig.shared.shouldColor` before passing a color
> value. Passing a color when the user has disabled color output will produce raw
> ANSI escape codes in their terminal.

### Numbered output

```swift
let formatter = HistoryFormatter()
let lines = parser.recentFiltered(count: 20) { !$0.hasPrefix("cd") }

let shouldColor = WhatDidIDoConfig.shared.shouldColor
let formatted = formatter.format(lines, mode: .numbered(
    offset: 0,
    color: shouldColor ? .dim : nil
))
printLines(formatted)
```

### Prefixed output

```swift
let formatted = formatter.format(lines, mode: .prefixed(
    symbol: "▸",
    color: shouldColor ? .cyan : nil
))
```

### Bar chart output

```swift
// Build BarEntry values from your own frequency data
var freq: [String: Int] = [:]
for cmd in history.content {
    let base = cmd.components(separatedBy: .whitespaces).first ?? cmd
    freq[base, default: 0] += 1
}

let sorted = freq.sorted { $0.value > $1.value }.prefix(10)
let maxCount = sorted.first?.value ?? 1

let entries = sorted.enumerated().map { i, pair in
    BarEntry(rank: i + 1, command: pair.key, count: pair.value, max: maxCount)
}

var barFormatter = HistoryBarFormatter()
barFormatter.barWidth = 30
barFormatter.barCharacter = "█"
barFormatter.barColor = shouldColor ? .green : nil

printLines(barFormatter.format(entries))
```

---

## Putting It Together

Here is a complete example — a command that shows the top filesystem-touching commands,
excluding navigation noise, with a custom bar chart:

```swift
import Foundation
import ArgumentParser

struct TopFS: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "top-fs",
        abstract: "Show most-used filesystem commands."
    )

    @OptionGroup var shellOpts: ShellOptions

    @Option(name: .shortAndLong, help: "How many commands to show.")
    var count: Int = 10

    func run() throws {
        let history = try loadHistory(options: shellOpts)
        let parser = HistoryParser(history: history)
        let shouldColor = WhatDidIDoConfig.shared.shouldColor

        let fsCommands: Set<String> = ["cp", "mv", "rm", "mkdir", "touch", "chmod", "chown"]

        let lines = parser.topFiltered(count: count) { base in
            fsCommands.contains(base)
        }

        // topFiltered returns "<rank>  <command> (<n>x)" strings —
        // prefix them with a custom symbol using HistoryFormatter
        let formatter = HistoryFormatter()
        let formatted = formatter.format(lines, mode: .prefixed(
            symbol: "▸",
            color: shouldColor ? .green : nil
        ))

        if formatted.isEmpty {
            print("No filesystem commands found in history.")
        } else {
            printLines(formatted)
        }
    }
}
```

Register it in `WhatDidIDo.swift` and run it with:

```bash
whatdidido top-fs
whatdidido top-fs -c 5
```

---

## Tips

**Reuse `ShellOptions`** — always include `@OptionGroup var shellOpts: ShellOptions` in
your command so users get `--shell` and `--os` overrides for free.

**Use `loadHistory(options:)`** — this handles config loading, shell resolution, and
error messaging consistently with the built-in commands.

**Use `printLines(_:)`** — keeps output consistent and avoids `print` call-sites
scattered through your command logic.

**Plain strings by default** — the queryable API returns unformatted strings
intentionally. Apply ``HistoryFormatter`` only when you're ready to print, so the
data stays reusable in between.
