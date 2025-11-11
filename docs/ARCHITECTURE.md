# Architecture Guide

## Five Processing Modes

1. **Video Mode** - MP4 → Spritesheet → Optional Processing
2. **Image Mode** - PNG → Processing → Enhanced PNG
3. **Consolidate Mode** - Multiple PNGs → Combined Spritesheet (file list or directory)
4. **Batch Mode** (v0.6.7+) - Directory of MP4s → Multiple Spritesheets → Optional Consolidation
5. **Verify Mode** - Read and display embedded metadata

---

## Processing Pipeline

### Video Mode

```
Input Video (MP4)
    ↓
[FFmpeg] Frame Extraction + Spritesheet Assembly
    ↓
[ImageMagick] Metadata Embedding
    ↓
[GIMP] Scale and/or Background Removal (optional)
    ↓
[ImageMagick] Sharpening (optional)
    ↓
Output PNG with Metadata
```

### Video Mode with Frame-by-Frame (v0.7.0.1+)

```
Input Video (MP4)
    ↓
[FFmpeg] Frame Extraction
    ↓
[GIMP] Remove Background from EACH Frame
    ↓
[FFmpeg] Assemble Spritesheet from Processed Frames
    ↓
[ImageMagick] Metadata Embedding (with processing_mode: by-frame)
    ↓
Output PNG with Metadata
```

### Video Mode with Cell-Based Cleanup (v0.7.0.1+)

```
Input Video (MP4)
    ↓
[FFmpeg] Frame Extraction + Spritesheet Assembly
    ↓
[GIMP] Background Removal (standard)
    ↓
[CellCleanupProcessor] Per-Cell Dominant Color Analysis & Removal
    ├─ Extract each cell from spritesheet
    ├─ Analyze dominant colors using ImageMagick histogram
    ├─ Generate GIMP script for each cell with colors > threshold
    ├─ Execute GIMP to clear dominant colors
    └─ Reassemble cleaned cells into final spritesheet
    ↓
[ImageMagick] Optional scaling/sharpening
    ↓
Output PNG with Metadata
```

### Image Mode

```
Input Image (PNG)
    ↓
[GIMP] Scale and/or Background Removal (optional)
    ↓
[ImageMagick] Sharpening (optional)
    ↓
[ImageMagick] Metadata Preservation
    ↓
Output PNG with Metadata
```

### Consolidate Mode

```
Multiple Input PNGs (file list or directory scan)
    ↓
[Metadata Filter] Find PNGs with spritesheet metadata (directory mode)
    ↓
[ImageMagick] Read Metadata from Each
    ↓
[ImageMagick] Validate Column Compatibility
    ↓
[ImageMagick] Vertical Stacking (append)
    ↓
[ImageMagick] Embed Combined Metadata
    ↓
[ImageMagick] Optional Max Compression
    ↓
Output Consolidated PNG
```

### Batch Mode (v0.6.7+)

```
Directory of MP4 Files
    ↓
[Scan] Find all MP4 files
    ↓
[Loop] For each MP4:
    ├─ [FFmpeg] Extract frames + create spritesheet
    ├─ [GIMP] Optional scaling/background removal
    ├─ [ImageMagick] Optional sharpening
    └─ [ImageMagick] Optional max compression
    ↓
[Optional] Consolidate all results with --batch-consolidate
    ↓
Multiple Output PNGs (or one consolidated PNG)
```

---

## Key Components

### Core Classes

**Processor** (`lib/ruby_spriter/processor.rb`)
- Main orchestration class
- Routes processing based on mode (--video, --image, --consolidate, --batch, --verify)
- Validates options and dependencies
- Manages workflow execution and cleanup

**VideoProcessor** (`lib/ruby_spriter/video_processor.rb`)
- FFmpeg integration for frame extraction and spritesheet assembly
- Frame-by-frame background removal support (v0.7.0.1+)
- Handles video analysis and metadata generation
- Supports custom grid dimensions and frame counts

**GimpProcessor** (`lib/ruby_spriter/gimp_processor.rb`)
- GIMP batch scripting and execution
- Generates Python-fu scripts for GIMP 3.x (GIMP 2.x NOT supported)
- Handles image scaling with 5 interpolation methods
- Background removal with fuzzy and global color select
- Platform-specific execution (Windows batch files, Unix shell, Linux Flatpak)

**CellCleanupProcessor** (`lib/ruby_spriter/cell_cleanup_processor.rb`) - v0.7.0.1+
- Cell-by-cell analysis and cleanup orchestration
- Dominant color detection using ImageMagick histogram
- Per-cell GIMP script generation and execution
- Spritesheet reassembly with ImageMagick montage

**Consolidator** (`lib/ruby_spriter/consolidator.rb`)
- Multi-spritesheet merging (file list or directory mode)
- Metadata compatibility validation
- Vertical stacking using ImageMagick append
- Combined metadata calculation and embedding

