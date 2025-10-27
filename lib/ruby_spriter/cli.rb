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

      # Handle context-sensitive help before validation
      if args.include?('--help') || args.include?('-h')
        handle_context_sensitive_help(args)
      end

      parser = build_option_parser(options)

      parser.parse!(args)

      # Handle special commands that don't need full processing
      if options[:check_dependencies]
        checker = DependencyChecker.new(verbose: true)
        checker.print_report
        exit(checker.all_satisfied? ? 0 : 1)
      end

      # Validate mutually exclusive options
      if options[:extract] && options[:split]
        raise ValidationError, "--extract and --split are mutually exclusive"
      end

      # Validate --add-meta cannot be combined with processing options
      if options[:add_meta] && (options[:scale_percent] || options[:remove_bg] || options[:sharpen])
        raise ValidationError, "--add-meta cannot be combined with processing options (--scale, --remove-bg, --sharpen)"
      end

      # Validate --aggressive requires --remove-bg
      if options[:aggressive] && !options[:remove_bg]
        puts "Error: --aggressive requires --remove-bg flag"
        puts "Usage: ruby_spriter --video INPUT --remove-bg --aggressive"
        exit 1
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
      opts.separator "Ruby Spriter v#{VERSION} - Professional MP4 to Spritesheet Converter with Advanced Image Processing"
      opts.separator "Platform: #{Platform.current.to_s.capitalize}"
      opts.separator ""
      opts.separator "Get mode-specific help:"
      opts.separator "  ruby_spriter --video --help"
      opts.separator "  ruby_spriter --image --help"
      opts.separator "  ruby_spriter --consolidate --help"
      opts.separator "  ruby_spriter --batch --help"
      opts.separator "  ruby_spriter --split --help"
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

      opts.on("--batch", "Batch process all MP4 files in directory") do
        options[:batch] = true
      end

      opts.on("--dir DIRECTORY", "Directory for batch processing") do |d|
        options[:dir] = d
      end

      opts.on("--outputdir DIRECTORY", "Output directory for batch processing") do |d|
        options[:outputdir] = d
      end

      opts.on("--batch-consolidate", "Consolidate all spritesheets after batch processing") do
        options[:batch_consolidate] = true
      end

      opts.on("--consolidate [FILES]", Array, "Consolidate spritesheets (comma-separated files or use with --dir)") do |c|
        options[:consolidate_mode] = true
        options[:consolidate] = c if c && !c.empty?
      end

      opts.on("--verify FILE", "Verify spritesheet metadata") do |v|
        options[:verify] = v
      end

      opts.on("--split R:C", "Split image into frames (rows:columns, e.g., 4:4)") do |s|
        options[:split] = s
      end

      opts.on("--override-md", "Override embedded metadata when using --split") do
        options[:override_md] = true
      end

      opts.on("--extract FRAMES", "Extract specific frames by number (comma-separated, e.g., 1,2,4,5,8)") do |e|
        options[:extract] = e
      end

      opts.on("--columns NUM", Integer, "Number of columns for extracted spritesheet (default: 4)") do |c|
        options[:columns] = c
      end

      opts.on("--add-meta R:C", "Add spritesheet metadata to image (rows:columns, e.g., 4:4)") do |m|
        options[:add_meta] = m
      end

      opts.on("--overwrite-meta", "Overwrite existing metadata when using --add-meta") do
        options[:overwrite_meta] = true
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

      opts.on("--save-frames", "Save individual frames to disk (for --video or --extract)") do
        options[:save_frames] = true
      end

      opts.separator ""
    end

    def add_gimp_options(opts, options)
      opts.separator "Processing Options:"

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

      opts.on("-r", "--remove-bg", "Remove background from spritesheet") do
        options[:remove_bg] = true
      end

      opts.on("--aggressive", "Use rembg for AI-powered background removal (requires --remove-bg and Python with rembg installed)") do
        options[:aggressive] = true
      end

      opts.on("-t", "--threshold VALUE", Float, "Background color tolerance % (default: 15.0, range: 0-100)") do |t|
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

      opts.on("--max-compress", "Apply maximum PNG compression to output") do
        options[:max_compress] = true
      end

      opts.on("--overwrite", "Overwrite existing output files (default: create unique filenames)") do
        options[:overwrite] = true
      end

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
      opts.separator "  ruby_spriter --video input.mp4 --remove-bg --aggressive"
      opts.separator "  ruby_spriter --video input.mp4 --scale 50 --interpolation nohalo --sharpen"
      opts.separator "  ruby_spriter --video input.mp4 --max-compress"
      opts.separator "  ruby_spriter --image sprite.png --scale 50 --sharpen --sharpen-gain 1.5"
      opts.separator "  ruby_spriter --image sprite.png --remove-bg --fuzzy"
      opts.separator "  ruby_spriter --batch --dir videos/"
      opts.separator "  ruby_spriter --batch --dir videos/ --outputdir output/"
      opts.separator "  ruby_spriter --batch --dir videos/ --batch-consolidate --max-compress"
      opts.separator "  ruby_spriter --consolidate file1.png,file2.png,file3.png"
      opts.separator "  ruby_spriter --consolidate --dir spritesheets/"
      opts.separator "  ruby_spriter --consolidate --dir spritesheets/ --outputdir output/ --max-compress"
      opts.separator "  ruby_spriter --verify spritesheet.png"
      opts.separator ""
    end

    def handle_context_sensitive_help(args)
      if args.include?('--video') || args.include?('-v')
        show_video_mode_help
      elsif args.include?('--image') || args.include?('-i')
        show_image_mode_help
      elsif args.include?('--consolidate')
        show_consolidate_mode_help
      elsif args.include?('--batch')
        show_batch_mode_help
      elsif args.include?('--split')
        show_split_mode_help
      else
        # Default help - let OptionParser handle it
        return
      end
    end

    def show_video_mode_help
      puts ""
      puts "Video Mode"
      puts "=" * 60
      puts ""
      puts "Convert MP4 videos to spritesheets with advanced image processing."
      puts ""
      puts "Basic Usage:"
      puts "  ruby_spriter --video FILE [options]"
      puts ""
      puts "Required:"
      puts "  -v, --video FILE                 Input video file (MP4)"
      puts ""
      puts "Spritesheet Options:"
      puts "  -o, --output FILE                Output file path"
      puts "  -f, --frames COUNT               Number of frames to extract (default: 16)"
      puts "  -c, --columns COUNT              Grid columns (default: 4)"
      puts "  -w, --width PIXELS               Max frame width (default: 320)"
      puts "  -b, --background COLOR           Tile background: black, white (default: black)"
      puts "  --save-frames                    Save individual frames to disk"
      puts ""
      puts "Image Processing:"
      puts "  -s, --scale PERCENT              Scale image by percentage"
      puts "    --interpolation METHOD         └─ Interpolation: none, linear, cubic, nohalo, lohalo (default: nohalo)"
      puts ""
      puts "  --sharpen                        Apply unsharp mask for edge enhancement"
      puts "    --sharpen-radius VALUE         └─ Sharpen radius in pixels (default: 2.0)"
      puts "    --sharpen-gain VALUE           └─ Sharpen gain/strength (default: 0.5)"
      puts "    --sharpen-threshold VALUE      └─ Sharpen threshold (default: 0.03)"
      puts ""
      puts "  -r, --remove-bg                  Remove background"
      puts "    --aggressive                   └─ Use rembg for AI-powered removal (requires Python + rembg)"
      puts "    --fuzzy                        └─ Use fuzzy select (contiguous regions) - DEFAULT"
      puts "    --no-fuzzy                     └─ Use global color select (all matching pixels)"
      puts "    -t, --threshold VALUE          └─ Feather radius (default: 0.0)"
      puts "    -g, --grow PIXELS              └─ Grow selection pixels (default: 1)"
      puts ""
      puts "  --order ORDER                    Operation order when using BOTH --scale AND --remove-bg:"
      puts "                                   scale_first or bg_first (default: scale_first)"
      puts ""
      puts "Output Options:"
      puts "  --max-compress                   Apply maximum PNG compression"
      puts "  --overwrite                      Overwrite existing files"
      puts "  --keep-temp                      Keep temporary files"
      puts "  --debug                          Enable debug mode"
      puts ""
      puts "Examples:"
      puts "  ruby_spriter --video input.mp4"
      puts "  ruby_spriter --video input.mp4 --scale 50 --interpolation nohalo"
      puts "  ruby_spriter --video input.mp4 --remove-bg --fuzzy --threshold 0.5"
      puts "  ruby_spriter --video input.mp4 --remove-bg --aggressive"
      puts "  ruby_spriter --video input.mp4 --scale 50 --sharpen --max-compress"
      puts ""
      exit
    end

    def show_image_mode_help
      puts ""
      puts "Image Mode"
      puts "=" * 60
      puts ""
      puts "Process PNG spritesheets with advanced image operations."
      puts ""
      puts "Basic Usage:"
      puts "  ruby_spriter --image FILE [options]"
      puts ""
      puts "Required:"
      puts "  -i, --image FILE                 Input image file (PNG)"
      puts ""
      puts "Image Processing:"
      puts "  -s, --scale PERCENT              Scale image by percentage"
      puts "    --interpolation METHOD         └─ Interpolation: none, linear, cubic, nohalo, lohalo (default: nohalo)"
      puts ""
      puts "  --sharpen                        Apply unsharp mask for edge enhancement"
      puts "    --sharpen-radius VALUE         └─ Sharpen radius in pixels (default: 2.0)"
      puts "    --sharpen-gain VALUE           └─ Sharpen gain/strength (default: 0.5)"
      puts "    --sharpen-threshold VALUE      └─ Sharpen threshold (default: 0.03)"
      puts ""
      puts "  -r, --remove-bg                  Remove background"
      puts "    --aggressive                   └─ Use rembg for AI-powered removal (requires Python + rembg)"
      puts "    --fuzzy                        └─ Use fuzzy select (contiguous regions) - DEFAULT"
      puts "    --no-fuzzy                     └─ Use global color select (all matching pixels)"
      puts "    -t, --threshold VALUE          └─ Feather radius (default: 0.0)"
      puts "    -g, --grow PIXELS              └─ Grow selection pixels (default: 1)"
      puts ""
      puts "  --order ORDER                    Operation order when using BOTH --scale AND --remove-bg:"
      puts "                                   scale_first or bg_first (default: scale_first)"
      puts ""
      puts "Frame Extraction & Reassembly:"
      puts "  --split R:C                      Split spritesheet into all individual frames (rows:columns)"
      puts "    --override-md                  └─ Override embedded metadata"
      puts ""
      puts "  --extract FRAMES                 Extract specific frames and create new spritesheet (e.g., 1,2,4,5,8)"
      puts "    --columns NUM                  └─ Output grid columns (default: 4)"
      puts "    --save-frames                  └─ Keep individual extracted frames on disk"
      puts ""
      puts "Metadata Management:"
      puts "  --add-meta R:C                   Add spritesheet metadata (rows:columns, e.g., 4:4)"
      puts "    --overwrite-meta               └─ Replace existing metadata"
      puts "    -f, --frames COUNT             └─ Custom frame count for partial grids"
      puts ""
      puts "Output Options:"
      puts "  -o, --output FILE                Output file path"
      puts "  --max-compress                   Apply maximum PNG compression"
      puts "  --overwrite                      Overwrite existing files"
      puts "  --keep-temp                      Keep temporary files"
      puts "  --debug                          Enable debug mode"
      puts ""
      puts "Examples:"
      puts "  ruby_spriter --image sprite.png --scale 50 --interpolation nohalo"
      puts "  ruby_spriter --image sprite.png --remove-bg --fuzzy --threshold 1.0"
      puts "  ruby_spriter --image sprite.png --remove-bg --aggressive"
      puts "  ruby_spriter --image sprite.png --scale 50 --sharpen --sharpen-gain 1.5"
      puts "  ruby_spriter --image sprite.png --split 4:4 --override-md"
      puts "  ruby_spriter --image sprite.png --extract 1,2,4,5,8 --columns 3"
      puts "  ruby_spriter --image sprite.png --extract 1,1,2,2,3,3 --save-frames"
      puts "  ruby_spriter --image sprite.png --add-meta 4:4"
      puts "  ruby_spriter --image sprite.png --add-meta 4:4 --frames 14 --output sprite_meta.png"
      puts ""
      exit
    end

    def show_consolidate_mode_help
      puts ""
      puts "Consolidate Mode"
      puts "=" * 60
      puts ""
      puts "Combine multiple spritesheets into a single consolidated spritesheet."
      puts ""
      puts "Basic Usage:"
      puts "  ruby_spriter --consolidate FILE1,FILE2,FILE3 [options]"
      puts "  ruby_spriter --consolidate --dir DIRECTORY [options]"
      puts ""
      puts "Input Methods:"
      puts "  --consolidate [FILES]            Comma-separated list of PNG files"
      puts "  --consolidate --dir DIRECTORY    Process all spritesheets in directory"
      puts "    --[no-]validate-columns        └─ Abort if column counts don't match (default: true)"
      puts ""
      puts "Output Options:"
      puts "  -o, --output FILE                Output file path"
      puts "  --outputdir DIRECTORY            Output directory (when using --dir)"
      puts "  --max-compress                   Apply maximum PNG compression"
      puts "  --overwrite                      Overwrite existing files"
      puts "  --keep-temp                      Keep temporary files"
      puts "  --debug                          Enable debug mode"
      puts ""
      puts "Requirements:"
      puts "  - All input files must be PNG spritesheets with embedded metadata"
      puts "  - Column counts must match across all spritesheets (unless --no-validate-columns)"
      puts "  - Minimum 2 spritesheets required"
      puts ""
      puts "Examples:"
      puts "  ruby_spriter --consolidate file1.png,file2.png,file3.png"
      puts "  ruby_spriter --consolidate --dir spritesheets/"
      puts "  ruby_spriter --consolidate --dir spritesheets/ --outputdir output/"
      puts "  ruby_spriter --consolidate --dir spritesheets/ --no-validate-columns"
      puts ""
      exit
    end

    def show_batch_mode_help
      puts ""
      puts "Batch Mode"
      puts "=" * 60
      puts ""
      puts "Process multiple MP4 videos in a directory with consistent options."
      puts ""
      puts "Basic Usage:"
      puts "  ruby_spriter --batch --dir DIRECTORY [options]"
      puts ""
      puts "Required:"
      puts "  --batch                          Enable batch processing mode"
      puts "  --dir DIRECTORY                  Directory containing MP4 files"
      puts ""
      puts "Batch Options:"
      puts "  --outputdir DIRECTORY            Output directory (default: same as input dir)"
      puts "  --batch-consolidate              Consolidate all results into single spritesheet"
      puts ""
      puts "Spritesheet Options (applied to all videos):"
      puts "  -f, --frames COUNT               Number of frames to extract (default: 16)"
      puts "  -c, --columns COUNT              Grid columns (default: 4)"
      puts "  -w, --width PIXELS               Max frame width (default: 320)"
      puts "  -b, --background COLOR           Tile background: black, white (default: black)"
      puts "  --save-frames                    Save individual frames to disk"
      puts ""
      puts "Image Processing (applied to all videos):"
      puts "  -s, --scale PERCENT              Scale images by percentage"
      puts "    --interpolation METHOD         └─ Interpolation: none, linear, cubic, nohalo, lohalo (default: nohalo)"
      puts ""
      puts "  --sharpen                        Apply unsharp mask for edge enhancement"
      puts "    --sharpen-radius VALUE         └─ Sharpen radius (default: 2.0)"
      puts "    --sharpen-gain VALUE           └─ Sharpen gain (default: 0.5)"
      puts "    --sharpen-threshold VALUE      └─ Sharpen threshold (default: 0.03)"
      puts ""
      puts "  -r, --remove-bg                  Remove background"
      puts "    --aggressive                   └─ Use rembg for AI-powered removal (requires Python + rembg)"
      puts "    --fuzzy                        └─ Use fuzzy select (DEFAULT)"
      puts "    --no-fuzzy                     └─ Use global color select"
      puts "    -t, --threshold VALUE          └─ Feather radius (default: 0.0)"
      puts "    -g, --grow PIXELS              └─ Grow selection (default: 1)"
      puts ""
      puts "  --order ORDER                    Operation order when using BOTH --scale AND --remove-bg:"
      puts "                                   scale_first or bg_first (default: scale_first)"
      puts ""
      puts "Output Options:"
      puts "  --max-compress                   Apply maximum PNG compression"
      puts "  --overwrite                      Overwrite existing files"
      puts "  --keep-temp                      Keep temporary files"
      puts "  --debug                          Enable debug mode"
      puts ""
      puts "Behavior:"
      puts "  - Processes all MP4 files in the specified directory"
      puts "  - Enforces unique filenames unless --overwrite is specified"
      puts "  - Continues processing remaining videos if one fails"
      puts "  - Provides summary of successes and failures"
      puts ""
      puts "Examples:"
      puts "  ruby_spriter --batch --dir videos/"
      puts "  ruby_spriter --batch --dir videos/ --outputdir output/"
      puts "  ruby_spriter --batch --dir videos/ --scale 50 --sharpen"
      puts "  ruby_spriter --batch --dir videos/ --remove-bg --aggressive"
      puts "  ruby_spriter --batch --dir videos/ --batch-consolidate --max-compress"
      puts ""
      exit
    end

    def show_split_mode_help
      puts ""
      puts "Split Mode"
      puts "=" * 60
      puts ""
      puts "Extract individual frames from a spritesheet (requires --image)."
      puts ""
      puts "Basic Usage:"
      puts "  ruby_spriter --image FILE --split R:C [options]"
      puts ""
      puts "Required:"
      puts "  -i, --image FILE                 Input spritesheet file (PNG)"
      puts "  --split R:C                      Split format: rows:columns (e.g., 4:4)"
      puts "    --override-md                  └─ Override embedded metadata"
      puts ""
      puts "Format Requirements:"
      puts "  - Rows and columns must be 1-99"
      puts "  - Total frames (R × C) must be < 1000"
      puts "  - Image dimensions must divide evenly by rows and columns"
      puts ""
      puts "Metadata Behavior:"
      puts "  - If spritesheet has embedded metadata, it will be used automatically"
      puts "  - Use --override-md to ignore embedded metadata and use --split value"
      puts "  - If no metadata exists, --split value is required"
      puts ""
      puts "Output Options:"
      puts "  -o, --output FILE                Output directory (default: filename_frames/)"
      puts "  --overwrite                      Overwrite existing files"
      puts "  --keep-temp                      Keep temporary files"
      puts "  --debug                          Enable debug mode"
      puts ""
      puts "Output:"
      puts "  - Frames are saved as: FR001_filename.png, FR002_filename.png, etc."
      puts "  - Frame naming uses 3-digit zero-padded format (FR001-FR999)"
      puts "  - Output directory: filename_frames/ (unless --output specified)"
      puts ""
      puts "Examples:"
      puts "  ruby_spriter --image sprite.png --split 4:4"
      puts "  ruby_spriter --image sprite.png --split 8:8 --override-md"
      puts "  ruby_spriter --image sprite.png --split 2:5 --output frames/"
      puts ""
      exit
    end
  end
end
