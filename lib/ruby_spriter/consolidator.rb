# frozen_string_literal: true

require 'open3'

module RubySpriter
  # Consolidates multiple spritesheets vertically
  class Consolidator
    attr_reader :options

    def initialize(options = {})
      @options = options
    end

    # Consolidate multiple spritesheets into one
    # @param files [Array<String>] Array of spritesheet file paths
    # @param output_file [String] Output consolidated file path
    # @return [Hash] Processing results
    def consolidate(files, output_file)
      validate_files!(files)

      Utils::OutputFormatter.header("Consolidating Spritesheets")

      metadata_list = read_all_metadata(files)
      validate_compatibility!(metadata_list) if options[:validate_columns]

      create_consolidated_image(files, output_file)

      total_frames = metadata_list.sum { |m| m[:frames] }
      columns = metadata_list.first[:columns]
      rows = (total_frames.to_f / columns).ceil

      # Embed consolidated metadata
      temp_file = output_file.sub('.png', '_temp.png')
      File.rename(output_file, temp_file)

      MetadataManager.embed(
        temp_file,
        output_file,
        columns: columns,
        rows: rows,
        frames: total_frames,
        debug: options[:debug]
      )

      File.delete(temp_file) if File.exist?(temp_file)

      file_size = File.size(output_file)

      # Display results with Godot instructions
      display_consolidation_results(output_file, file_size, files, metadata_list, columns, rows, total_frames)

      {
        output_file: output_file,
        columns: columns,
        rows: rows,
        frames: total_frames,
        size: file_size
      }
    end

    private

    def validate_files!(files)
      raise ValidationError, "Need at least 2 files to consolidate" if files.length < 2

      files.each { |file| Utils::FileHelper.validate_readable!(file) }
    end

    def read_all_metadata(files)
      metadata_list = files.map do |file|
        metadata = MetadataManager.read(file)
        
        unless metadata
          raise ValidationError, "File missing metadata: #{file}\nAll files must be Ruby Spriter spritesheets."
        end

        metadata
      end

      metadata_list
    end

    def validate_compatibility!(metadata_list)
      columns = metadata_list.first[:columns]
      
      incompatible = metadata_list.find { |m| m[:columns] != columns }
      
      if incompatible
        raise ValidationError, 
          "Column count mismatch: Expected #{columns}, found #{incompatible[:columns]}\n" \
          "Use --no-validate-columns to force consolidation."
      end
    end

    def create_consolidated_image(files, output_file)
      Utils::OutputFormatter.indent("Stacking spritesheets vertically...")

      # Use ImageMagick to stack images vertically
      magick_cmd = Platform.imagemagick_convert_cmd
      
      cmd = [
        magick_cmd,
        *files.map { |f| Utils::PathHelper.quote_path(f) },
        '-append',
        Utils::PathHelper.quote_path(output_file)
      ].join(' ')

      if options[:debug]
        Utils::OutputFormatter.indent("DEBUG: ImageMagick command: #{cmd}")
      end

      stdout, stderr, status = Open3.capture3(cmd)

      unless status.success?
        raise ProcessingError, "ImageMagick consolidation failed: #{stderr}"
      end

      Utils::FileHelper.validate_exists!(output_file)
    end

    def display_consolidation_results(output_file, file_size, files, metadata_list, columns, rows, total_frames)
      Utils::OutputFormatter.success("Consolidated spritesheet created")
      Utils::OutputFormatter.indent("Output: #{output_file}")
      Utils::OutputFormatter.indent("Size: #{Utils::FileHelper.format_size(file_size)}")
      Utils::OutputFormatter.note("Combined #{files.length} spritesheets (#{total_frames} total frames)")
      
      puts "\n      Grid Layout:"
      Utils::OutputFormatter.indent("Columns: #{columns}")
      Utils::OutputFormatter.indent("Rows: #{rows}")
      Utils::OutputFormatter.indent("Total Frames: #{total_frames}")
      
      puts "\n      📊 Godot AnimatedSprite2D Settings:"
      Utils::OutputFormatter.indent("HFrames = #{columns}")
      Utils::OutputFormatter.indent("VFrames = #{rows}")
      
      puts "\n      📋 Source Breakdown:"
      metadata_list.each_with_index do |meta, index|
        file_basename = File.basename(files[index])
        Utils::OutputFormatter.indent("#{index + 1}. #{file_basename}")
        Utils::OutputFormatter.indent("   └─ #{meta[:columns]}×#{meta[:rows]} grid (#{meta[:frames]} frames)")
      end
      
      puts ""
    end
  end
end
