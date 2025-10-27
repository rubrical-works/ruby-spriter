# frozen_string_literal: true

require 'open3'

module RubySpriter
  # Processes images with rembg for AI-powered background removal
  class RembgProcessor
    attr_reader :options

    def initialize(options = {})
      @options = options
      check_rembg_availability
    end

    # Remove background from image using rembg
    # @param input_path [String] Path to input image
    # @param output_path [String] Path to output image
    # @return [String] Path to output file
    def remove_background(input_path, output_path)
      Utils::FileHelper.validate_readable!(input_path)

      Utils::OutputFormatter.indent("Removing background with rembg (AI-powered)...")

      command = build_rembg_command(input_path, output_path)

      if options[:debug]
        Utils::OutputFormatter.indent("DEBUG: Executing command: #{command}")
      end

      stdout, stderr, status = Open3.capture3(command)

      unless status.success?
        error_msg = stderr.empty? ? stdout : stderr
        raise ProcessingError, "rembg failed: #{error_msg}"
      end

      if options[:debug]
        Utils::OutputFormatter.indent("DEBUG: rembg output: #{stdout}") unless stdout.empty?
      end

      size = Utils::FileHelper.format_size(File.size(output_path))
      Utils::OutputFormatter.success("Background removal complete (#{size})")

      output_path
    end

    private

    def check_rembg_availability
      rembg_check = DependencyChecker.check_rembg
      unless rembg_check[:available]
        raise ProcessingError, "rembg is not installed. Install with: pip install rembg[cli]"
      end
    end

    def build_rembg_command(input_path, output_path)
      # Use quotes for cross-platform path handling
      input_escaped = Utils::PathHelper.quote_path(input_path)
      output_escaped = Utils::PathHelper.quote_path(output_path)

      "rembg i #{input_escaped} #{output_escaped}"
    end
  end
end
