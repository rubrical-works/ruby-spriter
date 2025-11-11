# frozen_string_literal: true

require 'open3'
require 'timeout'
require 'tmpdir'

module RubySpriter
  # ThresholdStepper applies multiple threshold-based background removal passes
  # using GIMP Python-fu with edge-sampled background colors
  class ThresholdStepper
    attr_reader :input_file, :output_file, :background_palette, :gimp_processor, :options

    def initialize(input_file, output_file, background_palette, gimp_processor, options = {})
      @input_file = input_file
      @output_file = output_file
      @background_palette = background_palette
      @gimp_processor = gimp_processor
      @options = options
      @threshold_values = parse_threshold_values(options[:threshold_values])
      @threshold_timeout = options[:threshold_timeout] || 60
      @total_timeout = options[:total_threshold_timeout] || 300
      @thresholds_processed = 0
      @skipped_thresholds = 0
      @start_time = nil
      @end_time = nil
    end

    def process
      @start_time = Time.now
      temp_results = []

      begin
        Timeout.timeout(@total_timeout) do
          @threshold_values.each_with_index do |threshold, index|
            temp_output = File.join(Dir.tmpdir, "threshold_#{threshold}_#{Time.now.to_i}_#{index}.png")

            begin
              Timeout.timeout(@threshold_timeout) do
                script = generate_gimp_script(threshold, temp_output)

                if @gimp_processor.execute_python_script(script, temp_output)
                  temp_results << temp_output
                  @thresholds_processed += 1
                else
                  @skipped_thresholds += 1
                  log_debug "Threshold #{threshold} failed to process"
                end
              end
            rescue Timeout::Error
              @skipped_thresholds += 1
              log_debug "Threshold #{threshold} timed out after #{@threshold_timeout}s"
            rescue StandardError => e
              @skipped_thresholds += 1
              log_debug "Threshold #{threshold} error: #{e.message}"
            end
          end
        end
      rescue Timeout::Error
        log_debug "Total threshold stepping timed out after #{@total_timeout}s"
      end

      @end_time = Time.now

      # Composite all threshold results
      if temp_results.any?
        composite_results(temp_results)
      else
        # Fallback: copy input to output if no thresholds succeeded
        FileUtils.cp(@input_file, @output_file)
      end

      # Cleanup temp files
      temp_results.each { |f| File.delete(f) if File.exist?(f) }
    end

    def report
      {
        thresholds_processed: @thresholds_processed,
        skipped_thresholds: @skipped_thresholds,
        total_time: @end_time && @start_time ? (@end_time - @start_time).round(2) : 0
      }
    end

    private

    def parse_threshold_values(custom_values)
      if custom_values.is_a?(String)
        custom_values.split(',').map(&:strip).map(&:to_f)
      elsif custom_values.is_a?(Array)
        custom_values.map(&:to_f)
      else
        # Default threshold values
        [0.0, 0.5, 1.0, 3.0, 5.0, 10.0]
      end
    end

    def generate_gimp_script(threshold, output_path)
      # Build color list for GIMP script
      color_definitions = @background_palette.map.with_index do |color, idx|
        "    color#{idx} = Gegl.Color.new('rgb(#{color[:r] / 255.0}, #{color[:g] / 255.0}, #{color[:b] / 255.0})')"
      end.join("\n")

      color_selections = @background_palette.map.with_index do |color, idx|
        operation = idx == 0 ? 'Gimp.ChannelOps.REPLACE' : 'Gimp.ChannelOps.ADD'
        <<~PYTHON.chomp
            # Select color #{idx + 1}
            config = select_proc.create_config()
            config.set_property('image', img)
            config.set_property('operation', #{operation})
            config.set_property('drawable', layer)
            config.set_property('color', color#{idx})
            config.set_property('threshold', #{threshold})
            select_proc.run(config)
        PYTHON
      end.join("\n\n")

      <<~PYTHON
        #!/usr/bin/env python3
        import gi
        gi.require_version('Gimp', '3.0')
        gi.require_version('Gegl', '0.4')
        from gi.repository import Gimp, GLib, Gio, Gegl
        import sys

        def threshold_step():
            try:
                Gegl.init(None)

                # Load image
                img = Gimp.file_load(Gimp.RunMode.NONINTERACTIVE,
                                    Gio.File.new_for_path(r'#{@input_file}'))

                if not img:
                    raise Exception("Failed to load image")

                layers = img.get_layers()
                if not layers:
                    raise Exception("No layers found in image")

                layer = layers[0]

                # Add alpha channel if needed
                if not layer.has_alpha():
                    layer.add_alpha()

                pdb = Gimp.get_pdb()

                # Get select-color procedure
                select_proc = pdb.lookup_procedure('gimp-image-select-color')
                if not select_proc:
                    raise Exception("Could not find gimp-image-select-color procedure")

                # Define background colors
        #{color_definitions}

                # Select all background colors with threshold
        #{color_selections}

                # Delete selection (make transparent)
                edit_clear = pdb.lookup_procedure('gimp-drawable-edit-clear')
                config = edit_clear.create_config()
                config.set_property('drawable', layer)
                edit_clear.run(config)

                # Deselect
                select_none = pdb.lookup_procedure('gimp-selection-none')
                config = select_none.create_config()
                config.set_property('image', img)
                select_none.run(config)

                # Export
                export_proc = pdb.lookup_procedure('file-png-export')
                config = export_proc.create_config()
                config.set_property('image', img)
                config.set_property('file', Gio.File.new_for_path(r'#{output_path}'))
                export_proc.run(config)

                print("SUCCESS - Threshold #{threshold} complete!")
                return 0
            except Exception as e:
                print(f"ERROR: {e}")
                import traceback
                traceback.print_exc()
                return 1

        sys.exit(threshold_step())
      PYTHON
    end

    def composite_results(temp_files)
      # Use ImageMagick to composite all threshold results
      # Layer them with DstOver mode (later layers go behind earlier ones)

      if temp_files.length == 1
        # Only one result, just copy it
        FileUtils.cp(temp_files.first, @output_file)
        return
      end

      # Build composite command
      # Start with the first result as base
      cmd_parts = ['magick', Utils::PathHelper.quote_path(temp_files.first)]

      # Add each subsequent result as a layer
      temp_files[1..-1].each do |temp_file|
        cmd_parts << Utils::PathHelper.quote_path(temp_file)
        cmd_parts << '-compose' << 'DstOver' << '-composite'
      end

      # Output final result
      cmd_parts << Utils::PathHelper.quote_path(@output_file)

      cmd = cmd_parts.join(' ')
      stdout, stderr, status = Open3.capture3(cmd)

      unless status.success?
        raise ProcessingError, "Failed to composite threshold results: #{stderr}"
      end
    end

    def log_debug(message)
      return unless @options[:debug]

      Utils::OutputFormatter.indent("DEBUG: #{message}")
    end
  end
end
