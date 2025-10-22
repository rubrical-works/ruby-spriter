# frozen_string_literal: true

module RubySpriter
  module Utils
    # Cross-platform path handling utilities
    class PathHelper
      class << self
        # Quote a file path for shell execution
        # @param path [String] The path to quote
        # @return [String] Properly quoted path
        def quote_path(path)
          if Platform.windows?
            "\"#{path}\""
          else
            "'#{path.gsub("'", "\\'")}'"
          end
        end

        # Quote a command argument for shell execution
        # @param arg [String] The argument to quote
        # @return [String] Properly quoted argument
        def quote_arg(arg)
          if Platform.windows?
            "\"#{arg}\""
          else
            "'#{arg.gsub("'", "\\'")}'"
          end
        end

        # Normalize path for Python scripts (GIMP)
        # @param path [String] The path to normalize
        # @return [String] Normalized path with forward slashes
        def normalize_for_python(path)
          abs_path = File.absolute_path(path)
          
          if Platform.windows?
            # Use forward slashes for Python raw strings
            abs_path.gsub('\\', '/')
          else
            abs_path
          end
        end

        # Convert path to native format
        # @param path [String] The path to convert
        # @return [String] Path with platform-appropriate separators
        def to_native(path)
          if Platform.windows?
            path.gsub('/', '\\')
          else
            path.gsub('\\', '/')
          end
        end
      end
    end
  end
end
