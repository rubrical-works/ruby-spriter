#!/usr/bin/env ruby
# frozen_string_literal: true

# ==============================================================================
# MP4 to Spritesheet + GIMP Image Processing Script (Ruby)
# ==============================================================================
# 
# Version 0.6
# Developed with assistance from Claude (Anthropic AI)
# https://github.com/scooter-indie/ruby-spriter.git
#
# Cross-Platform: Works on Windows and Linux
# Configure GIMP_PATH below for your system
#
# Cross-Platform: Works on Windows and Linux
# Configure GIMP_PATH below for your system
#
# This script combines powerful workflows:
# 1. Extract frames from MP4 and create spritesheets using ffmpeg
# 2. Process images with GIMP (scale, remove background)
# 3. Consolidate multiple spritesheets vertically for Godot
# 4. Embed and read metadata for accurate grid detection (NEW in 0.6)
#
# Requirements:
#   Windows: choco install ffmpeg, GIMP 3.x
#   Linux:   sudo apt install ffmpeg, gimp (version 3.x)
#
# ==============================================================================
# PLATFORM CONFIGURATION
# ==============================================================================
#
# Set these paths according to your system:
#
# WINDOWS:
#   GIMP_PATH = 'C:\\Program Files\\GIMP 3\\bin\\gimp-console-3.0.exe'
#
# LINUX:
#   GIMP_PATH = '/usr/bin/gimp'
#
# MACOS:
#   GIMP_PATH = '/Applications/GIMP.app/Contents/MacOS/gimp'
#
# ==============================================================================
# USAGE EXAMPLES
# ==============================================================================
#
# Basic Usage:
#   ruby ruby_spriter.rb --video input.mp4
#   ruby ruby_spriter.rb --image input.png --remove-bg
#
# Video to Spritesheet:
#   ruby ruby_spriter.rb --video myvideo.mp4
#   ruby ruby_spriter.rb --video myvideo.mp4 --output sprite.png
#   ruby ruby_spriter.rb --video myvideo.mp4 --frames 20 --columns 5
#   ruby ruby_spriter.rb --video myvideo.mp4 --width 480
#
# Background Removal (Fuzzy Select - Recommended):
#   ruby ruby_spriter.rb --video myvideo.mp4 --remove-bg
#   ruby ruby_spriter.rb --video myvideo.mp4 --remove-bg --fuzzy
#   ruby ruby_spriter.rb --video myvideo.mp4 --remove-bg --fuzzy --grow 0
#   ruby ruby_spriter.rb --image sprite.png --remove-bg --fuzzy --grow 0
#
# Background Removal (Global Color Select):
#   ruby ruby_spriter.rb --video myvideo.mp4 --remove-bg --no-fuzzy
#   ruby ruby_spriter.rb --video myvideo.mp4 --remove-bg --no-fuzzy --grow 2
#
# Scaling:
#   ruby ruby_spriter.rb --video myvideo.mp4 --scale 50
#   ruby ruby_spriter.rb --video myvideo.mp4 --remove-bg --scale 75
#   ruby ruby_spriter.rb --image sprite.png --scale 50
#
# Combined Operations:
#   ruby ruby_spriter.rb --video myvideo.mp4 --remove-bg --scale 50
#   ruby ruby_spriter.rb --video myvideo.mp4 --remove-bg --scale 50 --order bg_first
#
# Consolidate Multiple Spritesheets (NEW in v0.6):
#   ruby ruby_spriter.rb --consolidate sprite1.png,sprite2.png,sprite3.png
#   ruby ruby_spriter.rb --consolidate sprite1.png,sprite2.png --output master.png
#
# Verify Spritesheet Metadata (NEW in v0.6):
#   ruby ruby_spriter.rb --verify spritesheet.png
#
# Presets:
#   ruby ruby_spriter.rb --video myvideo.mp4 --preset thumbnail
#   ruby ruby_spriter.rb --video myvideo.mp4 --preset preview --remove-bg
#
# Debug Mode:
#   ruby ruby_spriter.rb --video myvideo.mp4 --remove-bg --debug
#
# ==============================================================================
# COMMAND LINE OPTIONS
# ==============================================================================
#
# INPUT OPTIONS:
#   -v, --video FILE              Input video file (MP4)
#   -i, --image FILE              Input image file (PNG) for direct processing
#       --consolidate FILES       Consolidate multiple spritesheets (comma-separated)
#       --verify FILE             Verify spritesheet metadata
#
# SPRITESHEET OPTIONS:
#   -o, --output FILE             Output file path
#   -f, --frames COUNT            Number of frames to extract (default: 16)
#   -c, --columns COUNT           Grid columns (default: 4)
#   -w, --width PIXELS            Max frame width (default: 320)
#   -b, --background COLOR        Tile background: black, white (default: black)
#
# GIMP PROCESSING OPTIONS:
#   -s, --scale PERCENT           Scale image by percentage (e.g., 50, 75, 200)
#   -r, --remove-bg               Remove background from spritesheet using GIMP
#   -t, --threshold VALUE         Feather radius for smooth edges (default: 0.0)
#   -g, --grow PIXELS             Pixels to grow/shrink selection (default: 1)
#
# BACKGROUND REMOVAL METHOD:
#       --fuzzy                   Use fuzzy select (contiguous regions only) - DEFAULT
#       --no-fuzzy                Use global color select (all matching pixels)
#
# OPERATION ORDER:
#       --order scale_first       Scale first, then remove background (default)
#       --order bg_first          Remove background first, then scale
#
# CONSOLIDATION OPTIONS:
#       --validate-columns        Abort if column counts don't match (default: true)
#
# PRESET CONFIGURATIONS:
#       --preset thumbnail        3x3 grid, 9 frames, 240px wide
#       --preset preview          4x4 grid, 16 frames, 400px wide
#       --preset detailed         10x5 grid, 50 frames, 320px wide
#       --preset contact          8x8 grid, 64 frames, 160px wide
#
# OTHER OPTIONS:
#       --keep-temp               Keep temporary files for debugging
#       --debug                   Enable debug mode (verbose output + keep temp files)
#   -h, --help                    Show help message
#
# ==============================================================================

