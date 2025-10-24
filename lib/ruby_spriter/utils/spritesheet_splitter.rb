# frozen_string_literal: true

require 'open3'
require 'fileutils'

module RubySpriter
  module Utils
    # Splits a spritesheet into individual frame images
    class SpritesheetSplitter
      # Split spritesheet into individual frames
      # @param spritesheet_file [String] Path to spritesheet PNG
      # @param output_dir [String] Directory to save individual frames
      # @param columns [Integer] Number of columns in grid
      # @param rows [Integer] Number of rows in grid
      # @param frames [Integer] Total number of frames to extract
      def split_into_frames(spritesheet_file, output_dir, columns, rows, frames)
        FileUtils.mkdir_p(output_dir)

        OutputFormatter.header("Extracting Frames")
        OutputFormatter.indent("Splitting spritesheet into #{frames} frames to disk...")
        OutputFormatter.indent("Output directory: #{output_dir}")

        # Get spritesheet dimensions
        dimensions = get_image_dimensions(spritesheet_file)
        tile_width = dimensions[:width] / columns
        tile_height = dimensions[:height] / rows

        # Extract each frame
        spritesheet_basename = File.basename(spritesheet_file, '.*')

        frames.times do |i|
          frame_number = i + 1
          row = i / columns
          col = i % columns

          x_offset = col * tile_width
          y_offset = row * tile_height

          frame_filename = "FR#{format('%03d', frame_number)}_#{spritesheet_basename}.png"
          frame_path = File.join(output_dir, frame_filename)

          extract_tile(spritesheet_file, frame_path, tile_width, tile_height, x_offset, y_offset)
        end

        OutputFormatter.indent("✅ Frames extracted successfully\n")
      end

      private

      def get_image_dimensions(image_file)
        cmd = [
          'magick',
          'identify',
          '-format', '%wx%h',
          PathHelper.quote_path(image_file)
        ].join(' ')

        stdout, stderr, status = Open3.capture3(cmd)

        unless status.success?
          raise ProcessingError, "Could not get image dimensions: #{stderr}"
        end

        width, height = stdout.strip.split('x').map(&:to_i)
        { width: width, height: height }
      end

      def extract_tile(source_file, output_file, width, height, x_offset, y_offset)
        cmd = [
          'magick',
          'convert',
          PathHelper.quote_path(source_file),
          '-crop', "#{width}x#{height}+#{x_offset}+#{y_offset}",
          '+repage',
          PathHelper.quote_path(output_file)
        ].join(' ')

        stdout, stderr, status = Open3.capture3(cmd)

        unless status.success?
          raise ProcessingError, "Could not extract frame: #{stderr}"
        end
      end
    end
  end
end
