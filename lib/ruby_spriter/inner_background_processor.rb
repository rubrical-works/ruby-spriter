# frozen_string_literal: true

require 'open3'
require 'fileutils'
require 'tmpdir'

module RubySpriter
  # InnerBackgroundProcessor removes background colors found inside sprite boundaries (optimized version)
  class InnerBackgroundProcessor
    attr_reader :input_image, :output_image, :config, :background_palette
    attr_reader :regions_detected, :regions_removed, :processing_time

    def initialize(input_image, output_image, config, background_palette)
      @input_image = input_image
      @output_image = output_image
      @config = config
      @background_palette = background_palette
      @regions_detected = []
      @regions_removed = []
      @processing_time = 0
      @image_width = nil
      @image_height = nil
    end

    # Main processing method
    def process
      start_time = Time.now

      # Load image dimensions
      load_image_dimensions

      # Copy input to output as starting point
      FileUtils.cp(@input_image, @output_image)

      # Detect inner regions (fast method using ImageMagick)
      @regions_detected = detect_inner_regions

      # Remove each detected region
      @regions_detected.each do |region|
        if remove_region(region)
          @regions_removed << region
        end
      end

      @processing_time = Time.now - start_time

      true
    end

    # Detect contiguous inner background regions using ImageMagick
    def detect_inner_regions
      # Ensure dimensions are loaded
      load_image_dimensions if @image_width.nil? || @image_height.nil?

      regions = []
      threshold = calculate_adaptive_threshold

      # For each color in the background palette
      @background_palette.each do |bg_color|
        # Use fast ImageMagick-based detection
        color_regions = find_regions_fast(bg_color, threshold)
        regions.concat(color_regions)
      end

      regions
    end

    # Remove a specific region by making it transparent
    def remove_region(region)
      fuzz = @config.bg_fuzz

      # Use ImageMagick flood fill to remove the region
      # This is MUCH faster than pixel-by-pixel
      cmd = "magick #{Utils::PathHelper.quote_path(@output_image)} " \
            "-fuzz #{fuzz}% " \
            "-fill none " \
            "-draw \"color #{region[:x]},#{region[:y]} floodfill\" " \
            "#{Utils::PathHelper.quote_path(@output_image)}"

      stdout, stderr, status = Open3.capture3(cmd)

      unless status.success?
        warn "Failed to remove region at #{region[:x]},#{region[:y]}: #{stderr}"
        return false
      end

      true
    end

    # Calculate adaptive threshold based on image size
    def calculate_adaptive_threshold
      # Ensure dimensions are loaded
      load_image_dimensions if @image_width.nil? || @image_height.nil?

      if @config.adaptive_min_area
        total_pixels = @image_width * @image_height
        (total_pixels * 0.01).to_i  # 1% of image area
      else
        @config.inner_min_area
      end
    end

    # Generate processing report
    def report
      {
        regions_detected: @regions_detected.length,
        regions_removed: @regions_removed.length,
        total_area_removed: @regions_removed.sum { |r| r[:area] },
        region_sizes: @regions_removed.map { |r| r[:area] },
        processing_time: @processing_time.round(3),
        adaptive_threshold: calculate_adaptive_threshold,
        color_space: @config.color_space,
        bg_fuzz: @config.bg_fuzz
      }
    end

    private

    def load_image_dimensions
      cmd = "magick identify -format \"%w %h\" #{Utils::PathHelper.quote_path(@input_image)}"
      stdout, stderr, status = Open3.capture3(cmd)

      unless status.success?
        raise ProcessingError, "Failed to get image dimensions: #{stderr}"
      end

      @image_width, @image_height = stdout.strip.split.map(&:to_i)
    end

    # Fast region detection using ImageMagick connected components
    def find_regions_fast(bg_color, min_area)
      regions = []

      # Sample a grid of points to find potential inner regions
      # This is much faster than analyzing every pixel
      step = 15  # Sample every 15 pixels (better for small regions)
      edge_margin = @config.edge_sample_depth + 5

      (edge_margin...@image_height - edge_margin).step(step) do |y|
        (edge_margin...@image_width - edge_margin).step(step) do |x|
          # Quick check if this point matches background color
          if point_matches_color?(x, y, bg_color)
            # Estimate region size using ImageMagick
            area = estimate_region_area_fast(x, y, bg_color)

            if area >= min_area
              regions << {
                x: x,
                y: y,
                area: area,
                touches_edge: false,  # Already filtered by edge_margin
                color: bg_color
              }
            end
          end
        end
      end

      # Remove duplicate regions (same area, close coordinates)
      deduplicate_regions(regions)
    end

    def point_matches_color?(x, y, bg_color)
      # Quick pixel check using ImageMagick
      cmd = "magick #{Utils::PathHelper.quote_path(@input_image)} -format \"%[pixel:p{#{x},#{y}}]\" info:"
      stdout, stderr, status = Open3.capture3(cmd)

      return false unless status.success?

      if stdout =~ /srgba?\((\d+),(\d+),(\d+)/
        pixel_r, pixel_g, pixel_b = $1.to_i, $2.to_i, $3.to_i

        # Simple RGB distance check
        distance = Math.sqrt(
          (pixel_r - bg_color[:r])**2 +
          (pixel_g - bg_color[:g])**2 +
          (pixel_b - bg_color[:b])**2
        )

        # Fuzz tolerance (convert percentage to RGB distance)
        tolerance = (@config.bg_fuzz / 100.0) * 441.67  # Max RGB distance is ~441.67
        distance <= tolerance
      else
        false
      end
    end

    def estimate_region_area_fast(x, y, bg_color)
      # Use ImageMagick to create a temporary mask and count pixels
      fuzz = @config.bg_fuzz

      # Create mask using flood fill and count white pixels
      cmd = "magick #{Utils::PathHelper.quote_path(@input_image)} " \
            "-fuzz #{fuzz}% " \
            "-fill white " \
            "-draw \"color #{x},#{y} floodfill\" " \
            "-fill black " \
            "+opaque white " \
            "-format \"%[fx:w*h*mean]\" " \
            "info:"

      stdout, stderr, status = Open3.capture3(cmd)

      if status.success?
        stdout.strip.gsub('"', '').to_f.to_i
      else
        0
      end
    end

    def deduplicate_regions(regions)
      # Remove regions that are too close to each other (likely same region)
      unique_regions = []
      proximity_threshold = 30

      regions.each do |region|
        is_duplicate = unique_regions.any? do |existing|
          distance = Math.sqrt(
            (region[:x] - existing[:x])**2 +
            (region[:y] - existing[:y])**2
          )
          distance < proximity_threshold && (region[:area] - existing[:area]).abs < 100
        end

        unique_regions << region unless is_duplicate
      end

      unique_regions
    end
  end
end
