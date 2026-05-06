# Charter Details

**Last Updated:** 2026-05-06

## Problem Statement

Game developers — particularly those working with Godot — frequently need to turn animation sources (rendered videos, captured sequences) into spritesheets with embedded grid metadata for AnimatedSprite2D. Existing toolchains require stitching together FFmpeg, ImageMagick, and GIMP by hand, with brittle, OS-specific scripts and inconsistent background removal. Ruby Spriter encapsulates that pipeline behind a single cross-platform CLI with sane defaults and high-quality processing options.

## Target Users

- Indie game developers (primary)
- Technical artists producing 2D sprite animations
- CI / build pipelines that need scripted sprite generation

## Success Criteria

- Single-command conversion from MP4 to ready-to-import PNG spritesheet
- Output works directly with Godot `HFrames` / `VFrames` from embedded metadata
- Same commands and flags produce equivalent output on Windows, Linux, macOS
- Zero runtime gem dependencies; only system tools
- Continued green RSpec suite on every release tag

## Non-Functional Requirements

- **Performance:** Pipelines must process typical sprite videos (≤ 30s, ≤ 1080p) in seconds, not minutes; downscaling quality is non-negotiable
- **Reliability:** Headless Linux (Xvfb + GIMP 3.x) must work without manual display configuration
- **Security:** All shell invocations quote paths via `PathHelper.quote_path` — no command injection through filenames
- **Portability:** No assumptions about shell beyond what `Open3.capture3` provides

## Stakeholders

- **Maintainer:** scooter-indie
