```markdown
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
```

#### Linux (Ubuntu/Debian)

```bash
# Install Ruby and ffmpeg
sudo apt update
sudo apt install ruby ffmpeg

# Install GIMP 3.x (may require PPA)
sudo add-apt-repository ppa:ubuntuhandbook1/gimp
sudo apt update
sudo apt install gimp

# Download the script
wget https://[your-repo]/video_spritesheet_processor.rb
chmod +x video_spritesheet_processor.rb
```

#### macOS

```bash
# Install Homebrew (if not already installed)
# Visit: https://brew.sh

# Install dependencies
brew install ruby ffmpeg

# Install GIMP 3.x
brew install --cask gimp

# Download the script
# Save as: video_spritesheet_processor.rb
```

### Configuration

#### GIMP Path Setup

The script auto-detects GIMP installation, but you can customize paths if needed. Edit these lines at the top of the script (around line 142):

```ruby
# WINDOWS
GIMP_PATH = 'C:\\Program Files\\GIMP 3\\bin\\gimp-console-3.0.exe'

# LINUX
GIMP_PATH = '/usr/bin/gimp'

# MACOS
GIMP_PATH = '/Applications/GIMP.app/Contents/MacOS/gimp'
```

#### Automatic Path Detection

The script automatically searches these locations:

**Windows:**

- `C:\Program Files\GIMP 3\bin\gimp-console-3.0.exe`
- `C:\Program Files (x86)\GIMP 3\bin\gimp-console-3.0.exe`
- `C:\Program Files\GIMP 2\bin\gimp-console-2.10.exe`

**Linux:**

- `/usr/bin/gimp`
- `/usr/local/bin/gimp`
- `/snap/bin/gimp`
- `/opt/gimp/bin/gimp`

**macOS:**

- `/Applications/GIMP.app/Contents/MacOS/gimp`
- `/Applications/GIMP-2.10.app/Contents/MacOS/gimp`

***

## Usage Guide

### Quick Start Examples

```bash
# Basic spritesheet creation
ruby video_spritesheet_processor.rb --video input.mp4

# With background removal (recommended settings)
ruby video_spritesheet_processor.rb --video input.mp4 --remove-bg --fuzzy --grow 0

# Custom grid layout
ruby video_spritesheet_processor.rb --video input.mp4 --frames 20 --columns 5

# With scaling
ruby video_spritesheet_processor.rb --video input.mp4 --remove-bg --scale 50

# Process existing image
ruby video_spritesheet_processor.rb --image sprite.png --remove-bg --fuzzy --grow 0
```

### Complete Command-Line Reference

#### Input Options

|  Option  |  Description  |  Default  |  Example  |
| --- | --- | --- | --- |
|  `-v, --video FILE`  |  Input video file (MP4)  |  Required*  |  `--video animation.mp4`  |
|  `-i, --image FILE`  |  Input image file (PNG)  |  Required*  |  `--image sprite.png`  |
|  `-o, --output FILE`  |  Output file path  |  Auto-generated  |  `--output result.png`  |

*Either `--video` or `--image` is required.

#### Spritesheet Options

|  Option  |  Description  |  Default  |  Example  |
| --- | --- | --- | --- |
|  `-f, --frames COUNT`  |  Number of frames to extract  |  16  |  `--frames 20`  |
|  `-c, --columns COUNT`  |  Grid columns  |  4  |  `--columns 5`  |
|  `-w, --width PIXELS`  |  Max frame width  |  320  |  `--width 480`  |
|  `-b, --background COLOR`  |  Tile background (black/white)  |  black  |  `--background white`  |

#### GIMP Processing Options

|  Option  |  Description  |  Default  |  Example  |
| --- | --- | --- | --- |
|  `-s, --scale PERCENT`  |  Scale image by percentage  |  None  |  `--scale 50`  |
|  `-r, --remove-bg`  |  Enable background removal  |  Disabled  |  `--remove-bg`  |
|  `-t, --threshold VALUE`  |  Feather radius (0 = sharp)  |  0.0  |  `--threshold 2`  |
|  `-g, --grow PIXELS`  |  Grow/shrink selection  |  1  |  `--grow 0`  |

**Grow Parameter Details:**

- Positive values (1, 2, 3): Expand selection into image
- `0`: No growth (safest for sprites with similar colors to background)
- Negative values (-1, -2): Shrink away from edges (creates safety margin)

