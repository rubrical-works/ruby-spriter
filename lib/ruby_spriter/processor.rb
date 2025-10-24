# frozen_string_literal: true

require 'fileutils'
require 'tmpdir'

module RubySpriter
  # Main orchestration processor
  class Processor
    attr_reader :options, :gimp_path

    def initialize(options = {})
      @options = default_options.merge(options)
      @gimp_path = nil
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
        overwrite: false
      }
    end

    def validate_options!
      input_modes = [options[:video], options[:image], options[:consolidate], options[:verify]].compact
      
      if input_modes.empty?
        raise ValidationError, "Must specify --video, --image, --consolidate, or --verify"
      end

      if input_modes.length > 1
        raise ValidationError, "Cannot use multiple input modes together. Choose one."
      end

      validate_input_files!
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

      if options[:consolidate]
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

      # Step 3: Apply GIMP processing if requested
      if needs_gimp?
        working_file = process_with_gimp(working_file)
      end

      # Step 4: Move to final output location if different
      if final_output != working_file
        FileUtils.cp(working_file, final_output)
        working_file = final_output
      end

      Utils::OutputFormatter.header("SUCCESS!")
      Utils::OutputFormatter.success("Final output: #{working_file}")

      result.merge(final_output: working_file)
    end

    def execute_image_workflow
      working_file = options[:image]

      # Apply GIMP processing if requested (GimpProcessor handles uniqueness)
      if needs_gimp?
        working_file = process_with_gimp(working_file)
      end

      # Move to final output location if user specified explicit --output
      if options[:output]
        final_output = Utils::FileHelper.ensure_unique_output(options[:output], overwrite: options[:overwrite])
        if working_file != final_output
          FileUtils.cp(working_file, final_output)
          working_file = final_output
        end
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

      Utils::OutputFormatter.header("SUCCESS!")
      Utils::OutputFormatter.success("Final output: #{result[:output_file]}")

      result.merge(mode: :consolidate)
    end

    def process_with_gimp(input_file)
      gimp_processor = GimpProcessor.new(@gimp_path, options)
      gimp_processor.process(input_file)
    end

    def generate_consolidated_filename
      "consolidated_spritesheet.png"
    end

    def cleanup
      if options[:temp_dir] && Dir.exist?(options[:temp_dir])
        FileUtils.rm_rf(options[:temp_dir])
        Utils::OutputFormatter.note("Cleaned up temporary files") if options[:debug]
      end
    end
  end
end
