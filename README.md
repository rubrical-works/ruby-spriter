# Ruby Spriter v0.7.0

[![Ruby](https://img.shields.io/badge/Ruby-2.7+-red.svg)](https://www.ruby-lang.org/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Linux%20%7C%20macOS-lightgrey.svg)]()

**Professional MP4 to Spritesheet Converter with Advanced Image Processing**

A powerful cross-platform Ruby tool for creating high-quality spritesheets from video files and processing them with professional-grade image manipulation. Perfect for game development workflows, particularly with Godot Engine.

---

## ✨ Features

### Core Capabilities
- 🎬 **Video to Spritesheet** - Extract frames from MP4 videos using FFmpeg
- 🖼️ **Advanced Image Processing** - Scale, sharpen, and remove backgrounds with precision
- 🎨 **Quality Enhancement** - 5 interpolation methods and configurable unsharp masking
- 📐 **Spritesheet Consolidation** - Merge multiple spritesheets vertically (file list or directory)
- 📊 **Metadata Management** - Embed, verify, and add grid information to PNG files
- 🎯 **Frame Extraction** - Extract specific frames by number and create new spritesheets
- 🏷️ **Metadata Addition** - Add spritesheet metadata to external images
- 🔒 **Automatic File Protection** - Unique timestamped filenames prevent accidental overwrites (v0.6.6+)
- 📦 **Batch Processing** - Process multiple MP4 files in a directory automatically (v0.6.7+)
- 🗜️ **Maximum Compression** - Optimal PNG compression while preserving metadata (v0.6.7+)
- 🌍 **Cross-Platform** - Works seamlessly on Windows, Linux, and macOS
- 🧪 **Production Ready** - Comprehensive RSpec test coverage (365 tests)

### Image Processing Features

#### **Scaling with Quality Control**
- Percentage-based resizing
- **5 Interpolation Methods:**
  - `none` - No interpolation (nearest neighbor)
  - `linear` - Fast bilinear interpolation
  - `cubic` - High-quality bicubic interpolation
  - `nohalo` - Advanced edge-preserving (default)
  - `lohalo` - Maximum quality, slower

#### **Sharpening (Unsharp Mask)**
- Restore edge definition after scaling
- **Configurable Parameters:**
  - `radius` - Effect size in pixels (default: 2.0)
  - `gain` - Sharpening intensity (default: 0.5, range: 0.0-2.0+)
  - `threshold` - Minimum change threshold (default: 0.03, range: 0.0-1.0)
- Powered by ImageMagick for consistent results

#### **Background Removal**
- **Fuzzy Select** - Contiguous color regions (default)
- **Global Color Select** - All matching pixels across image
- Adjustable selection growth and feathering
- **Smart Operation Order** - Automatically optimizes quality

#### **Operation Order Optimization**
- `scale_first` (default) - Scale then remove background
- `bg_first` - Remove background then scale (auto-enabled when both operations used)
- Automatic optimization for best quality

---

## 📋 Requirements

### External Dependencies

| Tool | Version | Purpose |
|------|---------|---------|
| **FFmpeg** | Latest | Video frame extraction |
| **FFprobe** | Latest | Video analysis (included with FFmpeg) |
| **ImageMagick** | 7.x+ | Metadata and sharpening |
| **GIMP** | 3.x (or 2.10) | Scaling and background removal |
| **Xvfb** | Latest (Linux only) | Virtual display for headless GIMP |

### Ruby Version
- Ruby 2.7.0 or higher
- No runtime gem dependencies (uses Ruby standard library)

### Supported File Formats
- **Video Input**: MP4 only
- **Image Input/Output**: PNG only

---

## 🚀 Installation

### Prerequisites (All Installation Methods)

Ruby Spriter requires these external tools for video and image processing:

| Tool | Purpose | Version |
|------|---------|---------|
| **FFmpeg** | Video frame extraction | Any recent version |
| **ImageMagick** | Image manipulation & metadata | 7.x or 6.9+ |
| **GIMP** | Advanced image processing | 3.x (or 2.10) |
| **Xvfb** | Virtual display (Linux only) | Any recent version |

#### Installing Prerequisites

**Windows (Chocolatey - Recommended)**

Chocolatey is a package manager for Windows that simplifies software installation. If you don't have Chocolatey installed:

1. **Install Chocolatey** (run PowerShell as Administrator):
   ```powershell
   Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
   ```

   Verify installation:
   ```powershell
   choco --version
   ```

2. **Install Ruby** (if not already installed):
   ```powershell
   choco install ruby -y
   ```

   Close and reopen PowerShell, then verify:
   ```powershell
   ruby --version
   gem --version
   ```

3. **Install Ruby Spriter dependencies**:
   ```powershell
   choco install ffmpeg imagemagick gimp -y
   ```

   This installs all required tools:
   - **FFmpeg** - Video processing
   - **ImageMagick** - Image manipulation and metadata
   - **GIMP** - Advanced image processing

4. **Restart your terminal** to ensure all tools are in your PATH

**Alternative: Manual Installation on Windows**

If you prefer not to use Chocolatey:
- **Ruby**: Download from [rubyinstaller.org](https://rubyinstaller.org/)
- **FFmpeg**: Download from [ffmpeg.org](https://ffmpeg.org/download.html)
- **ImageMagick**: Download from [imagemagick.org](https://imagemagick.org/script/download.php#windows)
- **GIMP**: Download from [gimp.org](https://www.gimp.org/downloads/)

**macOS (Homebrew)**

```bash
# Install Homebrew if not already installed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Ruby (if not already installed)
brew install ruby

# Install Ruby Spriter dependencies
brew install ffmpeg imagemagick gimp
```

**Linux (Ubuntu/Debian)**

```bash
# Install Ruby (if not already installed)
sudo apt update && sudo apt install ruby-full -y

# Install Ruby Spriter dependencies
sudo apt install ffmpeg imagemagick -y

# Install GIMP 3.x via Flatpak (recommended)
sudo apt install flatpak -y
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install flathub org.gimp.GIMP -y

# Install Xvfb for headless GIMP operation
sudo apt install xvfb -y
```

**Note for Linux Users**: GIMP 3.x requires a display connection. Ruby Spriter automatically uses Xvfb (X Virtual Framebuffer) with Flatpak socket isolation to provide a completely headless virtual display. No GIMP GUI windows will appear on your screen - perfect for both desktop use (no distractions) and server environments (CI/CD, Docker, SSH sessions).

**Linux (Fedora/RHEL)**

```bash
# Install Ruby (if not already installed)
sudo dnf install ruby -y

# Install Ruby Spriter dependencies
sudo dnf install ffmpeg imagemagick -y

# Install GIMP 3.x via Flatpak (recommended)
sudo dnf install flatpak -y
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install flathub org.gimp.GIMP -y

# Install Xvfb for headless GIMP operation
sudo dnf install xorg-x11-server-Xvfb -y
```

---

### Choose Your Installation Method

#### 📦 **Option A: RubyGems (Recommended)**

Install the published gem from RubyGems.org:

```bash
gem install ruby_spriter
```

**Requirements**: Ruby 2.7 or higher
**Best for**: All platforms (Windows, macOS, Linux), automated workflows

---

#### 🛠️ **Option B: From Source (Development)**

Clone and build from source:

```bash
# Clone repository
git clone https://github.com/scooter-indie/ruby-spriter.git
cd ruby-spriter

# Install development dependencies
bundle install

# Build and install gem locally
gem build ruby_spriter.gemspec
gem install ruby_spriter-0.6.7.gem
```

**Best for**: Contributors, developers wanting latest code

---

### Verify Installation

After installing Ruby Spriter via any method:

```bash
# Check Ruby Spriter version
ruby_spriter --version

# Verify all dependencies
ruby_spriter --check-dependencies
```

The `--check-dependencies` command checks all external tools:
- ✅ **Tool found**: Shows version and path
- ❌ **Tool missing**: Shows platform-specific installation commands

Example output:
```
Checking external dependencies...

✓ FFmpeg found: 6.0 (C:\ProgramData\chocolatey\bin\ffmpeg.exe)
✓ FFprobe found: 6.0 (C:\ProgramData\chocolatey\bin\ffprobe.exe)
✓ ImageMagick (convert) found: 7.1.1-15 (C:\Program Files\ImageMagick\convert.exe)
✓ ImageMagick (identify) found: 7.1.1-15 (C:\Program Files\ImageMagick\identify.exe)
✓ GIMP found: 2.99.16 (C:\Program Files\GIMP 3\bin\gimp-2.99.exe)

All dependencies are installed!
```

---

## 🎯 Quick Start

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
# Remove background (auto-optimized order)
ruby_spriter --video input.mp4 --scale 50 --remove-bg

# Process existing spritesheet
ruby_spriter --image sprite.png --remove-bg --fuzzy

# Fine-tune background removal
ruby_spriter --image sprite.png --remove-bg \
  --threshold 1.5 --grow 2
```

### Batch Processing (v0.6.7+)
```bash
# Process all videos in a directory
ruby_spriter --batch --dir "videos/"

# Batch process with scaling and compression
ruby_spriter --batch --dir "videos/" --scale 50 --max-compress

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

## 📚 Usage

### Command-Line Options

#### **Input Options**
```bash
-v, --video FILE              Input video file (MP4 only)
-i, --image FILE              Input image file (PNG only)
    --batch                   Batch process mode (use with --dir)
    --dir DIRECTORY           Directory for batch or consolidate operations
    --consolidate [FILES]     Consolidate spritesheets (comma-separated files or use with --dir)
    --verify FILE             Verify spritesheet metadata (PNG only)
```

#### **Spritesheet Options**
```bash
-o, --output FILE             Output file path
-f, --frames COUNT            Number of frames to extract (default: 16)
-c, --columns COUNT           Grid columns (default: 4)
-w, --width PIXELS            Max frame width (default: 320)
-b, --background COLOR        Tile background: black, white (default: black)
```

#### **Scaling Options**
```bash
-s, --scale PERCENT           Scale image by percentage
    --interpolation METHOD    Interpolation: none, linear, cubic, nohalo, lohalo
                              (default: nohalo)
```

#### **Sharpening Options**
```bash
    --sharpen                 Apply unsharp mask after scaling
    --sharpen-radius VALUE    Radius in pixels (default: 2.0)
    --sharpen-gain VALUE      Gain/strength (default: 0.5, range: 0.0-2.0+)
    --sharpen-threshold VALUE Threshold fraction (default: 0.03, range: 0.0-1.0)
```

#### **Background Removal Options**
```bash
-r, --remove-bg               Remove background using GIMP
-t, --threshold VALUE         Feather radius (default: 0.0)
-g, --grow PIXELS             Pixels to grow selection (default: 1)
    --fuzzy                   Use fuzzy select (contiguous) - DEFAULT
    --no-fuzzy                Use global color select (all matching)
    --order ORDER             Operation order: scale_first, bg_first
```

#### **Preset Configurations**
```bash
--preset thumbnail            3×? grid, 9 frames, 240px wide
--preset preview              4×? grid, 16 frames, 400px wide
--preset detailed             10×? grid, 50 frames, 320px wide
--preset contact              8×? grid, 64 frames, 160px wide
```

#### **Batch Processing Options (v0.6.7+)**
```bash
    --batch                   Enable batch processing mode
    --dir DIRECTORY           Directory containing MP4 files to process
    --outputdir DIRECTORY     Output directory for processed files
    --batch-consolidate       Consolidate all resulting spritesheets
```

#### **Compression Options (v0.6.7+)**
```bash
    --max-compress            Apply maximum PNG compression (preserves metadata)
```

#### **Frame Extraction Options (v0.6.8+)**
```bash
    --extract FRAMES          Extract specific frames by number (e.g., 1,2,4,5,8)
    --columns NUM             Output grid columns for extracted spritesheet (default: 4)
    --save-frames             Keep individual extracted frames on disk
    --split R:C               Split spritesheet into all individual frames (rows:columns)
    --override-md             Override embedded metadata when using --split
```

#### **Metadata Management Options (v0.6.8+)**
```bash
    --add-meta R:C            Add spritesheet metadata (rows:columns, e.g., 4:4)
    --overwrite-meta          Replace existing metadata
```

#### **Other Options**
```bash
    --overwrite               Overwrite existing output files (default: create unique filenames)
    --keep-temp               Keep temporary files for debugging
    --debug                   Enable verbose output + keep temp files
    --check-dependencies      Check if all required external tools are installed
    --version                 Show version information
-h, --help                    Show help message
```

---

## 💡 Use Cases

### Game Development with Godot

#### Character Animation Sprites
```bash
# Export from Blender/animation software to MP4
# Convert to optimized spritesheet with background removal

ruby_spriter --video character_walk.mp4 \
  --frames 16 --columns 4 \
  --scale 50 --remove-bg \
  --sharpen
```

#### VFX and Particle Effects
```bash
# High frame count for smooth effects
ruby_spriter --video explosion.mp4 \
  --frames 64 --columns 8 \
  --scale 75 --interpolation nohalo
```

#### Multiple Character Directions
```bash
# Consolidate walk cycles for 8 directions (file list)
ruby_spriter --consolidate \
  walk_n.png,walk_ne.png,walk_e.png,walk_se.png,\
  walk_s.png,walk_sw.png,walk_w.png,walk_nw.png \
  --output character_walk_all.png

# Or consolidate all spritesheets in a directory (v0.6.7+)
ruby_spriter --consolidate --dir "walk_cycles/" \
  --output character_walk_all.png
```

### Batch Processing Workflows (v0.6.7+)
```bash
# Process entire animation library
ruby_spriter --batch --dir "raw_animations/" \
  --outputdir "game_assets/sprites/" \
  --scale 50 --remove-bg --sharpen --max-compress

# Create and consolidate multiple character states
ruby_spriter --batch --dir "character_states/" \
  --frames 8 --columns 4 \
  --batch-consolidate
```

### Quality Enhancement
```bash
# Downscale high-res renders while maintaining sharpness
ruby_spriter --image 4k_sprite.png \
  --scale 25 --interpolation lohalo \
  --sharpen --sharpen-gain 1.0 \
  --max-compress \
  --output hd_sprite.png
```

---

## 🔧 Advanced Features

### Batch Processing (v0.6.7+)

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

### Maximum Compression (v0.6.7+)

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

### Directory-Based Consolidation (v0.6.7+)

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

### File Protection with Unique Filenames (v0.6.6+)

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

#### Overwrite Mode

Use `--overwrite` to replace existing files instead:

```bash
# Always overwrites sprite-nobg-fuzzy.png
ruby_spriter --image sprite.png --remove-bg --overwrite
```

#### Behavior by Mode

| Mode | Default Filename | Unique on Collision |
|------|------------------|---------------------|
| `--video` | `input_spritesheet.png` | ✅ Yes |
| `--image` (with processing) | `input-scaled-50pct.png` | ✅ Yes |
| `--consolidate` | `consolidated_spritesheet.png` | ✅ Yes |
| Any with `--output` | Your specified name | ✅ Yes (unless `--overwrite`) |

### Metadata Management

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

### Operation Order Optimization

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

### Debug Mode

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

### Headless Linux Operation (v0.6.7.1+)

Ruby Spriter provides completely headless GIMP operation on Linux via Xvfb and Flatpak socket isolation:

```bash
# No GIMP GUI appears during processing
ruby_spriter --image sprite.png --remove-bg --scale 50

# Perfect for server environments
ruby_spriter --batch --dir "sprites/" --remove-bg --max-compress
```

**How it Works:**
- Automatically detects GIMP 3.x Flatpak installation
- Uses Xvfb (X Virtual Framebuffer) to provide virtual display
- Flatpak socket isolation (`--nosocket=x11 --nosocket=wayland`) prevents GUI from appearing
- No configuration required - works automatically

**Use Cases:**
- **Desktop**: No GUI distractions during batch processing
- **Server**: Headless automation on Ubuntu Server, CI/CD pipelines
- **Docker**: Run in containers without display server
- **SSH**: Process sprites remotely without X forwarding

**Requirements:**
- GIMP 3.x via Flatpak (`flatpak install flathub org.gimp.GIMP`)
- Xvfb (`sudo apt install xvfb` on Ubuntu/Debian)

---

## 🏗️ Architecture

### Five Processing Modes

1. **Video Mode** - MP4 → Spritesheet → Optional Processing
2. **Image Mode** - PNG → Processing → Enhanced PNG
3. **Consolidate Mode** - Multiple PNGs → Combined Spritesheet (file list or directory)
4. **Batch Mode** (v0.6.7+) - Directory of MP4s → Multiple Spritesheets → Optional Consolidation
5. **Verify Mode** - Read and display embedded metadata

### Processing Pipeline

**Video Mode:**
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

**Image Mode:**
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

**Consolidate Mode:**
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

**Batch Mode (v0.6.7+):**
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

### Key Components

- **Processor** - Main orchestration
- **VideoProcessor** - FFmpeg integration
- **GimpProcessor** - GIMP batch scripting
- **Consolidator** - Multi-sheet merging (file list or directory)
- **BatchProcessor** (v0.6.7+) - Directory batch processing
- **CompressionManager** (v0.6.7+) - PNG compression with metadata preservation
- **MetadataManager** - PNG metadata handling
- **DependencyChecker** - Tool detection
- **Platform** - Cross-platform abstraction

---

## 🧪 Development

### Setup Development Environment

```bash
# Clone and setup
git clone https://github.com/scooter-indie/ruby-spriter.git
cd ruby-spriter
bundle install

# Run tests
bundle exec rspec

# Run specific test
bundle exec rspec spec/ruby_spriter/processor_spec.rb

# Check code coverage
bundle exec rspec
# Opens coverage/index.html
```

### Project Structure

```
ruby-spriter/
├── bin/
│   └── ruby_spriter          # CLI executable
├── lib/
│   └── ruby_spriter/
│       ├── cli.rb            # Command-line interface
│       ├── processor.rb      # Main orchestration
│       ├── video_processor.rb
│       ├── gimp_processor.rb
│       ├── consolidator.rb
│       ├── batch_processor.rb        # v0.6.7+
│       ├── compression_manager.rb    # v0.6.7+
│       ├── metadata_manager.rb
│       ├── dependency_checker.rb
│       ├── platform.rb
│       └── utils/            # Helper modules
├── spec/                     # RSpec tests (313 examples)
├── .claude/
│   └── agents/               # Custom Claude Code agent config
├── CLAUDE.md                 # Developer documentation
├── CHANGELOG.md              # Version history
└── README.md                 # This file
```

### Running from Source

```bash
# Without installing gem
ruby -Ilib bin/ruby_spriter --video test.mp4

# Or use bundle exec
bundle exec ruby_spriter --video test.mp4
```

---

## 🤝 Contributing

Contributions are welcome! This project follows strict **Test-Driven Development (TDD)** practices.

### Development Workflow

1. **Fork the repository**
2. **Create a feature branch** (`git checkout -b feature/amazing-feature`)
3. **Follow TDD Red-Green-Refactor cycle:**
   - ✅ **Red**: Write ONE test → Run it → Verify it FAILS
   - ✅ **Green**: Write minimal code → Run test → Verify it PASSES
   - ✅ **Refactor**: Clean up → Run all tests → Verify still passing
   - ✅ **Repeat** for each new test
4. **Ensure all tests pass** (`bundle exec rspec`)
5. **Update documentation** (README.md, CHANGELOG.md, CLAUDE.md)
6. **Commit your changes** (`git commit -m 'Add amazing feature'`)
7. **Push to the branch** (`git push origin feature/amazing-feature`)
8. **Open a Pull Request**

### Agent Configuration

This project includes a custom Claude Code agent (`.claude/agents/ruby-spriter-architect.md`) that enforces:
- Strict TDD (Red-Green-Refactor) workflow
- Architecture consistency
- Documentation maintenance
- Cross-platform compatibility
- Test coverage requirements

The agent configuration is version-controlled and shared across the team.

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🔗 Links

- **GitHub**: [https://github.com/scooter-indie/ruby-spriter](https://github.com/scooter-indie/ruby-spriter)
- **Issues**: [https://github.com/scooter-indie/ruby-spriter/issues](https://github.com/scooter-indie/ruby-spriter/issues)
- **Changelog**: [CHANGELOG.md](CHANGELOG.md)

---

## 🙏 Acknowledgments

- **FFmpeg** - Video processing foundation
- **GIMP** - Professional image manipulation
- **ImageMagick** - Metadata and image operations
- **Ruby Community** - Excellent standard library

---

## 📖 See Also

- [CLAUDE.md](CLAUDE.md) - Detailed developer documentation and architecture guide
- [CHANGELOG.md](CHANGELOG.md) - Version history and release notes

---

**Made with ❤️ for game developers**
