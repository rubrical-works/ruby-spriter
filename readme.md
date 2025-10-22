# Ruby Spriter v0.6.1 (Unstable)

[![Ruby](https://img.shields.io/badge/Ruby-2.7+-red.svg)](https://www.ruby-lang.org/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Linux%20%7C%20macOS-lightgrey.svg)]()

**MP4 to Spritesheet + GIMP Image Processing**

A powerful cross-platform Ruby tool for creating spritesheets from video files and processing them with GIMP. Perfect for game development workflows, particularly with Godot Engine.

---

## 🎯 Features

### Core Capabilities
- ✅ **Video to Spritesheet** - Extract frames from MP4 videos using FFmpeg
- ✅ **GIMP Image Processing** - Scale and remove backgrounds with precision
- ✅ **Spritesheet Consolidation** - Merge multiple spritesheets vertically
- ✅ **Metadata Management** - Embed and read grid information in PNG files
- ✅ **Cross-Platform** - Works on Windows, Linux, and macOS
- ✅ **Modular Architecture** - Clean, testable, maintainable codebase
- ✅ **RSpec Testing** - Comprehensive test coverage

### Processing Options
- **Background Removal**
  - Fuzzy Select (contiguous regions)
  - Global Color Select (all matching pixels)
  - Adjustable selection growth and feathering
- **Image Scaling** - Percentage-based resizing
- **Configurable Operation Order** - Scale-first or background-removal-first
- **Preset Configurations** - Thumbnail, preview, detailed, contact sheet layouts

---

## 📋 Requirements

### External Dependencies

#### **Required Tools**

| Tool | Version | Purpose |
|------|---------|---------|
| **FFmpeg** | Latest | Video frame extraction and spritesheet creation |
| **FFprobe** | Latest | Video duration analysis (included with FFmpeg) |
| **ImageMagick** | 7.x+ | Metadata management and consolidation |
| **GIMP** | 3.x (or 2.10) | Image processing (scaling, background removal) |

#### **Ruby Version**
- Ruby 2.7.0 or higher

---

## 🚀 Installation

### Step 1: Install External Dependencies

#### **Windows (using Chocolatey)**
```powershell
# Install Chocolatey if not already installed
# See: https://chocolatey.org/install

# Install dependencies
choco install ffmpeg imagemagick gimp -y
