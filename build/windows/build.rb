# frozen_string_literal: true

# Windows Executable Build Script using OCRA
# Creates a standalone .exe that includes Ruby runtime and all dependencies
#
# Requirements:
# - Windows OS
# - OCRA gem: gem install ocra
#
# Usage:
# - ruby build/windows/build.rb
# - Or run via GitHub Actions

require 'fileutils'

puts "======================================================"
puts "Building Windows Executable with OCRA"
puts "======================================================"
puts ""

# Verify we're on Windows
unless Gem.win_platform?
  puts "ERROR: This script must be run on Windows"
  exit 1
end

# Verify OCRA is installed
begin
  require 'ocra'
rescue LoadError
  puts "ERROR: OCRA gem not installed"
  puts "Install with: gem install ocra"
  exit 1
end

# Build configuration
BIN_FILE = 'bin/ruby_spriter'
OUTPUT_EXE = 'ruby_spriter.exe'
LIB_DIR = 'lib'

puts "Building executable..."
puts "  Input: #{BIN_FILE}"
puts "  Output: #{OUTPUT_EXE}"
puts ""

# OCRA command
# --no-enc: Don't include all encodings (reduces size)
# --gem-all: Include all gems
# --no-autoload: Don't use autoload
# --add-all-core: Add all core Ruby files
cmd = [
  'ocra',
  BIN_FILE,
  '--no-enc',
  '--gem-all',
  '--no-autoload',
  '--add-all-core',
  '--chdir-first',
  '--',
  '--version'  # Test run with --version flag
].join(' ')

puts "Executing: #{cmd}"
puts ""

system(cmd)

if File.exist?(OUTPUT_EXE)
  size_mb = File.size(OUTPUT_EXE) / (1024.0 * 1024.0)
  puts ""
  puts "======================================================"
  puts "SUCCESS!"
  puts "======================================================"
  puts "  Executable: #{OUTPUT_EXE}"
  puts "  Size: #{size_mb.round(2)} MB"
  puts ""
  puts "NOTE: External dependencies still required:"
  puts "  - FFmpeg"
  puts "  - ImageMagick"
  puts "  - GIMP 3.x"
  puts ""
  puts "Install with: choco install ffmpeg imagemagick gimp"
  puts "======================================================"
else
  puts ""
  puts "======================================================"
  puts "ERROR: Build failed"
  puts "======================================================"
  exit 1
end
