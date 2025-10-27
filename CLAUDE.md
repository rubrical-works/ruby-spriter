# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Ruby Spriter is a cross-platform Ruby CLI tool for creating spritesheets from video files and processing them with GIMP. It's designed for game development workflows, particularly with Godot Engine.

**Current Version**: 0.7.0
**Ruby Version**: 2.7.0+

## External Dependencies

The tool orchestrates several external command-line tools:
- **FFmpeg/FFprobe**: Video frame extraction and analysis
- **ImageMagick**: Metadata management, consolidation, and sharpening
- **GIMP 3.x (or 2.10)**: Image processing (scaling with interpolation, background removal)
- **rembg** (Optional): AI-powered background removal (Python CLI tool, required for `--aggressive` mode)
- **Xvfb** (Linux only): Virtual display for headless GIMP operation

All external dependencies are checked at runtime via `DependencyChecker` (lib/ruby_spriter/dependency_checker.rb).

## Supported File Formats

**Input:**
- Video: MP4 only (validated at runtime)
- Image: PNG only (validated at runtime)

**Output:**
- PNG only (with embedded metadata)

File extension validation is performed in `Processor#validate_file_extension!` and will raise `ValidationError` if incorrect formats are provided.

## Development Commands

### Running Tests
```bash
# Run all tests
rake spec

# Run tests with coverage
rake coverage

# Run RuboCop linter
rake rubocop

# Run both linter and tests
rake test
```

### Running a Single Test
```bash
# Run specific spec file
rspec spec/ruby_spriter/processor_spec.rb

# Run specific test by line number
rspec spec/ruby_spriter/processor_spec.rb:42
```

### Checking Dependencies
```bash
# Via rake task (development)
rake check_deps

# Via CLI flag (production/user-facing)
ruby_spriter --check-dependencies
```

The `--check-dependencies` flag runs `DependencyChecker.print_report` and exits with:
- Exit code 0 if all dependencies are satisfied
- Exit code 1 if any dependencies are missing

### Running the CLI
```bash
# Via bin executable
ruby bin/ruby_spriter --help

# Via bundler
bundle exec ruby_spriter --help
```

## Architecture

### Processing Modes

Ruby Spriter operates in seven distinct modes, orchestrated by `Processor`:

1. **Video Mode** (`--video`): Convert MP4 to spritesheet using `VideoProcessor`
2. **Image Mode** (`--image`): Process existing PNG with GIMP using `GimpProcessor`
   - **Extract Sub-mode** (`--extract`): Extract specific frames and create new spritesheet (v0.6.8+)
   - **Add Metadata Sub-mode** (`--add-meta`): Add metadata to external spritesheets (v0.6.8+)
3. **Consolidate Mode** (`--consolidate`): Stack multiple spritesheets using `Consolidator`
4. **Batch Mode** (`--batch`): Process multiple MP4 files in a directory using `BatchProcessor`
5. **Verify Mode** (`--verify`): Read and display embedded metadata

### Core Processing Pipeline

The `Processor` class (lib/ruby_spriter/processor.rb) orchestrates the workflow:

1. **Validation**: Validate options, input files, and file extensions
2. **Dependency Check**: Ensure external tools are available
3. **Workflow Execution**: Execute mode-specific processing
4. **Cleanup**: Remove temporary files (unless `--keep-temp`)

**Validation includes:**
- File existence checks
- File extension validation (MP4 for video, PNG for images)
- Input mode compatibility (cannot use multiple input modes simultaneously)

### Key Components

**VideoProcessor** (lib/ruby_spriter/video_processor.rb)
- Uses FFprobe to analyze video duration
- Uses FFmpeg with `tile` filter to create spritesheets
- Embeds metadata into output PNG files

**GimpProcessor** (lib/ruby_spriter/gimp_processor.rb)
- Generates Python-fu scripts for GIMP 3.x batch processing
- Supports both GIMP 2.x and 3.x APIs (version-aware)
- Supports 5 interpolation methods: none, linear, cubic, nohalo (default), lohalo
- Automatically optimizes operation order (remove background before scale) when both operations requested
- Applies sharpening via ImageMagick after GIMP operations (not GIMP GEGL due to batch mode limitations)
- Preserves alpha channels and metadata through processing pipeline
- Handles platform-specific GIMP execution:
  - Windows: Uses batch files
  - Unix: Shell commands with redirection
  - Linux Flatpak: Automatic Xvfb integration for headless operation
- Filters out cosmetic GEGL warnings from GIMP 3.x

**RembgProcessor** (lib/ruby_spriter/rembg_processor.rb) - *v0.7.0+*
- AI-powered background removal using rembg Python tool
- Activated with `--aggressive` flag (requires `--remove-bg`)
- Uses machine learning models for superior edge detection
- Mutually exclusive with GIMP background removal
- Supports combined workflows: rembg for BG removal + GIMP for scaling/sharpening
- Cross-platform path handling via `Utils::PathHelper`
- Validates rembg availability at runtime via `DependencyChecker`
- Install: `pip install "rembg[cli]"`

