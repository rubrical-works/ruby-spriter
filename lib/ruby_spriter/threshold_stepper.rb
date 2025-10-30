# frozen_string_literal: true

require 'open3'
require 'fileutils'
require 'tmpdir'

module RubySpriter
  # ThresholdStepper processes images with multiple fuzzy select thresholds
  # and combines the results for improved edge detection
  class ThresholdStepper
    attr_reader :input_image, :output_image, :config
    attr_reader :thresholds_processed, :processing_time, :temp_files

    # Default threshold values per FR-7 requirements
    DEFAULT_THRESHOLDS = [0.0, 0.5, 1.0, 3.0, 5.0, 10.0].freeze

    def initialize(input_image, output_image, config)
      @input_image = input_image
      @output_image = output_image
      @config = config
      @thresholds_processed = []
      @processing_time = 0
      @temp_files = []
    end

    # Main processing method
    def process
      start_time = Time.now

      # Process image with each threshold value
      processed_images = []

      default_thresholds.each do |threshold|
        temp_output = process_with_threshold(threshold)
        if temp_output && File.exist?(temp_output)
          processed_images << temp_output
          @thresholds_processed << threshold
        end
      end

      # Flatten all results into final output
      if processed_images.any?
        flatten_results(processed_images, @output_image)
      else
        # Fallback: copy input to output
        FileUtils.cp(@input_image, @output_image)
      end

      # Cleanup temporary files
      cleanup_temp_files(processed_images)

      @processing_time = Time.now - start_time

      true
    end

    # Get default threshold values
    def default_thresholds
      DEFAULT_THRESHOLDS
    end

    # Process image with a specific threshold value
    def process_with_threshold(threshold)
      temp_output = File.join(Dir.tmpdir, "threshold_#{threshold}_#{Process.pid}_#{rand(1000)}.png")
      @temp_files << temp_output

      # Use ImageMagick with fuzzy select at this threshold
      # This simulates GIMP's fuzzy select with different tolerance values
      cmd = "magick #{Utils::PathHelper.quote_path(@input_image)} " \
            "-fuzz #{threshold}% " \
            "-transparent white " \
            "#{Utils::PathHelper.quote_path(temp_output)}"

      stdout, stderr, status = Open3.capture3(cmd)

      unless status.success?
        warn "Failed to process with threshold #{threshold}: #{stderr}"
        return nil
      end

      temp_output
    end

    # Flatten multiple processed images into one
    def flatten_results(image_paths, output_path)
      return false if image_paths.empty?

      # Use ImageMagick to composite all images
      # Start with the most aggressive threshold (highest value) as base
      base_image = image_paths.last

      # Build composite command
      # Each layer adds more refined transparency
      cmd_parts = ["magick", Utils::PathHelper.quote_path(base_image)]

      # Add each previous threshold as a layer
      image_paths[0...-1].reverse.each do |img|
        cmd_parts << Utils::PathHelper.quote_path(img)
        cmd_parts << "-compose" << "DstOver"
        cmd_parts << "-composite"
      end

      cmd_parts << Utils::PathHelper.quote_path(output_path)

      cmd = cmd_parts.join(" ")
      stdout, stderr, status = Open3.capture3(cmd)

      unless status.success?
        warn "Failed to flatten results: #{stderr}"
        # Fallback: use the last processed image
        FileUtils.cp(image_paths.last, output_path)
        return false
      end

      true
    end

    # Generate processing report
    def report
      {
        thresholds_processed: @thresholds_processed,
        processing_time: @processing_time.round(3),
        temp_files_created: @temp_files.length,
        threshold_count: @thresholds_processed.length
      }
    end

    private

    def cleanup_temp_files(files)
      files.each do |file|
        FileUtils.rm_f(file) if File.exist?(file)
      end
    end
  end
end
