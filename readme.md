# Video Spritesheet Processor v0.5

A cross-platform Ruby script that converts MP4 videos into spritesheets and provides advanced image processing capabilities using ffmpeg and GIMP 3.x.

---

## Overview

**Video Spritesheet Processor** extracts frames from videos and arranges them into customizable grid-based spritesheets. It features intelligent background removal, image scaling, and works seamlessly across Windows, Linux, and macOS.

### Key Features

✨ **Core Functionality**
- Extract frames from MP4 videos at precise intervals
- Create customizable grid-based spritesheets using ffmpeg
- Intelligent background removal using GIMP 3.x
- Image scaling and resizing
- Batch operations support

🎯 **Advanced Background Removal**
- **Fuzzy Select** (contiguous): Only removes connected background regions (recommended)
- **Global Color Select**: Removes all matching colors across entire image
- Adjustable feathering for smooth edges
- Grow/shrink selection controls for precision
- No white boxes or padding artifacts

🖥️ **Cross-Platform Support**
- Windows (10/11)
- Linux (Ubuntu, Debian, Arch, etc.)
- macOS
- Automatic platform detection and path handling

⚙️ **Flexible Configuration**
- Command-line driven with sensible defaults
- Preset configurations for common use cases
- Customizable frame count, grid layout, and dimensions
- Operation order control (scale then remove background, or vice versa)

---

## Requirements & Installation

### Software Dependencies

| Tool | Purpose | Version | Installation |
|------|---------|---------|--------------|
| **Ruby** | Script interpreter | 2.7+ | See platform instructions below |
| **ffmpeg** | Video processing | 4.0+ | See platform instructions below |
| **ffprobe** | Video analysis | 4.0+ | Included with ffmpeg |
| **GIMP** | Image processing | 3.0+ | See platform instructions below |

### Installation by Platform

#### Windows

```powershell
# Install Chocolatey (if not already installed)
# Visit: https://chocolatey.org/install

# Install dependencies
choco install ruby ffmpeg

# Install GIMP 3.x manually from:
# https://www.gimp.org/downloads/

# Download the script
# Save as: video_spritesheet_processor.rb
