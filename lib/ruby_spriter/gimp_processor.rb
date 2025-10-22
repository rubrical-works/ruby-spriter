# frozen_string_literal: true

require 'open3'
require 'tmpdir'

module RubySpriter
  # Processes images with GIMP
  class GimpProcessor
    attr_reader :options, :gimp_path

    def initialize(gimp_path, options = {})
      @gimp_path = gimp_path
      @options = options
    end

    # Process image with GIMP operations
    # @param input_file [String] Path to input image
    # @return [String] Path to processed output file
    def process(input_file)
      Utils::FileHelper.validate_readable!(input_file)

      Utils::OutputFormatter.header("GIMP Processing")

      # Inform user if automatic operation order optimization is applied
      if options[:scale_percent] && options[:remove_bg] &&
         options[:operation_order] == :scale_then_remove_bg
        Utils::OutputFormatter.note("Auto-optimized: Removing background before scaling for better quality")
      end

      working_file = input_file
      operations = determine_operations

      # Execute operations in configured order
      operations.each do |operation|
        working_file = send(operation, working_file)
      end

      # Apply sharpening at the very end, after all GIMP operations
      if options[:sharpen]
        working_file = apply_sharpen_imagemagick(working_file)
      end

      working_file
    end

    private

    def determine_operations
      ops = []

      # Automatically use bg_first when both scaling and background removal are enabled
      # This produces cleaner results because:
      # - Background removal works better at higher resolution
      # - Scaling smooths out any rough edges from background removal
      auto_bg_first = options[:scale_percent] && options[:remove_bg] &&
                      options[:operation_order] == :scale_then_remove_bg

      if options[:operation_order] == :remove_bg_then_scale || auto_bg_first
        ops << :remove_background if options[:remove_bg]
        ops << :scale_image if options[:scale_percent]
      else # :scale_then_remove_bg (when only one operation, or explicitly requested)
        ops << :scale_image if options[:scale_percent]
        ops << :remove_background if options[:remove_bg]
      end

      ops
    end

    def scale_image(input_file)
      percent = options[:scale_percent]
      output_file = Utils::FileHelper.output_filename(input_file, "scaled-#{percent}pct")

      Utils::OutputFormatter.indent("Scaling to #{percent}%...")

      script = generate_scale_script(input_file, output_file, percent)
      execute_gimp_script(script, output_file, "Scale")

      # Preserve metadata from input file
      preserve_metadata(input_file, output_file)

      # Note: Sharpening is applied at the end in process() method

      output_file
    end

    def remove_background(input_file)
      method = options[:fuzzy_select] ? 'fuzzy' : 'global'
      output_file = Utils::FileHelper.output_filename(input_file, "nobg-#{method}")

      Utils::OutputFormatter.indent("Removing background (#{method} select)...")

      script = generate_remove_bg_script(input_file, output_file)
      execute_gimp_script(script, output_file, "Background Removal")

      # Preserve metadata from input file
      preserve_metadata(input_file, output_file)

      output_file
    end

    def generate_scale_script(input_file, output_file, percent)
      input_path = Utils::PathHelper.normalize_for_python(input_file)
      output_path = Utils::PathHelper.normalize_for_python(output_file)
      interpolation = map_interpolation_method(options[:scale_interpolation] || 'nohalo')

      # Get sharpen parameters with proper defaults
      sharpen_enabled = options[:sharpen] || false
      sharpen_radius = options[:sharpen_radius] || 3.0
      sharpen_amount = options[:sharpen_amount] || 0.5
      sharpen_threshold = options[:sharpen_threshold] || 0

      <<~PYTHON
        import sys
        import gc
        from gi.repository import Gimp, Gio, Gegl

        img = None
        layer = None

        try:
            print("Loading image...")
            img = Gimp.file_load(Gimp.RunMode.NONINTERACTIVE, Gio.File.new_for_path(r'#{input_path}'))

            w = img.get_width()
            h = img.get_height()
            print(f"Image size: {w}x{h}")

            layers = img.get_layers()
            if not layers or len(layers) == 0:
                raise Exception("No layers found")
            layer = layers[0]

            # Calculate new dimensions
            new_width = int(w * #{percent} / 100.0)
            new_height = int(h * #{percent} / 100.0)
            print(f"Scaling to: {new_width}x{new_height}")
            print(f"Interpolation: #{interpolation}")

            # Set interpolation method via context
            pdb = Gimp.get_pdb()
            context_set_interp = pdb.lookup_procedure('gimp-context-set-interpolation')
            if context_set_interp:
                config = context_set_interp.create_config()
                config.set_property('interpolation', #{interpolation})
                context_set_interp.run(config)
                print("Interpolation method set in context")

            # Scale layer using the context interpolation
            scale_proc = pdb.lookup_procedure('gimp-layer-scale')
            if scale_proc:
                config = scale_proc.create_config()
                config.set_property('layer', layer)
                config.set_property('new-width', new_width)
                config.set_property('new-height', new_height)
                config.set_property('local-origin', False)
                scale_proc.run(config)
                print("Layer scaled with interpolation")

            # Resize canvas to match layer
            img.resize(new_width, new_height, 0, 0)
            print("Canvas resized")

            # Only flatten if there are multiple layers AND no transparency is needed
            # Otherwise, preserve the alpha channel for transparent images
            layers = img.get_layers()
            if len(layers) > 1:
                # Merge down multiple layers while preserving alpha
                merge_proc = pdb.lookup_procedure('gimp-image-merge-visible-layers')
                if merge_proc:
                    config = merge_proc.create_config()
                    config.set_property('image', img)
                    config.set_property('merge-type', Gimp.MergeType.EXPAND_AS_NECESSARY)
                    merge_proc.run(config)
                    print("Multiple layers merged (alpha preserved)")
            else:
                print("Single layer - no merge needed, alpha preserved")

            # Get the final layer
            layers = img.get_layers()
            final_layer = layers[0]

            # Note: Sharpening will be applied using ImageMagick after GIMP export
            # This is because GEGL operations in GIMP 3.x batch mode are unreliable

            # Export with alpha channel intact
            print("Exporting with alpha channel...")
            export_proc = pdb.lookup_procedure('file-png-export')
            if export_proc:
                config = export_proc.create_config()
                config.set_property('image', img)
                config.set_property('file', Gio.File.new_for_path(r'#{output_path}'))
                export_proc.run(config)

            print("SUCCESS - Image scaled!")

        except Exception as e:
            print(f"ERROR: {e}")
            import traceback
            traceback.print_exc()
            sys.exit(1)
        finally:
            # Explicit cleanup to minimize GEGL warnings
            try:
                if layer is not None:
                    layer = None
                if img is not None:
                    gc.collect()  # Force garbage collection
                    img.delete()
                    img = None
                    gc.collect()  # Force again after deletion
            except Exception as cleanup_error:
                print(f"Cleanup warning: {cleanup_error}")
                pass
      PYTHON
    end

    def generate_remove_bg_script(input_file, output_file)
      input_path = Utils::PathHelper.normalize_for_python(input_file)
      output_path = Utils::PathHelper.normalize_for_python(output_file)

      use_fuzzy = options[:fuzzy_select]

      # Build the selection code block
      selection_code = if use_fuzzy
        generate_fuzzy_select_code
      else
        generate_global_select_code
      end

      # Build optional processing code
      grow_code = generate_grow_selection_code
      feather_code = generate_feather_selection_code

      <<~PYTHON
        import sys
        import gc
        from gi.repository import Gimp, Gio, Gegl
        
        img = None
        layer = None
        
        try:
            print("Loading image...")
            img = Gimp.file_load(Gimp.RunMode.NONINTERACTIVE, Gio.File.new_for_path(r'#{input_path}'))
            
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
            
            print(f"Sampling {len(corners)} corners...")
            
        #{selection_code.split("\n").map { |line| "    " + line }.join("\n")}
            
            print("Selection complete")
            
        #{grow_code.split("\n").map { |line| "    " + line }.join("\n")}
            
        #{feather_code.split("\n").map { |line| "    " + line }.join("\n")}
            
            # Delete selection (clear background)
            print("Removing background...")
            edit_clear = pdb.lookup_procedure('gimp-drawable-edit-clear')
            if edit_clear:
                config = edit_clear.create_config()
                config.set_property('drawable', layer)
                edit_clear.run(config)
                print("Background removed")
            
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
                config.set_property('file', Gio.File.new_for_path(r'#{output_path}'))
                export_proc.run(config)
            
            print("SUCCESS - Background removed!")
        
        except Exception as e:
            print(f"ERROR: {e}")
            import traceback
            traceback.print_exc()
            sys.exit(1)
        finally:
            # Explicit cleanup to minimize GEGL warnings
            try:
                if layer is not None:
                    layer = None
                if img is not None:
                    gc.collect()  # Force garbage collection
                    img.delete()
                    img = None
                    gc.collect()  # Force again after deletion
            except Exception as cleanup_error:
                print(f"Cleanup warning: {cleanup_error}")
                pass
      PYTHON
    end

    def generate_fuzzy_select_code
      <<~PYTHON.chomp
        # Fuzzy select (contiguous regions only)
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
      PYTHON
    end

    def generate_global_select_code
      <<~PYTHON.chomp
        # Global color select (all matching pixels)
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
      PYTHON
    end

    def generate_grow_selection_code
      grow = options[:grow_selection] || 1
      return "# No selection growth" if grow <= 0

      <<~PYTHON.chomp
        # Grow selection
        print(f"Growing selection by #{grow} pixels...")
        grow_proc = pdb.lookup_procedure('gimp-selection-grow')
        if grow_proc:
            config = grow_proc.create_config()
            config.set_property('image', img)
            config.set_property('steps', #{grow})
            grow_proc.run(config)
            print("Selection grown")
      PYTHON
    end

    def generate_feather_selection_code
      threshold = options[:bg_threshold] || 0.0
      return "# No feathering" if threshold <= 0

      <<~PYTHON.chomp
        # Feather selection
        print(f"Feathering selection by #{threshold} pixels...")
        feather_proc = pdb.lookup_procedure('gimp-selection-feather')
        if feather_proc:
            config = feather_proc.create_config()
            config.set_property('image', img)
            config.set_property('radius', #{threshold})
            feather_proc.run(config)
            print("Selection feathered")
      PYTHON
    end

    def execute_gimp_script(script_content, expected_output, operation_name)
      script_file = File.join(Dir.tmpdir, "gimp_script_#{Time.now.to_i}_#{rand(10000)}.py")
      log_file = File.join(Dir.tmpdir, "gimp_log_#{Time.now.to_i}_#{rand(10000)}.txt")

      begin
        File.write(script_file, script_content)

        if options[:debug]
          Utils::OutputFormatter.indent("DEBUG: Script file: #{script_file}")
          Utils::OutputFormatter.indent("DEBUG: Log file: #{log_file}")
          Utils::OutputFormatter.indent("DEBUG: Expected output: #{expected_output}")
        end

        # Build GIMP command based on platform
        if Platform.windows?
          execute_gimp_windows(script_file, log_file)
        else
          execute_gimp_unix(script_file, log_file)
        end

        gimp_output = ""
        if File.exist?(log_file)
          gimp_output = File.read(log_file)
        end

        # Filter GEGL warnings but keep actual errors and success messages
        filtered_output = filter_gimp_output(gimp_output)

        # Only show output if debug mode OR if there are actual messages (not just warnings)
        if options[:debug] && !filtered_output.strip.empty?
          Utils::OutputFormatter.indent("=== GIMP Output ===")
          filtered_output.lines.each do |line|
            Utils::OutputFormatter.indent(line.chomp)
          end
          Utils::OutputFormatter.indent("==================\n")
        elsif !options[:debug] && has_important_messages?(gimp_output)
          # Show important messages even without debug mode
          Utils::OutputFormatter.indent("=== GIMP Messages ===")
          filtered_output.lines.each do |line|
            Utils::OutputFormatter.indent(line.chomp)
          end
          Utils::OutputFormatter.indent("====================\n")
        end

        Utils::FileHelper.validate_exists!(expected_output)

        size = Utils::FileHelper.format_size(File.size(expected_output))
        Utils::OutputFormatter.success("#{operation_name} complete (#{size})\n")

      ensure
        cleanup_temp_files(script_file, log_file) unless options[:keep_temp]
      end
    end

    # Windows execution with GEGL warning suppression
    def execute_gimp_windows(script_file, log_file)
      batch_file = File.join(Dir.tmpdir, "gimp_run_#{Time.now.to_i}_#{rand(10000)}.bat")
      
      batch_content = <<~BATCH
        @echo off
        REM Suppress GEGL debug output (known GIMP 3.x batch mode issue)
        set GEGL_DEBUG=
        "#{gimp_path}" --quit --batch-interpreter=python-fu-eval -b "exec(open(r'#{script_file}').read())" > "#{log_file}" 2>&1
        exit /b %errorlevel%
      BATCH

      File.write(batch_file, batch_content)

      if options[:debug]
        Utils::OutputFormatter.indent("DEBUG: Batch file: #{batch_file}")
        Utils::OutputFormatter.indent("DEBUG: Batch content:")
        batch_content.lines.each do |line|
          Utils::OutputFormatter.indent("  #{line.chomp}")
        end
      end

      # Use Open3.capture3 with cmd.exe wrapper - this is the v0.6 approach that works
      stdout, stderr, status = Open3.capture3("cmd.exe /c \"#{batch_file}\"")

      if options[:debug]
        Utils::OutputFormatter.indent("DEBUG: Command exit status: #{status.exitstatus}")
        Utils::OutputFormatter.indent("DEBUG: stdout: #{stdout}") unless stdout.strip.empty?
        Utils::OutputFormatter.indent("DEBUG: stderr: #{stderr}") unless stderr.strip.empty?
      end

      unless status.success?
        log_content = File.exist?(log_file) ? File.read(log_file) : "No log file created"
        raise ProcessingError, "GIMP processing failed (exit code: #{status.exitstatus})\n#{log_content}"
      end

      # Clean up batch file
      File.delete(batch_file) if File.exist?(batch_file) && !options[:keep_temp]
    end

    # Unix execution (Linux/macOS)
    def execute_gimp_unix(script_file, log_file)
      cmd = "#{Utils::PathHelper.quote_path(gimp_path)} --quit --batch-interpreter=python-fu-eval -b \"exec(open(r'#{script_file}').read())\" > #{Utils::PathHelper.quote_path(log_file)} 2>&1"

      if options[:debug]
        Utils::OutputFormatter.indent("DEBUG: GIMP command: #{cmd}")
      end

      stdout, stderr, status = Open3.capture3(cmd)

      if options[:debug]
        Utils::OutputFormatter.indent("DEBUG: Command exit status: #{status.exitstatus}")
      end

      unless status.success?
        log_content = File.exist?(log_file) ? File.read(log_file) : "No log file created"
        raise ProcessingError, "GIMP processing failed (exit code: #{status.exitstatus})\n#{log_content}"
      end
    end

    # Filter out known GEGL/GIMP warnings that are cosmetic
    def filter_gimp_output(output)
      lines = output.lines.reject do |line|
        # Filter known GEGL buffer leak warnings (cosmetic in GIMP 3.x batch mode)
        line.match?(/GEGL-WARNING/) ||
        line.match?(/gegl_tile_cache_destroy/) ||
        line.match?(/runtime check failed/) ||
        line.match?(/To debug GeglBuffer leaks/) ||
        line.match?(/GEGL_DEBUG.*buffer-alloc/) ||
        line.match?(/GeglBuffers leaked/) ||
        line.match?(/EEEEeEeek!/) ||
        line.match?(/batch command executed successfully/) ||
        line.strip.empty?
      end
      lines.join
    end

    # Check if output has important messages beyond warnings
    def has_important_messages?(output)
      filtered = filter_gimp_output(output)
      # Has content other than SUCCESS messages
      filtered.strip.split("\n").any? { |line| !line.match?(/SUCCESS/) && !line.strip.empty? }
    end

    # Preserve metadata from input file to output file
    # GIMP strips metadata during export, so we need to copy it
    def preserve_metadata(input_file, output_file)
      # Read metadata from input file
      input_metadata = MetadataManager.read(input_file)
      
      return unless input_metadata # No metadata to preserve
      
      if options[:debug]
        Utils::OutputFormatter.indent("DEBUG: Preserving metadata from input file")
        Utils::OutputFormatter.indent("  Columns: #{input_metadata[:columns]}")
        Utils::OutputFormatter.indent("  Rows: #{input_metadata[:rows]}")
        Utils::OutputFormatter.indent("  Frames: #{input_metadata[:frames]}")
      end

      # Create temporary file for re-embedding metadata
      temp_file = output_file.sub('.png', '_temp_meta.png')
      File.rename(output_file, temp_file)

      # Re-embed metadata
      MetadataManager.embed(
        temp_file,
        output_file,
        columns: input_metadata[:columns],
        rows: input_metadata[:rows],
        frames: input_metadata[:frames],
        debug: options[:debug]
      )

      # Clean up temp file
      File.delete(temp_file) if File.exist?(temp_file)

      if options[:debug]
        Utils::OutputFormatter.indent("DEBUG: Metadata preserved in output file")
      end
    rescue StandardError => e
      # If metadata preservation fails, keep the file but warn
      if options[:debug]
        Utils::OutputFormatter.warning("Could not preserve metadata: #{e.message}")
      end
      # Restore original file if temp exists
      File.rename(temp_file, output_file) if defined?(temp_file) && File.exist?(temp_file) && !File.exist?(output_file)
    end

    def cleanup_temp_files(script_file, log_file)
      batch_file = script_file.sub('.py', '.bat').sub('gimp_script', 'gimp_run')

      [script_file, log_file, batch_file].each do |file|
        File.delete(file) if File.exist?(file)
      rescue StandardError => e
        puts "Warning: Could not delete temp file #{file}: #{e.message}" if options[:debug]
      end
    end

    # Map interpolation method names to GIMP interpolation type enum values
    def map_interpolation_method(method)
      # GIMP 3.x GimpInterpolationType enum values
      case method.to_s.downcase
      when 'none'
        'Gimp.InterpolationType.NONE'
      when 'linear'
        'Gimp.InterpolationType.LINEAR'
      when 'cubic'
        'Gimp.InterpolationType.CUBIC'
      when 'nohalo'
        'Gimp.InterpolationType.NOHALO'
      when 'lohalo'
        'Gimp.InterpolationType.LOHALO'
      else
        'Gimp.InterpolationType.NOHALO'  # Default to NoHalo for quality
      end
    end

    # Apply unsharp mask using ImageMagick
    def apply_sharpen_imagemagick(input_file)
      radius = options[:sharpen_radius] || 2.0
      gain = options[:sharpen_gain] || 0.5
      threshold = options[:sharpen_threshold] || 0.03

      output_file = Utils::FileHelper.output_filename(input_file, "sharpened")

      Utils::OutputFormatter.indent("Applying unsharp mask (ImageMagick)...")
      Utils::OutputFormatter.indent("  radius=#{radius}, gain=#{gain}, threshold=#{threshold}")

      magick_cmd = Platform.imagemagick_convert_cmd

      # Build ImageMagick unsharp command
      # Format: -unsharp {radius}x{sigma}+{gain}+{threshold}
      # sigma is typically radius * 0.5 for good results
      sigma = radius * 0.5
      unsharp_params = "#{radius}x#{sigma}+#{gain}+#{threshold}"

      cmd = [
        magick_cmd,
        Utils::PathHelper.quote_path(input_file),
        '-unsharp', unsharp_params,
        Utils::PathHelper.quote_path(output_file)
      ].join(' ')

      if options[:debug]
        Utils::OutputFormatter.indent("DEBUG: ImageMagick command: #{cmd}")
      end

      stdout, stderr, status = Open3.capture3(cmd)

      unless status.success?
        raise ProcessingError, "ImageMagick sharpen failed: #{stderr}"
      end

      Utils::FileHelper.validate_exists!(output_file)

      # Preserve metadata
      preserve_metadata(input_file, output_file)

      Utils::OutputFormatter.success("Sharpening complete")

      output_file
    end
  end
end
