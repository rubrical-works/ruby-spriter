# Test Strategy

**Last Updated:** 2026-05-06

## Framework

**RSpec** — primary and only test framework.

## Layout

```
spec/
├─ spec_helper.rb
├─ ruby_spriter/          ← per-class unit specs
│   └─ utils/
├─ unit/                  ← additional focused unit specs
└─ integration/           ← integration-style specs
```

## Conventions

- External commands (`Open3.capture3`, `system`) are **mocked** at the boundary — tests never depend on FFmpeg / ImageMagick / GIMP being installed
- `DependencyChecker` is stubbed in upstream tests
- Temp directories use `Dir.mktmpdir` with explicit cleanup
- File fixtures kept minimal; prefer in-memory PNG byte strings or stubbed file paths

## Run Targets

| Command | Purpose |
|---------|---------|
| `rake spec` | Run full RSpec suite |
| `rake coverage` | RSpec + SimpleCov report |
| `rake rubocop` | Lint only |
| `rake test` | Lint + spec (CI-equivalent) |
| `rspec spec/path/file_spec.rb` | Single file |
| `rspec spec/path/file_spec.rb:42` | Single example by line |

## Coverage Posture

- 512+ examples currently — treat regressions as blockers
- New processing modes / flags require both happy-path and validation-error specs
- Background-removal heuristics get focused unit specs (see `spec/unit/`)

## What We Don't Test (yet)

- End-to-end GIMP execution (requires real GIMP 3.x installation; verified manually on release)
- Real video decoding through FFmpeg (mocked)
- Cross-platform path differences beyond what `Platform` abstracts
