# Ruby Spriter v0.6.3

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
- 📐 **Spritesheet Consolidation** - Merge multiple spritesheets vertically
- 📊 **Metadata Management** - Embed and verify grid information in PNG files
- 🌍 **Cross-Platform** - Works seamlessly on Windows, Linux, and macOS
- 🧪 **Production Ready** - Comprehensive RSpec test coverage

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

### Ruby Version
- Ruby 2.7.0 or higher
- No runtime gem dependencies (uses Ruby standard library)

### Supported File Formats
- **Video Input**: MP4 only
- **Image Input/Output**: PNG only

---

## 🚀 Installation

### Step 1: Install External Dependencies

#### **Windows (using Chocolatey)**
```powershell
# Install Chocolatey if needed: https://chocolatey.org/install

choco install ffmpeg imagemagick gimp -y
```

#### **macOS (using Homebrew)**
```bash
brew install ffmpeg imagemagick gimp
```

#### **Linux (Ubuntu/Debian)**
```bash
sudo apt update
sudo apt install ffmpeg imagemagick gimp -y
```

### Step 2: Install Ruby Spriter

#### **Option A: Install as Gem (when published)**
```bash
gem install ruby_spriter
```

#### **Option B: Install from Source**
```bash
# Clone repository
git clone https://github.com/scooter-indie/ruby-spriter.git
cd ruby-spriter

# Install development dependencies
bundle install

# Build and install gem locally
gem build ruby_spriter.gemspec
gem install ruby_spriter-0.6.3.gem
```

### Step 3: Verify Installation

```bash
# Check Ruby Spriter installation
ruby_spriter --version

# Check all external dependencies
ruby_spriter --check-dependencies
```

The `--check-dependencies` command will verify that FFmpeg, FFprobe, ImageMagick, and GIMP are properly installed and accessible. It displays:
- ✅ Tool found with version/path information
- ❌ Tool missing with platform-specific installation commands

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

### Advanced Workflows
```bash
# Complete processing pipeline
ruby_spriter --video input.mp4 \
  --frames 64 --columns 8 \
  --scale 50 --interpolation nohalo \
  --remove-bg \
  --sharpen --sharpen-gain 0.8

# Process existing image with quality enhancement
ruby_spriter --image large_sprite.png \
  --scale 50 --interpolation lohalo \
  --sharpen --sharpen-gain 1.2

# Consolidate multiple spritesheets
ruby_spriter --consolidate file1.png,file2.png,file3.png \
  --output combined.png
```

---

## 📚 Usage

### Command-Line Options

#### **Input Options**
```bash
-v, --video FILE              Input video file (MP4 only)
-i, --image FILE              Input image file (PNG only)
    --consolidate FILES       Consolidate multiple spritesheets (PNG only, comma-separated)
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

#### **Other Options**
```bash
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
# Consolidate walk cycles for 8 directions
ruby_spriter --consolidate \
  walk_n.png,walk_ne.png,walk_e.png,walk_se.png,\
  walk_s.png,walk_sw.png,walk_w.png,walk_nw.png \
  --output character_walk_all.png
```

### Quality Enhancement
```bash
# Downscale high-res renders while maintaining sharpness
ruby_spriter --image 4k_sprite.png \
  --scale 25 --interpolation lohalo \
  --sharpen --sharpen-gain 1.0 \
  --output hd_sprite.png
```

---

## 🔧 Advanced Features

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

---

## 🏗️ Architecture

### Four Processing Modes

1. **Video Mode** - MP4 → Spritesheet → Optional Processing
2. **Image Mode** - PNG → Processing → Enhanced PNG
3. **Consolidate Mode** - Multiple PNGs → Combined Spritesheet
4. **Verify Mode** - Read and display embedded metadata

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
Multiple Input PNGs
    ↓
[ImageMagick] Read Metadata from Each
    ↓
[ImageMagick] Validate Column Compatibility
    ↓
[ImageMagick] Vertical Stacking (append)
    ↓
[ImageMagick] Embed Combined Metadata
    ↓
Output Consolidated PNG
```

### Key Components

- **Processor** - Main orchestration
- **VideoProcessor** - FFmpeg integration
- **GimpProcessor** - GIMP batch scripting
- **Consolidator** - Multi-sheet merging
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
│       ├── metadata_manager.rb
│       ├── dependency_checker.rb
│       ├── platform.rb
│       └── utils/            # Helper modules
├── spec/                     # RSpec tests
├── CLAUDE.md                 # Developer documentation
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

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Write tests for your changes
4. Ensure all tests pass (`bundle exec rspec`)
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

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