**Consolidator** (lib/ruby_spriter/consolidator.rb)
- Validates column compatibility between spritesheets
- Uses ImageMagick's `-append` to stack vertically
- Calculates combined metadata (total frames, new row count)
- Supports two consolidation modes:
  - File list mode: comma-separated PNG files
  - Directory mode: scans directory for PNGs with metadata, filters and sorts alphabetically
- Directory scanning with `find_spritesheets_in_directory` method
- Requires at least 2 spritesheets for consolidation

**BatchProcessor** (lib/ruby_spriter/batch_processor.rb)
- Processes multiple MP4 files in a directory
- Finds all videos and processes each with consistent options
- Supports all video and image processing options (scale, remove-bg, sharpen, etc.)
- Enforces unique filenames unless --overwrite is specified
- Continues processing remaining videos if one fails
- Optional consolidation of all resulting spritesheets via --batch-consolidate
- Supports --outputdir to write outputs to a different directory

**CompressionManager** (lib/ruby_spriter/compression_manager.rb)
- Compresses PNG files using ImageMagick with maximum compression settings
- Uses compression level 9, filter 5 (Paeth), strategy 1, quality 95
- Preserves embedded metadata through compression via re-embedding
- Provides compression statistics (original size, compressed size, reduction percentage)
- Works with all processing modes: --video, --image, --batch, --consolidate

**Frame Extraction Workflow** (`--extract`, v0.6.8+)
- Extracts specific frames by number from a spritesheet
- Uses `SpritesheetSplitter` to extract all frames to temp directory
- Keeps only requested frames, deletes the rest
- Reassembles frames into new spritesheet using ImageMagick montage
- Supports duplicate frame numbers for animation loops
- 1-indexed frame numbering (left-to-right, top-to-bottom)
- Requires spritesheet metadata (validated during initialization)
- Supports custom column count (default: 4)
- Applies processing pipeline (scale, remove-bg, sharpen, compress) to reassembled spritesheet
- Individual frames temporary unless `--save-frames` specified
- Automatic output naming with `_extracted` suffix or custom via `--output`
- Implemented in `Processor#execute_extract_workflow` and `Processor#reassemble_frames`
- Mutual exclusivity with `--split` (validated in CLI)

**Metadata Addition Workflow** (`--add-meta`, v0.6.8+)
- Adds spritesheet metadata to external images without embedded metadata
- Validates image dimensions divide evenly by specified grid
- Supports partial grids (custom frame count with `--frames`)
- In-place modification (default) or copy to new file (`--output`)
- Respects `--overwrite` flag for file protection
- Can replace existing metadata with `--overwrite-meta`
- Validates grid layout (rows:columns format, 1-99 range, <1000 total frames)
- Standalone mode: Cannot combine with `--scale`, `--remove-bg`, `--sharpen`
- Enables workflow integration: add metadata to external spritesheets, then use `--extract`, `--consolidate`, `--verify`, or `--split`
- Implemented in `Processor#execute_add_meta_workflow`
- Uses `MetadataManager.embed` to add metadata

**MetadataManager** (lib/ruby_spriter/metadata_manager.rb)
- Embeds spritesheet grid info into PNG comment field using ImageMagick
- Format: `SPRITESHEET|columns=X|rows=Y|frames=Z|version=V`
- Metadata persists through GIMP processing via explicit preservation

**Platform** (lib/ruby_spriter/platform.rb)
- Detects OS (Windows, Linux, macOS)
- Provides platform-specific paths (GIMP executable, ImageMagick commands)
- Detects GIMP version (2.x or 3.x) from executable or Flatpak
- Supports Flatpak GIMP installation (`flatpak:org.gimp.GIMP`)
- Abstracts platform differences

### Utilities

**Utils::PathHelper** (lib/ruby_spriter/utils/path_helper.rb)
- Path quoting for shell commands
- Python string normalization for GIMP scripts

**Utils::FileHelper** (lib/ruby_spriter/utils/file_helper.rb)
- File validation (exists, readable)
- Output filename generation
- Size formatting

**Utils::OutputFormatter** (lib/ruby_spriter/utils/output_formatter.rb)
- Consistent CLI output formatting
- Headers, success/error messages, indentation

## GIMP Integration

### Script Generation

GIMP processing uses dynamically generated Python-fu scripts. The `GimpProcessor` creates complete Python scripts that:

1. Load the image
2. Apply operations (scale or background removal) in configured order
3. Export as PNG
4. Handle cleanup to minimize GEGL warnings

### Scaling Quality

Scaling uses GIMP's `gimp-layer-scale` procedure with configurable interpolation methods set via `gimp-context-set-interpolation`:

- **NoHalo** (`--interpolation nohalo`, default): Best quality for downscaling, excellent edge preservation
- **LoHalo** (`--interpolation lohalo`): Alternative high-quality method, slightly softer
- **Cubic** (`--interpolation cubic`): Good balance of speed and quality
- **Linear** (`--interpolation linear`): Faster but lower quality
- **None** (`--interpolation none`): Fastest, no interpolation (nearest neighbor)

