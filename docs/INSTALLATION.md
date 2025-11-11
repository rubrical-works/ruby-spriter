# Installation Guide

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

## 🚀 Prerequisites Installation

Ruby Spriter requires these external tools for video and image processing:

| Tool | Purpose | Version |
|------|---------|---------|
| **FFmpeg** | Video frame extraction | Any recent version |
| **ImageMagick** | Image manipulation & metadata | 7.x or 6.9+ |
| **GIMP** | Advanced image processing | 3.x (or 2.10) |
| **Xvfb** | Virtual display (Linux only) | Any recent version |

### Installing Prerequisites

#### Windows (Chocolatey - Recommended)

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

#### Alternative: Manual Installation on Windows

If you prefer not to use Chocolatey:
- **Ruby**: Download from [rubyinstaller.org](https://rubyinstaller.org/)
- **FFmpeg**: Download from [ffmpeg.org](https://ffmpeg.org/download.html)
- **ImageMagick**: Download from [imagemagick.org](https://imagemagick.org/script/download.php#windows)
- **GIMP**: Download from [gimp.org](https://www.gimp.org/downloads/)

#### macOS (Homebrew)

```bash
# Install Homebrew if not already installed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Ruby (if not already installed)
brew install ruby

# Install Ruby Spriter dependencies
brew install ffmpeg imagemagick gimp
```

#### Linux (Ubuntu/Debian)

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

#### Linux (Fedora/RHEL)

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

## Installation Methods

### 📦 Option A: RubyGems (Recommended)

Install the published gem from RubyGems.org:

```bash
gem install ruby_spriter
```

**Requirements**: Ruby 2.7 or higher
**Best for**: All platforms (Windows, macOS, Linux), automated workflows

---

### 🛠️ Option B: From Source (Development)

Clone and build from source:

```bash
# Clone repository
git clone https://github.com/scooter-indie/ruby-spriter.git
cd ruby-spriter

# Install development dependencies
bundle install

# Build and install gem locally
gem build ruby_spriter.gemspec
gem install ruby_spriter-0.7.0.1.gem
```

**Best for**: Contributors, developers wanting latest code

---

## Verify Installation

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

**Next Steps:**
- [Usage Guide](USAGE.md) - Learn command-line options
- [Features Overview](FEATURES.md) - Explore capabilities
- [Quick Start](../README.md#-quick-start) - Get started immediately
