# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AICodingStatusLine is a custom status line for Claude Code that displays model info, git context, token usage, and rate limits. It is a fork of [daniel3303/ClaudeCodeStatusLine](https://github.com/daniel3303/ClaudeCodeStatusLine). The project consists of two parallel shell scripts (`statusline.sh` for Bash, `statusline.ps1` for PowerShell) that must stay feature-aligned.

## Commands

```bash
# Run full test suite
python3 -m unittest tests/test_statusline.py

# Run a single test
python3 -m unittest tests.test_statusline.StatusLineTests.test_wide_budget_keeps_all_segments

# Smoke-test Bash script
printf '%s' '{"cwd":"/tmp","model":{"display_name":"Opus 4.6"}}' | ./statusline.sh

# Smoke-test PowerShell script
pwsh -NoProfile -File ./statusline.ps1 < sample.json
```

There is no build pipeline, linter, or formatter. Scripts are edited directly.

## Architecture

Both scripts follow the same pipeline: **read JSON from stdin -> parse model/context/cwd data -> fetch usage from Anthropic API (with 60s cache at `/tmp/claude/statusline-usage-cache.json`) -> compose segments -> adaptive width truncation -> output ANSI-colored text**.

### Dual-Script Parity

`statusline.sh` (Bash) and `statusline.ps1` (PowerShell) implement identical logic. Changes to one must be mirrored in the other. The PowerShell script must remain ASCII-only (non-ASCII glyphs are built from code points like `[char]0x25CF` instead of source literals).

### Segment Composition

Segments are built independently (`build_model_segment`, `build_git_segment`, `build_ctx_segment`, `build_eff_segment`, `build_five_hour_segment`, `build_seven_day_segment`, `build_extra_segment`) then joined with `|` separators. Each segment produces both a `TEXT` (ANSI-colored) and `PLAIN` (uncolored) variant; `PLAIN` is used for width calculations.

### Width Budget System

When output exceeds `max_width`, segments collapse in a fixed priority order:
1. Drop `extra` segment
2. Drop 7-day reset time
3. Drop 5-hour reset time
4. Drop git diff stats
5. Drop 7-day segment entirely
6. Truncate git segment with `...` ellipsis

### Layouts and Configuration

- `CLAUDE_CODE_STATUSLINE_LAYOUT`: `compact` (default single-line) or `bars` (overview line + two progress-bar lines for 5h/7d)
- `CLAUDE_CODE_STATUSLINE_BAR_STYLE`: `ascii` (default), `dots`, `squares` -- only affects `bars` layout
- `CLAUDE_CODE_STATUSLINE_THEME`: `default` or `forest` -- changes ANSI color palette
- `CLAUDE_CODE_STATUSLINE_MAX_WIDTH`: force a specific width budget

## Coding Conventions

- **Bash**: 4-space indent, `snake_case` functions, `UPPERCASE` env vars
- **PowerShell**: 4-space indent, `Verb-Noun` PascalCase functions (e.g., `Format-Tokens`, `Build-GitSegment`)
- **Tests**: Python `unittest` with `test_*` methods; tests invoke the actual shell scripts via `subprocess`

## Testing

Tests in `tests/test_statusline.py` exercise both scripts by piping JSON stdin and checking stripped-ANSI output. They set up temporary git repos, write usage cache files, and validate width budgeting, layout modes, theme isolation, bar style glyphs, and Bash/PowerShell parity. Run the test suite before any PR that touches layout, truncation, or theme logic.

## Commit Style

Use short Conventional Commit subjects with emoji prefixes: `feat:`, `fix:`, `docs:`, etc.