require 'optparse'
require 'fileutils'
require 'tmpdir'
require 'open3'

class VideoSpritesheetProcessor
  # ===========================================================================
  # PLATFORM CONFIGURATION - EDIT THESE FOR YOUR SYSTEM
  # ===========================================================================
  
  # Detect platform
  PLATFORM = case RUBY_PLATFORM
  when /mingw|mswin|windows/i
    :windows
  when /linux/i
    :linux
  when /darwin/i
    :macos
  else
    :unknown
  end
  
  # GIMP executable path (EDIT THIS FOR YOUR SYSTEM)
  GIMP_PATH = case PLATFORM
  when :windows
    'C:\\Program Files\\GIMP 3\\bin\\gimp-console-3.0.exe'
  when :linux
    '/usr/bin/gimp'
  when :macos
    '/Applications/GIMP.app/Contents/MacOS/gimp'
  else
    'gimp'
  end
  
  # Alternative GIMP paths to try if default doesn't exist
  GIMP_ALTERNATIVE_PATHS = case PLATFORM
  when :windows
    [
      'C:\\Program Files\\GIMP 3\\bin\\gimp-console-3.0.exe',
      'C:\\Program Files (x86)\\GIMP 3\\bin\\gimp-console-3.0.exe',
      'C:\\Program Files\\GIMP 2\\bin\\gimp-console-2.10.exe'
    ]
  when :linux
    [
      '/usr/bin/gimp',
      '/usr/local/bin/gimp',
      '/snap/bin/gimp',
      '/opt/gimp/bin/gimp'
    ]
  when :macos
    [
      '/Applications/GIMP.app/Contents/MacOS/gimp',
      '/Applications/GIMP-2.10.app/Contents/MacOS/gimp'
    ]
  else
    ['gimp']
  end
  
  attr_reader :options
  
  def initialize
    @options = {
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
      remove_bg: false,
      bg_threshold: 0.0,
      grow_selection: 1,
      fuzzy_select: true,
      operation_order: :scale_then_remove_bg,
      validate_columns: true,
      temp_dir: nil,
      keep_temp: false,
      debug: false
    }
    
    @gimp_executable = find_gimp_executable
  end

  def parse_arguments(args)
    OptionParser.new do |opts|
      opts.banner = "Usage: #{File.basename($0)} [options]"
      
      opts.separator ""
      opts.separator "Platform: #{PLATFORM.to_s.capitalize}"
      opts.separator ""
      opts.separator "Input Options:"
      opts.on("-v", "--video FILE", "Input video file (MP4)") do |v|
        @options[:video] = v
      end
      
      opts.on("-i", "--image FILE", "Input image file (PNG) for direct processing") do |i|
        @options[:image] = i
      end
      
      opts.on("--consolidate FILES", "Consolidate multiple spritesheets (comma-separated)") do |c|
        @options[:consolidate] = c.split(',').map(&:strip)
      end
      
      opts.on("--verify FILE", "Verify spritesheet metadata") do |v|
        @options[:verify] = v
      end
      
      opts.separator ""
      opts.separator "Spritesheet Options:"
      opts.on("-o", "--output FILE", "Output file path") do |o|
        @options[:output] = o
      end
      
      opts.on("-f", "--frames COUNT", Integer, "Number of frames to extract (default: 16)") do |f|
        @options[:frame_count] = f
      end
      
      opts.on("-c", "--columns COUNT", Integer, "Grid columns (default: 4)") do |c|
        @options[:columns] = c
      end
      
      opts.on("-w", "--width PIXELS", Integer, "Max frame width (default: 320)") do |w|
        @options[:max_width] = w
      end
      
      opts.on("-b", "--background COLOR", "Tile background: black, white (default: black)") do |b|
        @options[:bg_color] = b
      end
      
      opts.separator ""
      opts.separator "GIMP Processing Options:"
      opts.on("-s", "--scale PERCENT", Integer, "Scale image by percentage") do |s|
        @options[:scale_percent] = s
      end
      
      opts.on("-r", "--remove-bg", "Remove background from spritesheet using GIMP") do
        @options[:remove_bg] = true
      end
      
      opts.on("-t", "--threshold VALUE", Float, "Feather radius (default: 0.0 = no feathering)") do |t|
        @options[:bg_threshold] = t
      end
      
      opts.on("-g", "--grow PIXELS", Integer, "Pixels to grow selection (default: 1, try 0 for less aggressive)") do |g|
        @options[:grow_selection] = g
      end
      
      opts.separator ""
      opts.separator "Background Removal Method:"
      opts.on("--fuzzy", "Use fuzzy select (contiguous regions only) - DEFAULT") do
        @options[:fuzzy_select] = true
      end
      
      opts.on("--no-fuzzy", "Use global color select (all matching pixels)") do
        @options[:fuzzy_select] = false
      end
      
      opts.separator ""
      opts.on("--order ORDER", [:scale_first, :bg_first], 
              "Operation order: scale_first or bg_first (default: scale_first)") do |order|
        @options[:operation_order] = order == :bg_first ? :remove_bg_then_scale : :scale_then_remove_bg
      end
      
      opts.separator ""
      opts.separator "Consolidation Options:"
      opts.on("--[no-]validate-columns", "Validate column counts match (default: true)") do |v|
        @options[:validate_columns] = v
      end
      
      opts.separator ""
      opts.separator "Preset Configurations:"
      opts.on("--preset NAME", [:thumbnail, :preview, :detailed, :contact],
              "Use preset: thumbnail, preview, detailed, contact") do |preset|
        apply_preset(preset)
      end
      
      opts.separator ""
      opts.separator "Other Options:"
      opts.on("--keep-temp", "Keep temporary files for debugging") do
        @options[:keep_temp] = true
      end
      
      opts.on("--debug", "Enable debug mode (verbose output)") do
        @options[:debug] = true
        @options[:keep_temp] = true
      end
      
      opts.on("-h", "--help", "Show this help message") do
        puts opts
        exit
      end
    end.parse!(args)
    
    validate_options
  end
  
  def apply_preset(preset)
    case preset
    when :thumbnail
      @options.merge!(frame_count: 9, columns: 3, max_width: 240, padding: 0, bg_color: 'black')
    when :preview
      @options.merge!(frame_count: 16, columns: 4, max_width: 400, padding: 0, bg_color: 'black')
    when :detailed
      @options.merge!(frame_count: 50, columns: 10, max_width: 320, padding: 0, bg_color: 'black')
    when :contact
      @options.merge!(frame_count: 64, columns: 8, max_width: 160, padding: 0, bg_color: 'black')
    end
  end
  
  def validate_options
    # Check for verify mode (standalone)
    return if @options[:verify]
    
    # Check for mutually exclusive input options
    input_count = [@options[:video], @options[:image], @options[:consolidate]].compact.length
    
    if input_count == 0
      abort "ERROR: Must specify --video, --image, --consolidate, or --verify"
    end

    if input_count > 1
      abort "ERROR: Cannot use --video, --image, and --consolidate together. Choose one."
    end
    
    if @options[:video] && !File.exist?(@options[:video])
      abort "ERROR: Video file not found: #{@options[:video]}"
    end
    
    if @options[:image] && !File.exist?(@options[:image])
      abort "ERROR: Image file not found: #{@options[:image]}"
    end
    
    # Validate consolidate files
    if @options[:consolidate]
      if @options[:consolidate].length < 2
        abort "ERROR: --consolidate requires at least 2 files"
      end

      @options[:consolidate].each do |file|
        unless File.exist?(file)
          abort "ERROR: Consolidate file not found: #{file}"
        end
      end
    end
  end
  
  def run
    # Handle verify mode
    if @options[:verify]
      verify_spritesheet_metadata(@options[:verify])
      return
    end
    
    puts "\n" + "=" * 60
    puts "Ruby Spriter (Version 0.6)"
    puts "Platform: #{PLATFORM.to_s.capitalize}"
    puts "=" * 60 + "\n"
    
    check_dependencies
    
    if @options[:consolidate]
      # Consolidation mode
      consolidate_spritesheets(@options[:consolidate])
    elsif @options[:image]
      # Direct image processing
      working_file = @options[:image]
      
      if @options[:scale_percent] || @options[:remove_bg]
        working_file = process_with_gimp(working_file)
      end
      
      if @options[:output] && working_file != @options[:output]
        FileUtils.cp(working_file, @options[:output])
        puts "\n✅ Final output: #{@options[:output]}"
      else
        puts "\n✅ Processing complete: #{working_file}"
      end
    else
      # Video to spritesheet
      working_file = process_video_to_spritesheet
      
      if @options[:scale_percent] || @options[:remove_bg]
        working_file = process_with_gimp(working_file)
      end
      
      if @options[:output] && working_file != @options[:output]
        FileUtils.cp(working_file, @options[:output])
        puts "\n✅ Final output: #{@options[:output]}"
      else
        puts "\n✅ Processing complete: #{working_file}"
      end
    end
    
    cleanup unless @options[:keep_temp]
    
    puts "\n" + "=" * 60
    puts "SUCCESS!"
    puts "=" * 60 + "\n"
  end
  
  private
  
  # ===========================================================================
  # NEW: Metadata Management (v0.6)
  # ===========================================================================
  
  def add_spritesheet_metadata(input_file, output_file, columns, rows, frames)
  # Use ImageMagick to add PNG comment with metadata
  magick_cmd = PLATFORM == :windows ? 'magick convert' : 'convert'
  
  # Create metadata string
  metadata_str = "SPRITESHEET|columns=#{columns}|rows=#{rows}|frames=#{frames}|version=0.6"
  
  cmd = [
    magick_cmd,
    quote_path(input_file),
    '-set', 'comment', quote_arg(metadata_str),
    quote_path(output_file)
  ]
  
  cmd_str = cmd.join(' ')
  
  if @options[:debug]
    puts "      DEBUG: Metadata command: #{cmd_str}"
  end
  
  stdout, stderr, status = Open3.capture3(cmd_str)
  
  unless status.success?
    # Fallback: just copy the file
    FileUtils.cp(input_file, output_file) if input_file != output_file
    puts "      ⚠️  Warning: Could not write metadata" if @options[:debug]
  end