**Threshold Parameter Details:**

- `0`: Sharp, crisp edges (no feathering) - Best for pixel art
- `1-2`: Slight smoothing - Good for most sprites
- `3-5`: Moderate smoothing
- `>5`: Heavy smoothing (may create halos)

#### Background Removal Methods

|  Option  |  Description  |  Best For  |
| --- | --- | --- |
|  `--fuzzy`  |  Contiguous select (DEFAULT)  |  Sprites with colors similar to background  |
|  `--no-fuzzy`  |  Global select  |  Backgrounds distinctly different from sprite  |

**Fuzzy Select (Recommended):**

- Samples colors from image corners
- Selects only **connected** regions starting from corners
- Won't jump into sprite interior even if colors match
- Safest option for complex sprites

**Global Color Select:**

- Samples colors from image corners
- Selects **ALL** matching pixels across entire image
- Can affect sprite interior if colors match
- Faster but less precise

#### Operation Order

|  Option  |  Description  |  Use Case  |
| --- | --- | --- |
|  `--order scale_first`  |  Scale then remove background (DEFAULT)  |  Most cases  |
|  `--order bg_first`  |  Remove background then scale  |  When scaling artifacts affect edges  |

#### Preset Configurations

|  Preset  |  Grid  |  Frames  |  Width  |  Use Case  |
| --- | --- | --- | --- | --- |
|  `--preset thumbnail`  |  3x3  |  9  |  240px  |  Quick video previews  |
|  `--preset preview`  |  4x4  |  16  |  400px  |  Video thumbnails  |
|  `--preset detailed`  |  10x5  |  50  |  320px  |  Detailed contact sheets  |
|  `--preset contact`  |  8x8  |  64  |  160px  |  High-density overviews  |

#### Debug Options

|  Option  |  Description  |
| --- | --- |
|  `--debug`  |  Verbose output + keep temp files  |
|  `--keep-temp`  |  Keep temporary files for debugging  |
|  `-h, --help`  |  Show help message  |

***

## Common Use Cases & Examples

### Example 1: Game Animation Spritesheet

**Scenario:** Character walking animation for 2D game

```bash
ruby video_spritesheet_processor.rb \
  --video character_walk.mp4 \
  --frames 8 \
  --columns 4 \
  --width 256 \
  --remove-bg \
  --fuzzy \
  --grow 0 \
  --output walk_sprite.png
```

**Result:** 4x2 grid with 8 frames, clean transparent background, 256px frame width

***

### Example 2: Video Preview Grid

**Scenario:** Create thumbnail grid from movie

```bash
ruby video_spritesheet_processor.rb \
  --video movie.mp4 \
  --preset preview \
  --output movie_preview.png
```

**Result:** 4x4 grid with 16 evenly distributed frames across the video

***

### Example 3: Pixel Art Sprite

**Scenario:** Pixel art character with crisp edges

```bash
ruby video_spritesheet_processor.rb \
  --video pixel_character.mp4 \
  --frames 12 \
  --columns 6 \
  --width 128 \
  --remove-bg \
  --fuzzy \
  --grow 0 \
  --threshold 0 \
  --scale 200 \
  --output pixel_sprite_2x.png
```

**Result:** Crisp pixel art at 2x scale with sharp edges and transparent background

***

### Example 4: High-Detail Contact Sheet

**Scenario:** Video analysis with many frames

```bash
ruby video_spritesheet_processor.rb \
  --video footage.mp4 \
  --preset detailed \
  --output contact_sheet.png
```

**Result:** 10x5 grid with 50 frames evenly distributed

***

### Example 5: Scaled Sprite with Background Removal

**Scenario:** Create sprite then scale down for optimization

```bash
ruby video_spritesheet_processor.rb \
  --video animation.mp4 \
  --remove-bg \
  --fuzzy \
  --grow 0 \
  --scale 50 \
  --order bg_first \
  --output small_sprite.png
```

**Result:** Background removed first, then scaled to 50%

***

### Example 6: Process Existing Spritesheet

**Scenario:** Remove background from already-created spritesheet

```bash
ruby video_spritesheet_processor.rb \
  --image existing_sprite.png \
  --remove-bg \
  --fuzzy \
  --grow 0 \
  --output cleaned_sprite.png
```

**Result:** Background removed from existing image file

***

### Example 7: Custom Wide Layout

**Scenario:** Long horizontal spritesheet

