PREFIX ?= /usr/local
BINARY  = whatdidido
BUILD   = .build/release/$(BINARY)

.PHONY: all build release install uninstall clean test debug

# ── Default ────────────────────────────────────────────────
all: build

# ── Debug build (fast iteration) ──────────────────────────
build:
	swift build

# ── Release build (optimised) ─────────────────────────────
release:
	swift build -c release

# ── Install to PREFIX/bin (default: /usr/local/bin) ───────
install: release
	install -d "$(PREFIX)/bin"
	install -m 755 "$(BUILD)" "$(PREFIX)/bin/$(BINARY)"
	@echo "✔ Installed to $(PREFIX)/bin/$(BINARY)"

# ── Uninstall ─────────────────────────────────────────────
uninstall:
	rm -f "$(PREFIX)/bin/$(BINARY)"
	@echo "✔ Removed $(PREFIX)/bin/$(BINARY)"

# ── Clean build artefacts ─────────────────────────────────
clean:
	swift package clean

# ── Run tests (add XCTest targets to Package.swift first) ─
test:
	swift test

debug:
	swift build
	./.build/debug/WhatDidIDo debug
