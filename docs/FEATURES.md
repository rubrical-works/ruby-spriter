# Features Overview

## ✨ Core Capabilities

- 🎬 **Video to Spritesheet** - Extract frames from MP4 videos using FFmpeg
- 🖼️ **Advanced Image Processing** - Scale, sharpen, and remove backgrounds with precision
- 🎨 **Quality Enhancement** - 5 interpolation methods and configurable unsharp masking
- 🎞️ **Frame-by-Frame Processing** - Process each video frame individually for varying backgrounds (v0.7.0.1+)
- 🔮 **Inner Background Removal** - Remove interior background regions with advanced edge sampling (v0.7.0+)
- 🧹 **Multi-Threshold Processing** - Process with multiple fuzzy select thresholds for superior edges (v0.7.0+)
- 👻 **Ghost Edge Prevention** - Multi-pass cleanup of semi-transparent artifacts (v0.7.0+)
- 💨 **Smoke Detection** - Identify and remove transparency gradients (v0.7.0+)
- 📐 **Spritesheet Consolidation** - Merge multiple spritesheets vertically (file list or directory)
- 📊 **Metadata Management** - Embed, verify, and add grid information to PNG files
- 🎯 **Frame Extraction** - Extract specific frames by number and create new spritesheets
- 🏷️ **Metadata Addition** - Add spritesheet metadata to external images
- 🔒 **Automatic File Protection** - Unique timestamped filenames prevent accidental overwrites (v0.6.6+)
- 📦 **Batch Processing** - Process multiple MP4 files in a directory automatically (v0.6.7+)
- 🗜️ **Maximum Compression** - Optimal PNG compression while preserving metadata (v0.6.7+)
- 🌍 **Cross-Platform** - Works seamlessly on Windows, Linux, and macOS
- 🧪 **Production Ready** - Comprehensive RSpec test coverage (512+ tests)

---

## Image Processing Features

### Scaling with Quality Control

- Percentage-based resizing
- **5 Interpolation Methods:**
  - `none` - No interpolation (nearest neighbor)
  - `linear` - Fast bilinear interpolation
  - `cubic` - High-quality bicubic interpolation
  - `nohalo` - Advanced edge-preserving (default)
  - `lohalo` - Maximum quality, slower

### Sharpening (Unsharp Mask)

- Restore edge definition after scaling
- **Configurable Parameters:**
  - `radius` - Effect size in pixels (default: 2.0)
  - `gain` - Sharpening intensity (default: 0.5, range: 0.0-2.0+)
  - `threshold` - Minimum change threshold (default: 0.03, range: 0.0-1.0)
- Powered by ImageMagick for consistent results

### Background Removal

- **Fuzzy Select** - Contiguous color regions (default)
- **Global Color Select** - All matching pixels across image
- **Frame-by-Frame** - Process each video frame individually (v0.7.0.1+)
- Adjustable selection growth and feathering
- **Smart Operation Order** - Automatically optimizes quality

### Operation Order Optimization

- `scale_first` (default) - Scale then remove background
- `bg_first` - Remove background then scale (auto-enabled when both operations used)
- Automatic optimization for best quality

---

## 🆕 v0.7.0 Features - Advanced Background Removal

### Inner Background Removal

Remove background regions inside sprites (not touching edges) - perfect for centered sprites with interior backgrounds.

**Key Capabilities:**
- **Edge Sampling** - Detect background colors from image borders
- **Intelligent Region Detection** - Find and remove contiguous background regions
- **Multi-Threshold Processing** - Process with multiple threshold values for superior edge quality
- **Ghost Edge Prevention** - Remove semi-transparent artifacts with multi-pass cleanup
- **Smoke Detection** - Identify and remove transparency gradients (smoke effects)

**Command-Line Flags:**

Core Features:
- `--try-inner` - Enable inner background removal
- `--threshold-stepping` - Process with multiple thresholds (0.0, 0.5, 1.0, 3.0, 5.0, 10.0%)
- `--multi-pass` - Remove semi-transparent ghost pixels (max 3 passes)
- `--remove-smoke` - Detect and remove transparency gradients (alpha 20-80%)

Configuration Options:
- `--inner-min-area N` - Minimum area in pixels to remove (default: 100)
- `--adaptive-min-area` - Calculate threshold as 1% of image area
- `--edge-sample-depth N` - Edge sampling depth in pixels (default: 10)
- `--edge-sample-pattern PATTERN` - Sampling pattern: `linear` or `weighted` (default: linear)
- `--color-space SPACE` - Color matching: `rgb` or `lab` (default: rgb)
- `--bg-fuzz N` - Background color tolerance percentage (default: 10)
- `--ghost-threshold N` - Ghost edge detection threshold 0-255 (default: 30)

