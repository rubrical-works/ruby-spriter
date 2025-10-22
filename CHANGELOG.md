
---

### **CHANGELOG.md**
```markdown
# Changelog

All notable changes to Ruby Spriter will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[0.6.1]: https://github.com/scooter-indie/ruby-spriter/compare/v0.6.0...v0.6.1
[0.6.0]: https://github.com/scooter-indie/ruby-spriter/releases/tag/v0.6.0
