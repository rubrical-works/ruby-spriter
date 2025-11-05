# frozen_string_literal: true

require 'open3'

module RubySpriter
  # EdgeSampler samples pixel colors from image edges for background detection
  # Uses dense shallow sampling strategy to capture varied backgrounds
  class EdgeSampler
    attr_reader :image_path, :config, :samples, :outliers, :pixel_cache

    def initialize(image_path, config)
      @image_path = image_path
      @config = config
      @samples = []
      @outliers = []
      @image_width = nil
      @image_height = nil
      @pixel_cache = nil  # Will hold all pixels when loaded
    end

    # Load all pixels into memory cache using ImageMagick txt: format
    # This eliminates the need for individual pixel sampling calls
    def load_pixel_cache
      load_image_dimensions if @image_width.nil? || @image_height.nil?

      # Use txt: format to dump all pixels in one call
      cmd = "magick #{Utils::PathHelper.quote_path(@image_path)} txt:-"
      stdout, stderr, status = Open3.capture3(cmd)

      unless status.success?
        raise ProcessingError, "Failed to load pixel cache: #{stderr}"
      end

      @pixel_cache = {}

      # Parse txt: format output
      # Format: "x,y: (r,g,b) #RRGGBB colorname"
      # or with alpha: "x,y: (r,g,b,a) #RRGGBBAA colorname"
      stdout.each_line do |line|
        # Skip header line
        next if line.start_with?('#')

        # Parse pixel data
        if line =~ /^(\d+),(\d+):\s+\((\d+),(\d+),(\d+)(?:,(\d+))?\)/
          x = $1.to_i
          y = $2.to_i
          r = $3.to_i
          g = $4.to_i
          b = $5.to_i
          a = $6 ? $6.to_i : nil

          pixel = { r: r, g: g, b: b }
          pixel[:a] = a if a

          @pixel_cache[[x, y]] = pixel
        end
      end

      @pixel_cache
    end

    # Sample colors from all four edges
    def sample_edges
      load_image_dimensions

      # Load all pixels into cache ONCE
      load_pixel_cache unless @pixel_cache

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
        edge_sample_depth: @config.edge_sample_depth,
        pixel_cache_size: @pixel_cache ? @pixel_cache.length : 0
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

    # Sample a single pixel - now uses cache instead of ImageMagick call
    def sample_pixel(x, y)
      # Return from cache if available
      return @pixel_cache[[x, y]] if @pixel_cache

      # Fallback to old method if cache not loaded (shouldn't happen)
      cmd = "magick identify -format \"%[pixel:p{#{x},#{y}]\" #{Utils::PathHelper.quote_path(@image_path)}"
      stdout, stderr, status = Open3.capture3(cmd)

      return nil unless status.success?

      # Parse color from output: "srgb(255,255,255)" or "srgba(255,255,255,1.0)"
      if stdout =~ /srgba?\((\d+),(\d+),(\d+)/
        { r: $1.to_i, g: $2.to_i, b: $3.to_i }
      else
        nil
      end
    end
  end
end
