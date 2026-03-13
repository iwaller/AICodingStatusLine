# Repository Guidelines

## Project Structure & Module Organization
This repository is intentionally small. [`statusline.sh`](/Users/nowcoder/Documents/MyCode/services/ai-coding-status-line/statusline.sh) is the macOS/Linux entrypoint, and [`statusline.ps1`](/Users/nowcoder/Documents/MyCode/services/ai-coding-status-line/statusline.ps1) provides the Windows implementation. Keep feature behavior aligned across both scripts. Tests live in [`tests/test_statusline.py`](/Users/nowcoder/Documents/MyCode/services/ai-coding-status-line/tests/test_statusline.py). User-facing documentation and setup instructions live in [`README.md`](/Users/nowcoder/Documents/MyCode/services/ai-coding-status-line/README.md). [`screenshot.png`](/Users/nowcoder/Documents/MyCode/services/ai-coding-status-line/screenshot.png) is the current visual reference for README updates.

## Build, Test, and Development Commands
There is no build pipeline; contributors edit the scripts directly.

- `python3 -m unittest tests/test_statusline.py`: run the full regression suite.
- `printf '%s' '{"cwd":"/tmp","model":{"display_name":"Opus 4.6"}}' | ./statusline.sh`: smoke-test the Bash entrypoint.
- `pwsh -NoProfile -File ./statusline.ps1 < sample.json`: smoke-test the PowerShell entrypoint with sample JSON input.

When changing layout, truncation, or theme logic, run the Python tests before opening a PR.

## Coding Style & Naming Conventions
Match the native style of each language instead of forcing one convention across the repo.

- Bash: use 4-space indentation, lowercase snake_case function names such as `format_tokens`, and keep environment variable names uppercase.
- PowerShell: use 4-space indentation and approved verb-style PascalCase function names such as `Format-Tokens` or `Build-GitSegment`.
- Python tests: follow `unittest` conventions with `test_*` methods and clear fixture helpers.

No formatter or linter is configured here, so keep edits small, readable, and consistent with nearby code.

## Testing Guidelines
Add or update tests in [`tests/test_statusline.py`](/Users/nowcoder/Documents/MyCode/services/ai-coding-status-line/tests/test_statusline.py) for every behavior change. Cover width budgeting, layout fallbacks, ANSI/theme output, cache/usage edge cases, and Bash/PowerShell parity when relevant. Name new tests by outcome, for example `test_unknown_theme_falls_back_to_default`.

## Commit & Pull Request Guidelines
Recent history uses short Conventional Commit subjects, often with emoji prefixes, for example `✨ feat: ...`, `📝 docs: ...`, and `fix: ...`. Follow that pattern and keep each commit focused on one logical change.

PRs should explain the user-visible effect, note which environments were tested (`bash`, `pwsh`, macOS/Linux/Windows if applicable), and include an updated screenshot when output formatting changes. Update [`README.md`](/Users/nowcoder/Documents/MyCode/services/ai-coding-status-line/README.md) whenever you add or change environment variables, layouts, or theme options.

<!-- chinese-language-config:start -->
## Language
Use **Chinese** for:
- Task execution results and error messages
- Confirmations and clarifications with the user
- Solution descriptions and to-do items
- Commit info for git
<!-- chinese-language-config:end -->
