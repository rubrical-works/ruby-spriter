# Ruby Spriter v0.7.0.1

[![Ruby](https://img.shields.io/badge/Ruby-2.7+-red.svg)](https://www.ruby-lang.org/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Linux%20%7C%20macOS-lightgrey.svg)]()

**Professional MP4 to Spritesheet Converter with Advanced Image Processing**

A powerful cross-platform Ruby tool for creating high-quality spritesheets from video files and processing them with professional-grade image manipulation. Perfect for game development workflows, particularly with Godot Engine.

---

## ✨ Key Features

- 🎬 **Video to Spritesheet** - Extract frames from MP4 videos using FFmpeg
- 🖼️ **Advanced Image Processing** - Scale, sharpen, and remove backgrounds with precision
- 🎨 **Quality Enhancement** - 5 interpolation methods and configurable unsharp masking
- 🎞️ **Frame-by-Frame Processing** - Process each video frame individually for varying backgrounds (v0.7.0.1+)
- 📐 **Spritesheet Consolidation** - Merge multiple spritesheets vertically
- 📊 **Metadata Management** - Embed, verify, and add grid information to PNG files
- 📦 **Batch Processing** - Process multiple MP4 files in a directory automatically (v0.6.7+)
- 🗜️ **Maximum Compression** - Optimal PNG compression while preserving metadata (v0.6.7+)
- 🌍 **Cross-Platform** - Works seamlessly on Windows, Linux, and macOS
- 🧪 **Production Ready** - Comprehensive RSpec test coverage (512+ tests)

---

## 🚀 Quick Start

### Install

```bash
gem install ruby_spriter
```

### Verify Installation

```bash
ruby_spriter --check-dependencies
```

### Basic Usage

```bash
# Create 4x4 grid with 16 frames
ruby_spriter --video input.mp4

# Remove background
ruby_spriter --video input.mp4 --remove-bg

# Scale and compress
ruby_spriter --video input.mp4 --scale 50 --max-compress

# Batch process entire directory
ruby_spriter --batch --dir "videos/" --remove-bg
```

---

## 📚 Documentation

Complete documentation is organized into focused guides:

| Guide | Purpose |
|-------|---------|
| **[Installation Guide](docs/INSTALLATION.md)** | Prerequisites, installation methods, and verification |
| **[Usage Reference](docs/USAGE.md)** | Complete CLI options and command examples |
| **[Features Overview](docs/FEATURES.md)** | All capabilities and image processing features |
| **[Advanced Features](docs/ADVANCED.md)** | Batch processing, compression, consolidation, etc. |
| **[Architecture Guide](docs/ARCHITECTURE.md)** | System design, processing pipelines, components |
| **[Development Guide](docs/DEVELOPMENT.md)** | Contributing, testing, and development setup |
| **[Use Cases & Examples](docs/USE_CASES.md)** | Real-world scenarios and game development workflows |

---

## 📋 Requirements

### External Dependencies

| Tool | Purpose |
|------|---------|
| **FFmpeg** | Video frame extraction |
| **ImageMagick** | Metadata and image processing |
| **GIMP** | Advanced scaling and background removal |
| **Xvfb** | Virtual display (Linux only) |

### Ruby Version

- Ruby 2.7.0 or higher
- No runtime gem dependencies (uses Ruby standard library)

### Supported Formats

- **Video Input**: MP4 only
- **Image Input/Output**: PNG only

---

## 💡 Common Workflows

### Game Development

```bash
# Character animation for Godot
ruby_spriter --video character_walk.mp4 \
  --frames 16 --columns 4 \
  --scale 50 --remove-bg --sharpen

# VFX effects with high frame count
ruby_spriter --video explosion.mp4 \
  --frames 64 --columns 8 \
  --scale 75 --interpolation nohalo

# Consolidate 8-directional walk cycles
ruby_spriter --consolidate --dir "walk_cycles/" \
  --output character_walk_all.png
```

### Batch Processing

```bash
# Process entire animation library
ruby_spriter --batch --dir "raw_animations/" \
  --outputdir "game_assets/" \
  --scale 50 --remove-bg --max-compress

# Batch with consolidation
ruby_spriter --batch --dir "states/" \
  --batch-consolidate --output character_all.png
```

### Varying Backgrounds

```bash
# Frame-by-frame for videos with changing backgrounds
ruby_spriter --video animation.mp4 \
  --remove-bg --by-frame \
  --frames 32 --columns 8

# Batch process with frame-by-frame
ruby_spriter --batch --dir "animations/" \
  --remove-bg --by-frame --scale 50
```

---

## 🔧 Advanced Features

- **Inner Background Removal** - Remove interior background regions (v0.7.0+)
- **Threshold Stepping** - Process with multiple thresholds for superior edges (v0.7.0+)
- **Ghost Edge Prevention** - Multi-pass cleanup of semi-transparent artifacts (v0.7.0+)
- **Smoke Detection** - Identify and remove transparency gradients (v0.7.0+)
- **Frame Extraction** - Extract specific frames by number (v0.7.0+)
- **Metadata Addition** - Add grid information to external spritesheets (v0.7.0+)
- **Cell-Based Cleanup** - Post-process residual backgrounds per-cell (v0.7.0.1+, experimental)

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🔗 Links

- **GitHub**: [https://github.com/scooter-indie/ruby-spriter](https://github.com/scooter-indie/ruby-spriter)
- **Issues**: [https://github.com/scooter-indie/ruby-spriter/issues](https://github.com/scooter-indie/ruby-spriter/issues)
- **Changelog**: [CHANGELOG.md](CHANGELOG.md)
- **Developer Docs**: [CLAUDE.md](CLAUDE.md)

---

## 🙏 Acknowledgments

- **FFmpeg** - Video processing foundation
- **GIMP** - Professional image manipulation
- **ImageMagick** - Metadata and image operations
- **Ruby Community** - Excellent standard library

---

**Made with ❤️ for game developers**
