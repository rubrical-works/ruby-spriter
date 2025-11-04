# frozen_string_literal: true

require 'open3'

module RubySpriter
  # EdgeSampler samples pixel colors from image edges for background detection
  # Uses dense shallow sampling strategy to capture varied backgrounds
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
        edge_sample_interval: @config.edge_sample_interval,
        edge_sample_depth: @config.edge_sample_depth
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

    # Dense shallow sampling: sample every N pixels at depth=1 (second pixel from edge)
    # Avoids absolute edge pixels (0 and max-1) to prevent compression artifacts
    def sample_top_edge
      samples = []
      interval = @config.edge_sample_interval || 5
      y = 1  # Second pixel from top, avoiding y=0

      # Start from interval (not 0) to avoid x=0, sample up to width-2 to avoid x=width-1
      (interval...(@image_width - 1)).step(interval) do |x|
        samples << sample_pixel(x, y)
      end

      samples.compact
    end

    def sample_bottom_edge
      samples = []
      interval = @config.edge_sample_interval || 5
      y = @image_height - 2  # Second pixel from bottom, avoiding y=height-1

      # Start from interval (not 0) to avoid x=0, sample up to width-2 to avoid x=width-1
      (interval...(@image_width - 1)).step(interval) do |x|
        samples << sample_pixel(x, y)
      end

      samples.compact
    end

    def sample_left_edge
      samples = []
      interval = @config.edge_sample_interval || 5
      x = 1  # Second pixel from left, avoiding x=0

      # Start from interval (not 0) to avoid y=0, sample up to height-2 to avoid y=height-1
      (interval...(@image_height - 1)).step(interval) do |y|
        samples << sample_pixel(x, y)
      end

      samples.compact
    end

    def sample_right_edge
      samples = []
      interval = @config.edge_sample_interval || 5
      x = @image_width - 2  # Second pixel from right, avoiding x=width-1

      # Start from interval (not 0) to avoid y=0, sample up to height-2 to avoid y=height-1
      (interval...(@image_height - 1)).step(interval) do |y|
        samples << sample_pixel(x, y)
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
