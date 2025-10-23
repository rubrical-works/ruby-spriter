
---

### **CHANGELOG.md**
```markdown
# Changelog

All notable changes to Ruby Spriter will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [0.6.2] - 2025-10-22

### ✨ Quality Enhancement & Tooling Release

#### Added
- **Interpolation Options**: 5 interpolation methods for scaling (none, linear, cubic, nohalo, lohalo)
- **Sharpening Support**: Unsharp mask with configurable radius, gain, and threshold
- **`--version` Flag**: Display version, platform, and date information
- **`--check-dependencies` Flag**: Verify all external tools are installed with platform-specific guidance
- **File Extension Validation**: Runtime validation for MP4 (video) and PNG (images)
- **GIMP Investigation Documentation**: Comprehensive documentation of GIMP sharpen attempts and solutions

#### Changed
- **Automatic Operation Order**: Auto-optimize to remove background before scaling for better quality
- **Sharpening via ImageMagick**: Use ImageMagick instead of GIMP for reliable cross-platform sharpening
- **Alpha Channel Preservation**: Use merge instead of flatten to preserve transparency
- **Conservative Sharpen Defaults**: radius: 2.0, gain: 0.5, threshold: 0.03 to minimize halo artifacts
- **Parameter Terminology**: Changed "amount" to "gain" to match ImageMagick documentation

#### Fixed
- **Gem Build Error**: Removed .rb extension from `bin/ruby_spriter` executable
- **Clear Error Messages**: File extension validation provides helpful feedback

#### Documentation
- **README.md**: Added interpolation and sharpening documentation, file format requirements
- **CLAUDE.md**: Updated with new features and validation details
- **GIMP_SHARPEN_INVESTIGATION.md**: Documents 8 failed GIMP attempts and architectural decisions

---

## [0.6.1] - 2025-10-22

### 🎉 Major Refactoring Release

#### Added
- **Modular Architecture**: Split monolithic script into organized modules
- **RSpec Testing Framework**: Comprehensive unit test coverage
- **Dependency Checking**: Automatic validation of external tools
- **Better Error Handling**: Custom exception classes
- **Code Documentation**: Inline comments and YARD-compatible docs
- **SimpleCov Integration**: Code coverage reporting
- **RuboCop Support**: Code style enforcement

#### Changed
- **Project Structure**: Reorganized into `lib/`, `spec/`, and `bin/` directories
- **Class Organization**:
  - `Platform` - Platform detection and configuration
  - `DependencyChecker` - External tool validation
  - `VideoProcessor` - FFmpeg operations
  - `GimpProcessor` - GIMP operations
  - `MetadataManager` - PNG metadata handling
  - `Consolidator` - Spritesheet consolidation
  - `Processor` - Main orchestration
  - `CLI` - Command-line interface
  - Utilities: `PathHelper`, `FileHelper`, `OutputFormatter`

#### Fixed
- Path handling edge cases on Windows
- Improved error messages with actionable guidance
- Better temp file cleanup

#### Developer Experience
- Gemfile for dependency management
- RSpec test suite with fixtures
- Comprehensive README with examples
- Troubleshooting guide
- Contributing guidelines

---

## [0.6.0] - 2024-XX-XX

### Added
- Metadata embedding in PNG files
- Spritesheet consolidation feature
- Metadata verification command (`--verify`)
- Debug mode for troubleshooting

### Changed
- Improved GIMP script generation
- Better cross-platform path handling

---

## [0.5.0] - 2024-XX-XX

### Added
- Background removal with GIMP
- Fuzzy select and global color select options
- Image scaling support
- Configurable operation order

---

## [0.4.0] - 2024-XX-XX

### Added
- Video to spritesheet conversion
- FFmpeg integration
- Customizable grid layouts

---

## [0.1.0] - 2024-XX-XX

### Added
- Initial release
- Basic video processing
- Cross-platform support

---

[0.6.2]: https://github.com/scooter-indie/ruby-spriter/compare/v0.6.1...v0.6.2
[0.6.1]: https://github.com/scooter-indie/ruby-spriter/compare/v0.6.0...v0.6.1
[0.6.0]: https://github.com/scooter-indie/ruby-spriter/releases/tag/v0.6.0