end

def read_spritesheet_metadata(file)
  metadata = { columns: nil, rows: nil, frames: nil }
  
  # Use ImageMagick identify to read PNG comment
  identify_cmd = PLATFORM == :windows ? 'magick identify' : 'identify'
  
  cmd = "#{identify_cmd} -format \"%c\" #{quote_path(file)}"
  
  stdout, stderr, status = Open3.capture3(cmd)
  
  if status.success? && !stdout.empty?
    # Parse metadata string format: SPRITESHEET|columns=8|rows=2|frames=16|version=0.6
    if stdout =~ /SPRITESHEET/
      stdout.scan(/columns=(\d+)/i) { metadata[:columns] = $1.to_i }
      stdout.scan(/rows=(\d+)/i) { metadata[:rows] = $1.to_i }
      stdout.scan(/frames=(\d+)/i) { metadata[:frames] = $1.to_i }
    end
  end
  
  metadata
end

def command_exists?(cmd)
  if PLATFORM == :windows
    system("where #{cmd} >nul 2>&1")
  else
    system("which #{cmd} >/dev/null 2>&1")
  end
end

  
  def verify_spritesheet_metadata(file)
    unless File.exist?(file)
      abort "ERROR: File not found: #{file}"
    end
    
    puts "\n" + "=" * 60
    puts "Spritesheet Metadata Verification"
    puts "=" * 60
    puts ""
    puts "File: #{File.basename(file)}"
    puts "Path: #{File.dirname(file)}"
    
    dimensions = get_image_dimensions(file)
    metadata = read_spritesheet_metadata(file)
    
    puts ""
    puts "Image Dimensions: #{dimensions[:width]}×#{dimensions[:height]} pixels"
    puts "File Size: #{format_file_size(File.size(file))}"
    puts ""
    
    if metadata[:columns] && metadata[:rows]
      puts "✅ Embedded Metadata Found:"
      puts "   Columns: #{metadata[:columns]}"
      puts "   Rows: #{metadata[:rows]}"
      puts "   Total Cells: #{metadata[:columns] * metadata[:rows]}"
      puts "   Frames: #{metadata[:frames]}" if metadata[:frames]
      puts "   Cell Size: #{dimensions[:width] / metadata[:columns]}×#{dimensions[:height] / metadata[:rows]} pixels"
      puts ""
      puts "🎮 Godot AnimatedSprite2D Settings:"
      puts "   Hframes: #{metadata[:columns]}"
      puts "   Vframes: #{metadata[:rows]}"
    else
      puts "❌ No Spritesheet Metadata Found"
      puts ""
      puts "Auto-detection results:"
      info = analyze_spritesheet(file)
      puts "   Detected Grid: #{info[:columns]}×#{info[:rows]}"
      puts "   Cell Size: #{info[:cell_width]}×#{info[:cell_height]} pixels"
      puts ""
      puts "⚠️  Note: Auto-detection may be inaccurate. Consider recreating"
      puts "   the spritesheet with ruby_spriter to embed proper metadata."
    end
    
    puts "=" * 60 + "\n"
  end
  
  # ===========================================================================
  # Spritesheet Consolidation (v0.6)
  # ===========================================================================
  
  def consolidate_spritesheets(input_files)
    puts "🔗 Consolidating #{input_files.length} spritesheets...\n"
    
    # Analyze all input spritesheets
    sheets_info = input_files.map.with_index do |file, idx|
      puts "[#{idx + 1}/#{input_files.length}] Analyzing #{File.basename(file)}..."
      info = analyze_spritesheet(file)
      info[:filename] = file
      info[:index] = idx + 1
      info
    end
    
    # Display analysis results
    puts "\n" + "=" * 60
    puts "Analysis Results:"
    puts "=" * 60
    sheets_info.each do |info|
      metadata_indicator = info[:has_metadata] ? "📝" : "🔍"
      puts "[#{info[:index]}] #{File.basename(info[:filename])} #{metadata_indicator}"
      puts "    Size: #{info[:width]}×#{info[:height]} pixels"
      puts "    Grid: #{info[:columns]}×#{info[:rows]} (#{info[:total_cells]} cells)"
      puts "    Cell: #{info[:cell_width]}×#{info[:cell_height]} pixels"
    end
    puts ""
    puts "Legend: 📝 = metadata embedded, 🔍 = auto-detected"
    puts "=" * 60 + "\n"
    
    # Validate compatibility
    validate_consolidation_compatibility(sheets_info)
    
    # Calculate output dimensions
    output_width = sheets_info.first[:width]
    output_height = sheets_info.sum { |s| s[:height] }
    total_columns = sheets_info.first[:columns]
    total_rows = sheets_info.sum { |s| s[:rows] }
    total_cells = total_columns * total_rows
    
    puts "Output Specifications:"
    puts "  Size: #{output_width}×#{output_height} pixels"
    puts "  Grid: #{total_columns}×#{total_rows} (#{total_cells} cells)"
    puts ""
    
    # Determine output filename
    output_file = @options[:output] || generate_consolidation_filename(input_files)
    
    # Perform consolidation
    puts "Creating consolidated spritesheet..."
    consolidate_with_ffmpeg(input_files, output_file, total_columns, total_rows, total_cells)
    
    # Display results
    file_size = File.size(output_file)
    puts ""
    puts "=" * 60
    puts "✅ CONSOLIDATION COMPLETE!"
    puts "=" * 60
    puts ""
    puts "Output: #{output_file}"
    puts "Size:   #{format_file_size(file_size)}"
    puts ""
    puts "🎮 Godot AnimatedSprite2D Settings:"
    puts "   Hframes: #{total_columns}"
    puts "   Vframes: #{total_rows}"
    puts ""
    puts "📝 Metadata has been embedded in the consolidated spritesheet."
    puts "   Use --verify to confirm: ruby_spriter --verify #{File.basename(output_file)}"
    puts ""
  end
  
  def analyze_spritesheet(file)
    # Get image dimensions using ffprobe
    dimensions = get_image_dimensions(file)
    width = dimensions[:width]
    height = dimensions[:height]
    
    # Try to read metadata first
    metadata = read_spritesheet_metadata(file)
    
    if metadata[:columns] && metadata[:rows]
      # Use metadata if available
      columns = metadata[:columns]
      rows = metadata[:rows]
      cell_width = width / columns
      cell_height = height / rows
      total_cells = columns * rows
      
      if @options[:debug]
        puts "      ✓ Using embedded metadata: #{columns}×#{rows}"
      end
      
      {
        width: width,
        height: height,
        columns: columns,
        rows: rows,
        cell_width: cell_width,
        cell_height: cell_height,
        total_cells: total_cells,
        has_metadata: true
      }
    else
      # Fall back to detection
      if @options[:debug]
        puts "      ⚠️  No metadata found, auto-detecting grid..."
      end
      
      # Detect columns (use specified columns if set and not default)
      columns = if @options[:columns] != 4  # 4 is default
        @options[:columns]
      else
        detect_columns(width, height)
      end
      
      # Calculate cell width
      cell_width = width / columns
      
      # Try to detect rows properly
      common_rows = [1, 2, 3, 4, 5, 6, 8, 10, 12, 16, 20]
      
      rows = nil
      common_rows.each do |r|
        if height % r == 0
          test_cell_height = height / r
          # Check if this gives reasonable cell proportions
          aspect_ratio = cell_width.to_f / test_cell_height
          if aspect_ratio >= 0.5 && aspect_ratio <= 2.0
            rows = r
            break
          end
        end
      end
      
      # Fallback to square cells assumption
      rows ||= (height.to_f / cell_width).round
      rows = 1 if rows < 1
      
      cell_height = height / rows
      total_cells = columns * rows
      
      {
        width: width,
        height: height,
        columns: columns,
        rows: rows,
        cell_width: cell_width,
        cell_height: cell_height,
        total_cells: total_cells,
        has_metadata: false
      }
    end
  end
  
  def get_image_dimensions(file)
    cmd = [
      'ffprobe',
      '-v', 'error',
      '-select_streams', 'v:0',
      '-show_entries', 'stream=width,height',
      '-of', 'csv=s=x:p=0',
      file
    ]
    
    stdout, stderr, status = Open3.capture3(*cmd)
    
    unless status.success?
      abort "ERROR: Could not read image dimensions for #{file}"
    end
    
    width, height = stdout.strip.split('x').map(&:to_i)
    
    { width: width, height: height }
  end
  
  def detect_columns(width, height)
    # Try common column counts and pick the best match
    common_columns = [4, 8, 5, 10, 6, 3, 12, 16, 2, 1]
    
    best_columns = 4
    best_ratio_diff = Float::INFINITY
    
    common_columns.each do |cols|
      next if width % cols != 0
      
      cell_w = width / cols
      potential_rows = height / cell_w
      next if height % cell_w != 0
      
      # Prefer square cells (ratio close to 1.0)
      ratio = cell_w.to_f / (height / potential_rows)
      ratio_diff = (ratio - 1.0).abs
      
      if ratio_diff < best_ratio_diff
        best_ratio_diff = ratio_diff
        best_columns = cols
      end
    end
    
    best_columns
  end
  
  def validate_consolidation_compatibility(sheets_info)
    # Check width consistency
    widths = sheets_info.map { |s| s[:width] }.uniq
    if widths.length > 1
      puts "❌ ERROR: All spritesheets must have the same width!"
      puts ""
      sheets_info.each do |info|
        puts "   [#{info[:index]}] #{File.basename(info[:filename])}: #{info[:width]} pixels"
      end
      puts ""
      abort "Cannot consolidate spritesheets with different widths."
    end
    
    # Check column consistency if validation enabled
    if @options[:validate_columns]
      columns = sheets_info.map { |s| s[:columns] }.uniq
      if columns.length > 1
        puts "❌ ERROR: All spritesheets must have the same number of columns!"
        puts ""
        sheets_info.each do |info|
          puts "   [#{info[:index]}] #{File.basename(info[:filename])}: #{info[:columns]} columns"
        end
        puts ""
        puts "💡 TIP: Use --columns to override or --no-validate-columns to skip this check"
        abort "Cannot consolidate spritesheets with different column counts."
      end
    end
    
    # Check cell size consistency
    cell_widths = sheets_info.map { |s| s[:cell_width] }.uniq
    cell_heights = sheets_info.map { |s| s[:cell_height] }.uniq
    
    if cell_widths.length > 1 || cell_heights.length > 1
      puts "⚠️  WARNING: Cell sizes vary between spritesheets!"
      sheets_info.each do |info|
        puts "   [#{info[:index]}] #{File.basename(info[:filename])}: #{info[:cell_width]}×#{info[:cell_height]} pixels per cell"
      end
      puts ""
      puts "   This may cause alignment issues in Godot."
      puts "   Press Enter to continue or CTRL+C to cancel..."
      gets unless ENV['CI']  # Skip prompt in CI environments
      puts ""
    end
    
    puts "✅ Validation passed\n"
  end
  
  def consolidate_with_ffmpeg(input_files, output_file, total_columns, total_rows, total_frames)
    # Build ffmpeg command for vertical stacking
    inputs = input_files.map { |f| ['-i', f] }.flatten
    filter_inputs = (0...input_files.length).map { |i| "[#{i}:v]" }.join
    filter_complex = "#{filter_inputs}vstack=inputs=#{input_files.length}"
    
    # Create temp file first for metadata addition
    temp_output = output_file.sub('.png', '_temp.png')
    
    cmd = [
      'ffmpeg',
      *inputs,
      '-filter_complex', filter_complex,
      '-y',
      temp_output
    ]
    
    if @options[:debug]
      puts "\nDEBUG: ffmpeg consolidation command:"
      puts "  #{cmd.join(' ')}\n"
    end
    
    stdout, stderr, status = Open3.capture3(*cmd)
    
    if @options[:debug]
      puts stdout unless stdout.empty?
      puts stderr unless stderr.empty?
    end
    
    unless status.success?
      puts "\nERROR: Consolidation failed"
      puts stderr unless stderr.empty?
      abort "ffmpeg vstack operation failed"
    end
    
    unless File.exist?(temp_output)
      abort "ERROR: Temporary output file was not created"
    end
    
    # Add metadata to consolidated file
    add_spritesheet_metadata(temp_output, output_file, total_columns, total_rows, total_frames)
    
    # Clean up temp file
    File.delete(temp_output) if File.exist?(temp_output)
    
    unless File.exist?(output_file)
      abort "ERROR: Output file was not created"
    end
    
    puts "      ✓ Consolidated and embedded metadata: #{total_columns}×#{total_rows} grid"
  end
  
  def generate_consolidation_filename(input_files)
    dir = File.dirname(input_files.first)
    timestamp = Time.now.strftime("%Y%m%d_%H%M%S")
    File.join(dir, "consolidated_#{timestamp}.png")
  end
  
  # ===========================================================================
  # Existing Methods from v0.5
  # ===========================================================================
  
  def find_gimp_executable
    # Try default path first
    return GIMP_PATH if File.exist?(GIMP_PATH)
    
    # Try alternative paths
    GIMP_ALTERNATIVE_PATHS.each do |path|
      return path if File.exist?(path)
    end
    
    # Try to find in PATH
    if PLATFORM == :windows
      path_result = `where gimp 2>nul`.strip
      return path_result unless path_result.empty?
    else
      path_result = `which gimp 2>/dev/null`.strip
      return path_result unless path_result.empty?
    end
    
    # Return default and let error handling deal with it
    GIMP_PATH
  end
  
  def check_dependencies
    puts "[1/1] Checking dependencies..."
    
    check_command('ffmpeg')
    check_command('ffprobe')
    
    if @options[:scale_percent] || @options[:remove_bg]
      unless File.exist?(@gimp_executable)
        abort "ERROR: GIMP 3.x not found!\n" +
              "Searched locations:\n" +
              GIMP_ALTERNATIVE_PATHS.map { |p| "  - #{p}" }.join("\n") +
              "\n\nPlease install GIMP 3.x or edit GIMP_PATH in the script."
      end
      puts "      ✅ GIMP found: #{@gimp_executable}"
    end
    
    puts "      ✅ All dependencies found\n\n"
  end
  
  def check_command(cmd)
    if PLATFORM == :windows
      stdout, stderr, status = Open3.capture3("where #{cmd} 2>nul")
    else
      stdout, stderr, status = Open3.capture3("which #{cmd} 2>/dev/null")
    end
    
    unless status.success?
      install_hint = case PLATFORM
      when :windows
        "choco install #{cmd == 'ffprobe' ? 'ffmpeg' : cmd}"
      when :linux
        "sudo apt install #{cmd == 'ffprobe' ? 'ffmpeg' : cmd}"
      when :macos
        "brew install #{cmd == 'ffprobe' ? 'ffmpeg' : cmd}"
      else
        "install #{cmd}"
      end
      
      abort "ERROR: #{cmd} not found!\nInstall with: #{install_hint}"
    end
  end
  
  def process_video_to_spritesheet
    puts "[2/3] Analyzing video..."
    
    # Get video duration
    duration = get_video_duration(@options[:video])
    puts "      Duration: #{duration} seconds\n\n"
    
    # Calculate rows for grid
    rows = (@options[:frame_count].to_f / @options[:columns]).ceil
    
    # Create spritesheet directly with ffmpeg
    puts "[3/3] Creating spritesheet with ffmpeg..."
    output_file = generate_spritesheet_output_filename(@options[:video])
    create_spritesheet_with_ffmpeg(output_file, duration, rows)
    
    output_file
  end
  
  def get_video_duration(video_path)
    # Normalize path for platform
    video_path_quoted = quote_path(video_path)
    
    cmd = "ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 #{video_path_quoted}"
    stdout, stderr, status = Open3.capture3(cmd)
    
    unless status.success?
      abort "ERROR: Could not determine video duration"
    end
    
    stdout.strip.to_f
  end
  
  def create_spritesheet_with_ffmpeg(output_file, duration, rows)
    video = @options[:video]
    frame_count = @options[:frame_count]
    columns = @options[:columns]
    max_width = @options[:max_width]
    
    # Calculate FPS for frame extraction
    fps = (frame_count / duration.to_f).round(6)
    
    puts "      Layout: #{columns}x#{rows} grid (#{frame_count} frames)"
    puts "      Frame rate: #{fps} fps"
    puts "      Max frame width: #{max_width}px"
    puts "      Padding: NONE (tight grid)"
    puts "      Building spritesheet..."
    
    # ffmpeg filter chain
    filter_complex = [
      "fps=#{fps}",
      "scale=#{max_width}:-1:flags=lanczos",
      "tile=#{columns}x#{rows}"
    ].join(',')
    
    # Quote paths appropriately for platform
    video_quoted = quote_path(video)
    
    # Create temporary file first
    temp_output = output_file.sub('.png', '_temp.png')
    temp_quoted = quote_path(temp_output)
    
    cmd = [
      'ffmpeg',
      '-i', video_quoted,
      '-filter_complex', quote_arg(filter_complex),
      '-frames:v', '1',
      '-y',
      temp_quoted,
      '-hide_banner',
      @options[:debug] ? '-loglevel info' : '-loglevel error'
    ].join(' ')
    
    if @options[:debug]
      puts "\n      DEBUG: ffmpeg command:"
      puts "      #{cmd}\n\n"
    end
    
    stdout, stderr, status = Open3.capture3(cmd)
    
    unless status.success?
      puts "ERROR: Spritesheet creation failed"
      puts stderr unless stderr.strip.empty?
      abort "ffmpeg failed"
    end
    
    unless File.exist?(temp_output)
      abort "ERROR: Temporary output file was not created"
    end
    
    # Add metadata to the PNG file
    add_spritesheet_metadata(temp_output, output_file, columns, rows, frame_count)
    
    # Clean up temp file
    File.delete(temp_output) if File.exist?(temp_output)
    
    unless File.exist?(output_file)
      abort "ERROR: Output file was not created"
    end
    
    file_size = File.size(output_file)
    size_str = format_file_size(file_size)
    
    puts "      ✅ Spritesheet created: #{output_file} (#{size_str})"
    puts "      📝 Metadata embedded: #{columns}×#{rows} grid (#{frame_count} frames)\n\n"
  end
  
  def process_with_gimp(input_file)
  puts "[4/4] Processing with GIMP...\n"
  
  # Read metadata BEFORE processing (so we can restore it after)
  original_metadata = read_spritesheet_metadata(input_file)
  
  if original_metadata[:columns] && original_metadata[:rows]
    puts "      📝 Original metadata found: #{original_metadata[:columns]}×#{original_metadata[:rows]}"
  else
    puts "      ⚠️  No metadata found in source file"
  end
  
  operations = []
  operations << :scale if @options[:scale_percent]
  operations << :remove_bg if @options[:remove_bg]
  
  # Determine operation order
  if @options[:operation_order] == :remove_bg_then_scale
    operations.reverse!
  end
  
  current_file = input_file
  
  operations.each do |op|
    case op
    when :scale
      puts "      📏 Scaling to #{@options[:scale_percent]}%..."
      scaled_file = generate_output_filename(current_file, 'scaled')
      python_script = generate_gimp_scale_script(current_file, scaled_file)
      execute_gimp_script(python_script, scaled_file, "Scale")
      
      # Restore metadata after GIMP processing
      if original_metadata[:columns] && original_metadata[:rows]
        temp_file = scaled_file + ".tmp"
        FileUtils.mv(scaled_file, temp_file)
        add_spritesheet_metadata(temp_file, scaled_file, 
                                original_metadata[:columns], 
                                original_metadata[:rows], 
                                original_metadata[:frames])
        File.delete(temp_file) if File.exist?(temp_file)
        puts "      ✓ Metadata restored to scaled image"
      end
      
      current_file = scaled_file
      
    when :remove_bg
      method_desc = @options[:fuzzy_select] ? "fuzzy select (contiguous)" : "global color select"
      puts "      🎨 Removing background using #{method_desc}..."
      puts "      Settings: feather=#{@options[:bg_threshold]}px, grow=#{@options[:grow_selection]}px"
      nobg_file = generate_output_filename(current_file, 'nobg')
      python_script = generate_gimp_removebg_script(current_file, nobg_file)
      execute_gimp_script(python_script, nobg_file, "Remove Background")
      
      # Restore metadata after GIMP processing
      if original_metadata[:columns] && original_metadata[:rows]
        temp_file = nobg_file + ".tmp"
        FileUtils.mv(nobg_file, temp_file)
        add_spritesheet_metadata(temp_file, nobg_file, 
                                original_metadata[:columns], 
                                original_metadata[:rows], 
                                original_metadata[:frames])
        File.delete(temp_file) if File.exist?(temp_file)
        puts "      ✓ Metadata restored to processed image"
      end
      
      current_file = nobg_file
    end
  end
  
  current_file
