# frozen_string_literal: true

require 'open3'
require 'fileutils'

module RubySpriter
  # SmokeDetector identifies and optionally removes smoke-like transparency gradients
  # Detects alpha values between 20-80% in contiguous regions
  class SmokeDetector
    attr_reader :input_image, :output_image, :config
    attr_reader :smoke_regions, :processing_time

    # Smoke detection thresholds
    MIN_ALPHA = 0.2   # 20% - minimum alpha for smoke
    MAX_ALPHA = 0.8   # 80% - maximum alpha for smoke
    MIN_AREA = 50     # Minimum contiguous area in pixels

    def initialize(input_image, output_image, config)
      @input_image = input_image
      @output_image = output_image
      @config = config
      @smoke_regions = []
      @processing_time = 0
    end

    # Main processing method
    def process
      start_time = Time.now

      # Validate input file exists
      unless File.exist?(@input_image)
        warn "SmokeDetector: Input image does not exist: #{@input_image}"
        @processing_time = Time.now - start_time
        return false
      end

      # Always detect smoke (for reporting)
      @smoke_regions = detect

      # Remove smoke if configured
      if @config.remove_smoke
        FileUtils.cp(@input_image, @output_image)
        remove_smoke_regions(@smoke_regions)
      else
        # Just copy input to output
        FileUtils.cp(@input_image, @output_image)
      end

      @processing_time = Time.now - start_time

      true
    end

    # Detect smoke-like transparency gradients
    def detect
      regions = []

      # Use ImageMagick to analyze alpha channel
      # Find regions with alpha in the smoke range (20-80%)
      regions = find_smoke_regions

      # Filter by minimum area
      regions.select { |r| r[:area] >= MIN_AREA }
    end

    # Remove detected smoke regions
    def remove_smoke_regions(regions)
      return true if regions.empty?

      # Apply smoke removal to the entire image
      # Remove all pixels with alpha in the smoke range
      remove_smoke_pixels

      true
    end

    # Check if alpha value is smoke-like
    def is_smoke_like?(alpha)
      alpha >= MIN_ALPHA && alpha <= MAX_ALPHA
    end

    # Generate detection report
    def report
      {
        smoke_detected: @smoke_regions.length,
        smoke_removed: @config.remove_smoke,
        smoke_regions: @smoke_regions.map do |r|
          {
            x: r[:x],
            y: r[:y],
            area: r[:area],
            alpha_range: r[:alpha_range]
          }
        end,
        processing_time: @processing_time.round(3),
        min_alpha_threshold: MIN_ALPHA,
        max_alpha_threshold: MAX_ALPHA,
        min_area_threshold: MIN_AREA
      }
    end

    private

    def find_smoke_regions
      regions = []

      # Get image dimensions
      cmd = "magick identify -format \"%w %h\" #{Utils::PathHelper.quote_path(@input_image)}"
      stdout, stderr, status = Open3.capture3(cmd)

      return regions unless status.success?

      width, height = stdout.strip.split.map(&:to_i)
      return regions if width == 0 || height == 0

      # Sample grid to find smoke-like regions
      step = 20
      visited = {}

      (step...height).step(step) do |y|
        (step...width).step(step) do |x|
          next if visited["#{x},#{y}"]

          alpha = get_alpha_at_point(x, y)

          if alpha && is_smoke_like?(alpha)
            # Found a smoke-like pixel, estimate region
            area = estimate_smoke_area(x, y, visited)

            if area >= MIN_AREA
              regions << {
                x: x,
                y: y,
                area: area,
                alpha_range: [MIN_ALPHA, MAX_ALPHA]
              }
            end
          end
        end
      end

      regions
    end

    def get_alpha_at_point(x, y)
      cmd = "magick #{Utils::PathHelper.quote_path(@input_image)} " \
            "-format \"%[pixel:p{#{x},#{y}}]\" info:"
      stdout, stderr, status = Open3.capture3(cmd)

      return nil unless status.success?

      # Parse alpha from output like "srgba(255,255,255,0.5)" or "gray(128,0.5)"
      if stdout =~ /[a-z]+\([^)]+,([0-9.]+)\)/
        $1.to_f
      elsif stdout =~ /[a-z]+\([^)]+\)/ && stdout !~ /,/
        # No alpha in output, fully opaque
        1.0
      else
        # Try to extract from different format
        1.0
      end
    end

    def estimate_smoke_area(x, y, visited)
      # Simple flood fill estimation for smoke region
      queue = [[x, y]]
      area = 0
      max_checks = 100  # Limit to prevent long processing

      while !queue.empty? && area < max_checks
        cx, cy = queue.shift
        key = "#{cx},#{cy}"

        next if visited[key]

        alpha = get_alpha_at_point(cx, cy)

        if alpha && is_smoke_like?(alpha)
          visited[key] = true
          area += 1

          # Add neighbors (simplified 4-directional)
          [[cx + 20, cy], [cx - 20, cy], [cx, cy + 20], [cx, cy - 20]].each do |nx, ny|
            queue << [nx, ny] unless visited["#{nx},#{ny}"]
          end
        else
          visited[key] = true
        end
      end

      # Approximate actual area (we sampled every 20 pixels)
      area * 400  # 20x20 = 400 pixels per sample
    end

    def remove_smoke_pixels
      # Use ImageMagick to remove pixels with alpha in smoke range
      # Convert pixels with alpha 20-80% to fully transparent

      min_threshold = (MIN_ALPHA * 100).to_i
      max_threshold = (MAX_ALPHA * 100).to_i

      # Use -fx to conditionally set alpha:
      # if alpha is between MIN_ALPHA and MAX_ALPHA, set to 0 (transparent)
      # otherwise keep original alpha
      cmd = "magick #{Utils::PathHelper.quote_path(@output_image)} " \
            "-define png:color-type=6 " \
            "-alpha set " \
            "-channel A " \
            "-fx \"(u >= #{MIN_ALPHA} && u <= #{MAX_ALPHA}) ? 0 : u\" " \
            "+channel " \
            "#{Utils::PathHelper.quote_path(@output_image)}"

      stdout, stderr, status = Open3.capture3(cmd)

      unless status.success?
        warn "Failed to remove smoke pixels: #{stderr}"
        return false
      end

      true
    end
  end
end
