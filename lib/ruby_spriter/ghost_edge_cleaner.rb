# frozen_string_literal: true

require 'open3'
require 'fileutils'

module RubySpriter
  # GhostEdgeCleaner removes semi-transparent "ghost" pixels around sprite edges
  # using multi-pass alpha channel cleanup while preserving anti-aliasing
  class GhostEdgeCleaner
    attr_reader :input_image, :output_image, :config
    attr_reader :ghost_pixels_detected, :passes_performed, :processing_time

    MAX_PASSES = 3  # Maximum cleanup passes to prevent infinite loops

    def initialize(input_image, output_image, config)
      @input_image = input_image
      @output_image = output_image
      @config = config
      @ghost_pixels_detected = 0
      @passes_performed = 0
      @processing_time = 0
    end

    # Main processing method
    def process
      start_time = Time.now

      # Copy input to output as starting point
      FileUtils.cp(@input_image, @output_image)

      # Detect ghost pixels before cleanup
      @ghost_pixels_detected = detect_ghost_pixels

      # Perform multi-pass cleanup if multi_pass enabled
      if @config.multi_pass
        @passes_performed = multi_pass_cleanup
      else
        # Single pass cleanup
        clean_edges
        @passes_performed = 1
      end

      @processing_time = Time.now - start_time

      true
    end

    # Detect pixels with alpha below threshold
    def detect_ghost_pixels
      threshold = @config.ghost_threshold

      # Use ImageMagick to count pixels with alpha below threshold
      # Alpha values are 0-255, threshold is 0-255
      threshold_fraction = threshold / 255.0

      cmd = "magick #{Utils::PathHelper.quote_path(@input_image)} " \
            "-channel A " \
            "-separate " \
            "-threshold #{(threshold_fraction * 100).to_i}% " \
            "-format '%[fx:w*h*(1-mean)]' " \
            "info:"

      stdout, stderr, status = Open3.capture3(cmd)

      if status.success?
        stdout.strip.gsub("'", '').to_f.to_i
      else
        0
      end
    end

    # Clean edges by removing low-alpha pixels
    def clean_edges
      threshold = @config.ghost_threshold

      # Use ImageMagick to selectively remove pixels below alpha threshold
      # This preserves RGB data and anti-aliasing for pixels above threshold
      threshold_fraction = threshold / 255.0

      # Use direct -fx operation on alpha channel with explicit RGB preservation
      # Use png:color-type=6 to force RGBA output (handles grayscale inputs)
      # Use 'u' to refer to current channel value in -channel context
      cmd = "magick #{Utils::PathHelper.quote_path(@output_image)} " \
            "-define png:color-type=6 " \
            "-alpha set " \
            "-channel A " \
            "-fx \"u < #{threshold_fraction} ? 0 : u\" " \
            "+channel " \
            "#{Utils::PathHelper.quote_path(@output_image)}"

      stdout, stderr, status = Open3.capture3(cmd)

      unless status.success?
        warn "Failed to clean edges: #{stderr}"
        return false
      end

      true
    end

    # Perform multiple cleanup passes
    def multi_pass_cleanup
      passes = 0
      previous_ghost_count = @ghost_pixels_detected

      MAX_PASSES.times do
        passes += 1

        # Perform cleanup pass
        clean_edges

        # Check if we still have ghost pixels
        current_ghost_count = detect_ghost_pixels_from_file(@output_image)

        # Stop if no improvement or no ghost pixels remain
        break if current_ghost_count == 0
        break if current_ghost_count >= previous_ghost_count

        previous_ghost_count = current_ghost_count
      end

      # Update instance variable for reporting
      @passes_performed = passes

      passes
    end

    # Generate processing report
    def report
      {
        ghost_pixels_detected: @ghost_pixels_detected,
        threshold_used: @config.ghost_threshold,
        passes_performed: @passes_performed,
        processing_time: @processing_time.round(3),
        max_passes: MAX_PASSES
      }
    end

    private

    def detect_ghost_pixels_from_file(file_path)
      threshold = @config.ghost_threshold
      threshold_fraction = threshold / 255.0

      cmd = "magick #{Utils::PathHelper.quote_path(file_path)} " \
            "-channel A " \
            "-separate " \
            "-threshold #{(threshold_fraction * 100).to_i}% " \
            "-format '%[fx:w*h*(1-mean)]' " \
            "info:"

      stdout, stderr, status = Open3.capture3(cmd)

      if status.success?
        stdout.strip.gsub("'", '').to_f.to_i
      else
        0
      end
    end
  end
end
