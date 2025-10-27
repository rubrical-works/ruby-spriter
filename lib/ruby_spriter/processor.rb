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
      @gimp_version = nil
      validate_numeric_options!
      validate_split_option!
      validate_extract_option!
      validate_add_meta_option!
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
        aggressive: false,
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
        override_md: false,
        extract: nil,
        add_meta: nil,
        overwrite_meta: false
      }
    end

    def validate_options!
      input_modes = [options[:video], options[:image], options[:consolidate_mode], options[:verify], options[:batch]].compact

      if input_modes.empty?
        raise ValidationError, "Must specify --video, --image, --consolidate, --verify, or --batch"
      end

      if input_modes.length > 1
        raise ValidationError, "Cannot use multiple input modes together. Choose one."
      end

      validate_consolidate_options!
      validate_input_files!
      validate_numeric_options!
      validate_split_option!
      validate_extract_option!
      validate_add_meta_option!
    end

    def validate_consolidate_options!
      return unless options[:consolidate_mode]

      # Check for mutual exclusivity between file list and directory
      if options[:consolidate] && options[:dir]
        raise ValidationError, "Cannot use --dir with comma-separated file list for --consolidate. Choose one method."
      end

      # Require either file list or directory
      unless options[:consolidate] || options[:dir]
        raise ValidationError, "--consolidate requires either comma-separated files or --dir option"
      end

      # Validate directory if using directory mode
      if options[:dir] && !options[:consolidate]
        unless File.directory?(options[:dir])
          raise ValidationError, "Directory not found: #{options[:dir]}"
        end
      end
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

    def validate_extract_option!
      return unless options[:extract]

      # Parse extract format: comma-separated integers (allow negatives for better error messages)
      unless options[:extract] =~ /^-?\d+(,-?\d+)*$/
        raise ValidationError, "Invalid --extract format. Use comma-separated frame numbers (e.g., 1,2,4,5,8)"
      end

      # Parse frame numbers
      frame_numbers = options[:extract].split(',').map(&:to_i)

      # Validate minimum 2 frames
      if frame_numbers.length < 2
        raise ValidationError, "--extract requires at least 2 frames, got: #{frame_numbers.length}"
      end

      # Validate frame numbers are 1-indexed (no 0 or negative)
      invalid_frames = frame_numbers.select { |n| n <= 0 }
      if invalid_frames.any?
        raise ValidationError, "Frame numbers must be 1-indexed (positive integers), got invalid: #{invalid_frames.join(', ')}"
      end

      # Check for metadata (required for extraction)
      return unless options[:image] # Only validate bounds if we have an image path

      image_file = options[:image]
      metadata = MetadataManager.read(image_file)

      unless metadata
        raise ValidationError, "Image has no metadata. Cannot extract frames without knowing the grid layout. Use --add-meta first."
      end

      # Validate frame numbers are within bounds
      total_frames = metadata[:frames]
      out_of_bounds = frame_numbers.select { |n| n > total_frames }
      if out_of_bounds.any?
        first_oob = out_of_bounds.first
        raise ValidationError, "Frame #{first_oob} is out of bounds (image only has #{total_frames} frames)"
      end

      # Set default columns if not specified
      options[:columns] ||= 4
    end

    def validate_add_meta_option!
      return unless options[:add_meta]

      # Parse add-meta format: R:C
      unless options[:add_meta] =~ /^\d+:\d+$/
        raise ValidationError, "Invalid --add-meta format. Use R:C (e.g., 4:4)"
      end

      rows, columns = options[:add_meta].split(':').map(&:to_i)

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

      # Check if we need to validate against image file
      return unless options[:image]

      image_file = options[:image]
      metadata = MetadataManager.read(image_file)

      # Check for existing metadata
      if metadata && !options[:overwrite_meta]
        raise ValidationError, "Image already has spritesheet metadata. Use --overwrite-meta to replace it."
      end

      # Validate image dimensions divide evenly by grid
      dimensions = get_image_dimensions(image_file)
      tile_width = dimensions[:width] / columns.to_f
      tile_height = dimensions[:height] / rows.to_f

      unless tile_width == tile_width.to_i && tile_height == tile_height.to_i
        raise ValidationError, "Image dimensions (#{dimensions[:width]}x#{dimensions[:height]}) must divide evenly by grid (#{rows}x#{columns}). Expected frame size: #{tile_width}x#{tile_height}"
      end

      # Validate custom frame count doesn't exceed grid size
      if options[:frame_count] && options[:frame_count] > total_frames
        raise ValidationError, "Frame count (#{options[:frame_count]}) exceeds grid size (#{total_frames})"
      end
    end

    def get_image_dimensions(image_file)
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
      { width: width, height: height }
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

      if results[:gimp][:available]
        @gimp_path = checker.gimp_path
        @gimp_version = checker.gimp_version
      end

      if options[:debug]
        checker.print_report
      end
    end

    def needs_gimp?
      options[:scale_percent] || options[:remove_bg] || options[:sharpen]
    end

    def needs_gimp_specifically?
      # GIMP not needed if using aggressive mode (rembg handles background removal)
      return false if options[:aggressive]

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
      elsif options[:consolidate_mode]
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

      # Handle metadata addition workflow first
      if options[:add_meta]
        return execute_add_meta_workflow
      end

      # Handle frame extraction workflow
      if options[:extract]
        return execute_extract_workflow
      end

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

    def execute_extract_workflow
      input_file = options[:image]
      metadata = MetadataManager.read(input_file)
      frame_numbers = options[:extract].split(',').map(&:to_i)
      columns = options[:columns]

      Utils::OutputFormatter.header("Frame Extraction")
      Utils::OutputFormatter.indent("Input: #{input_file}")
      Utils::OutputFormatter.indent("Frames to extract: #{frame_numbers.join(', ')}")
      Utils::OutputFormatter.indent("Output columns: #{columns}")

      # Step 1: Extract all frames to temp directory
      temp_frames_dir = File.join(options[:temp_dir], 'extracted_frames')
      splitter = Utils::SpritesheetSplitter.new
      splitter.split_into_frames(input_file, temp_frames_dir, metadata[:columns], metadata[:rows], metadata[:frames])

      # Step 2: Keep only requested frames, delete the rest
      spritesheet_basename = File.basename(input_file, '.*')
      all_frame_files = Dir.glob(File.join(temp_frames_dir, "FR*_#{spritesheet_basename}.png")).sort
      requested_frame_files = frame_numbers.map do |frame_num|
        # Frame files are named FR001, FR002, etc. (1-indexed)
        File.join(temp_frames_dir, "FR#{format('%03d', frame_num)}_#{spritesheet_basename}.png")
      end

      # Delete unwanted frames
      (all_frame_files - requested_frame_files).each { |f| FileUtils.rm_f(f) }

      Utils::OutputFormatter.indent("Kept #{requested_frame_files.length} frames, deleted #{all_frame_files.length - requested_frame_files.length} frames")

      # Step 3: Reassemble into new spritesheet
      Utils::OutputFormatter.header("Reassembling Spritesheet")
      reassembled_file = File.join(options[:temp_dir], "reassembled_#{spritesheet_basename}.png")
      reassemble_frames(requested_frame_files, reassembled_file, columns)

      working_file = reassembled_file
      intermediate_files = []

      # Step 4: Apply GIMP processing if requested
      if needs_gimp?
        initial_file = working_file
        working_file = process_with_gimp(working_file)

        if working_file != initial_file
          intermediate_files = collect_intermediate_files(initial_file, working_file)
        end
      end

      # Step 5: Determine final output filename
      if options[:output]
        final_output = Utils::FileHelper.ensure_unique_output(options[:output], overwrite: options[:overwrite])
      else
        # Auto-generate output filename with _extracted suffix
        base = File.basename(input_file, '.*')
        ext = File.extname(input_file)
        desired_output = File.join(File.dirname(input_file), "#{base}_extracted#{ext}")
        final_output = Utils::FileHelper.ensure_unique_output(desired_output, overwrite: options[:overwrite])
      end

      # Step 6: Copy to final output
      FileUtils.cp(working_file, final_output)
      working_file = final_output

      # Step 7: Clean up intermediate files
      cleanup_intermediate_files(intermediate_files)

      # Step 8: Apply max compression if requested
      if options[:max_compress]
        working_file = apply_max_compression(working_file)
      end

      # Step 9: Optionally save individual frames
      if options[:save_frames]
        frames_output_dir = File.join(File.dirname(working_file), "#{File.basename(working_file, '.*')}_frames")
        FileUtils.mkdir_p(frames_output_dir)
        requested_frame_files.each_with_index do |frame_file, idx|
          frame_num = frame_numbers[idx]
          dest = File.join(frames_output_dir, "FR#{format('%03d', frame_num)}_#{spritesheet_basename}.png")
          FileUtils.cp(frame_file, dest)
        end
        Utils::OutputFormatter.indent("Saved #{requested_frame_files.length} frames to: #{frames_output_dir}")
      end

      Utils::OutputFormatter.header("SUCCESS!")
      Utils::OutputFormatter.success("Extracted spritesheet: #{working_file}")

      {
        mode: :extract,
        input_file: input_file,
        output_file: working_file,
        frames_extracted: frame_numbers.length,
        columns: columns
      }
    end

    def execute_add_meta_workflow
      input_file = options[:image]
      rows, columns = options[:add_meta].split(':').map(&:to_i)

      # Determine frame count
      frame_count = if options[:frame_count]
                      options[:frame_count]
                    else
                      rows * columns
                    end

      Utils::OutputFormatter.header("Adding Metadata")
      Utils::OutputFormatter.indent("Input: #{input_file}")
      Utils::OutputFormatter.indent("Grid: #{rows}×#{columns} (#{frame_count} frames)")

      # Determine output file
      if options[:output]
        # User specified explicit output
        output_file = Utils::FileHelper.ensure_unique_output(options[:output], overwrite: options[:overwrite])

        # Copy input to output
        FileUtils.cp(input_file, output_file)
        Utils::OutputFormatter.indent("Copied to: #{output_file}")
      else
        # In-place modification
        if options[:overwrite]
          output_file = input_file
          Utils::OutputFormatter.indent("Modifying in-place (--overwrite specified)")
        else
          # Create unique filename
          output_file = Utils::FileHelper.ensure_unique_output(input_file, overwrite: false)
          FileUtils.cp(input_file, output_file)
          Utils::OutputFormatter.indent("Created: #{output_file}")
        end
      end

      # Embed metadata
      MetadataManager.embed(output_file, columns, rows, frame_count)
      Utils::OutputFormatter.indent("📝 Metadata embedded: #{columns}×#{rows} grid (#{frame_count} frames)")

      Utils::OutputFormatter.header("SUCCESS!")
      Utils::OutputFormatter.success("Metadata added to: #{output_file}")

      {
        mode: :add_meta,
        input_file: input_file,
        output_file: output_file,
        columns: columns,
        rows: rows,
        frames: frame_count
      }
    end

    def execute_consolidate_workflow
      consolidator = Consolidator.new(options)

      # Determine file list: either from command line or from directory
      files_to_consolidate = if options[:dir] && !options[:consolidate]
                               # Directory-based consolidation
                               consolidator.find_spritesheets_in_directory(options[:dir])
                             else
                               # File list consolidation
                               options[:consolidate]
                             end

      # Determine output filename and directory
      if options[:dir] && !options[:consolidate]
        # Directory mode: output to dir or outputdir
        output_dir = options[:outputdir] || options[:dir]
        desired_output = if options[:output]
                           File.join(output_dir, File.basename(options[:output]))
                         else
                           File.join(output_dir, generate_consolidated_filename)
                         end
      else
        # File list mode: use current directory behavior
        if options[:outputdir]
          desired_output = File.join(options[:outputdir], options[:output] || generate_consolidated_filename)
        else
          desired_output = options[:output] || generate_consolidated_filename
        end
      end

      final_output = Utils::FileHelper.ensure_unique_output(desired_output, overwrite: options[:overwrite])

      result = consolidator.consolidate(files_to_consolidate, final_output)

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
      working_file = input_file

      # Step 1: Background removal with rembg if aggressive mode
      if options[:remove_bg] && options[:aggressive]
        working_file = remove_background_with_rembg(working_file)
      end

      # Step 2: GIMP processing for other operations (or non-aggressive BG removal)
      if needs_gimp_for_operations?
        gimp_options = options.merge(gimp_version: @gimp_version)

        # If aggressive, disable BG removal in GIMP (already done by rembg)
        if options[:aggressive]
          gimp_options = gimp_options.merge(remove_bg: false)
        end

        gimp_processor = GimpProcessor.new(@gimp_path, gimp_options)
        working_file = gimp_processor.process(working_file)
      end

      working_file
    end

    def needs_gimp_for_operations?
      # Need GIMP if we have scaling, sharpening, OR non-aggressive background removal
      options[:scale_percent] ||
        options[:sharpen] ||
        (options[:remove_bg] && !options[:aggressive])
    end

    def remove_background_with_rembg(input_file)
      rembg_processor = RembgProcessor.new(options)
      output_file = input_file.sub('.png', '_rembg.png')
      rembg_processor.remove_background(input_file, output_file)
      output_file
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

    def reassemble_frames(frame_files, output_file, columns)
      # Calculate rows needed for the specified columns
      total_frames = frame_files.length
      rows = (total_frames.to_f / columns).ceil

      Utils::OutputFormatter.indent("Layout: #{columns}×#{rows} grid (#{total_frames} frames)")

      # Use ImageMagick montage to create spritesheet
      # Montage arranges images in a grid
      cmd = [
        'magick',
        'montage',
        frame_files.map { |f| Utils::PathHelper.quote_path(f) }.join(' '),
        '-tile', "#{columns}x#{rows}",
        '-geometry', '+0+0',  # No spacing between tiles
        '-background', 'none',  # Transparent background
        Utils::PathHelper.quote_path(output_file)
      ].join(' ')

      stdout, stderr, status = Open3.capture3(cmd)

      unless status.success?
        raise ProcessingError, "Failed to reassemble frames: #{stderr}"
      end

      # Embed metadata in the reassembled spritesheet
      MetadataManager.embed(output_file, columns, rows, total_frames)

      Utils::OutputFormatter.indent("✅ Reassembled into #{columns}×#{rows} spritesheet")
      Utils::OutputFormatter.indent("📝 Metadata embedded: #{columns}×#{rows} grid (#{total_frames} frames)")
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
