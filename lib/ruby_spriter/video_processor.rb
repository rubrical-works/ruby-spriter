# frozen_string_literal: true

require 'open3'

module RubySpriter
  # Processes video files with FFmpeg
  class VideoProcessor
    attr_reader :options

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

    private

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
