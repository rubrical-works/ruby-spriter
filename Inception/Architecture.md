# Architecture

**Last Updated:** 2026-05-06

See `CLAUDE.md` for the canonical architecture reference. This document summarizes the structure for charter purposes.

## Component Map

```
bin/ruby_spriter
        │
        ▼
   CLI (cli.rb)
        │
        ▼
   Processor (processor.rb)  ── orchestrates all 7 modes
        │
        ├─ VideoProcessor      (FFmpeg tile filter)
        ├─ GimpProcessor       (Python-fu scripts, GIMP 3.x)
        ├─ Consolidator        (ImageMagick -append)
        ├─ BatchProcessor      (multi-MP4 runner)
        ├─ CompressionManager  (ImageMagick max compression)
        ├─ MetadataManager     (PNG comment field)
        └─ Background subsystem
              ├─ BackgroundSampler
              ├─ CellCleanupProcessor / Config / GimpScript
              ├─ GhostEdgeCleaner
              ├─ SmokeDetector
              └─ ThresholdStepper
```

## Cross-Cutting

- `Platform` — OS detection, GIMP path resolution, Flatpak handling
- `DependencyChecker` — runtime presence + GIMP 3.x version check
- `Utils::PathHelper` — shell quoting, Python string escaping
- `Utils::FileHelper` — file validation, output naming
- `Utils::OutputFormatter` — consistent CLI output
- `Utils::SpritesheetSplitter` — frame extraction support
- `Utils::ImageHelper` — image dimension/metadata helpers

## Processing Modes

1. `--video` — MP4 → spritesheet
2. `--image` — process existing PNG (sub-modes: `--extract`, `--add-meta`)
3. `--consolidate` — stack spritesheets
4. `--batch` — multi-MP4 run
5. `--verify` — read embedded metadata

## Key Invariants

- Metadata survives every operation (re-embedded after GIMP and ImageMagick stages)
- Temp dirs created via `Dir.mktmpdir`, cleaned unless `--debug` or `--keep-temp`
- All paths quoted via `PathHelper.quote_path`
