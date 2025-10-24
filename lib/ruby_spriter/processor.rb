# frozen_string_literal: true

require 'fileutils'
require 'tmpdir'
require 'open3'

module RubySpriter
  # Main orchestration processor
  class Processor
    attr_reader :options, :gimp_path, :split_rows, :split_columns

    # Valid ranges for numeric options
    VALID_RANGES = {
      frame_count: { min: 1, max: 10000, type: Integer },
      columns: { min: 1, max: 100, type: Integer },
      max_width: { min: 1, max: 1920, type: Integer },
      scale_percent: { min: 1, max: 500, type: Integer },
      grow_selection: { min: 0, max: 100, type: Integer },
      sharpen_radius: { min: 0.1, max: 100.0, type: Float },
      sharpen_gain: { min: 0.0, max: 10.0, type: Float },
      sharpen_threshold: { min: 0.0, max: 1.0, type: Float },
      bg_threshold: { min: 0.0, max: 100.0, type: Float }
    }.freeze

    def initialize(options = {})
      @options = default_options.merge(options)
      @gimp_path = nil
      validate_numeric_options!
      validate_split_option!
    end

    # Run the processing workflow
    def run
      validate_options!
      check_dependencies!
      setup_temp_directory

      result = execute_workflow

      cleanup unless options[:keep_temp]

      result
    end

    private

    def default_options
      {
        video: nil,
        image: nil,
        consolidate: nil,
        verify: nil,
        output: nil,
        frame_count: 16,
        columns: 4,
        max_width: 320,
        padding: 0,
        bg_color: 'black',
        scale_percent: nil,
        scale_interpolation: 'nohalo',
        sharpen: false,
        sharpen_radius: 2.0,
        sharpen_gain: 0.5,
        sharpen_threshold: 0.03,
        remove_bg: false,
        bg_threshold: 0.0,
        grow_selection: 1,
        fuzzy_select: true,
        operation_order: :scale_then_remove_bg,
        validate_columns: true,
        temp_dir: nil,
        keep_temp: false,
        debug: false,
        overwrite: false,
        save_frames: false,
        split: nil,
        override_md: false
      }
    end

    def validate_options!
      input_modes = [options[:video], options[:image], options[:consolidate], options[:verify], options[:batch]].compact

      if input_modes.empty?
        raise ValidationError, "Must specify --video, --image, --consolidate, --verify, or --batch"
      end

      if input_modes.length > 1
        raise ValidationError, "Cannot use multiple input modes together. Choose one."
      end

      validate_input_files!
      validate_numeric_options!
      validate_split_option!
    end

    def validate_input_files!
      if options[:video]
        Utils::FileHelper.validate_exists!(options[:video])
        validate_file_extension!(options[:video], ['.mp4'], '--video')
      end

      if options[:image]
        Utils::FileHelper.validate_exists!(options[:image])
        validate_file_extension!(options[:image], ['.png'], '--image')
      end

      if options[:consolidate]
        if options[:consolidate].length < 2
          raise ValidationError, "--consolidate requires at least 2 files"
        end

        options[:consolidate].each do |file|
          Utils::FileHelper.validate_exists!(file)
          validate_file_extension!(file, ['.png'], '--consolidate')
        end
      end

      if options[:verify]
        Utils::FileHelper.validate_exists!(options[:verify])
        validate_file_extension!(options[:verify], ['.png'], '--verify')
      end
    end

    def validate_file_extension!(file_path, valid_extensions, flag_name)
      ext = File.extname(file_path).downcase
      unless valid_extensions.include?(ext)
        expected = valid_extensions.join(', ')
        raise ValidationError, "#{flag_name} expects #{expected} file, got: #{ext || '(no extension)'}"
      end
    end

    def validate_numeric_options!
      VALID_RANGES.each do |option_name, range_config|
        value = options[option_name]

        # Skip validation if option is not set (nil)
        next if value.nil?

        min = range_config[:min]
        max = range_config[:max]

        # Validate that value is within range
        if value < min || value > max
          raise ValidationError, "#{option_name} must be between #{min} and #{max}, got: #{value}"
        end
      end
    end

    def validate_split_option!
      return unless options[:split]

      # Parse split format: R:C
      unless options[:split] =~ /^\d+:\d+$/
        raise ValidationError, "Invalid --split format. Use R:C (e.g., 4:4)"
      end

      rows, columns = options[:split].split(':').map(&:to_i)

      # Validate ranges
      if rows < 1 || rows > 99
        raise ValidationError, "rows must be between 1 and 99, got: #{rows}"
      end

      if columns < 1 || columns > 99
        raise ValidationError, "columns must be between 1 and 99, got: #{columns}"
      end

      # Validate total frames < 1000
      total_frames = rows * columns
      if total_frames >= 1000
        raise ValidationError, "Total frames (#{total_frames}) must be less than 1000"
      end

      # Store parsed values for later use
      @split_rows = rows
      @split_columns = columns
    end

    def check_dependencies!
      checker = DependencyChecker.new(verbose: options[:debug])
      results = checker.check_all

      # Check required tools
      missing = []
      
      [:ffmpeg, :ffprobe, :imagemagick].each do |tool|
        missing << tool unless results[tool][:available]
      end

      # GIMP only needed for scaling and background removal (not for sharpen-only)
      if needs_gimp_specifically? && !results[:gimp][:available]
        missing << :gimp
      end

      if missing.any?
        checker.print_report
        raise DependencyError, "Missing required dependencies: #{missing.join(', ')}"
      end

      @gimp_path = checker.gimp_path if results[:gimp][:available]

      if options[:debug]
        checker.print_report
      end
    end

    def needs_gimp?
      options[:scale_percent] || options[:remove_bg] || options[:sharpen]
    end

    def needs_gimp_specifically?
      options[:scale_percent] || options[:remove_bg]
    end

    def setup_temp_directory
      @options[:temp_dir] = Dir.mktmpdir('ruby_spriter_')
      
      if options[:debug]
        Utils::OutputFormatter.indent("Temp directory: #{options[:temp_dir]}")
      end
    end

    def execute_workflow
      Utils::OutputFormatter.header("Ruby Spriter v#{VERSION}")
      puts "Platform: #{Platform.current.to_s.capitalize}"
      puts "Date: #{VERSION_DATE}\n\n"

      if options[:verify]
        MetadataManager.verify(options[:verify])
        return { mode: :verify, file: options[:verify] }
      end

      if options[:batch]
        return execute_batch_workflow
      elsif options[:consolidate]
        return execute_consolidate_workflow
      elsif options[:image]
        return execute_image_workflow
      else
        return execute_video_workflow
      end
    end

    def execute_video_workflow
      # Step 1: Determine output filename
      desired_output = options[:output] || Utils::FileHelper.spritesheet_filename(options[:video])
      final_output = Utils::FileHelper.ensure_unique_output(desired_output, overwrite: options[:overwrite])

      # Step 2: Convert video to spritesheet
      video_processor = VideoProcessor.new(options)
      result = video_processor.create_spritesheet(
        options[:video],
        final_output
      )

      working_file = result[:output_file]
      intermediate_files = []

      # Step 3: Apply GIMP processing if requested
      if needs_gimp?
        initial_file = working_file
        working_file = process_with_gimp(working_file)

        # Track intermediate files for cleanup (everything except initial and final)
        if working_file != initial_file
          intermediate_files = collect_intermediate_files(initial_file, working_file)
        end
      end

      # Step 4: Move to final output location if different
      if final_output != working_file
        FileUtils.cp(working_file, final_output)
        # Add the GIMP output to intermediates if it's different from final
        intermediate_files << working_file unless intermediate_files.include?(working_file)
        working_file = final_output
      end

      # Step 5: Clean up intermediate files
      cleanup_intermediate_files(intermediate_files)

      # Step 6: Apply max compression if requested
      if options[:max_compress]
        working_file = apply_max_compression(working_file)
      end

      # Step 7: Extract individual frames if requested
      if options[:save_frames]
        split_frames_from_spritesheet(working_file, result[:columns], result[:rows], result[:frames])
      end

      Utils::OutputFormatter.header("SUCCESS!")
      Utils::OutputFormatter.success("Final output: #{working_file}")

      result.merge(final_output: working_file)
    end

    def execute_image_workflow
      working_file = options[:image]
      intermediate_files = []

      # Apply GIMP processing if requested (GimpProcessor handles uniqueness)
      if needs_gimp?
        initial_file = working_file
        working_file = process_with_gimp(working_file)

        # Track intermediate files for cleanup (everything except initial and final)
        if working_file != initial_file
          intermediate_files = collect_intermediate_files(initial_file, working_file)
        end
      end

      # Move to final output location if user specified explicit --output
      if options[:output]
        final_output = Utils::FileHelper.ensure_unique_output(options[:output], overwrite: options[:overwrite])
        if working_file != final_output
          FileUtils.cp(working_file, final_output)
          # Add the GIMP output to intermediates if it's different from final
          intermediate_files << working_file unless intermediate_files.include?(working_file)
          working_file = final_output
        end
      end

      # Clean up intermediate files
      cleanup_intermediate_files(intermediate_files)

      # Apply max compression if requested
      if options[:max_compress]
        working_file = apply_max_compression(working_file)
      end

      # Determine if we should split the image into frames
      should_split = options[:save_frames] || options[:split]

      if should_split
        # Determine rows, columns, and frames to use
        rows, columns, frames = determine_split_parameters(working_file)

        # Split the image into frames
        split_frames_from_spritesheet(working_file, columns, rows, frames)
      end

      Utils::OutputFormatter.header("SUCCESS!")
      Utils::OutputFormatter.success("Final output: #{working_file}")

      {
        mode: :image,
        input_file: options[:image],
        output_file: working_file
      }
    end

    def execute_consolidate_workflow
      consolidator = Consolidator.new(options)

      desired_output = options[:output] || generate_consolidated_filename
      final_output = Utils::FileHelper.ensure_unique_output(desired_output, overwrite: options[:overwrite])

      result = consolidator.consolidate(options[:consolidate], final_output)

      # Apply max compression if requested
      if options[:max_compress]
        final_output = apply_max_compression(result[:output_file])
        result[:output_file] = final_output
      end

      Utils::OutputFormatter.header("SUCCESS!")
      Utils::OutputFormatter.success("Final output: #{result[:output_file]}")

      result.merge(mode: :consolidate)
    end

    def execute_batch_workflow
      batch_processor = BatchProcessor.new(options)
      result = batch_processor.process

      result.merge(mode: :batch)
    end

    def process_with_gimp(input_file)
      gimp_processor = GimpProcessor.new(@gimp_path, options)
      gimp_processor.process(input_file)
    end

    def generate_consolidated_filename
      "consolidated_spritesheet.png"
    end

    def split_frames_from_spritesheet(spritesheet_file, columns, rows, frames)
      # Determine frames directory based on spritesheet filename
      spritesheet_basename = File.basename(spritesheet_file, '.*')
      frames_dir = File.join(File.dirname(spritesheet_file), "#{spritesheet_basename}_frames")

      # Split the spritesheet into individual frames
      splitter = Utils::SpritesheetSplitter.new
      splitter.split_into_frames(spritesheet_file, frames_dir, columns, rows, frames)
    end

    def collect_intermediate_files(initial_file, final_file)
      # Find all files that were created during GIMP processing
      # Pattern: initial_file + suffixes like -nobg-fuzzy, -scaled-40pct, etc.
      # Note: output_filename uses DASH separator, not underscore
      dir = File.dirname(initial_file)
      basename = File.basename(initial_file, '.*')
      ext = File.extname(initial_file)

      # Get all PNG files in the directory that start with the basename and have a dash
      pattern = File.join(dir, "#{basename}-*#{ext}")
      intermediate_files = Dir.glob(pattern)

      # Normalize paths for comparison (Windows compatibility)
      initial_normalized = File.expand_path(initial_file)
      final_normalized = File.expand_path(final_file)

      # Exclude the initial and final files
      intermediate_files.reject do |f|
        f_normalized = File.expand_path(f)
        f_normalized == initial_normalized || f_normalized == final_normalized
      end
    end

    def cleanup_intermediate_files(files)
      return if files.empty?

      if options[:debug]
        Utils::OutputFormatter.note("Cleaning up #{files.length} intermediate file(s):")
      end

      files.each do |file|
        if File.exist?(file)
          File.delete(file)
          if options[:debug]
            Utils::OutputFormatter.indent("Deleted: #{File.basename(file)}")
          end
        end
      end
    end

    def cleanup
      if options[:temp_dir] && Dir.exist?(options[:temp_dir])
        FileUtils.rm_rf(options[:temp_dir])
        Utils::OutputFormatter.note("Cleaned up temporary files") if options[:debug]
      end
    end

    def determine_split_parameters(image_file)
      metadata = MetadataManager.read(image_file)

      # Check if we have metadata
      if metadata && metadata[:columns] && metadata[:rows] && metadata[:frames]
        # Metadata exists
        if options[:split] && !options[:override_md]
          # Warn user that split values will be ignored
          Utils::OutputFormatter.note("Image has metadata (#{metadata[:rows]}×#{metadata[:columns]}). Your --split values will be ignored. Use --override-md to override.")
          return [metadata[:rows], metadata[:columns], metadata[:frames]]
        elsif options[:split] && options[:override_md]
          # Use user's split values
          frames = @split_rows * @split_columns
          validate_image_dimensions(image_file, @split_rows, @split_columns)
          return [@split_rows, @split_columns, frames]
        else
          # Use metadata
          return [metadata[:rows], metadata[:columns], metadata[:frames]]
        end
      else
        # No metadata
        if options[:split]
          # Use user's split values
          frames = @split_rows * @split_columns
          validate_image_dimensions(image_file, @split_rows, @split_columns)
          return [@split_rows, @split_columns, frames]
        else
          # Error: no metadata and no split option
          raise ValidationError, "Image has no metadata. Please provide --split R:C"
        end
      end
    end

    def validate_image_dimensions(image_file, rows, columns)
      # Get image dimensions using ImageMagick
      cmd = [
        'magick',
        'identify',
        '-format', '%wx%h',
        Utils::PathHelper.quote_path(image_file)
      ].join(' ')

      stdout, stderr, status = Open3.capture3(cmd)

      unless status.success?
        raise ProcessingError, "Could not get image dimensions: #{stderr}"
      end

      width, height = stdout.strip.split('x').map(&:to_i)

      # Check if dimensions divide evenly
      unless width % columns == 0
        raise ValidationError, "Image width (#{width}) not evenly divisible by #{columns} columns"
      end

      unless height % rows == 0
        raise ValidationError, "Image height (#{height}) not evenly divisible by #{rows} rows"
      end
    end

    def apply_max_compression(file)
      Utils::OutputFormatter.note("Applying maximum compression...")

      original_size = File.size(file)
      temp_file = file.gsub('.png', '_compressed_temp.png')

      CompressionManager.compress_with_metadata(file, temp_file, debug: options[:debug])

      # Show compression stats
      stats = CompressionManager.compression_stats(file, temp_file)

      if options[:debug] || stats[:saved_bytes] > 0
        Utils::OutputFormatter.indent("Original: #{Utils::FileHelper.format_size(stats[:original_size])}")
        Utils::OutputFormatter.indent("Compressed: #{Utils::FileHelper.format_size(stats[:compressed_size])}")
        Utils::OutputFormatter.indent("Saved: #{Utils::FileHelper.format_size(stats[:saved_bytes])} (#{stats[:reduction_percent].round(1)}% reduction)")
      end

      # Replace original with compressed
      FileUtils.mv(temp_file, file)

      file
    end
  end
end
