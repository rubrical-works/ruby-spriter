require 'open3'
require 'fileutils'
require 'tmpdir'
require_relative 'cell_cleanup_config'
require_relative 'cell_cleanup_gimp_script'
require_relative 'gimp_processor'
require_relative 'utils/image_helper'

module RubySpriter
  class CellCleanupProcessor

    def initialize(options = {})
      @config = CellCleanupConfig.new(options)
      @gimp_processor = GimpProcessor.new(options[:gimp_path], options)
      @options = options
    end

    # Main method to cleanup background colors in spritesheet cells
    # @param spritesheet_path [String] Path to the spritesheet PNG
    # @param options [Hash] Processing options
    # @return [Hash] Statistics about cleanup process
    def cleanup_cells(spritesheet_path, options)
      cell_dims = calculate_cell_dimensions(spritesheet_path, options)
      rows = calculate_rows(options)
      columns = options[:columns]

      temp_dir = create_temp_dir
      cleaned_cells = []
      stats = { processed: 0, cleaned: 0, skipped: 0, colors_removed: 0 }

      puts "  Analyzing spritesheet: #{columns}×#{rows} grid (#{rows * columns} cells)"
      puts "  Dominance threshold: #{@config.threshold}%\n\n"

      (0...rows).each do |row|
        (0...columns).each do |col|
          stats[:processed] += 1

          # Extract cell region
          cell_path = extract_cell(spritesheet_path, row, col, cell_dims[:width], cell_dims[:height], temp_dir)

          # Analyze for dominant colors
          dominant_colors = analyze_cell_colors(cell_path)

          if dominant_colors && !dominant_colors.empty?
            # Remove dominant colors via GIMP
            cleaned_cell = remove_dominant_colors(cell_path, dominant_colors, options, temp_dir)
            cleaned_cells << cleaned_cell
            stats[:cleaned] += 1
            stats[:colors_removed] += dominant_colors.length

            puts "  Cell [#{row},#{col}]: Removed #{dominant_colors.length} dominant color(s)"
          else
            # No cleanup needed
            cleaned_cells << cell_path
            stats[:skipped] += 1
            puts "  Cell [#{row},#{col}]: No dominant colors detected (skipped)"
          end
        end
      end

      # Reassemble cleaned cells
      reassemble_spritesheet(cleaned_cells, columns, rows, spritesheet_path)

      puts "\n  ✓ Cleanup complete"
      puts "  - Processed: #{stats[:processed]} cells"
      puts "  - Cleaned: #{stats[:cleaned]} cells"
      puts "  - Skipped: #{stats[:skipped]} cells"
      puts "  - Dominant colors removed: #{stats[:colors_removed]} total\n"

      stats
    ensure
      cleanup_temp_dir(temp_dir) if temp_dir
    end

    private

    def calculate_cell_dimensions(spritesheet_path, options)
      image_info = Utils::ImageHelper.get_dimensions(spritesheet_path)

      columns = options[:columns]
      raise ProcessingError, "columns is nil or zero" if columns.nil? || columns == 0

      rows = calculate_rows(options)
      raise ProcessingError, "rows is nil or zero" if rows.nil? || rows == 0

      {
        width: image_info[:width] / columns,
        height: image_info[:height] / rows
      }
    end

    def calculate_rows(options)
      frames = options[:frames]
      columns = options[:columns]

      raise ProcessingError, "frames is nil or zero: #{frames.inspect}" if frames.nil? || frames == 0
      raise ProcessingError, "columns is nil or zero: #{columns.inspect}" if columns.nil? || columns == 0

      (frames.to_f / columns).ceil
    end

    def parse_histogram(histogram_output)
      colors = {}

      histogram_output.each_line do |line|
        # Parse ImageMagick histogram format:
        # "1234: (255,0,0) #FF0000 srgb(255,0,0)"
        next unless line.match(/^\s*(\d+):\s*\((\d+),(\d+),(\d+)/)

        count = $1.to_i
        r = $2.to_i
        g = $3.to_i
        b = $4.to_i

        # Skip fully transparent pixels (indicated by rgba format with alpha=0)
        next if line.include?('srgba') && line.include?(',0)')

        colors["rgb(#{r},#{g},#{b})"] = count
      end

      colors
    end

    def analyze_cell_colors(cell_image_path)
      # Extract histogram using ImageMagick
      convert_cmd = Platform.imagemagick_convert_cmd
      cmd = "#{convert_cmd} #{Utils::PathHelper.quote_path(cell_image_path)} -define histogram:unique-colors=true -format %c histogram:info:-"
      histogram_output = execute_command(cmd)

      # Parse histogram into color => pixel_count hash
      colors = parse_histogram(histogram_output)

      # Calculate total non-transparent pixels
      total_pixels = colors.values.sum
      return nil if total_pixels == 0  # Empty cell

      # Find colors exceeding dominance threshold
      dominant_colors = colors.select do |color, count|
        percentage = (count.to_f / total_pixels) * 100
        percentage >= @config.threshold
      end

      # Return dominant colors or nil if none found
      dominant_colors.empty? ? nil : dominant_colors.keys
    end

    def execute_command(cmd)
      stdout, stderr, status = Open3.capture3(cmd)
      raise ProcessingError, "Command failed: #{stderr}" unless status.success?
      stdout
    end

    def create_temp_dir
      Dir.mktmpdir('cell_cleanup')
    end

    def cleanup_temp_dir(temp_dir)
      FileUtils.rm_rf(temp_dir) if temp_dir && Dir.exist?(temp_dir)
    end

    def extract_cell(spritesheet_path, row, col, cell_width, cell_height, temp_dir)
      x_offset = col * cell_width
      y_offset = row * cell_height
      cell_path = File.join(temp_dir, "cell_#{row}_#{col}.png")

      # Use ImageMagick crop: convert spritesheet.png -crop WxH+X+Y +repage cell.png
      convert_cmd = Platform.imagemagick_convert_cmd
      cmd = [
        convert_cmd,
        Utils::PathHelper.quote_path(spritesheet_path),
        '-crop', "#{cell_width}x#{cell_height}+#{x_offset}+#{y_offset}",
        '+repage',
        Utils::PathHelper.quote_path(cell_path)
      ].join(' ')

      stdout, stderr, status = Open3.capture3(cmd)

      unless status.success?
        raise ProcessingError, "Failed to extract cell: #{stderr}"
      end

      cell_path
    end

    def remove_dominant_colors(cell_path, dominant_colors, options, temp_dir)
      cleaned_path = cell_path.sub('.png', '_cleaned.png')

      # Generate GIMP Python-fu script
      script_content = CellCleanupGimpScript.generate_cleanup_script(
        cell_path,
        cleaned_path,
        dominant_colors
      )

      # Execute GIMP script - pass script content and expected output file
      success = @gimp_processor.execute_python_script(script_content, cleaned_path)

      unless success
        raise ProcessingError, "GIMP script failed to create output file: #{cleaned_path}"
      end

      # Validate output was created
      Utils::FileHelper.validate_exists!(cleaned_path)

      cleaned_path
    end

    def reassemble_spritesheet(cell_paths, columns, rows, output_path)
      # Use ImageMagick montage to reassemble cells
      quoted_paths = cell_paths.map { |p| Utils::PathHelper.quote_path(p) }.join(' ')

      cmd = [
        'magick', 'montage',
        quoted_paths,
        '-tile', "#{columns}x#{rows}",
        '-geometry', '+0+0',  # No gaps/borders
        '-background', 'none',
        Utils::PathHelper.quote_path(output_path)
      ].join(' ')

      stdout, stderr, status = Open3.capture3(cmd)

      unless status.success?
        raise ProcessingError, "Failed to reassemble spritesheet: #{stderr}"
      end

      Utils::FileHelper.validate_exists!(output_path)
    end
  end
end
