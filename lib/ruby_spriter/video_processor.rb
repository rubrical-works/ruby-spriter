# frozen_string_literal: true

require 'open3'

module RubySpriter
  # Processes video files with FFmpeg
  class VideoProcessor
    attr_reader :options

    # Filename suffix for background-removed frames
    NO_BACKGROUND_SUFFIX = '_nobg'

    def initialize(options = {})
      @options = options
    end

    # Create spritesheet from video file
    # @param video_file [String] Path to video file
    # @param output_file [String] Path to output spritesheet
    # @return [Hash] Processing results
    def create_spritesheet(video_file, output_file)
      Utils::FileHelper.validate_readable!(video_file)

      Utils::OutputFormatter.header("Video Analysis")
      duration = get_duration(video_file)
      Utils::OutputFormatter.indent("Duration: #{duration.round(2)} seconds\n")

      columns = options[:columns] || 4
      frame_count = options[:frame_count] || 16
      rows = (frame_count.to_f / columns).ceil

      Utils::OutputFormatter.header("Creating Spritesheet")

      temp_file = output_file.sub('.png', '_temp.png')

      create_with_ffmpeg(video_file, temp_file, duration, columns, rows, frame_count)

      # Embed metadata
      MetadataManager.embed(
        temp_file,
        output_file,
        columns: columns,
        rows: rows,
        frames: frame_count,
        debug: options[:debug]
      )

      # Clean up temp file
      File.delete(temp_file) if File.exist?(temp_file)

      file_size = File.size(output_file)

      # Display results with Godot instructions
      display_spritesheet_results(output_file, file_size, columns, rows, frame_count)

      {
        output_file: output_file,
        columns: columns,
        rows: rows,
        frames: frame_count,
        size: file_size
      }
    end

    # Get video duration in seconds
    # @param video_file [String] Path to video file
    # @return [Float] Duration in seconds
    def get_duration(video_file)
      cmd = [
        'ffprobe',
        '-v', 'error',
        '-show_entries', 'format=duration',
        '-of', 'default=noprint_wrappers=1:nokey=1',
        Utils::PathHelper.quote_path(video_file)
      ].join(' ')

      stdout, stderr, status = Open3.capture3(cmd)

      unless status.success?
        raise ProcessingError, "Could not determine video duration: #{stderr}"
      end

      stdout.strip.to_f
    end

    # Process video frames with background removal
    # @param video_path [String] Path to input video file
    # @param output_path [String] Path to output spritesheet
    # @param options [Hash] Processing options
    # @option options [Boolean] :by_frame Process each frame individually
    # @option options [String] :gimp_path Path to GIMP executable
    # @option options [Integer] :columns Number of columns in spritesheet
    # @option options [Integer] :frames Number of frames to extract
    # @option options [Boolean] :keep_temp Keep temporary files
    # @option options [Boolean] :debug Enable debug output
    # @return [Hash] Processing results with :output_file, :columns, :frames, :processing_mode
    def process_with_background_removal(video_path, output_path, options)
      temp_dir = Dir.mktmpdir('ruby_spriter_')

      begin
        # Extract frames from video
        frame_files = extract_frames(video_path, temp_dir, options)

        if options[:by_frame]
          # Frame-by-frame processing
          process_frames_individually(frame_files, temp_dir, options)

          # Assemble spritesheet from processed frames
          processed_frames = frame_files.map { |f| no_background_filename(f) }
          assemble_spritesheet_from_frames(processed_frames, output_path, options.merge(temp_dir: temp_dir))
        else
          # Standard processing: assemble first, then process spritesheet
          assemble_spritesheet_from_frames(frame_files, output_path, options.merge(temp_dir: temp_dir))

          # Apply background removal to entire spritesheet
          process_image_with_gimp(output_path, output_path, options)
        end

        # Cell-based cleanup (if --cleanup-cells flag present)
        if options[:cleanup_cells]
          require_relative 'cell_cleanup_processor'
          cell_processor = CellCleanupProcessor.new(options)
          stats = cell_processor.cleanup_cells(output_path, options)
        end

        # Calculate rows for metadata
        columns = options[:columns] || 4
        frames = options[:frames] || 16
        rows = (frames.to_f / columns).ceil

        # Embed metadata using temp file pattern (like create_spritesheet does)
        temp_file = output_path.sub('.png', '_temp.png')
        FileUtils.mv(output_path, temp_file)

        RubySpriter::MetadataManager.embed(
          temp_file,
          output_path,
          columns: columns,
          rows: rows,
          frames: frames,
          debug: options[:debug]
        )

        # Clean up temp file
        File.delete(temp_file) if File.exist?(temp_file)

        # Return processing results
        {
          output_file: output_path,
          columns: options[:columns],
          frames: options[:frames],
          processing_mode: options[:by_frame] ? 'by-frame' : 'standard'
        }

      ensure
        # Cleanup temp directory unless --keep-temp or --debug
        FileUtils.rm_rf(temp_dir) unless options[:keep_temp] || options[:debug]
      end
    end

    private

    # Process an image with GIMP and move to expected output location
    # @param input_path [String] Path to input image
    # @param expected_output_path [String] Expected output path
    # @param options [Hash] Processing options including :gimp_path
    # @return [String] Path to processed file
    def process_image_with_gimp(input_path, expected_output_path, options)
      gimp_path = options[:gimp_path]
      gimp_processor = RubySpriter::GimpProcessor.new(gimp_path, options)
      processed_file = gimp_processor.process(input_path)

      # Move file to expected location if different
      FileUtils.mv(processed_file, expected_output_path) if processed_file != expected_output_path

      expected_output_path
    end

    # Generate filename with no-background suffix
    # @param filename [String] Original filename
    # @return [String] Filename with _nobg suffix
    def no_background_filename(filename)
      filename.sub('.png', "#{NO_BACKGROUND_SUFFIX}.png")
    end

    # Extract individual frames from video file
    # @param video_path [String] Path to input video file
    # @param temp_dir [String] Directory to store extracted frames
    # @param options [Hash] Processing options
    # @option options [Integer] :frames Number of frames to extract (default: 16)
    # @option options [Integer] :max_width Maximum frame width (default: 320)
    # @option options [Boolean] :debug Enable debug output
    # @return [Array<String>] Array of frame filenames (basenames only, not full paths)
    def extract_frames(video_path, temp_dir, options)
      frame_count = options[:frames] || 16
      max_width = options[:max_width] || 320

      # Get video duration to calculate FPS
      duration = get_duration(video_path)
      fps = (frame_count / duration.to_f).round(6)

      # Output pattern for frames
      output_pattern = File.join(temp_dir, 'frame_%03d.png')

      # Build FFmpeg command
      cmd = [
        'ffmpeg',
        '-i', Utils::PathHelper.quote_path(video_path),
        '-vf', "fps=#{fps},scale=#{max_width}:-1:flags=lanczos",
        '-frames:v', frame_count.to_s,
        Utils::PathHelper.quote_path(output_pattern),
        '-hide_banner',
        options[:debug] ? '-loglevel info' : '-loglevel error'
      ].join(' ')

      if options[:debug]
        Utils::OutputFormatter.indent("DEBUG: Extracting frames with command:")
        Utils::OutputFormatter.indent(cmd)
      end

      # Execute FFmpeg
      stdout, stderr, status = Open3.capture3(cmd)

      unless status.success?
        raise ProcessingError, "Failed to extract frames: #{stderr}"
      end

      # Return array of frame filenames (basenames only)
      (1..frame_count).map { |i| format('frame_%03d.png', i) }
    end


    # Assemble individual frames into a spritesheet
    # @param frame_files [Array<String>] Array of frame filenames (basenames)
    # @param output_path [String] Path to output spritesheet
    # @param options [Hash] Processing options
    # @option options [Integer] :columns Number of columns in grid (default: 4)
    # @option options [String] :temp_dir Temporary directory containing frames
    # @option options [Boolean] :debug Enable debug output
    # @return [void]
    def assemble_spritesheet_from_frames(frame_files, output_path, options)
      columns = options[:columns] || 4
      frame_count = frame_files.length
      rows = (frame_count.to_f / columns).ceil
      temp_dir = options[:temp_dir]

      # Detect the pattern from the first filename
      # Examples: frame_001.png → frame_%03d.png
      #           frame_001_nobg.png → frame_%03d_nobg.png
      first_file = frame_files.first
      pattern = if first_file.include?('_nobg.png')
                  'frame_%03d_nobg.png'
                else
                  'frame_%03d.png'
                end

      # Input pattern for frames
      input_pattern = File.join(temp_dir, pattern)

      # Build FFmpeg command
      cmd = [
        'ffmpeg',
        '-i', Utils::PathHelper.quote_path(input_pattern),
        '-filter_complex', "tile=#{columns}x#{rows}",
        '-frames:v', '1',
        '-y',
        Utils::PathHelper.quote_path(output_path),
        '-hide_banner',
        options[:debug] ? '-loglevel info' : '-loglevel error'
      ].join(' ')

      if options[:debug]
        Utils::OutputFormatter.indent("DEBUG: Assembling spritesheet with command:")
        Utils::OutputFormatter.indent(cmd)
      end

      # Execute FFmpeg
      stdout, stderr, status = Open3.capture3(cmd)

      unless status.success?
        raise ProcessingError, "Failed to assemble spritesheet: #{stderr}"
      end

      Utils::FileHelper.validate_exists!(output_path)
    end

    def process_frames_individually(frame_files, temp_dir, options)
      total_frames = frame_files.length

      frame_files.each_with_index do |frame_file, index|
        frame_number = index + 1
        puts "Processing frame #{frame_number}/#{total_frames}..."

        # Input and output paths
        input_path = File.join(temp_dir, frame_file)
        output_path = File.join(temp_dir, no_background_filename(frame_file))

        # Process the frame with GIMP
        process_image_with_gimp(input_path, output_path, options)
      end
    end

    def create_with_ffmpeg(video_file, output_file, duration, columns, rows, frame_count)
      fps = (frame_count / duration.to_f).round(6)
      max_width = options[:max_width] || 320

      Utils::OutputFormatter.indent("Layout: #{columns}×#{rows} grid (#{frame_count} frames)")
      Utils::OutputFormatter.indent("Frame rate: #{fps} fps")
      Utils::OutputFormatter.indent("Max frame width: #{max_width}px")
      Utils::OutputFormatter.indent("Building spritesheet...")

      filter_complex = [
        "fps=#{fps}",
        "scale=#{max_width}:-1:flags=lanczos",
        "tile=#{columns}x#{rows}"
      ].join(',')

      cmd = build_ffmpeg_command(video_file, output_file, filter_complex)

      if options[:debug]
        Utils::OutputFormatter.indent("DEBUG: ffmpeg command:")
        Utils::OutputFormatter.indent(cmd)
      end

      stdout, stderr, status = Open3.capture3(cmd)

      unless status.success?
        raise ProcessingError, "FFmpeg failed: #{stderr}"
      end

      Utils::FileHelper.validate_exists!(output_file)
    end

    def build_ffmpeg_command(video_file, output_file, filter_complex)
      [
        'ffmpeg',
        '-i', Utils::PathHelper.quote_path(video_file),
        '-filter_complex', Utils::PathHelper.quote_arg(filter_complex),
        '-frames:v', '1',
        '-y',
        Utils::PathHelper.quote_path(output_file),
        '-hide_banner',
        options[:debug] ? '-loglevel info' : '-loglevel error'
      ].join(' ')
    end

    def display_spritesheet_results(output_file, file_size, columns, rows, frame_count)
      Utils::OutputFormatter.success("Spritesheet created: #{output_file}")
      Utils::OutputFormatter.indent("Size: #{Utils::FileHelper.format_size(file_size)}")
      Utils::OutputFormatter.note("Metadata embedded: #{columns}×#{rows} grid (#{frame_count} frames)")
      
      puts "\n      📊 Godot AnimatedSprite2D Settings:"
      Utils::OutputFormatter.indent("HFrames = #{columns}")
      Utils::OutputFormatter.indent("VFrames = #{rows}\n")
    end
  end
end