end


  
  def generate_gimp_scale_script(input_file, output_file)
    input_path = normalize_path_for_python(input_file)
    output_path = normalize_path_for_python(output_file)
    scale_percent = @options[:scale_percent]
    
    <<~PYTHON
      import sys
      from gi.repository import Gimp, Gio
      
      try:
          img = Gimp.file_load(Gimp.RunMode.NONINTERACTIVE, Gio.File.new_for_path(r"#{input_path}"))
          
          w = img.get_width()
          h = img.get_height()
          
          new_w = int(w * #{scale_percent} / 100.0)
          new_h = int(h * #{scale_percent} / 100.0)
          
          pdb = Gimp.get_pdb()
          scale_proc = pdb.lookup_procedure('gimp-image-scale')
          
          if scale_proc:
              config = scale_proc.create_config()
              config.set_property('image', img)
              config.set_property('new-width', new_w)
              config.set_property('new-height', new_h)
              scale_proc.run(config)
          
          export_proc = pdb.lookup_procedure('file-png-export')
          if export_proc:
              config = export_proc.create_config()
              config.set_property('image', img)
              config.set_property('file', Gio.File.new_for_path(r"#{output_path}"))
              export_proc.run(config)
          
          print("SUCCESS - Scaled to {}x{}".format(new_w, new_h))
      
      except Exception as e:
          print(f"ERROR: {e}")
          import traceback
          traceback.print_exc()
          sys.exit(1)
      finally:
          try:
              img.delete()
          except:
              pass
    PYTHON
  end
  
  def generate_gimp_removebg_script(input_file, output_file)
    input_path = normalize_path_for_python(input_file)
    output_path = normalize_path_for_python(output_file)
    threshold = @options[:bg_threshold]
    grow = @options[:grow_selection]
    use_fuzzy = @options[:fuzzy_select]
    
    <<~PYTHON
      import sys
      from gi.repository import Gimp, Gio, Gegl
      
      try:
          print("Loading image...")
          img = Gimp.file_load(Gimp.RunMode.NONINTERACTIVE, Gio.File.new_for_path(r"#{input_path}"))
          
          w = img.get_width()
          h = img.get_height()
          print(f"Image size: {w}x{h}")
          
          layers = img.get_layers()
          if not layers or len(layers) == 0:
              raise Exception("No layers found")
          layer = layers[0]
          
          # Add alpha channel if needed
          if not layer.has_alpha():
              layer.add_alpha()
              print("Added alpha channel")
          
          pdb = Gimp.get_pdb()
          
          # Sample all four corners
          corners = [
              (0, 0),           # Top-left
              (w-1, 0),         # Top-right
              (0, h-1),         # Bottom-left
              (w-1, h-1)        # Bottom-right
          ]
          
          use_fuzzy = #{use_fuzzy ? 'True' : 'False'}
          
          print(f"Sampling {len(corners)} corners...")
          
          if use_fuzzy:
              print("Using FUZZY SELECT (contiguous regions only)")
              select_proc = pdb.lookup_procedure('gimp-image-select-contiguous-color')
              
              if not select_proc:
                  raise Exception("Could not find gimp-image-select-contiguous-color procedure")
              
              for i, (x, y) in enumerate(corners):
                  print(f"  Corner {i+1} at ({x}, {y})")
                  
                  config = select_proc.create_config()
                  config.set_property('image', img)
                  config.set_property('operation', Gimp.ChannelOps.REPLACE if i == 0 else Gimp.ChannelOps.ADD)
                  config.set_property('drawable', layer)
                  config.set_property('x', float(x))
                  config.set_property('y', float(y))
                  select_proc.run(config)
          else:
              print("Using GLOBAL COLOR SELECT (all matching pixels)")
              select_proc = pdb.lookup_procedure('gimp-image-select-color')
              
              if not select_proc:
                  raise Exception("Could not find gimp-image-select-color procedure")
              
              for i, (x, y) in enumerate(corners):
                  print(f"  Corner {i+1} at ({x}, {y})")
                  color = layer.get_pixel(x, y)
                  
                  config = select_proc.create_config()
                  config.set_property('image', img)
                  config.set_property('operation', Gimp.ChannelOps.REPLACE if i == 0 else Gimp.ChannelOps.ADD)
                  config.set_property('drawable', layer)
                  config.set_property('color', color)
                  select_proc.run(config)
          
          print("Selection complete")
          
          # Grow selection to catch edge pixels
          if #{grow} > 0:
              print(f"Growing selection by {#{grow}} pixels...")
              grow_proc = pdb.lookup_procedure('gimp-selection-grow')
              if grow_proc:
                  config = grow_proc.create_config()
                  config.set_property('image', img)
                  config.set_property('steps', #{grow})
                  grow_proc.run(config)
          elif #{grow} < 0:
              print(f"Shrinking selection by {abs(#{grow})} pixels...")
              shrink_proc = pdb.lookup_procedure('gimp-selection-shrink')
              if shrink_proc:
                  config = shrink_proc.create_config()
                  config.set_property('image', img)
                  config.set_property('steps', abs(#{grow}))
                  shrink_proc.run(config)
          
          # Feather selection only if threshold > 0
          if #{threshold} > 0:
              print(f"Feathering selection by {#{threshold}} pixels...")
              feather_proc = pdb.lookup_procedure('gimp-selection-feather')
              if feather_proc:
                  config = feather_proc.create_config()
                  config.set_property('image', img)
                  config.set_property('radius', #{threshold})
                  feather_proc.run(config)
          
          # Clear the selection
          print("Clearing selected pixels...")
          edit_clear = pdb.lookup_procedure('gimp-drawable-edit-clear')
          if edit_clear:
              config = edit_clear.create_config()
              config.set_property('drawable', layer)
              edit_clear.run(config)
          
          # Deselect
          print("Deselecting...")
          select_none = pdb.lookup_procedure('gimp-selection-none')
          if select_none:
              config = select_none.create_config()
              config.set_property('image', img)
              select_none.run(config)
          
          # Export
          print("Exporting...")
          export_proc = pdb.lookup_procedure('file-png-export')
          if export_proc:
              config = export_proc.create_config()
              config.set_property('image', img)
              config.set_property('file', Gio.File.new_for_path(r"#{output_path}"))
              export_proc.run(config)
          
          print("SUCCESS - Background removed!")
      
      except Exception as e:
          print(f"ERROR: {e}")
          import traceback
          traceback.print_exc()
          sys.exit(1)
      finally:
          try:
              if 'img' in locals():
                  img.delete()
          except:
              pass
    PYTHON
  end
  
  def execute_gimp_script(python_code, expected_output, operation_name)
    script_file = File.join(Dir.tmpdir, "gimp_script_#{Time.now.to_i}_#{rand(10000)}.py")
    log_file = File.join(Dir.tmpdir, "gimp_log_#{Time.now.to_i}_#{rand(10000)}.txt")
    
    begin
      File.write(script_file, python_code)
      
      if @options[:debug]
        puts "\n      DEBUG: Script file: #{script_file}"
        puts "      DEBUG: Log file: #{log_file}"
        puts "      DEBUG: Expected output: #{expected_output}"
      end
      
      # Build GIMP command based on platform
      if PLATFORM == :windows
        # Windows: Use batch file wrapper
        batch_file = File.join(Dir.tmpdir, "gimp_run_#{Time.now.to_i}_#{rand(10000)}.bat")
        batch_content = <<~BATCH
          @echo off
          "#{@gimp_executable}" --quit --batch-interpreter=python-fu-eval -b "exec(open(r'#{script_file}').read())" > "#{log_file}" 2>&1
          exit /b %errorlevel%
        BATCH
        
        File.write(batch_file, batch_content)
        stdout, stderr, status = Open3.capture3("cmd.exe /c \"#{batch_file}\"")
      else
        # Linux/Mac: Direct shell execution
        cmd = "#{quote_path(@gimp_executable)} --quit --batch-interpreter=python-fu-eval -b \"exec(open(r'#{script_file}').read())\" > #{quote_path(log_file)} 2>&1"
        stdout, stderr, status = Open3.capture3(cmd)
      end
      
      gimp_output = ""
      if File.exist?(log_file)
        gimp_output = File.read(log_file)
      end
      
      if @options[:debug] || !status.success?
        puts "\n      === GIMP Output ==="
        puts gimp_output unless gimp_output.strip.empty?
        puts "      ==================\n"
      end
      
      unless File.exist?(expected_output)
        puts "\n      ❌ ERROR: #{operation_name} failed - output file not created"
        puts "\n      Debug Information:"
        puts "        Script: #{script_file}"
        puts "        Log: #{log_file}"
        abort "GIMP processing failed"
      end
      
      file_size = File.size(expected_output)
      size_str = format_file_size(file_size)
      puts "      ✅ #{operation_name} complete (#{size_str})\n"
      
    ensure
      unless @options[:keep_temp]
        File.delete(script_file) if File.exist?(script_file)
        File.delete(log_file) if File.exist?(log_file)
        File.delete(batch_file) if defined?(batch_file) && File.exist?(batch_file) rescue nil
      end
    end
  end
  
  # Platform-specific path helpers
  
  def quote_path(path)
    if PLATFORM == :windows
      "\"#{path}\""
    else
      "'#{path.gsub("'", "\\'")}'"
    end
  end
  
  def quote_arg(arg)
    if PLATFORM == :windows
      "\"#{arg}\""
    else
      "'#{arg.gsub("'", "\\'")}'"
    end
  end
  
  def normalize_path_for_python(path)
    # Convert to absolute path and normalize separators
    abs_path = File.absolute_path(path)
    
    if PLATFORM == :windows
      # Keep backslashes for Windows, but use forward slashes in Python raw strings
      abs_path.gsub('\\', '/')
    else
      abs_path
    end
  end
  
  def generate_spritesheet_output_filename(video_file)
    dir = File.dirname(video_file)
    basename = File.basename(video_file, '.*')
    File.join(dir, "#{basename}_spritesheet.png")
  end
  
  def generate_output_filename(input_file, suffix)
    dir = File.dirname(input_file)
    basename = File.basename(input_file, '.*')
    File.join(dir, "#{basename}-#{suffix}.png")
  end
  
  def format_file_size(bytes)
    if bytes >= 1024 * 1024
      "#{(bytes / (1024.0 * 1024.0)).round(2)} MB"
    else
      "#{(bytes / 1024.0).round(2)} KB"
    end
  end
  
  def cleanup
    if @options[:temp_dir] && Dir.exist?(@options[:temp_dir])
      FileUtils.rm_rf(@options[:temp_dir])
      puts "\n🧹 Cleaned up temporary files"
    end
  end
end

# ==============================================================================
# Main Execution
# ==============================================================================

if __FILE__ == $0
  begin
    processor = VideoSpritesheetProcessor.new
    processor.parse_arguments(ARGV)
    processor.run
  rescue Interrupt
    puts "\n\n⚠️  Process interrupted by user"
    exit 130
  rescue => e
    puts "\n❌ ERROR: #{e.message}"
    puts e.backtrace.join("\n") if ENV['DEBUG']
    exit 1
  end
end
