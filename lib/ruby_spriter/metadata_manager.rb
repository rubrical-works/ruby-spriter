# frozen_string_literal: true

require 'open3'

module RubySpriter
  # Manages PNG metadata for spritesheets
  class MetadataManager
    METADATA_PREFIX = 'SPRITESHEET'

    # Embed metadata into PNG file
    # @param input_file [String] Source PNG file
    # @param output_file [String] Destination PNG file with metadata
    # @param columns [Integer] Number of columns in grid
    # @param rows [Integer] Number of rows in grid
    # @param frames [Integer] Total number of frames
    # @param debug [Boolean] Enable debug output
    def self.embed(input_file, output_file, columns:, rows:, frames:, debug: false)
      Utils::FileHelper.validate_readable!(input_file)

      metadata_str = build_metadata_string(columns, rows, frames)
      
      cmd = build_embed_command(input_file, output_file, metadata_str)
      
      if debug
        Utils::OutputFormatter.indent("DEBUG: Metadata command: #{cmd}")
      end

      stdout, stderr, status = Open3.capture3(cmd)

      unless status.success?
        raise ProcessingError, "Failed to embed metadata: #{stderr}"
      end

      Utils::FileHelper.validate_exists!(output_file)
    end

    # Read metadata from PNG file
    # @param file [String] PNG file path
    # @return [Hash, nil] Metadata hash or nil if not found
    def self.read(file)
      Utils::FileHelper.validate_readable!(file)

      cmd = build_read_command(file)
      stdout, stderr, status = Open3.capture3(cmd)

      return nil unless status.success?

      parse_metadata(stdout)
    end

    # Verify and print metadata from file
    # @param file [String] PNG file path
    def self.verify(file)
      Utils::OutputFormatter.header("Spritesheet Metadata Verification")
      
      puts "File: #{file}"
      puts "Size: #{Utils::FileHelper.format_size(File.size(file))}\n\n"

      metadata = read(file)

      if metadata
        Utils::OutputFormatter.success("Metadata Found")
        puts "\n  Grid Layout:"
        Utils::OutputFormatter.indent("Columns: #{metadata[:columns]}")
        Utils::OutputFormatter.indent("Rows: #{metadata[:rows]}")
        Utils::OutputFormatter.indent("Total Frames: #{metadata[:frames]}")
        Utils::OutputFormatter.indent("Metadata Version: #{metadata[:version]}")
      else
        Utils::OutputFormatter.warning("No spritesheet metadata found in this file")
        puts "\nThis file may not have been created by Ruby Spriter,"
        puts "or the metadata was stripped during processing."
      end

      puts "\n" + "=" * 60 + "\n"
    end

    private_class_method def self.build_metadata_string(columns, rows, frames)
      "#{METADATA_PREFIX}|columns=#{columns}|rows=#{rows}|frames=#{frames}|version=#{METADATA_VERSION}"
    end

    private_class_method def self.build_embed_command(input_file, output_file, metadata_str)
      magick_cmd = Platform.imagemagick_convert_cmd
      
      [
        magick_cmd,
        Utils::PathHelper.quote_path(input_file),
        '-set', 'comment', Utils::PathHelper.quote_arg(metadata_str),
        Utils::PathHelper.quote_path(output_file)
      ].join(' ')
    end

    private_class_method def self.build_read_command(file)
      magick_cmd = Platform.imagemagick_identify_cmd
      
      [
        magick_cmd,
        '-format', Utils::PathHelper.quote_arg('%c'),
        Utils::PathHelper.quote_path(file)
      ].join(' ')
    end

    private_class_method def self.parse_metadata(output)
      # Look for SPRITESHEET metadata pattern
      match = output.match(/#{METADATA_PREFIX}\|columns=(\d+)\|rows=(\d+)\|frames=(\d+)\|version=([\d.]+)/)
      
      return nil unless match

      {
        columns: match[1].to_i,
        rows: match[2].to_i,
        frames: match[3].to_i,
        version: match[4]
      }
    end
  end
end
