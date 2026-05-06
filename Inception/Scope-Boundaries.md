# Scope Boundaries

**Last Updated:** 2026-05-06

## In Scope

- MP4 → PNG spritesheet conversion with embedded grid metadata
- Image post-processing: scale (NoHalo / LoHalo / Cubic / Linear / None), unsharp mask, background removal
- Background removal variants: fuzzy contiguous, global color, edge sampling, inner sampling, ghost-edge cleanup, smoke detection, multi-threshold, cell cleanup
- Batch processing across MP4 directories (`--batch`), with optional consolidation
- Consolidation of multiple spritesheets (file list and directory modes)
- Frame extraction from existing spritesheets (`--extract`)
- Metadata addition to external spritesheets (`--add-meta`)
- Metadata verification (`--verify`)
- Maximum PNG compression (`--max-compress`) preserving metadata
- Cross-platform CLI behavior (Windows / Linux / macOS, including headless Linux)
- Godot AnimatedSprite2D-friendly output

## Out of Scope

- GIMP 2.x support (explicitly dropped)
- Input formats other than MP4
- Output formats other than PNG
- Runtime gem dependencies — must remain stdlib only
- Interactive GUI or web frontend
- Hosted / SaaS conversion service
- Real-time / streaming video processing
- Direct integration into game engines beyond Godot-friendly metadata

## Possibly In Scope (Future)

- Additional input formats (WebM, MOV) — would require dependency surface review
- GIMP-script presets exposed as CLI flags
- Animation timing metadata beyond grid info

## Decision Log

- **2026-05-06** — Initial scope drawn from existing codebase via `/charter` extraction. No expansions yet.
