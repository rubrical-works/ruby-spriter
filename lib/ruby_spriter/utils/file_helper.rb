# frozen_string_literal: true

module RubySpriter
  module Utils
    # File naming and size utilities
    class FileHelper
      class << self
        # Generate spritesheet filename from video file
        # @param video_file [String] Path to video file
        # @return [String] Generated spritesheet filename
        def spritesheet_filename(video_file)
          dir = File.dirname(video_file)
          basename = File.basename(video_file, '.*')
          File.join(dir, "#{basename}_spritesheet.png")
        end

        # Generate output filename with suffix
        # @param input_file [String] Original input file
        # @param suffix [String] Suffix to add to filename
        # @return [String] Generated output filename
        def output_filename(input_file, suffix)
          dir = File.dirname(input_file)
          basename = File.basename(input_file, '.*')
          File.join(dir, "#{basename}-#{suffix}.png")
        end

        # Format file size in human-readable format
        # @param bytes [Integer] File size in bytes
        # @return [String] Formatted file size
        def format_size(bytes)
          if bytes >= 1024 * 1024
            "#{(bytes / (1024.0 * 1024.0)).round(2)} MB"
          elsif bytes >= 1024
            "#{(bytes / 1024.0).round(2)} KB"
          else
            "#{bytes} bytes"
          end
        end

        # Validate file exists
        # @param path [String] File path to validate
        # @raise [ValidationError] if file doesn't exist
        def validate_exists!(path)
          raise ValidationError, "File not found: #{path}" unless File.exist?(path)
        end

        # Validate file is readable
        # @param path [String] File path to validate
        # @raise [ValidationError] if file isn't readable
        def validate_readable!(path)
          validate_exists!(path)
          raise ValidationError, "File not readable: #{path}" unless File.readable?(path)
        end

        # Generate unique filename by adding timestamp if file exists
        # @param path [String] Original file path
        # @return [String] Unique file path (adds timestamp if original exists)
        def unique_filename(path)
          return path unless File.exist?(path)

          dir = File.dirname(path)
          ext = File.extname(path)
          basename = File.basename(path, ext)
          timestamp = Time.now.strftime('%Y%m%d_%H%M%S_%3N') # Include milliseconds

          File.join(dir, "#{basename}_#{timestamp}#{ext}")
        end

        # Ensure output filename is unique based on overwrite option
        # @param path [String] Desired output path
        # @param overwrite [Boolean] If true, return original path; if false, make unique
        # @return [String] Output path (unique if overwrite is false and file exists)
        def ensure_unique_output(path, overwrite: false)
          return path if overwrite
          return path unless File.exist?(path)

          unique_filename(path)
        end
      end
    end
  end
end
