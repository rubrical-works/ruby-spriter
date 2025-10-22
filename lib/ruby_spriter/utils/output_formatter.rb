# frozen_string_literal: true

module RubySpriter
  module Utils
    # Console output formatting utilities
    class OutputFormatter
      ICONS = {
        success: '✅',
        error: '❌',
        warning: '⚠️',
        info: 'ℹ️',
        clean: '🧹',
        note: '📝'
      }.freeze

      class << self
        # Print section header
        # @param title [String] Section title
        # @param width [Integer] Header width
        def header(title, width = 60)
          puts "\n" + "=" * width
          puts title
          puts "=" * width + "\n"
        end

        # Print success message
        # @param message [String] Message to print
        def success(message)
          puts "#{ICONS[:success]} #{message}"
        end

        # Print error message
        # @param message [String] Message to print
        def error(message)
          puts "#{ICONS[:error]} #{message}"
        end

        # Print warning message
        # @param message [String] Message to print
        def warning(message)
          puts "#{ICONS[:warning]} #{message}"
        end

        # Print info message
        # @param message [String] Message to print
        def info(message)
          puts "#{ICONS[:info]} #{message}"
        end

        # Print note message
        # @param message [String] Message to print
        def note(message)
          puts "#{ICONS[:note]} #{message}"
        end

        # Print indented message
        # @param message [String] Message to print
        # @param indent [Integer] Number of spaces to indent
        def indent(message, indent = 6)
          puts " " * indent + message
        end
      end
    end
  end
end
