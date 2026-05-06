# Project Charter: ruby-spriter

**Status:** Draft
**Last Updated:** 2026-05-06
**Version:** 0.7.0.1

## Vision

Ruby Spriter is a cross-platform Ruby CLI that converts MP4 videos into high-quality PNG spritesheets with advanced GIMP-based image processing — purpose-built for game development workflows, especially Godot Engine.

## Current Focus

Stabilization on the v0.7.0.x line: GIMP 3.x enforcement, headless Linux (Xvfb) reliability, and modular documentation. Background-removal robustness (edge/inner sampling, ghost-edge cleanup, smoke detection) is the active quality area.

## Tech Stack

- **Language:** Ruby (>= 2.7.0), standard library only — no runtime gem dependencies
- **External tools:** FFmpeg / FFprobe (video), ImageMagick (compose, compress, sharpen), GIMP 3.x (scale, background removal), Xvfb (Linux headless)
- **Test:** RSpec, RuboCop, Rake (`rake spec`, `rake rubocop`, `rake test`, `rake coverage`)
- **Distribution:** RubyGems gem (`ruby_spriter`)
- **Platforms:** Windows, Linux, macOS

## In Scope

- Video → spritesheet conversion (MP4 → PNG with embedded grid metadata)
- Image processing pipeline: scale (5 interpolation methods), unsharp mask, background removal
- Background-removal subsystems: edge sampling, inner sampling, ghost-edge cleanup, smoke detection, multi-threshold processing, cell cleanup
- Batch processing of MP4 directories (with optional consolidation)
- Spritesheet consolidation (file list and directory modes)
- Frame extraction (`--extract`) and external metadata addition (`--add-meta`)
- Maximum-compression PNG output preserving metadata
- GIMP 3.x exclusive support (Flatpak + native packages)
- Cross-platform behavior parity (Windows / Linux / macOS)

## Out of Scope

- GIMP 2.x support
- Input formats other than MP4; output formats other than PNG
- Runtime gem dependencies
- GUI / interactive editor
- Hosted service or web frontend

## Key Entities

| Entity | Count | Location |
|--------|-------|----------|
| Library classes | 24 | `lib/ruby_spriter/` |
| RSpec test files | 24 | `spec/` |
| Processing modes | 5 | `lib/ruby_spriter/processor.rb` |
| External tool integrations | 4 | FFmpeg, ImageMagick, GIMP, Xvfb |

## Goals

- Reliable, repeatable spritesheet generation suitable for direct Godot AnimatedSprite2D import
- Cross-platform parity, including headless Linux
- High test coverage (currently 512+ specs) with no runtime dependencies

## References

- `README.md` — user-facing overview
- `CLAUDE.md` — architecture and component guide
- `Inception/` — detailed charter artifacts
