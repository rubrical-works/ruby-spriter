# frozen_string_literal: true

require 'open3'
require 'fileutils'

module RubySpriter
  # Manages PNG compression with metadata preservation
  class CompressionManager
    # Compress PNG file using ImageMagick with maximum compression
    # @param input_file [String] Source PNG file
    # @param output_file [String] Destination PNG file
    # @param debug [Boolean] Enable debug output
    def self.compress(input_file, output_file, debug: false)
      Utils::FileHelper.validate_readable!(input_file)

      cmd = build_compression_command(input_file, output_file)

      if debug
        Utils::OutputFormatter.indent("DEBUG: Compression command: #{cmd}")
      end

      stdout, stderr, status = Open3.capture3(cmd)

      unless status.success?
        raise ProcessingError, "Failed to compress PNG: #{stderr}"
      end

      Utils::FileHelper.validate_exists!(output_file)
    end

    # Compress PNG file while preserving embedded metadata
    # @param input_file [String] Source PNG file
    # @param output_file [String] Destination PNG file
    # @param debug [Boolean] Enable debug output
    def self.compress_with_metadata(input_file, output_file, debug: false)
      # Read metadata before compression
      metadata = MetadataManager.read(input_file)

      # Compress the file
      temp_file = output_file.gsub('.png', '_compress_temp.png')
      compress(input_file, temp_file, debug: debug)

      # Re-embed metadata if it existed
      if metadata
        MetadataManager.embed(
          temp_file,
          output_file,
          columns: metadata[:columns],
          rows: metadata[:rows],
          frames: metadata[:frames],
          debug: debug
        )

        # Clean up temp file
        FileUtils.rm_f(temp_file) if File.exist?(temp_file)
      else
        # No metadata, just move temp to output
        FileUtils.mv(temp_file, output_file)
      end
    end

    # Get compression statistics
    # @param original_file [String] Original file path
    # @param compressed_file [String] Compressed file path
    # @return [Hash] Statistics including sizes and reduction percentage
    def self.compression_stats(original_file, compressed_file)
      original_size = File.size(original_file)
      compressed_size = File.size(compressed_file)
      saved_bytes = original_size - compressed_size
      reduction_percent = (saved_bytes.to_f / original_size * 100.0)

      {
        original_size: original_size,
        compressed_size: compressed_size,
        saved_bytes: saved_bytes,
        reduction_percent: reduction_percent
      }
    end

    private_class_method def self.build_compression_command(input_file, output_file)
      magick_cmd = Platform.imagemagick_convert_cmd

      # Use maximum PNG compression settings:
      # - compression-level=9: Maximum zlib compression
      # - compression-filter=5: Paeth filter (best for most images)
      # - compression-strategy=1: Filtered strategy
      # - quality=95: High quality
      # - strip: Remove all metadata (we'll re-add it later)
      [
        magick_cmd,
        Utils::PathHelper.quote_path(input_file),
        '-strip',
        '-define', 'png:compression-level=9',
        '-define', 'png:compression-filter=5',
        '-define', 'png:compression-strategy=1',
        '-quality', '95',
        Utils::PathHelper.quote_path(output_file)
      ].join(' ')
    end
  end
end