For 50% downscaling, **NoHalo** or **LoHalo** provide the best quality with sharp edges and minimal artifacts.

### Sharpening (Unsharp Mask)

After scaling, an optional unsharp mask can be applied using ImageMagick to enhance edge detail and restore sharpness:

- **--sharpen**: Enable unsharp mask filter
- **--sharpen-radius VALUE**: Blur radius in pixels (default: 3.0, typical range: 0.5-5.0)
- **--sharpen-amount VALUE**: Sharpening strength (default: 0.5, range: 0.0-5.0)
- **--sharpen-threshold VALUE**: Threshold for edge detection (default: 0, range: 0-255)

**When to use sharpening:**
- Downscaling by 50% or more can soften details - sharpening restores crispness
- Default values (radius 3.0, amount 0.5) are tuned for typical sprite downscaling
- For more aggressive sharpening: increase amount to 1.0-3.0
- For subtle sharpening: decrease radius to 1.0-2.0

**Implementation Notes**:
- In GIMP 3.x, interpolation is controlled via the context API (`gimp-context-set-interpolation`) rather than as a direct parameter to scaling procedures.
- The scale operation preserves alpha channels (transparency) by using `gimp-image-merge-visible-layers` instead of `gimp-image-flatten` when multiple layers exist.
- Single-layer images are exported directly without merging, maintaining their alpha channel.
- Unsharp mask is applied using ImageMagick after GIMP scaling, with format: `-unsharp {radius}x{sigma}+{amount}+{threshold}` where sigma = radius * 0.5.
- ImageMagick sharpening is used because GEGL operations in GIMP 3.x batch mode have reliability issues.

### Background Removal Methods

Two selection methods are supported:

- **Fuzzy Select** (`--fuzzy`, default): Selects contiguous regions only (gimp-image-select-contiguous-color)
- **Global Color Select** (`--no-fuzzy`): Selects all matching pixels globally (gimp-image-select-color)

Both methods sample all four corners of the image and combine selections.

### Platform-Specific Execution

**Windows**: Uses a generated batch file (`.bat`) that suppresses GEGL debug output and calls GIMP with proper escaping

**Unix**: Calls GIMP directly with shell redirection

**Linux (Flatpak GIMP)**: Automatically uses Xvfb for headless operation
- Detection: GIMP path starts with `flatpak:`
- Command format: `xvfb-run -a flatpak run org.gimp.GIMP --quit --batch-interpreter=python-fu-eval`
- Virtual display eliminates display connection requirement
- Enables batch processing on headless servers

### Metadata Preservation

GIMP strips PNG metadata during export, so `GimpProcessor#preserve_metadata` explicitly:
1. Reads metadata from input file
2. Renames output to temp file
3. Re-embeds metadata using `MetadataManager`
4. Cleans up temp file

## Testing

Tests use RSpec and follow the pattern:
- Mock external commands (Open3.capture3) to avoid requiring FFmpeg/GIMP/ImageMagick during tests
- Unit tests for each processor component
- Integration-style tests for the main `Processor` orchestration

## Important Implementation Notes

- **No Runtime Dependencies**: Uses only Ruby stdlib + external tools (no gem dependencies)
- **Temp Directory Management**: Creates temp directories with Dir.mktmpdir, cleans up unless `--debug` or `--keep-temp`
- **Path Handling**: All paths are quoted appropriately for shell commands via `PathHelper.quote_path`
- **Error Handling**: Custom exceptions (DependencyError, ProcessingError, ValidationError) for clear error messages
- **GIMP 3.x Batch Mode**: GEGL buffer leak warnings are cosmetic and filtered from output
- **Linux Headless Operation**: Xvfb automatically used for Flatpak GIMP to enable headless batch processing
- **GIMP Version Detection**: Automatically detects and adapts to GIMP 2.x or 3.x APIs

## Common Workflows

### Video to Spritesheet with Processing
```
video.mp4 → VideoProcessor → temp spritesheet → GimpProcessor → final output
                ↓                                      ↓
        metadata embedded                  metadata preserved
```

### Consolidation
```
spritesheet1.png → read metadata → validate columns match
spritesheet2.png → read metadata ↗
spritesheet3.png → read metadata ↗
                        ↓
                ImageMagick -append
                        ↓
                 embed combined metadata
```

## CLI Presets

Four presets available via `--preset`:
- `thumbnail`: 3×? grid, 9 frames, 240px wide
- `preview`: 4×? grid, 16 frames, 400px wide
- `detailed`: 10×? grid, 50 frames, 320px wide
- `contact`: 8×? grid, 64 frames, 160px wide

## Godot Integration

Output spritesheets include Godot AnimatedSprite2D configuration info:
- `HFrames = columns`
- `VFrames = rows`

This allows direct import into Godot for sprite animations.
