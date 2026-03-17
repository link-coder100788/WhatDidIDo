import Foundation
import ArgumentParser

func autoDetectOS() -> String {
#if os(macOS)
	return "macos"
#elseif os(Linux)
	return "linux"
#else
	return "windows"
#endif
}

func loadHistory(options: ShellOptions) throws -> History {
	WhatDidIDoConfigCore().load()
	let shell = try options.resolvedShell()
	let os = try options.resolvedOS()
	guard let history = HistoryReader().readHistory(os: os, shell: shell) else {
		throw ValidationError("Could not read history file. Check your shell/OS or set a custom path with `whatdidido config set --path`.")
	}
	return history
}

func printLines(_ lines: [String]) {
	lines.forEach { print($0) }
}
