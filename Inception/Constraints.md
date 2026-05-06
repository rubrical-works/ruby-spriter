# Constraints

**Last Updated:** 2026-05-06

## Technical Constraints

- Ruby `>= 2.7.0` — must remain compatible with this floor
- Zero runtime gem dependencies — stdlib + external tools only
- All external tools invoked via `Open3.capture3` for cross-platform safety
- All filesystem paths must pass through `Utils::PathHelper.quote_path` before reaching a shell
- GIMP 3.x only — 2.x is hard-rejected at dependency check time
- On Linux, all GIMP invocations must use `env -u DISPLAY`, `xvfb-run`, and `--no-interface` to guarantee headless operation

## Process Constraints

- IDPF-Agile framework, solo review mode
- All work performed on branches; merges to `main` go through PRs
- Commits reference issues with `Refs #N` until user explicitly says "done"

## Compatibility Constraints

- Output PNG must remain readable by Godot's importer with no extra processing
- Embedded metadata format `SPRITESHEET|columns=X|rows=Y|frames=Z|version=V` is a stability surface — changes require version bump

## Quality Constraints

- RSpec suite must remain green on each release tag
- RuboCop clean before merge
- New external command paths must be mocked (`Open3.capture3`) in tests
