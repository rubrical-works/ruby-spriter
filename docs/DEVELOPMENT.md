# Development Guide

## Setup Development Environment

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

---

## Project Structure

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
│       ├── cell_cleanup_processor.rb    # v0.7.0.1+
│       ├── cell_cleanup_config.rb       # v0.7.0.1+
│       ├── cell_cleanup_gimp_script.rb  # v0.7.0.1+
│       ├── consolidator.rb
│       ├── batch_processor.rb        # v0.6.7+
│       ├── compression_manager.rb    # v0.6.7+
│       ├── metadata_manager.rb
│       ├── dependency_checker.rb
│       ├── platform.rb
│       └── utils/            # Helper modules
│           ├── path_helper.rb
│           ├── file_helper.rb
│           ├── output_formatter.rb
│           └── image_helper.rb
├── spec/                     # RSpec tests (512+ examples)
│   ├── unit/                 # Unit tests
│   │   ├── cell_cleanup_config_spec.rb
│   │   ├── cell_cleanup_gimp_script_spec.rb
│   │   └── cell_cleanup_processor_spec.rb
│   ├── ruby_spriter/         # Integration tests
│   ├── fixtures/             # Test data and media files
│   └── spec_helper.rb
├── docs/                     # Documentation
│   ├── INSTALLATION.md
│   ├── USAGE.md
│   ├── FEATURES.md
│   ├── ADVANCED.md
│   ├── ARCHITECTURE.md
│   ├── DEVELOPMENT.md
│   └── USE_CASES.md
├── .claude/
│   ├── agents/               # Custom Claude Code agent config
│   └── settings.local.json
├── CLAUDE.md                 # Developer documentation
├── CHANGELOG.md              # Version history
├── README.md                 # Project overview
└── ruby_spriter.gemspec      # Gem specification
```

---

## Running from Source

```bash
# Without installing gem
ruby -Ilib bin/ruby_spriter --video test.mp4

# Or use bundle exec
bundle exec ruby_spriter --video test.mp4
```

---

## Code Quality

Ruby Spriter follows strict development practices:

- **Test-Driven Development (TDD)**: All features developed using RED-GREEN-REFACTOR cycle
- **High Test Coverage**: 512+ examples with comprehensive unit and integration tests
- **Performance Optimization**: Continuous refactoring to eliminate redundancy and improve efficiency
  - Example: BatchProcessor refactoring (v0.7.0.1) achieved 20× reduction in dependency checks
- **Architectural Consistency**: Shared patterns across Processor and BatchProcessor classes
- **Code Reviews**: Regular analysis to identify and eliminate duplication

### Running Tests

```bash
# Run all tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/ruby_spriter/processor_spec.rb

# Run specific test by line
bundle exec rspec spec/ruby_spriter/processor_spec.rb:42

# Run with coverage report
COVERAGE=true bundle exec rspec

# Run linter
bundle exec rubocop
```

---

## Contributing

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

### Testing Best Practices

- **Mock External Commands**: Use Open3.capture3 mocking to avoid requiring FFmpeg/GIMP/ImageMagick
- **Unit Tests**: Test individual methods in isolation
- **Integration Tests**: Test workflow combinations
- **Edge Cases**: Test error conditions and boundary conditions
- **Clear Naming**: Test names describe what is being tested and expected outcome

### Code Style

- Follow Ruby conventions
- Use meaningful variable names
- Keep methods focused and testable
- Add comments for complex logic
- Maintain consistent indentation (2 spaces)

---

## Agent Configuration

This project includes a custom Claude Code agent (`.claude/agents/ruby-spriter-architect.md`) that enforces:
- Strict TDD (Red-Green-Refactor) workflow
- Architecture consistency
- Documentation maintenance
- Cross-platform compatibility
- Test coverage requirements

The agent configuration is version-controlled and shared across the team.

---

## Key Development Areas

### Cell-Based Background Cleanup (v0.7.0.1)

Key files involved:
- `lib/ruby_spriter/cell_cleanup_processor.rb` - Main orchestration
- `lib/ruby_spriter/cell_cleanup_config.rb` - Configuration validation
- `lib/ruby_spriter/cell_cleanup_gimp_script.rb` - GIMP script generation
- `spec/unit/cell_cleanup_*_spec.rb` - Unit tests (21 tests)

Features:
- Per-cell dominant color detection (ImageMagick histogram)
- GIMP Python-fu script generation for color removal
- Spritesheet reassembly with montage
- Progress reporting and statistics

Known Issues (Deferred to v0.7.0.2):
- Feature executes but doesn't effectively remove backgrounds
- Performance exceeds <30% target
- PNG metadata embedding not implemented

### Frame-by-Frame Processing (v0.7.0.1)

Key files involved:
- `lib/ruby_spriter/video_processor.rb` - Extract frames and process individually
- `lib/ruby_spriter/processor.rb` - Integration with main workflow

Features:
- Extract frames from video
- Remove background from each frame individually
- Reassemble spritesheet from processed frames
- Metadata indicates processing_mode: by-frame

### Batch Processing (v0.6.7+)

Key files involved:
- `lib/ruby_spriter/batch_processor.rb` - Directory processing
- Cached dependency checking
- Unique filename enforcement
- Optional consolidation

---

## Debugging Tips

### Enable Debug Mode

```bash
bundle exec ruby_spriter --video input.mp4 --debug

# Shows:
# - Dependency check results
# - Temp directory location
# - GIMP script paths
# - ImageMagick commands
# - Processing timestamps
```

### Keep Temporary Files

```bash
bundle exec ruby_spriter --video input.mp4 --keep-temp

# Preserves:
# - Extracted frames
# - GIMP scripts
# - Intermediate images
# - Temp directory path printed to console
```

### Run Specific Tests with Verbose Output

```bash
bundle exec rspec spec/ruby_spriter/processor_spec.rb -f d

# -f d: documentation format (shows test names)
# -f p: progress format (default)
# -f j: JSON output
```

---

## Performance Profiling

```bash
# Measure processing time
time bundle exec ruby_spriter --video input.mp4 --scale 50

# Profile with Ruby's built-in profiler
ruby -p -Ilib bin/ruby_spriter --video input.mp4
```

---

## Common Development Tasks

### Add a New Feature

1. Create failing test in appropriate spec file
2. Implement minimal code to make test pass
3. Refactor for clarity and efficiency
4. Update CHANGELOG.md
5. Update docs if user-facing

### Fix a Bug

1. Create test that reproduces the bug
2. Verify test fails
3. Implement fix
4. Verify test passes
5. Check no regressions in other tests
6. Update CHANGELOG.md

### Refactor Existing Code

1. Ensure all tests pass before refactoring
2. Refactor while keeping tests passing
3. Run full test suite after refactoring
4. Commit refactoring separately from feature work

---

**Next Steps:**
- [Architecture Guide](ARCHITECTURE.md) - Understand system design
- [Features Overview](FEATURES.md) - Learn all capabilities
- [Installation Guide](INSTALLATION.md) - Set up for development
