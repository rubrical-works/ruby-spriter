# Advanced Features

## Batch Processing (v0.6.7+)

Process entire directories of MP4 files with consistent settings:

```bash
# Basic batch processing
ruby_spriter --batch --dir "animations/"
# Processes all MP4s with default 4x4 grid

# Batch with processing options
ruby_spriter --batch --dir "animations/" \
  --frames 32 --columns 8 \
  --scale 50 --remove-bg --sharpen \
  --max-compress

# Batch with output directory
ruby_spriter --batch --dir "raw_videos/" \
  --outputdir "game_assets/sprites/"

# Batch and consolidate results
ruby_spriter --batch --dir "character_states/" \
  --batch-consolidate \
  --output character_complete.png
```

**Features:**
- Automatically finds all MP4 files in directory
- Applies consistent processing to all videos
- Enforces unique output filenames (unless `--overwrite`)
- Continues processing if one file fails
- Optional consolidation of all results
- Supports all video and image processing options

---

## Maximum Compression (v0.6.7+)

Reduce file sizes while preserving metadata:

```bash
# Compress during video processing
ruby_spriter --video input.mp4 --max-compress

# Compress during image processing
ruby_spriter --image sprite.png --scale 50 --max-compress

# Compress batch output
ruby_spriter --batch --dir "videos/" --max-compress

# Compress consolidated output
ruby_spriter --consolidate --dir "sprites/" --max-compress
```

**Compression Details:**
- Uses ImageMagick optimal PNG compression settings
- Compression level 9 (maximum zlib)
- Paeth filter (compression filter 5)
- Filtered strategy (compression strategy 1)
- Quality 95
- Preserves embedded spritesheet metadata
- Displays size reduction statistics

---

## Directory-Based Consolidation (v0.6.7+)

Consolidate all spritesheets in a directory automatically:

```bash
# Scan directory and consolidate all spritesheets
ruby_spriter --consolidate --dir "character_animations/"

# With output directory
ruby_spriter --consolidate --dir "sprites/" \
  --outputdir "final_assets/"

# With compression
ruby_spriter --consolidate --dir "sprites/" \
  --max-compress \
  --output character_complete.png
```

**Directory Mode Features:**
- Automatically scans for PNG files with metadata
- Filters out non-spritesheet images
- Sorts files alphabetically before consolidation
- Requires at least 2 valid spritesheets
- Cannot mix with comma-separated file list mode

---

## File Protection with Unique Filenames (v0.6.6+)

By default, Ruby Spriter protects your existing files by generating unique timestamped filenames when output files already exist:

```bash
# First run - creates new file
ruby_spriter --image sprite.png --remove-bg
# Output: sprite-nobg-fuzzy.png

# Second run - creates unique file instead of overwriting
ruby_spriter --image sprite.png --remove-bg
# Output: sprite-nobg-fuzzy_20251023_170542_123.png

# Third run - another unique file
ruby_spriter --image sprite.png --remove-bg
# Output: sprite-nobg-fuzzy_20251023_170545_456.png
```

### Overwrite Mode

Use `--overwrite` to replace existing files instead:

```bash
# Always overwrites sprite-nobg-fuzzy.png
ruby_spriter --image sprite.png --remove-bg --overwrite
```

### Behavior by Mode

| Mode | Default Filename | Unique on Collision |
|------|------------------|---------------------|
| `--video` | `input_spritesheet.png` | ✅ Yes |
| `--image` (with processing) | `input-scaled-50pct.png` | ✅ Yes |
| `--consolidate` | `consolidated_spritesheet.png` | ✅ Yes |
| Any with `--output` | Your specified name | ✅ Yes (unless `--overwrite`) |

---

## Metadata Management

Ruby Spriter embeds grid information directly into PNG files:

```bash
# Metadata is automatically embedded during creation
ruby_spriter --video input.mp4 --frames 32 --columns 8

# Verify metadata in existing spritesheet
ruby_spriter --verify spritesheet.png

# Output:
# Spritesheet Metadata Verification
# ================================
# File: spritesheet.png
# Columns: 8
# Frames: 32
# Rows: 4 (calculated)
```

---

## Operation Order Optimization

When both scaling and background removal are requested, Ruby Spriter automatically uses the optimal order:

```bash
# This automatically removes background BEFORE scaling
ruby_spriter --video input.mp4 --scale 50 --remove-bg

# Why? Background removal works better at full resolution,
# then scaling smooths any rough edges
```

Override if needed:
```bash
ruby_spriter --video input.mp4 --scale 50 --remove-bg --order scale_first
```

---

## Debug Mode

```bash
# See exactly what's happening
ruby_spriter --video input.mp4 --scale 50 --sharpen --debug

# Output includes:
# - Dependency check results
# - Temp directory location
# - GIMP script paths and logs
# - ImageMagick commands
# - Processing timestamps
```

---

## Headless Linux Operation (v0.7.0+)

Ruby Spriter provides completely headless GIMP operation on Linux with multiple layers of GUI prevention:

```bash
# No GIMP GUI appears during processing
ruby_spriter --image sprite.png --remove-bg --scale 50

# Perfect for server environments
ruby_spriter --batch --dir "sprites/" --remove-bg --max-compress
```

**How it Works:**
- **Multiple GUI Prevention Layers**:
  1. `env -u DISPLAY` - Unsets display environment variable
  2. `xvfb-run` - Provides virtual display buffer
  3. `--no-interface` - Disables GIMP GUI interface
  4. `--console-messages` - Routes messages to console instead of dialogs
  5. Flatpak socket isolation (`--nosocket=x11 --nosocket=wayland`) for Flatpak installations
- Works with both native GIMP (Ubuntu 25.04+) and Flatpak GIMP (older distributions)
- No configuration required - works automatically

**Use Cases:**
- **Desktop**: No GUI distractions during batch processing
- **Server**: Headless automation on Ubuntu Server, CI/CD pipelines
- **Docker**: Run in containers without display server
- **SSH**: Process sprites remotely without X forwarding

**Requirements:**
- GIMP 3.x (native package on Ubuntu 25.04+, or Flatpak on older distributions)
- Xvfb (`sudo apt install xvfb` on Ubuntu/Debian)

---

## Frame-by-Frame Background Removal (v0.7.0.1+)

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

**Next Steps:**
- [Features Overview](FEATURES.md) - Learn about all capabilities
- [Architecture](ARCHITECTURE.md) - Understand system design
- [Use Cases & Examples](USE_CASES.md) - See real-world applications
