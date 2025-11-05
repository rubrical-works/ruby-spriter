# frozen_string_literal: true

require 'open3'
require 'fileutils'
require 'tmpdir'
require 'set'

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
      @pixel_cache = nil  # Add pixel cache support
    end

    # Load all pixels into memory cache using ImageMagick txt: format
    def load_pixel_cache
      load_image_dimensions if @image_width.nil? || @image_height.nil?

      # Use txt: format to dump all pixels in one call
      cmd = "magick #{Utils::PathHelper.quote_path(@input_image)} txt:-"
      stdout, stderr, status = Open3.capture3(cmd)

      unless status.success?
        raise ProcessingError, "Failed to load pixel cache: #{stderr}"
      end

      @pixel_cache = {}

      # Parse txt: format output
      stdout.each_line do |line|
        next if line.start_with?('#')

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

    # Main processing method
    def process
      start_time = Time.now

      # Load image dimensions
      load_image_dimensions

      # Load pixel cache ONCE for fast grid sampling
      load_pixel_cache

      # Copy input to output as starting point
      FileUtils.cp(@input_image, @output_image)

      # Detect inner regions (fast method using pixel cache)
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

      # Ensure pixel cache is loaded
      load_pixel_cache unless @pixel_cache

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
            # Use cached area estimation if pixel cache is available
            area = if @pixel_cache
                     estimate_region_area_from_cache(x, y, bg_color, min_area)
                   else
                     estimate_region_area_fast(x, y, bg_color)
                   end

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
      # Use pixel cache instead of ImageMagick call
      pixel = @pixel_cache[[x, y]]
      return false unless pixel

      # Simple RGB distance check
      distance = Math.sqrt(
        (pixel[:r] - bg_color[:r])**2 +
        (pixel[:g] - bg_color[:g])**2 +
        (pixel[:b] - bg_color[:b])**2
      )

      # Fuzz tolerance (convert percentage to RGB distance)
      tolerance = (@config.bg_fuzz / 100.0) * 441.67  # Max RGB distance is ~441.67
      distance <= tolerance
    end

    # Estimate region area using pixel cache (fast, no ImageMagick calls)
    # Optimized with early termination - stops once we know if region meets min_area
    def estimate_region_area_from_cache(x, y, bg_color, min_area = nil)
      area, _ = estimate_region_area_from_cache_with_tracking(x, y, bg_color, min_area)
      area
    end

    # Estimate region area and return visited coordinates for deduplication
    def estimate_region_area_from_cache_with_tracking(x, y, bg_color, min_area = nil)
      return [0, []] unless @pixel_cache

      # Use flood fill algorithm on pixel cache with Set for faster lookups
      visited_keys = Set.new
      visited_coords = []
      queue = [[x, y]]
      area = 0
      max_area = min_area ? min_area * 2 : Float::INFINITY  # Early termination threshold

      while !queue.empty? && area < max_area
        cx, cy = queue.shift

        # Skip if out of bounds
        next if cx < 0 || cy < 0 || cx >= @image_width || cy >= @image_height

        # Skip if already visited (Set lookup is O(1))
        coord_key = cx * 10000 + cy  # Pack coordinates into single integer for faster hashing
        next if visited_keys.include?(coord_key)

        # Mark as visited
        visited_keys.add(coord_key)

        # Get pixel from cache
        pixel = @pixel_cache[[cx, cy]]
        next unless pixel

        # Check if pixel matches background color (with fuzz tolerance)
        if colors_match?(pixel, bg_color)
          area += 1
          visited_coords << [cx, cy]

          # Add neighbors to queue (4-way connectivity)
          queue << [cx + 1, cy]
          queue << [cx - 1, cy]
          queue << [cx, cy + 1]
          queue << [cx, cy - 1]
        end
      end

      [area, visited_coords]
    end

    # Check if two colors match within fuzz tolerance
    def colors_match?(pixel, bg_color)
      distance = Math.sqrt(
        (pixel[:r] - bg_color[:r])**2 +
        (pixel[:g] - bg_color[:g])**2 +
        (pixel[:b] - bg_color[:b])**2
      )

      tolerance = (@config.bg_fuzz / 100.0) * 441.67
      distance <= tolerance
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