```bash
ruby video_spritesheet_processor.rb \
  --video animation.mp4 \
  --frames 16 \
  --columns 16 \
  --width 128 \
  --remove-bg \
  --fuzzy \
  --output horizontal_strip.png
```

**Result:** Single row with 16 frames (16x1 grid)

***

### Example 8: Batch Processing Multiple Videos

**Scenario:** Process entire folder of videos

```bash
#!/bin/bash
# batch_process.sh

for video in *.mp4; do
  echo "Processing $video..."
  ruby video_spritesheet_processor.rb \
    --video "$video" \
    --remove-bg \
    --fuzzy \
    --grow 0 \
    --output "${video%.mp4}_sprite.png"
done
```

***

## Troubleshooting & Solutions

### Problem: GIMP Not Found

**Error Message:**

```javascript
ERROR: GIMP 3.x not found!
```

**Solutions:**

1. **Install GIMP 3.x:**

- Windows: https://www.gimp.org/downloads/
- Linux: `sudo apt install gimp` (may need PPA for 3.x)
- macOS: `brew install --cask gimp`

2. **Edit Script Path:**

```ruby
   # Line ~142 in script
   GIMP_PATH = '/your/custom/path/to/gimp'
```

3. **Verify Installation:**

```bash
   # Windows
   where gimp
   
   # Linux/Mac
   which gimp
   gimp --version
```

***

### Problem: ffmpeg Not Found

**Error Message:**

```javascript
ERROR: ffmpeg not found!
```

**Solutions by Platform:**

**Windows:**

```powershell
choco install ffmpeg
# OR download from: https://ffmpeg.org/download.html
```

**Linux:**

```bash
sudo apt install ffmpeg
```

**macOS:**

```bash
brew install ffmpeg
```

**Verify Installation:**

```bash
ffmpeg -version
```

***

### Problem: Background Removal Too Aggressive

**Symptom:** Script removes pixels from inside sprite

**Solution 1: Use Fuzzy Select with No Growth**

```bash
ruby video_spritesheet_processor.rb \
  --video sprite.mp4 \
  --remove-bg \
  --fuzzy \
  --grow 0
```

**Solution 2: Shrink Selection**

```bash
ruby video_spritesheet_processor.rb \
  --video sprite.mp4 \
  --remove-bg \
  --fuzzy \
  --grow -1  # Shrinks away from sprite edges
```

**Solution 3: Disable Feathering**

```bash
ruby video_spritesheet_processor.rb \
  --video sprite.mp4 \
  --remove-bg \
  --fuzzy \
  --threshold 0  # Sharp edges only
  --grow 0
```

***

### Problem: Halo Around Sprite Edges

**Symptom:** Light-colored outline around sprite

**Cause:** Too much feathering (threshold too high)

**Solution:**

```bash
# Remove feathering completely
ruby video_spritesheet_processor.rb \
  --video sprite.mp4 \
  --remove-bg \
  --fuzzy \
  --threshold 0 \
  --grow 0
```

***

### Problem: Background Not Fully Removed

**Symptom:** Some background pixels remain

**Solution 1: Increase Grow Value**

```bash
ruby video_spritesheet_processor.rb \
  --video sprite.mp4 \
  --remove-bg \
  --fuzzy \
  --grow 2  # Expand selection further
```

**Solution 2: Use Global Color Select**

```bash
ruby video_spritesheet_processor.rb \
  --video sprite.mp4 \
  --remove-bg \
  --no-fuzzy  # Select all matching colors
  --grow 1
```

**Solution 3: Add Slight Feathering**

```bash
ruby video_spritesheet_processor.rb \
  --video sprite.mp4 \
  --remove-bg \
  --fuzzy \
  --threshold 1  # Catch edge pixels
  --grow 1
```

***

### Problem: Video Format Not Supported

**Symptom:** Error loading video

**Solution:**

- Convert to MP4 first using ffmpeg:

```bash
ffmpeg -i input.avi -c:v libx264 -crc a:a aac output.mp4
```

***

### Using Debug Mode

Enable verbose output to diagnose any issue:

```bash
ruby video_spritesheet_processor.rb \
  --video sprite.mp4 \
  --remove-bg \
  --debug
```

**Debug output includes:**

- Platform detection
- GIMP executable path used
- ffmpeg commands executed
- GIMP Python script content
- Temporary file locations
- Full error messages with stack traces

**Temporary files preserved in debug mode:**

