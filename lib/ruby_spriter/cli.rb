# frozen_string_literal: true

require 'optparse'

module RubySpriter
  # Command-line interface
  class CLI
    PRESETS = {
      thumbnail: { columns: 3, frame_count: 9, max_width: 240 },
      preview: { columns: 4, frame_count: 16, max_width: 400 },
      detailed: { columns: 10, frame_count: 50, max_width: 320 },
      contact: { columns: 8, frame_count: 64, max_width: 160 }
    }.freeze

    def self.start(args)
      new.parse_and_run(args)
    end

    def parse_and_run(args)
      options = {}
      parser = build_option_parser(options)

      parser.parse!(args)

      # Handle special commands that don't need full processing
      if options[:check_dependencies]
        checker = DependencyChecker.new(verbose: true)
        checker.print_report
        exit(checker.all_satisfied? ? 0 : 1)
      end

      # Run processor
      processor = Processor.new(options)
      processor.run
    rescue OptionParser::InvalidOption, OptionParser::MissingArgument => e
      puts "Error: #{e.message}"
      puts "\nUse --help for usage information"
      exit 1
    end

    private

    def build_option_parser(options)
      OptionParser.new do |opts|
        opts.banner = "Usage: ruby_spriter [options]"
        
        add_header(opts)
        add_input_options(opts, options)
        add_spritesheet_options(opts, options)
        add_gimp_options(opts, options)
        add_bg_removal_options(opts, options)
        add_consolidation_options(opts, options)
        add_preset_options(opts, options)
        add_other_options(opts, options)
      end
    end

    def add_header(opts)
      opts.separator ""
      opts.separator "Ruby Spriter v#{VERSION} - MP4 to Spritesheet + GIMP Processing"
      opts.separator "Platform: #{Platform.current.to_s.capitalize}"
      opts.separator ""
    end

    def add_input_options(opts, options)
      opts.separator "Input Options:"
      
      opts.on("-v", "--video FILE", "Input video file (MP4)") do |v|
        options[:video] = v
      end

      opts.on("-i", "--image FILE", "Input image file (PNG) for direct processing") do |i|
        options[:image] = i
      end

      opts.on("--consolidate FILES", Array, "Consolidate multiple spritesheets (comma-separated)") do |c|
        options[:consolidate] = c
      end

      opts.on("--verify FILE", "Verify spritesheet metadata") do |v|
        options[:verify] = v
      end

      opts.separator ""
    end

    def add_spritesheet_options(opts, options)
      opts.separator "Spritesheet Options:"

      opts.on("-o", "--output FILE", "Output file path") do |o|
        options[:output] = o
      end

      opts.on("-f", "--frames COUNT", Integer, "Number of frames to extract (default: 16)") do |f|
        options[:frame_count] = f
      end

      opts.on("-c", "--columns COUNT", Integer, "Grid columns (default: 4)") do |c|
        options[:columns] = c
      end

      opts.on("-w", "--width PIXELS", Integer, "Max frame width (default: 320)") do |w|
        options[:max_width] = w
      end

      opts.on("-b", "--background COLOR", "Tile background: black, white (default: black)") do |b|
        options[:bg_color] = b
      end

      opts.separator ""
    end

    def add_gimp_options(opts, options)
      opts.separator "GIMP Processing Options:"

      opts.on("-s", "--scale PERCENT", Integer, "Scale image by percentage") do |s|
        options[:scale_percent] = s
      end

      opts.on("--interpolation METHOD", [:none, :linear, :cubic, :nohalo, :lohalo],
              "Interpolation method: none, linear, cubic, nohalo, lohalo (default: nohalo)") do |i|
        options[:scale_interpolation] = i.to_s
      end

      opts.on("--sharpen", "Apply unsharp mask after scaling (enhances edges)") do
        options[:sharpen] = true
      end

      opts.on("--sharpen-radius VALUE", Float, "Sharpen radius in pixels (default: 2.0)") do |r|
        options[:sharpen_radius] = r
      end

      opts.on("--sharpen-gain VALUE", Float, "Sharpen gain/strength (default: 0.5, range: 0.0-2.0+)") do |g|
        options[:sharpen_gain] = g
      end

      opts.on("--sharpen-threshold VALUE", Float, "Sharpen threshold as fraction (default: 0.03, range: 0.0-1.0)") do |t|
        options[:sharpen_threshold] = t
      end

      opts.on("-r", "--remove-bg", "Remove background from spritesheet using GIMP") do
        options[:remove_bg] = true
      end

      opts.on("-t", "--threshold VALUE", Float, "Feather radius (default: 0.0 = no feathering)") do |t|
        options[:bg_threshold] = t
      end

      opts.on("-g", "--grow PIXELS", Integer, "Pixels to grow selection (default: 1)") do |g|
        options[:grow_selection] = g
      end

      opts.separator ""
    end

    def add_bg_removal_options(opts, options)
      opts.separator "Background Removal Method:"

      opts.on("--fuzzy", "Use fuzzy select (contiguous regions) - DEFAULT") do
        options[:fuzzy_select] = true
      end

      opts.on("--no-fuzzy", "Use global color select (all matching pixels)") do
        options[:fuzzy_select] = false
      end

      opts.separator ""
      opts.separator "Operation Order:"

      opts.on("--order ORDER", [:scale_first, :bg_first],
              "Operation order: scale_first or bg_first (default: scale_first)") do |order|
        options[:operation_order] = order == :scale_first ? :scale_then_remove_bg : :remove_bg_then_scale
      end

      opts.separator ""
    end

    def add_consolidation_options(opts, options)
      opts.separator "Consolidation Options:"

      opts.on("--[no-]validate-columns", "Abort if column counts don't match (default: true)") do |v|
        options[:validate_columns] = v
      end

      opts.separator ""
    end

    def add_preset_options(opts, options)
      opts.separator "Preset Configurations:"

      preset_descriptions = PRESETS.map do |name, config|
        "    #{name}: #{config[:columns]}×? grid, #{config[:frame_count]} frames, #{config[:max_width]}px wide"
      end.join("\n")

      opts.on("--preset NAME", String, "Apply preset configuration:",
              *preset_descriptions.split("\n")) do |preset_name|
        preset_key = preset_name.to_sym
        unless PRESETS.key?(preset_key)
          valid_presets = PRESETS.keys.join(', ')
          raise OptionParser::InvalidArgument, "Unknown preset: #{preset_name}. Valid options: #{valid_presets}"
        end
        options.merge!(PRESETS[preset_key])
      end

      opts.separator ""
    end

    def add_other_options(opts, options)
      opts.separator "Other Options:"

      opts.on("--keep-temp", "Keep temporary files for debugging") do
        options[:keep_temp] = true
      end

      opts.on("--debug", "Enable debug mode (verbose output + keep temp files)") do
        options[:debug] = true
        options[:keep_temp] = true
      end

      opts.on("-h", "--help", "Show this help message") do
        puts opts
        exit
      end

      opts.on("--version", "Show version information") do
        puts "Ruby Spriter v#{VERSION}"
        puts "Platform: #{Platform.current.to_s.capitalize}"
        puts "Date: #{VERSION_DATE}"
        exit
      end

      opts.on("--check-dependencies", "Check if all required external tools are installed") do
        options[:check_dependencies] = true
      end

      opts.separator ""
      opts.separator "Examples:"
      opts.separator "  ruby_spriter --check-dependencies"
      opts.separator "  ruby_spriter --video input.mp4"
      opts.separator "  ruby_spriter --video input.mp4 --remove-bg --scale 50"
      opts.separator "  ruby_spriter --video input.mp4 --scale 50 --interpolation nohalo --sharpen"
      opts.separator "  ruby_spriter --image sprite.png --scale 50 --sharpen --sharpen-gain 1.5"
      opts.separator "  ruby_spriter --image sprite.png --remove-bg --fuzzy"
      opts.separator "  ruby_spriter --consolidate file1.png,file2.png,file3.png"
      opts.separator "  ruby_spriter --verify spritesheet.png"
      opts.separator ""
    end
  end
end
