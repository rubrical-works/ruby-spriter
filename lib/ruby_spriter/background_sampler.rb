# frozen_string_literal: true

require 'open3'

module RubySpriter
  # BackgroundSampler collects unique background colors from interior image regions
  #
  # Sampling Strategy:
  # - Starts at (sample_offset, sample_offset) to avoid edge compression artifacts
  # - Samples horizontally across the image with calculated intervals
  # - Moves to next row if not enough unique colors found
  # - Uses pixel cache for fast lookups (loads all pixels once)
  class BackgroundSampler
    attr_reader :image_path, :sample_offset, :sample_count, :max_rows

    def initialize(image_path, sample_offset = 5, sample_count = 10, max_rows = 20)
      @image_path = image_path
      @sample_offset = sample_offset
      @sample_count = sample_count
      @max_rows = max_rows
      @image_width = nil
      @image_height = nil
      @pixel_cache = nil
    end

    # Collect unique background colors by sampling interior regions
    def collect_unique_colors
      load_image_dimensions
      load_pixel_cache

      # Input validation
      if @sample_count < 2
        raise ValidationError, "sample_count must be at least 2"
      end

      usable_width = @image_width - (2 * @sample_offset)
      if usable_width <= 0
        raise ValidationError, "sample_offset (#{@sample_offset}) too large for image width (#{@image_width})"
      end

      unique_colors = []
      y = @sample_offset
      rows_sampled = 0

      while unique_colors.length < @sample_count && rows_sampled < @max_rows
        # Calculate interval across usable width (excluding offset margins on both sides)
        interval = (@image_width - 2 * @sample_offset).to_f / (@sample_count - 1)

        # Sample across the width at current y position
        @sample_count.times do |i|
          x = @sample_offset + (i * interval).round

          # Ensure x is within bounds
          x = x.clamp(@sample_offset, @image_width - @sample_offset - 1)

          color = sample_pixel(x, y)

          if color && !color_exists?(unique_colors, color)
            unique_colors << color
            break if unique_colors.length >= @sample_count
          end
        end

        # Move to next row
        y += 1
        rows_sampled += 1
      end

      unique_colors
    end

    private

    def load_image_dimensions
      cmd = "magick identify -format \"%w %h\" #{Utils::PathHelper.quote_path(@image_path)}"
      stdout, stderr, status = Open3.capture3(cmd)

      unless status.success?
        raise ProcessingError, "Failed to get image dimensions: #{stderr}"
      end

      @image_width, @image_height = stdout.strip.split.map(&:to_i)
    end

    def load_pixel_cache
      return if @pixel_cache

      cmd = "magick #{Utils::PathHelper.quote_path(@image_path)} txt:-"
      stdout, stderr, status = Open3.capture3(cmd)

      unless status.success?
        raise ProcessingError, "Failed to load pixel cache: #{stderr}"
      end

      @pixel_cache = {}

      stdout.each_line do |line|
        next if line.start_with?('#')

        if line =~ /^(\d+),(\d+):\s+\((\d+),(\d+),(\d+)/
          x = $1.to_i
          y = $2.to_i
          r = $3.to_i
          g = $4.to_i
          b = $5.to_i

          @pixel_cache[[x, y]] = { r: r, g: g, b: b }
        end
      end
    end

    def sample_pixel(x, y)
      # Fallback to direct ImageMagick call if cache not loaded (for testing)
      return @pixel_cache[[x, y]] if @pixel_cache

      cmd = "magick #{Utils::PathHelper.quote_path(@image_path)} -format \"%[pixel:p{#{x},#{y}}]\" info:"
      stdout, stderr, status = Open3.capture3(cmd)

      return nil unless status.success?

      # Parse output like "srgb(255,255,255)", "srgba(255,255,255,1.0)", or "gray(255)"
      if stdout =~ /srgba?\((\d+),(\d+),(\d+)/
        { r: $1.to_i, g: $2.to_i, b: $3.to_i }
      elsif stdout =~ /gray\((\d+)\)/
        # Convert grayscale to RGB
        gray_value = $1.to_i
        { r: gray_value, g: gray_value, b: gray_value }
      else
        nil
      end
    end

    def color_exists?(colors, new_color)
      colors.any? { |c| c[:r] == new_color[:r] && c[:g] == new_color[:g] && c[:b] == new_color[:b] }
    end
  end
end