**Usage Examples:**

```bash
# Basic inner background removal
ruby bin/ruby_spriter --image sprite.png --remove-bg --try-inner

# Full v0.7.0 pipeline with all features
ruby bin/ruby_spriter --image sprite.png \
  --remove-bg \
  --threshold-stepping \
  --try-inner \
  --multi-pass \
  --remove-smoke

# Advanced configuration
ruby bin/ruby_spriter --image sprite.png \
  --remove-bg \
  --try-inner \
  --adaptive-min-area \
  --color-space lab \
  --bg-fuzz 15 \
  --ghost-threshold 40
```

**Processing Order:**
1. Edge sampling (if --try-inner or --threshold-stepping) - captures background palette
2. Threshold stepping (if enabled) - OR -
3. Edge-based background removal (GIMP fuzzy select)
4. Inner background removal (if --try-inner) - uses pre-sampled palette
5. Ghost edge cleaning (if --multi-pass)
6. Smoke detection/removal (detection always active with --remove-bg)

**Note:** When using --try-inner without --threshold-stepping, GIMP removes outer background first, then inner removal processes interior regions. This order is faster as inner removal has less area to process after GIMP clears edges.

---

## 🎞️ Frame-by-Frame Processing (v0.7.0.1+)

Process each video frame individually before assembling the spritesheet - perfect for videos with varying backgrounds.

```bash
# Basic frame-by-frame processing
ruby_spriter --video input.mp4 --remove-bg --by-frame

# With custom settings
ruby_spriter --video input.mp4 --remove-bg --by-frame \
  --frames 32 --columns 8 \
  --scale 50 --sharpen

# Batch processing with frame-by-frame
ruby_spriter --batch --dir "videos/" --remove-bg --by-frame
```

**How it Works:**
1. Extract frames from video → `frame_001.png`, `frame_002.png`, etc.
2. Remove background from EACH frame individually (progress indicator shows "Processing frame X/Y...")
3. Assemble spritesheet from processed frames
4. Add metadata with `processing_mode: by-frame`

**Standard Workflow vs Frame-by-Frame:**

| Workflow | Process Order | Best For |
|----------|---------------|----------|
| **Standard** | Extract → Assemble → Remove BG | Consistent backgrounds |
| **Frame-by-Frame** | Extract → Remove BG (each) → Assemble | Varying backgrounds |

**Performance:**
- Standard mode: ~7.5 seconds for 16 frames
- Frame-by-frame mode: ~120 seconds for 16 frames (16× slower)
- Trade-off: Longer processing time for superior quality

**Compatibility:**
- ✅ Works with `--video` and `--batch` modes
- ✅ Supports all background removal modes (`--fuzzy`, `--threshold`, `--threshold-stepping`)
- ✅ Compatible with `--scale`, `--sharpen`, `--max-compress`
- ❌ Not available for `--image` mode (only for video processing)

---

## 🆕 Cell-Based Background Cleanup (v0.7.0.1+ - Experimental)

Post-process residual backgrounds from finished spritesheets with per-cell analysis.

```bash
# Basic cell cleanup
ruby_spriter --video input.mp4 --remove-bg --cleanup-cells

# With custom threshold
ruby_spriter --video input.mp4 --remove-bg --cleanup-cells \
  --cell-cleanup-threshold 10.0

# Batch processing with cell cleanup
ruby_spriter --batch --dir "videos/" --remove-bg --cleanup-cells
```

**Key Features:**
- Analyzes each cell independently for dominant background colors
- Uses GIMP to remove detected dominant colors from individual cells
- Configurable threshold (default: 15%, range: 1-50%)
- Requires `--remove-bg` flag
- Cannot be combined with `--by-frame` (redundant)
- Progress reporting with processed/cleaned/skipped counts

**Status:** ⚠️ Experimental - Feature executes but doesn't effectively remove backgrounds yet. Requires algorithm optimization. Not recommended for production use.

**When to Use:**
- ✅ You have a finished spritesheet with minor residual backgrounds
- ✅ Want a quick post-processing pass without full reprocessing
- ❌ Primary background removal (use `--remove-bg` alone)
- ❌ Videos with varying backgrounds (use `--by-frame` instead)

---

**Next Steps:**
- [Usage Guide](USAGE.md) - Learn all command-line options
- [Advanced Features](ADVANCED.md) - Dive deeper into powerful features
- [Use Cases & Examples](USE_CASES.md) - See real-world applications
