# frozen_string_literal: true

require_relative 'lib/ruby_spriter/version'

Gem::Specification.new do |spec|
  spec.name          = 'ruby_spriter'
  spec.version       = RubySpriter::VERSION
  spec.authors       = ['scooter-indie']
  spec.email         = ['scooter-indie@users.noreply.github.com']

  spec.summary       = 'Professional MP4 to Spritesheet converter with advanced GIMP image processing'
  spec.description   = <<~DESC
    Ruby Spriter is a cross-platform tool for creating professional spritesheets from video files
    with advanced GIMP image processing. Features include edge-based and inner background removal,
    multi-threshold processing, ghost edge prevention, smoke detection, scaling with multiple
    interpolation methods, sharpening, batch processing, spritesheet consolidation, frame extraction,
    and comprehensive metadata management. Designed for game development workflows with Godot Engine.
  DESC
  spec.homepage      = 'https://github.com/scooter-indie/ruby-spriter'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 2.7.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/scooter-indie/ruby-spriter'
  spec.metadata['changelog_uri'] = 'https://github.com/scooter-indie/ruby-spriter/blob/main/CHANGELOG.md'

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.glob('{bin,lib,spec}/**/*') + %w[
    README.md
    CHANGELOG.md
    LICENSE
    Gemfile
    ruby_spriter.gemspec
    .rspec
  ]

  spec.bindir        = 'bin'
  spec.executables   = ['ruby_spriter']
  spec.require_paths = ['lib']

  # Runtime dependencies (none - uses only standard library + external tools)
  
  # Development dependencies are in Gemfile
end
