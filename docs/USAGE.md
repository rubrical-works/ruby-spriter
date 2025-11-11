# Usage Guide

## Command-Line Options Reference

### Input Options

```bash
-v, --video FILE              Input video file (MP4 only)
-i, --image FILE              Input image file (PNG only)
    --batch                   Batch process mode (use with --dir)
    --dir DIRECTORY           Directory for batch or consolidate operations
    --consolidate [FILES]     Consolidate spritesheets (comma-separated files or use with --dir)
    --verify FILE             Verify spritesheet metadata (PNG only)
```

### Spritesheet Options

```bash
-o, --output FILE             Output file path
-f, --frames COUNT            Number of frames to extract (default: 16)
-c, --columns COUNT           Grid columns (default: 4)
-w, --width PIXELS            Max frame width (default: 320)
-b, --background COLOR        Tile background: black, white (default: black)
```

### Scaling Options

```bash
-s, --scale PERCENT           Scale image by percentage
    --interpolation METHOD    Interpolation: none, linear, cubic, nohalo, lohalo
                              (default: nohalo)
```

### Sharpening Options

```bash
    --sharpen                 Apply unsharp mask after scaling
    --sharpen-radius VALUE    Radius in pixels (default: 2.0)
    --sharpen-gain VALUE      Gain/strength (default: 0.5, range: 0.0-2.0+)
    --sharpen-threshold VALUE Threshold fraction (default: 0.03, range: 0.0-1.0)
```

### Background Removal Options

```bash
-r, --remove-bg               Remove background using GIMP
-t, --threshold VALUE         Feather radius (default: 0.0)
-g, --grow PIXELS             Pixels to grow selection (default: 1)
    --fuzzy                   Use fuzzy select (contiguous) - DEFAULT
    --no-fuzzy                Use global color select (all matching)
    --order ORDER             Operation order: scale_first, bg_first
    --by-frame                Frame-by-frame background removal (video/batch only)
```

### Preset Configurations

```bash
--preset thumbnail            3×? grid, 9 frames, 240px wide
--preset preview              4×? grid, 16 frames, 400px wide
--preset detailed             10×? grid, 50 frames, 320px wide
--preset contact              8×? grid, 64 frames, 160px wide
```

### Batch Processing Options (v0.6.7+)

```bash
    --batch                   Enable batch processing mode
    --dir DIRECTORY           Directory containing MP4 files to process
    --outputdir DIRECTORY     Output directory for processed files
    --batch-consolidate       Consolidate all resulting spritesheets
```

### Compression Options (v0.6.7+)

```bash
    --max-compress            Apply maximum PNG compression (preserves metadata)
```

### Frame Extraction Options (v0.6.8+)

```bash
    --extract FRAMES          Extract specific frames by number (e.g., 1,2,4,5,8)
    --columns NUM             Output grid columns for extracted spritesheet (default: 4)
    --save-frames             Keep individual extracted frames on disk
    --split R:C               Split spritesheet into all individual frames (rows:columns)
    --override-md             Override embedded metadata when using --split
```

### Metadata Management Options (v0.6.8+)

```bash
    --add-meta R:C            Add spritesheet metadata (rows:columns, e.g., 4:4)
    --overwrite-meta          Replace existing metadata
```

### Other Options

```bash
    --overwrite               Overwrite existing output files (default: create unique filenames)
    --keep-temp               Keep temporary files for debugging
    --debug                   Enable verbose output + keep temp files
    --check-dependencies      Check if all required external tools are installed
    --version                 Show version information
-h, --help                    Show help message
```

---

## Quick Command Examples

### Basic Video to Spritesheet

```bash
# Create 4x4 grid with 16 frames
ruby_spriter --video input.mp4

# Custom grid and frame count
ruby_spriter --video input.mp4 --frames 32 --columns 8
```

### High-Quality Scaling

```bash
# Scale to 50% with best quality interpolation
ruby_spriter --video input.mp4 --scale 50 --interpolation nohalo

# Scale and sharpen for crisp results
ruby_spriter --video input.mp4 --scale 50 --sharpen

# Custom sharpening for maximum detail
ruby_spriter --video input.mp4 --scale 50 --sharpen \
  --sharpen-gain 1.5 --sharpen-radius 3.0
```

### Background Removal

```bash
# Remove background (default: global select with inner background removal)
ruby_spriter --video input.mp4 --remove-bg

# Remove only contiguous background (fuzzy select)
ruby_spriter --video input.mp4 --remove-bg --fuzzy

# Frame-by-frame for varying backgrounds (v0.7.0.1+)
ruby_spriter --video input.mp4 --remove-bg --by-frame

# Fine-tune background removal
ruby_spriter --image sprite.png --remove-bg --threshold 52.0

# Adjust background sampling
ruby_spriter --image sprite.png --remove-bg --bg-sample-offset 7 --bg-sample-count 15
```

### Batch Processing (v0.6.7+)

```bash
# Process all videos in a directory
ruby_spriter --batch --dir "videos/"

# Batch process with scaling and compression
ruby_spriter --batch --dir "videos/" --scale 50 --max-compress

# Batch with frame-by-frame processing (v0.7.0.1+)
ruby_spriter --batch --dir "videos/" --remove-bg --by-frame

# Batch process with output to different directory
ruby_spriter --batch --dir "videos/" --outputdir "output/"

# Batch process and consolidate all results
ruby_spriter --batch --dir "videos/" --batch-consolidate
```

### Consolidate Spritesheets

```bash
# Consolidate specific files (comma-separated)
ruby_spriter --consolidate file1.png,file2.png,file3.png

# Consolidate all spritesheets in a directory (v0.6.7+)
ruby_spriter --consolidate --dir "spritesheets/"

# Consolidate with compression
ruby_spriter --consolidate --dir "spritesheets/" --max-compress
```

### Frame Extraction (v0.6.8+)

```bash
# Extract specific frames by number
ruby_spriter --image sprite.png --extract 1,2,4,5,8 --columns 3

# Extract with duplicates for animation loops
ruby_spriter --image sprite.png --extract 1,1,2,2,3,3

# Extract, process, and save frames
ruby_spriter --image sprite.png --extract 1,3,5,7 \
  --scale 50 --sharpen --save-frames

# Workflow: Add metadata then extract frames
ruby_spriter --image external.png --add-meta 4:4
ruby_spriter --image external.png --extract 1,5,9,13 --columns 2
```

### Metadata Management (v0.6.8+)

```bash
# Add metadata to external spritesheet
ruby_spriter --image sprite.png --add-meta 4:4

# Add metadata with partial grid (14 frames in 4x4 grid)
ruby_spriter --image sprite.png --add-meta 4:4 --frames 14

# Replace existing metadata
ruby_spriter --image existing.png --add-meta 8:8 --overwrite-meta

# Add metadata and copy to new file
ruby_spriter --image sprite.png --add-meta 4:4 --output sprite_meta.png
```

### Advanced Workflows

```bash
# Complete processing pipeline with compression
ruby_spriter --video input.mp4 \
  --frames 64 --columns 8 \
  --scale 50 --interpolation nohalo \
  --remove-bg \
  --sharpen --sharpen-gain 0.8 \
  --max-compress

# Process existing image with quality enhancement
ruby_spriter --image large_sprite.png \
  --scale 50 --interpolation lohalo \
  --sharpen --sharpen-gain 1.2
```

---

**Next Steps:**
- [Features Overview](FEATURES.md) - Learn about all capabilities
- [Advanced Features](ADVANCED.md) - Deep dive into powerful features
- [Use Cases & Examples](USE_CASES.md) - Real-world scenarios
