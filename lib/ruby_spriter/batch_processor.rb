# frozen_string_literal: true

require 'fileutils'

module RubySpriter
  # Processes multiple videos in batch mode
  class BatchProcessor
    attr_reader :options

    def initialize(options = {})
      @options = options
      validate_directory!
    end

    # Find all MP4 files in the directory
    # @return [Array<String>] List of MP4 file paths
    def find_videos
      pattern = File.join(options[:dir], '*.mp4')
      videos = Dir.glob(pattern)

      if videos.empty?
        raise ValidationError, "No MP4 files found in directory: #{options[:dir]}"
      end

      if options[:debug]
        Utils::OutputFormatter.note("Found #{videos.length} video(s) to process")
        videos.each { |v| Utils::OutputFormatter.indent(File.basename(v)) }
      end

      videos
    end

    # Process all videos in the directory
    # @return [Hash] Processing results with outputs and errors
    def process
      videos = find_videos
      output_dir = determine_output_directory
      ensure_output_directory_exists(output_dir)

      results = {
        processed_count: 0,
        outputs: [],
        errors: []
      }

      Utils::OutputFormatter.header("Batch Processing: #{videos.length} video(s)")

      videos.each_with_index do |video, index|
        begin
          puts "\nProcessing [#{index + 1}/#{videos.length}]: #{File.basename(video)}"

          output_file = determine_output_file(video, output_dir)
          output_file = Utils::FileHelper.ensure_unique_output(output_file, overwrite: options[:overwrite])

          # Process video
          video_result = process_video(video, output_file)

          # Apply max compression if requested
          if options[:max_compress] && video_result[:output_file]
            video_result[:output_file] = apply_compression(video_result[:output_file])
          end

          results[:outputs] << video_result[:output_file]
          results[:processed_count] += 1

          Utils::OutputFormatter.success("Output: #{File.basename(video_result[:output_file])}")
        rescue StandardError => e
          error_msg = "#{File.basename(video)}: #{e.message}"
          results[:errors] << error_msg
          Utils::OutputFormatter.error(error_msg)
        end
      end

      # Consolidate if requested
      if options[:batch_consolidate] && results[:outputs].any?
        consolidated = consolidate_results(results[:outputs])
        results[:consolidated] = consolidated if consolidated
      end

      display_summary(results)

      results
    end

    # Consolidate all resulting spritesheets
    # @param outputs [Array<String>] List of spritesheet file paths
    # @return [Hash, nil] Consolidation result or nil if not requested
    def consolidate_results(outputs)
      return nil unless options[:batch_consolidate]
      return nil if outputs.empty?

      Utils::OutputFormatter.header("Consolidating #{outputs.length} spritesheets")

      output_dir = options[:outputdir] || options[:dir]
      consolidated_file = File.join(output_dir, 'batch_consolidated_spritesheet.png')
      consolidated_file = Utils::FileHelper.ensure_unique_output(consolidated_file, overwrite: options[:overwrite])

      consolidator = Consolidator.new(options)
      result = consolidator.consolidate(outputs, consolidated_file)

      Utils::OutputFormatter.success("Consolidated output: #{File.basename(consolidated_file)}")

      result
    end

    private

    def validate_directory!
      dir = options[:dir]

      raise ValidationError, "Must specify --dir for batch processing" unless dir
      raise ValidationError, "Directory not found: #{dir}" unless File.directory?(dir)
    end

    def determine_output_directory
      options[:outputdir] || options[:dir]
    end

    def ensure_output_directory_exists(dir)
      return if File.directory?(dir)

      if options[:debug]
        Utils::OutputFormatter.note("Creating output directory: #{dir}")
      end

      FileUtils.mkdir_p(dir)
    end

    def determine_output_file(video_file, output_dir)
      basename = File.basename(video_file, '.*')
      File.join(output_dir, "#{basename}_spritesheet.png")
    end

    def process_video(video_file, output_file)
      video_processor = VideoProcessor.new(options)

      # Check if we need frame-by-frame background removal
      if options[:by_frame] && options[:remove_bg]
        # Frame-by-frame processing with background removal
        # Get GIMP path for VideoProcessor
        checker = DependencyChecker.new(verbose: false)
        results = checker.check_all
        gimp_path = checker.gimp_path

        unless gimp_path
          raise DependencyError, "GIMP not found but required for --by-frame processing"
        end

        # Pass gimp_path through options
        video_options = options.merge(gimp_path: gimp_path)
        video_processor = VideoProcessor.new(video_options)

        result = video_processor.process_with_background_removal(
          video_file,
          output_file,
          video_options
        )

        # Normalize result format to match create_spritesheet
        result = {
          output_file: result[:output_file],
          columns: result[:columns],
          rows: (result[:frames].to_f / result[:columns]).ceil,
          frames: result[:frames]
        }

        working_file = result[:output_file]
      else
        # Standard video processing
        result = video_processor.create_spritesheet(video_file, output_file)
        working_file = result[:output_file]

        # Apply GIMP processing if requested (only for non-by-frame mode)
        if needs_gimp_processing?
          working_file = process_with_gimp(working_file, result)
        end
      end

      # Update result with final file
      result[:output_file] = working_file
      result
    end

    def needs_gimp_processing?
      options[:scale_percent] || options[:remove_bg] || options[:sharpen]
    end

    def process_with_gimp(input_file, video_result)
      # Get GIMP path and version from dependency checker
      checker = DependencyChecker.new(verbose: false)
      results = checker.check_all
      gimp_path = checker.gimp_path
      gimp_version = checker.gimp_version

      unless gimp_path
        raise DependencyError, "GIMP not found but required for processing"
      end

      gimp_options = options.merge(gimp_version: gimp_version)
      gimp_processor = GimpProcessor.new(gimp_path, gimp_options)
      output_file = gimp_processor.process(input_file)

      # Clean up intermediate file if different
      if output_file != input_file && File.exist?(input_file)
        File.delete(input_file) unless options[:keep_temp]
      end

      output_file
    end

    def apply_compression(file)
      Utils::OutputFormatter.indent("Applying maximum compression...")

      temp_file = file.gsub('.png', '_temp.png')
      CompressionManager.compress_with_metadata(file, temp_file)

      # Show compression stats
      if options[:debug]
        stats = CompressionManager.compression_stats(file, temp_file)
        Utils::OutputFormatter.indent("Saved #{Utils::FileHelper.format_size(stats[:saved_bytes])} (#{stats[:reduction_percent].round(1)}% reduction)")
      end

      # Replace original with compressed
      FileUtils.mv(temp_file, file)

      file
    end

    def display_summary(results)
      Utils::OutputFormatter.header("Batch Processing Summary")

      puts "Total videos: #{results[:processed_count] + results[:errors].length}"
      Utils::OutputFormatter.success("Successfully processed: #{results[:processed_count]}")

      if results[:errors].any?
        Utils::OutputFormatter.error("Failed: #{results[:errors].length}")
        results[:errors].each do |error|
          Utils::OutputFormatter.indent("- #{error}")
        end
      end

      if results[:consolidated]
        puts "\nConsolidated spritesheet:"
        Utils::OutputFormatter.indent(results[:consolidated][:output_file])
      end
    end
  end
end