- Python scripts: `%TEMP%/gimp_script_*.py`
- Log files: `%TEMP%/gimp_log_*.txt`
- Batch files (Windows): `%TEMP%/gimp_run_*.bat`

***

## Optimal Settings by Use Case

### Game Sprites (Pixel Art)

```bash
--remove-bg --fuzzy --grow 0 --threshold 0 --scale 200
```

- Sharp edges preserved
- No feathering
- Safe for interior pixels
- 2x upscaling

### Game Sprites (Hi-Res/Smooth)

```bash
--remove-bg --fuzzy --grow 0 --threshold 1
```

- Slight edge smoothing
- Prevents interior removal
- Professional appearance

### Video Thumbnails

```bash
--preset preview
```

- No background removal needed
- Fast processing
- Good overview

### Animation Sheets

```bash
--frames 16 --columns 4 --remove-bg --fuzzy --grow 0
```

- Standard 4x4 layout
- Clean backgrounds
- Safe processing

### Contact Sheets (Analysis)

```bash
--preset detailed --width 640
```

- Many frames
- High resolution
- No post-processing

### Transparent Sprites (Complex)

```bash
--remove-bg --fuzzy --grow 0 --threshold 0
```

- Maximum precision
- No accidental removal
- Sharp edges

***

## Performance Tips

**For Large Videos:**

```bash
# Reduce frame count
--frames 12 --columns 3

# Reduce frame width
--width 240
```

**For High Quality:**

```bash
# Increase resolution
--width 640

# More frames
--frames 30 --columns 6
```

**Speed vs Quality Trade-offs:**

- Fewer frames = Faster processing
- Smaller frame width = Faster processing
- No background removal = Fastest
- Fuzzy select = Slower than global (but safer)

***

## Known Limitations & Notes

### Current Limitations

1. **Video Formats:** Primarily tested with MP4 (other formats supported via ffmpeg)
2. **Image Output:** PNG only (preserves transparency)
3. **GIMP Version:** Requires GIMP 3.x (not compatible with 2.x Python API)
4. **Background Removal:** Works best with solid or gradient backgrounds
5. **Performance:** Processing time increases with frame count and resolution
6. **Platform:** Ruby must be installed (not standalone executable)

### Important Notes

- **Temporary Files:** Automatically cleaned up unless `--keep-temp` or `--debug` used
- **File Naming:** Output files auto-named as `{input}_spritesheet.png`
- **Overwriting:** Use `-y` flag with ffmpeg (automatic, no prompts)
- **Path Spaces:** Script handles paths with spaces automatically
- **Memory Usage:** Large frame counts with high resolution may use significant RAM

***

## FAQ

**Q: Can I use videos other than MP4?**  
A: Yes, any format supported by ffmpeg (AVI, MOV, MKV, WebM, etc.)

**Q: Why do I need GIMP 3.x and not 2.x?**  
A: The Python API changed significantly. GIMP 3.x uses different procedure names and Gio library.

**Q: Can I remove backgrounds from existing spritesheets?**  
A: Yes! Use `--image` instead of `--video`: `--image existing.png --remove-bg`

**Q: How do I adjust if background removal is too aggressive?**  
A: Use `--fuzzy --grow 0` or `--grow -1` to shrink away from sprite edges.

**Q: What if my sprite has the same color as the background?**  
A: Use `--fuzzy` mode which only selects connected regions from corners.

**Q: Can I process multiple videos at once?**  
A: Yes, use a shell script loop (see Example 8 above).

**Q: How do I get sharp pixel-art edges?**  
A: Use `--threshold 0 --grow 0` to disable feathering and prevent bleeding.

**Q: The script is slow, how can I speed it up?**  
A: Reduce `--frames` count, decrease `--width`, or skip `--remove-bg`.

**Q: What's the difference between fuzzy and global select?**  
A: Fuzzy only selects connected regions (safer), global selects all matching colors (faster but riskier).

**Q: Can I customize the GIMP path?**  
A: Yes, edit the `GIMP_PATH` constant at line ~142 in the script.

**Q: Does it work with animated GIFs?**  
A: Convert GIF to MP4 first: `ffmpeg -i input.gif output.mp4`

**Q: How much disk space do I need?**  
A: Minimal - temporary files cleaned automatically. Final PNG size depends on frame count and resolution.

***

## Version History

### v0.5 (Current Release - October 2025)

**Major Features Added:**

