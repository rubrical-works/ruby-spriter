# Tech Stack

**Last Updated:** 2026-05-06

## Language & Runtime

- **Ruby** — `>= 2.7.0` (declared in `ruby_spriter.gemspec`)
- Standard library only at runtime (no gem dependencies)

## External Tools (runtime)

| Tool | Purpose | Version Constraint |
|------|---------|-------------------|
| FFmpeg / FFprobe | Video decoding, frame extraction, tile filter | Any modern build |
| ImageMagick | Composition, compression, unsharp mask, metadata | v7+ recommended |
| GIMP | Scaling (5 interpolation methods), background removal | **3.x required** (2.x unsupported) |
| Xvfb | Headless display for GIMP on Linux | Linux only |

Dependency presence is verified at runtime by `DependencyChecker` (`lib/ruby_spriter/dependency_checker.rb`).

## Development Tooling

- **RSpec** — primary test framework (`spec/`)
- **RuboCop** — linter
- **Rake** — task runner (`rake spec`, `rake rubocop`, `rake test`, `rake coverage`, `rake check_deps`)
- **SimpleCov** — coverage (via `rake coverage`)

## Distribution

- **RubyGems** — gem name `ruby_spriter`
- Single executable: `bin/ruby_spriter`

## Supported Platforms

- Windows (uses `.bat` wrappers for GIMP)
- Linux (native GIMP 3.x or Flatpak `org.gimp.GIMP`, headless via Xvfb)
- macOS

## File Formats

- **Input:** MP4 (video), PNG (image)
- **Output:** PNG (with embedded `SPRITESHEET|columns=X|rows=Y|frames=Z|version=V` comment)

## Detected Ecosystems (auto)

| Ecosystem | Dependency Files | Registry |
|-----------|-----------------|----------|
| Ruby | Gemfile, ruby_spriter.gemspec | rubygems |
