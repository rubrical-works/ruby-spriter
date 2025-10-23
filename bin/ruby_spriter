#!/usr/bin/env ruby
# frozen_string_literal: true

# Add lib directory to load path
lib = File.expand_path('../lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'ruby_spriter'

# Run the CLI
begin
  RubySpriter::CLI.start(ARGV)
rescue Interrupt
  puts "\n\n⚠️  Process interrupted by user"
  exit 130
rescue StandardError => e
  puts "\n❌ ERROR: #{e.message}"
  puts e.backtrace.join("\n") if ENV['DEBUG']
  exit 1
end
