# frozen_string_literal: true

require_relative 'lib/ruby_spriter/version'

Gem::Specification.new do |spec|
  spec.name          = 'ruby_spriter'
  spec.version       = RubySpriter::VERSION
  spec.authors       = ['scooter-indie']
  spec.email         = ['scooter-indie@users.noreply.github.com']

  spec.summary       = 'MP4 to Spritesheet converter with GIMP image processing'
  spec.description   = <<~DESC
    Ruby Spriter is a cross-platform tool for creating spritesheets from video files
    and processing them with GIMP. Features include background removal, scaling,
    consolidation, and metadata management.
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