**BatchProcessor** (`lib/ruby_spriter/batch_processor.rb`) - v0.6.7+
- Directory scanning for MP4 files
- Consistent processing across multiple videos
- Cached dependency checking for performance
- Optional consolidation of all results
- Unique filename enforcement

**CompressionManager** (`lib/ruby_spriter/compression_manager.rb`) - v0.6.7+
- PNG compression with metadata preservation
- Compression level 9, Paeth filter, strategy 1
- Size reduction statistics reporting

**MetadataManager** (`lib/ruby_spriter/metadata_manager.rb`)
- PNG metadata embedding and reading
- Grid information (columns, rows, frames) storage
- Metadata verification and parsing

### Supporting Classes

**DependencyChecker** (`lib/ruby_spriter/dependency_checker.rb`)
- Detects installed external tools (FFmpeg, GIMP, ImageMagick, Xvfb)
- Reports version information and paths
- Provides platform-specific installation instructions

**Platform** (`lib/ruby_spriter/platform.rb`)
- Cross-platform detection (Windows, Linux, macOS)
- GIMP 3.x detection and validation (2.x NOT supported)
- Flatpak GIMP detection for older Linux distributions
- Native GIMP 3.x support on Ubuntu 25.04+
- Platform-specific path handling

**Utilities** (`lib/ruby_spriter/utils/`)
- **PathHelper**: Path quoting and normalization
- **FileHelper**: File validation, size formatting, output naming
- **OutputFormatter**: Consistent CLI output formatting
- **ImageHelper**: Image dimension reading (v0.7.0.1+)

---

## Data Flow

### Video Processing Example

```
User Input:
  ruby_spriter --video input.mp4 --remove-bg --scale 50

Processor Workflow:
  1. Validate options and dependencies
  2. Create temp directory
  3. Call VideoProcessor.create_spritesheet()
     ├─ FFmpeg: Extract frames → frame_001.png, etc.
     ├─ FFmpeg: Create spritesheet (FFmpeg tile filter)
     └─ Return: { frames: N, columns: C, dimensions: WxH }
  4. Call GimpProcessor.process_image()
     ├─ Generate Python-fu script for scaling + BG removal
     ├─ Execute GIMP script
     └─ Return: processed_spritesheet.png
  5. Call MetadataManager.embed()
     └─ Add grid metadata to PNG
  6. Cleanup temp directory
  7. Report completion with stats

Output:
  input_spritesheet.png (with embedded metadata)
```

### Cell Cleanup Processing Example

```
User Input:
  ruby_spriter --video input.mp4 --remove-bg --cleanup-cells

Processor Workflow (after standard BG removal):
  4. Call CellCleanupProcessor.cleanup_cells()
     ├─ For each cell in grid:
     │  ├─ Extract cell via ImageMagick crop
     │  ├─ Analyze colors via histogram
     │  ├─ Identify dominant colors (>threshold %)
     │  ├─ If dominant colors found:
     │  │  ├─ Generate GIMP Python-fu script
     │  │  ├─ Execute via GimpProcessor
     │  │  └─ Validate output created
     │  └─ Return cleaned or original cell path
     ├─ Collect all cell paths
     └─ Reassemble via ImageMagick montage
  5. Call MetadataManager.embed()
     └─ Add grid metadata + cleanup stats

Output:
  input_spritesheet.png (cells cleaned, metadata added)
```

---

## Version-Specific Features

| Feature | v0.6.7 | v0.7.0 | v0.7.0.1 |
|---------|--------|--------|----------|
| Video Mode | ✅ | ✅ | ✅ |
| Image Mode | ✅ | ✅ | ✅ |
| Batch Processing | ✅ | ✅ | ✅ |
| Consolidation | ✅ | ✅ | ✅ |
| Max Compression | ✅ | ✅ | ✅ |
| GIMP 3.x | ✅ | ✅ | ✅ |
| Inner BG Removal | ❌ | ✅ | ✅ |
| Threshold Stepping | ❌ | ✅ | ✅ |
| Ghost Edge Cleaning | ❌ | ✅ | ✅ |
| Smoke Detection | ❌ | ✅ | ✅ |
| Frame-by-Frame BG | ❌ | ❌ | ✅ |
| Cell-Based Cleanup | ❌ | ❌ | ✅ |
| Headless Linux | ✅ | ✅ | ✅ |

---

## Technology Stack

- **Language**: Ruby 2.7+
- **Video**: FFmpeg + FFprobe
- **Image Processing**: ImageMagick 7.x, GIMP 3.x (2.x NOT supported)
- **Testing**: RSpec (512+ tests)
- **Process Management**: Open3 (Ruby stdlib)
- **File I/O**: Ruby stdlib only (no runtime dependencies)

---

**Next Steps:**
- [Development Guide](DEVELOPMENT.md) - Set up dev environment
- [Features Overview](FEATURES.md) - Learn all capabilities
- [Advanced Features](ADVANCED.md) - Explore powerful features