- ✨ Cross-platform support (Windows, Linux, macOS)
- ✨ Fuzzy select vs. global color select background removal methods
- ✨ Adjustable grow/shrink selection parameters
- ✨ Feathering control for edge smoothness
- ✨ Operation order control (scale first vs bg removal first)
- ✨ Preset configurations for common use cases
- ✨ ffmpeg-only spritesheet creation (removed ImageMagick dependency)
- ✨ Direct spritesheet assembly with zero padding

**Improvements:**

- 🔧 Automatic platform detection
- 🔧 GIMP path auto-detection with intelligent fallbacks
- 🔧 Enhanced error messages with actionable solutions
- 🔧 Cleaner edge handling (no halo artifacts)
- 🔧 No white box padding artifacts
- 🔧 Better temporary file management
- 🔧 Comprehensive debug mode

**Bug Fixes:**

- 🐛 Fixed path handling across different platforms
- 🐛 Fixed Python/Ruby boolean conversion (true vs True)
- 🐛 Fixed file extension handling (.mp4 → .png)
- 🐛 Fixed temporary file cleanup on all platforms
- 🐛 Fixed GIMP 3.x API compatibility issues
- 🐛 Fixed string interpolation syntax errors

**Breaking Changes:**

- Requires GIMP 3.x (not backward compatible with 2.x)
- ImageMagick no longer required
- Default background is now transparent (use `--background black` for old behavior)

***


### License

This project is released under the MIT License.

```javascript
MIT License

Copyright (c) 2025 Video Spritesheet Processor Contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

### Support & Community

**Getting Help:**

- Review this README thoroughly
- Use `--debug` flag for detailed error output
- Check the Troubleshooting section
- Review FAQ for common questions

**Reporting Issues:**

- Include platform (Windows/Linux/macOS)
- Include Ruby version: `ruby --version`
- Include GIMP version: `gimp --version`
- Include complete error message
- Include command used
- Use `--debug` and include output

**Feature Requests:**

- Describe use case clearly
- Explain expected behavior
- Provide example inputs/outputs if possible

### Acknowledgments

This project builds upon excellent open-source tools:

- **ffmpeg** - Comprehensive video processing framework
- **GIMP** - Powerful cross-platform image manipulation
- **Ruby** - Elegant and expressive scripting language
- **Open Source Community** - For continuous inspiration and support

Special thanks to all contributors and users who help improve this tool.

***

## Quick Reference Card

### Essential Commands

```bash
# Basic spritesheet
ruby video_spritesheet_processor.rb --video input.mp4

# Game sprite (recommended)
ruby video_spritesheet_processor.rb --video input.mp4 --remove-bg --fuzzy --grow 0

# Pixel art (sharp edges)
ruby video_spritesheet_processor.rb --video input.mp4 --remove-bg --fuzzy --grow 0 --threshold 0

# Video preview
ruby video_spritesheet_processor.rb --video input.mp4 --preset preview

# Custom layout
ruby video_spritesheet_processor.rb --video input.mp4 --frames 20 --columns 5 --width 480

# Process existing image
ruby video_spritesheet_processor.rb --image sprite.png --remove-bg --fuzzy --grow 0

# Debug mode
ruby video_spritesheet_processor.rb --video input.mp4 --remove-bg --debug
```

### Common Parameters

|  What You Want  |  Parameters  |
| --- | --- |
|  Clean sprite edges  |  `--remove-bg --fuzzy --grow 0 --threshold 0`  |
|  Smooth sprite edges  |  `--remove-bg --fuzzy --grow 0 --threshold 1`  |
|  Fast preview  |  `--preset preview`  |
|  Detailed analysis  |  `--preset detailed`  |
|  Small file size  |  `--width 240 --scale 50`  |
|  High quality  |  `--width 640 --frames 30`  |
|  Pixel perfect  |  `--threshold 0 --grow 0`  |
|  Safe processing  |  `--fuzzy --grow 0`  |

***

**Version:** 0.5  
**Release Date:** October 2025  
**Compatibility:** Windows 10+, Linux (Ubuntu 20.04+), macOS 11+  
**Ruby Version:** 2.7+  
**GIMP Version:** 3.0+  
**ffmpeg Version:** 4.0+  

**Project Status:** ✅ Stable Release  
**Maintenance:** 🟢 Actively Maintained  

***

Made with ❤️ for game developers, animators, video editors, and content creators worldwide.

