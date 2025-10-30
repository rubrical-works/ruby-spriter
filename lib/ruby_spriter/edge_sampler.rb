# frozen_string_literal: true

require 'open3'

module RubySpriter
  # EdgeSampler samples pixel colors from image edges for background detection
  class EdgeSampler
    attr_reader :image_path, :config, :samples, :outliers

    def initialize(image_path, config)
      @image_path = image_path
      @config = config
      @samples = []
      @outliers = []
      @image_width = nil
      @image_height = nil
    end

    # Sample colors from all four edges
    def sample_edges
      load_image_dimensions

      @samples = []
      @samples += sample_top_edge
      @samples += sample_bottom_edge
      @samples += sample_left_edge
      @samples += sample_right_edge

      @samples
    end

    # Build a unique color palette from samples
    def build_color_palette(samples)
      # Remove duplicates by converting to set-like structure
      unique_colors = samples.uniq { |color| "#{color[:r]},#{color[:g]},#{color[:b]}" }
      unique_colors
    end

    # Detect outlier colors that differ significantly from majority
    def detect_outliers(samples)
      return [] if samples.empty? || samples.length < 4

      # Calculate average color
      avg_r = samples.sum { |s| s[:r] } / samples.length
      avg_g = samples.sum { |s| s[:g] } / samples.length
      avg_b = samples.sum { |s| s[:b] } / samples.length

      # Find colors that are significantly different (threshold: 50 units in RGB space)
      outlier_threshold = 50

      @outliers = samples.select do |color|
        distance = Math.sqrt(
          (color[:r] - avg_r)**2 +
          (color[:g] - avg_g)**2 +
          (color[:b] - avg_b)**2
        )
        distance > outlier_threshold
      end

      @outliers.uniq { |color| "#{color[:r]},#{color[:g]},#{color[:b]}" }
    end

    # Generate sampling report
    def report
      {
        samples_collected: @samples.length,
        unique_colors: build_color_palette(@samples).length,
        outliers_detected: @outliers.length,
        sampling_pattern: @config.edge_sample_pattern
      }
    end

    private

    def load_image_dimensions
      # Use ImageMagick identify to get dimensions
      cmd = "magick identify -format \"%w %h\" #{Utils::PathHelper.quote_path(@image_path)}"
      stdout, stderr, status = Open3.capture3(cmd)

      unless status.success?
        raise ProcessingError, "Failed to get image dimensions: #{stderr}"
      end

      @image_width, @image_height = stdout.strip.split.map(&:to_i)
    end

    def sample_top_edge
      depth = @config.edge_sample_depth
      samples = []

      if @config.edge_sample_pattern == 'linear'
        # Sample evenly across the top edge
        step = [@image_width / 10, 1].max
        (0...@image_width).step(step) do |x|
          (0...depth).each do |y|
            samples << sample_pixel(x, y)
          end
        end
      else
        # Weighted: more samples at corners
        samples += sample_corner_region(0, 0, depth, depth)
        samples += sample_corner_region(@image_width - depth, 0, depth, depth)
      end

      samples.compact
    end

    def sample_bottom_edge
      depth = @config.edge_sample_depth
      samples = []

      if @config.edge_sample_pattern == 'linear'
        step = [@image_width / 10, 1].max
        (0...@image_width).step(step) do |x|
          ((@image_height - depth)...@image_height).each do |y|
            samples << sample_pixel(x, y)
          end
        end
      else
        # Weighted: more samples at corners
        samples += sample_corner_region(0, @image_height - depth, depth, depth)
        samples += sample_corner_region(@image_width - depth, @image_height - depth, depth, depth)
      end

      samples.compact
    end

    def sample_left_edge
      depth = @config.edge_sample_depth
      samples = []

      if @config.edge_sample_pattern == 'linear'
        step = [@image_height / 10, 1].max
        (0...@image_height).step(step) do |y|
          (0...depth).each do |x|
            samples << sample_pixel(x, y)
          end
        end
      else
        # Weighted pattern already sampled corners
        # Sample middle section
        mid_start = @image_height / 3
        mid_end = (2 * @image_height) / 3
        (mid_start...mid_end).step(10) do |y|
          (0...depth).each do |x|
            samples << sample_pixel(x, y)
          end
        end
      end

      samples.compact
    end

    def sample_right_edge
      depth = @config.edge_sample_depth
      samples = []

      if @config.edge_sample_pattern == 'linear'
        step = [@image_height / 10, 1].max
        (0...@image_height).step(step) do |y|
          ((@image_width - depth)...@image_width).each do |x|
            samples << sample_pixel(x, y)
          end
        end
      else
        # Weighted pattern already sampled corners
        # Sample middle section
        mid_start = @image_height / 3
        mid_end = (2 * @image_height) / 3
        (mid_start...mid_end).step(10) do |y|
          ((@image_width - depth)...@image_width).each do |x|
            samples << sample_pixel(x, y)
          end
        end
      end

      samples.compact
    end

    def sample_corner_region(start_x, start_y, width, height)
      samples = []
      (start_x...(start_x + width)).each do |x|
        (start_y...(start_y + height)).each do |y|
          samples << sample_pixel(x, y)
        end
      end
      samples.compact
    end

    def sample_pixel(x, y)
      # Use ImageMagick to get pixel color at specific coordinates
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
  end
end
