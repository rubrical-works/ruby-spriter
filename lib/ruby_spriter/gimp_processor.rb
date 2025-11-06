# frozen_string_literal: true

require 'open3'
require 'tmpdir'

module RubySpriter
  # Processes images with GIMP
  class GimpProcessor
    attr_reader :options, :gimp_path, :gimp_version

    # Default background color tolerance for selection operations (0-100 scale)
    DEFAULT_BG_THRESHOLD = 15.0

    def initialize(gimp_path, options = {})
      @gimp_path = gimp_path
      @options = options
      @gimp_version = options[:gimp_version] || { major: 3, minor: 0 }  # Default to GIMP 3
    end

    # Process image with GIMP operations
    # @param input_file [String] Path to input image
    # @return [String] Path to processed output file
    def process(input_file)
      Utils::FileHelper.validate_readable!(input_file)

      Utils::OutputFormatter.header("GIMP Processing")

      # Inform about Xvfb usage on Linux
      if Platform.linux? && gimp_path.start_with?('flatpak:')
        Utils::OutputFormatter.note("Using GIMP via Xvfb (virtual display)")
      end

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

    # Execute a Python script with GIMP (used by ThresholdStepper)
    # @param script [String] The Python script content
    # @param output_file [String] Expected output file path
    # @return [Boolean] True if successful, false otherwise
    def execute_python_script(script, output_file)
      script_file = File.join(Dir.tmpdir, "gimp_threshold_#{Time.now.to_i}_#{rand(10_000)}.py")
      log_file = File.join(Dir.tmpdir, "gimp_threshold_log_#{Time.now.to_i}_#{rand(10_000)}.txt")

      begin
        File.write(script_file, script)

        if options[:debug]
          Utils::OutputFormatter.indent("DEBUG: Threshold script: #{script_file}")
          Utils::OutputFormatter.indent("DEBUG: Expected output: #{output_file}")
        end

        # Execute using existing platform-specific methods
        if Platform.windows?
          execute_gimp_windows(script_file, log_file)
        else
          execute_gimp_unix(script_file, log_file)
        end

        # Check if output was created
        if File.exist?(output_file) && File.size(output_file).positive?
          true
        else
          if options[:debug]
            Utils::OutputFormatter.indent("WARNING: Threshold script did not produce output")
          end
          false
        end
      rescue StandardError => e
        if options[:debug]
          Utils::OutputFormatter.indent("ERROR in threshold script: #{e.message}")
        end
        false
      ensure
        cleanup_temp_files(script_file, log_file) unless options[:keep_temp]
      end
    end

    private

    def gimp_major_version
      @gimp_version[:major]
    end

    def gimp2?
      gimp_major_version == 2
    end

    def gimp3?
      gimp_major_version == 3
    end

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
      desired_output = Utils::FileHelper.output_filename(input_file, "scaled-#{percent}pct")
      output_file = Utils::FileHelper.ensure_unique_output(desired_output, overwrite: options[:overwrite])

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
      desired_output = Utils::FileHelper.output_filename(input_file, "nobg-#{method}")
      output_file = Utils::FileHelper.ensure_unique_output(desired_output, overwrite: options[:overwrite])

      Utils::OutputFormatter.indent("Removing background (#{method} select)...")

      script = generate_remove_bg_script(input_file, output_file)
      execute_gimp_script(script, output_file, "Background Removal")

      # Preserve metadata from input file
      preserve_metadata(input_file, output_file)

      output_file
    end

    def generate_scale_script(input_file, output_file, percent)
      if gimp2?
        generate_scale_script_gimp2(input_file, output_file, percent)
      else
        generate_scale_script_gimp3(input_file, output_file, percent)
      end
    end

    def generate_scale_script_gimp3(input_file, output_file, percent)
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

    def generate_scale_script_gimp2(input_file, output_file, percent)
      input_path = Utils::PathHelper.normalize_for_python(input_file)
      output_path = Utils::PathHelper.normalize_for_python(output_file)
      interpolation = map_interpolation_method_gimp2(options[:scale_interpolation] || 'nohalo')

      <<~PYTHON
        from gimpfu import *
        import sys

        def scale_image():
            try:
                print "Loading image..."
                img = pdb.gimp_file_load(r'#{input_path}', r'#{input_path}')

                w = img.width
                h = img.height
                print "Image size: %dx%d" % (w, h)

                if len(img.layers) == 0:
                    raise Exception("No layers found")
                layer = img.layers[0]

                # Calculate new dimensions
                new_width = int(w * #{percent} / 100.0)
                new_height = int(h * #{percent} / 100.0)
                print "Scaling to: %dx%d" % (new_width, new_height)
                print "Interpolation: #{interpolation}"

                # Scale layer with interpolation
                pdb.gimp_layer_scale(layer, new_width, new_height, False, #{interpolation})
                print "Layer scaled with interpolation"

                # Resize canvas to match layer
                pdb.gimp_image_resize(img, new_width, new_height, 0, 0)
                print "Canvas resized"

                # Handle multiple layers while preserving alpha
                if len(img.layers) > 1:
                    pdb.gimp_image_merge_visible_layers(img, EXPAND_AS_NECESSARY)
                    print "Multiple layers merged (alpha preserved)"
                else:
                    print "Single layer - no merge needed, alpha preserved"

                # Export with alpha channel intact
                print "Exporting with alpha channel..."
                pdb.file_png_save(img, img.layers[0], r'#{output_path}', r'#{output_path}',
                                  0, 9, 0, 0, 0, 0, 0)

                print "SUCCESS - Image scaled!"

            except Exception as e:
                print "ERROR: %s" % str(e)
                import traceback
                traceback.print_exc()
                sys.exit(1)

        scale_image()
      PYTHON
    end

    def generate_remove_bg_script(input_file, output_file)
      if gimp2?
        generate_remove_bg_script_gimp2(input_file, output_file)
      else
        generate_remove_bg_script_gimp3(input_file, output_file)
      end
    end

    def generate_remove_bg_script_gimp3(input_file, output_file)
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

    def generate_remove_bg_script_gimp2(input_file, output_file)
      input_path = Utils::PathHelper.normalize_for_python(input_file)
      output_path = Utils::PathHelper.normalize_for_python(output_file)

      use_fuzzy = options[:fuzzy_select]
      grow = options[:grow_selection] || 1
      feather = options[:feather_radius] || 0.0

      # Build selection method
      if use_fuzzy
        select_method = "CHANNEL_OP_REPLACE" # First corner
        select_add = "CHANNEL_OP_ADD"        # Additional corners
        select_call = "pdb.gimp_image_select_contiguous_color(img, select_op, layer, x, y)"
      else
        select_method = "CHANNEL_OP_REPLACE"
        select_add = "CHANNEL_OP_ADD"
        select_call = "pdb.gimp_image_select_color(img, select_op, layer, color)"
      end

      <<~PYTHON
        from gimpfu import *
        import sys

        def remove_background():
            try:
                print "Loading image..."
                img = pdb.gimp_file_load(r'#{input_path}', r'#{input_path}')

                w = img.width
                h = img.height
                print "Image size: %dx%d" % (w, h)

                if len(img.layers) == 0:
                    raise Exception("No layers found")
                layer = img.layers[0]

                # Add alpha channel if needed
                if not pdb.gimp_layer_has_alpha(layer):
                    pdb.gimp_layer_add_alpha(layer)
                    print "Added alpha channel"

                # Sample all four corners
                corners = [
                    (0, 0),           # Top-left
                    (w-1, 0),         # Top-right
                    (0, h-1),         # Bottom-left
                    (w-1, h-1)        # Bottom-right
                ]

                print "Sampling %d corners..." % len(corners)
                #{"print \"Using FUZZY SELECT (contiguous regions only)\"" if use_fuzzy}
                #{"print \"Using GLOBAL COLOR SELECT (all matching pixels)\"" unless use_fuzzy}

                for i, (x, y) in enumerate(corners):
                    print "  Corner %d at (%d, %d)" % (i+1, x, y)
                    select_op = CHANNEL_OP_REPLACE if i == 0 else CHANNEL_OP_ADD
                    #{use_fuzzy ? "pdb.gimp_image_select_contiguous_color(img, select_op, layer, x, y)" : "color = pdb.gimp_image_get_pixel_color(img, layer, x, y)[1]\n                    pdb.gimp_image_select_color(img, select_op, layer, color)"}

                print "Selection complete"

                # Grow selection if configured
                #{grow > 0 ? "print \"Growing selection by #{grow} pixels...\"\n                pdb.gimp_selection_grow(img, #{grow})\n                print \"Selection grown\"" : "# No selection growth"}

                # Feather selection if configured
                #{feather > 0 ? "print \"Feathering selection by #{feather} pixels...\"\n                pdb.gimp_selection_feather(img, #{feather})\n                print \"Selection feathered\"" : "# No feathering"}

                # Delete selection (clear background)
                print "Removing background..."
                pdb.gimp_edit_clear(layer)
                print "Background removed"

                # Deselect
                print "Deselecting..."
                pdb.gimp_selection_none(img)

                # Export
                print "Exporting..."
                pdb.file_png_save(img, layer, r'#{output_path}', r'#{output_path}',
                                  0, 9, 0, 0, 0, 0, 0)

                print "SUCCESS - Background removed!"

            except Exception as e:
                print "ERROR: %s" % str(e)
                import traceback
                traceback.print_exc()
                sys.exit(1)

        remove_background()
      PYTHON
    end

    def generate_fuzzy_select_code
      # Use nil-coalescing to ensure default is applied when option is nil
      threshold = options[:bg_threshold].nil? ? DEFAULT_BG_THRESHOLD : options[:bg_threshold]

      <<~PYTHON.chomp
        # Fuzzy select (contiguous regions only)
        print("Using FUZZY SELECT (contiguous regions only)")
        print(f"Threshold: #{threshold}")

        # Set ALL context settings to match GUI defaults EXACTLY
        Gimp.context_set_antialias(True)
        Gimp.context_set_feather(False)
        Gimp.context_set_sample_merged(False)
        Gimp.context_set_sample_criterion(Gimp.SelectCriterion.COMPOSITE)
        Gimp.context_set_sample_threshold_int(int(#{threshold}))
        Gimp.context_set_sample_transparent(True)
        Gimp.context_set_diagonal_neighbors(False)

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
      # Use nil-coalescing to ensure default is applied when option is nil
      threshold = options[:bg_threshold].nil? ? DEFAULT_BG_THRESHOLD : options[:bg_threshold]

      <<~PYTHON.chomp
        # Global color select (all matching pixels)
        print("Using GLOBAL COLOR SELECT (all matching pixels)")
        print(f"Threshold: #{threshold}")

        # Set ALL context settings to match GUI defaults EXACTLY
        Gimp.context_set_antialias(True)
        Gimp.context_set_feather(False)
        Gimp.context_set_sample_merged(False)
        Gimp.context_set_sample_criterion(Gimp.SelectCriterion.COMPOSITE)
        Gimp.context_set_sample_threshold_int(int(#{threshold}))
        Gimp.context_set_sample_transparent(True)

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
      grow = options[:grow_selection].nil? ? 0 : options[:grow_selection]  # DEFAULT TO 0!
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
      feather_radius = options[:feather_radius] || 0.0

      if feather_radius > 0
        # Set feathering via context
        <<~PYTHON.chomp
          # Feather selection
          print(f"Feathering selection by #{feather_radius} pixels...")
          Gimp.context_set_feather(True)
          Gimp.context_set_feather_radius(#{feather_radius})

          feather_proc = pdb.lookup_procedure('gimp-selection-feather')
          if feather_proc:
              config = feather_proc.create_config()
              config.set_property('image', img)
              config.set_property('radius', #{feather_radius})
              feather_proc.run(config)
              print("Selection feathered")
        PYTHON
      else
        "# No feathering"
      end
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
        "#{gimp_path}" --no-splash --quit --batch-interpreter=python-fu-eval -b "exec(open(r'#{script_file}').read())" > "#{log_file}" 2>&1
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
      # Check if we're using Flatpak GIMP (needs xvfb-run)
      use_xvfb = gimp_path.start_with?('flatpak:')

      if gimp2?
        # GIMP 2.x: Use gimp-console for batch processing
        gimp_console_path = gimp_path.sub('/gimp', '/gimp-console')
        cmd = "#{Utils::PathHelper.quote_path(gimp_console_path)} -i --no-splash --batch-interpreter python-fu-eval -b 'exec(open(\"#{script_file}\").read())' -b '(gimp-quit 0)' > #{Utils::PathHelper.quote_path(log_file)} 2>&1"
      else
        # GIMP 3.x command
        if use_xvfb
          # Flatpak GIMP needs xvfb-run to provide virtual display
          # Use --nosocket options to prevent Flatpak from accessing host display
          flatpak_app = gimp_path.sub('flatpak:', '')
          cmd = "xvfb-run --auto-servernum --server-args='-screen 0 1024x768x24' flatpak run --nosocket=x11 --nosocket=wayland #{flatpak_app} --no-splash --quit --batch-interpreter=python-fu-eval -b \"exec(open(r'#{script_file}').read())\" > #{Utils::PathHelper.quote_path(log_file)} 2>&1"
        else
          # Regular GIMP 3.x installation
          cmd = "#{Utils::PathHelper.quote_path(gimp_path)} --no-splash --quit --batch-interpreter=python-fu-eval -b \"exec(open(r'#{script_file}').read())\" > #{Utils::PathHelper.quote_path(log_file)} 2>&1"
        end
      end

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
        # Filter Linux/Wayland/Flatpak cosmetic warnings
        line.match?(/Gdk-WARNING.*Failed to read portal settings/) ||
        line.match?(/set device.*to mode: disabled/) ||
        line.match?(/Gdk-WARNING.*Server is missing xdg_foreign support/) ||
        line.match?(/gimp_widget_set_handle_on_mapped.*gdk_wayland_window_export_handle/) ||
        line.match?(/It will not be possible to set windows in other processes/) ||
        line.match?(/LibGimp-WARNING.*gimp_flush.*Broken pipe/) ||
        line.match?(/Gimp-Core-WARNING.*gimp_finalize.*list of contexts not empty/) ||
        line.match?(/stale context:/) ||
        line.match?(/F: X11 socket.*does not exist in filesystem/) ||
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

    # Map interpolation method names to GIMP 3.x interpolation type enum values
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

    # Map interpolation method names to GIMP 2.x interpolation type constants
    def map_interpolation_method_gimp2(method)
      # GIMP 2.x interpolation constants
      case method.to_s.downcase
      when 'none'
        'INTERPOLATION_NONE'
      when 'linear'
        'INTERPOLATION_LINEAR'
      when 'cubic'
        'INTERPOLATION_CUBIC'
      when 'nohalo'
        'INTERPOLATION_NOHALO'
      when 'lohalo'
        'INTERPOLATION_LOHALO'
      else
        'INTERPOLATION_NOHALO'  # Default to NoHalo for quality
      end
    end

    # Remove background using ImageMagick (fallback for Linux)
    # Uses edge detection and multiple techniques for better results
    def remove_background_imagemagick(input_file, output_file)
      magick_cmd = Platform.imagemagick_convert_cmd
      identify_cmd = Platform.imagemagick_identify_cmd

      # Get options
      use_fuzzy = options[:fuzzy_select]
      fuzz_percent = options[:bg_threshold] || 15.0
      grow = options[:grow_selection] || 1

      # Get image dimensions
      stdout, _stderr, status = Open3.capture3("#{identify_cmd} -format '%w %h' #{Utils::PathHelper.quote_path(input_file)}")
      unless status.success?
        raise ProcessingError, "Could not get image dimensions"
      end
      width, height = stdout.strip.split.map(&:to_i)

      # Sample more points around the border (not just corners)
      sample_points = [
        # Corners
        [0, 0], [width - 1, 0], [0, height - 1], [width - 1, height - 1],
        # Mid-edges
        [width / 2, 0], [width / 2, height - 1],
        [0, height / 2], [width - 1, height / 2]
      ]

      # Get colors from all sample points
      sampled_colors = []
      sample_points.each do |x, y|
        color_stdout, _stderr, status = Open3.capture3("#{identify_cmd} -format '%[pixel:p{#{x},#{y}}]' #{Utils::PathHelper.quote_path(input_file)}")
        sampled_colors << color_stdout.strip if status.success? && !color_stdout.strip.empty?
      end

      # Find the most common color (likely the background)
      bg_color = sampled_colors.group_by(&:itself).max_by { |_, v| v.size }.first

      if options[:debug]
        Utils::OutputFormatter.indent("DEBUG: Image size: #{width}x#{height}")
        Utils::OutputFormatter.indent("DEBUG: Sampled #{sampled_colors.size} border colors")
        Utils::OutputFormatter.indent("DEBUG: Unique colors: #{sampled_colors.uniq.size}")
        Utils::OutputFormatter.indent("DEBUG: Using background color: #{bg_color}")
        Utils::OutputFormatter.indent("DEBUG: Fuzz: #{fuzz_percent}%")
      end

      # Create a multi-pass approach for better results
      # Pass 1: Use floodfill from edges with fuzz tolerance
      temp_file1 = File.join(Dir.tmpdir, "bg_removal_pass1_#{Time.now.to_i}.png")

      draw_commands = sample_points.map { |x, y| "'color #{x},#{y} floodfill'" }.join(' -draw ')

      cmd1 = "#{magick_cmd} #{Utils::PathHelper.quote_path(input_file)} -alpha set -fuzz #{fuzz_percent}% -fill none -draw #{draw_commands} #{temp_file1}"

      if options[:debug]
        Utils::OutputFormatter.indent("DEBUG: Pass 1 - Floodfill from #{sample_points.size} points")
      end

      stdout, stderr, status = Open3.capture3(cmd1)
      unless status.success?
        File.delete(temp_file1) if File.exist?(temp_file1)
        raise ProcessingError, "Background removal pass 1 failed: #{stderr}"
      end

      # Pass 2: Remove the detected background color globally with fuzz
      temp_file2 = File.join(Dir.tmpdir, "bg_removal_pass2_#{Time.now.to_i}.png")

      cmd2 = "#{magick_cmd} #{temp_file1} -fuzz #{fuzz_percent}% -transparent '#{bg_color}' #{temp_file2}"

      if options[:debug]
        Utils::OutputFormatter.indent("DEBUG: Pass 2 - Remove color #{bg_color} globally")
      end

      stdout, stderr, status = Open3.capture3(cmd2)
      unless status.success?
        File.delete(temp_file1) if File.exist?(temp_file1)
        File.delete(temp_file2) if File.exist?(temp_file2)
        raise ProcessingError, "Background removal pass 2 failed: #{stderr}"
      end

      # Pass 3: Minimal cleanup - preserve quality
      cmd3_parts = [
        magick_cmd,
        temp_file2
      ]

      # Only clean up the alpha channel, don't touch the RGB data
      # This preserves sprite quality while cleaning edges
      cmd3_parts += [
        '-channel', 'A',
        # Very gentle cleanup - only remove nearly-transparent pixels
        '-threshold', '5%',  # Anything less than 5% alpha becomes fully transparent
        '+channel'
      ]

      # Optionally grow the transparent areas
      if grow > 0
        cmd3_parts += ['-morphology', 'Dilate', "Disk:#{grow}"]
      end

      cmd3_parts << Utils::PathHelper.quote_path(output_file)
      cmd3 = cmd3_parts.join(' ')

      if options[:debug]
        Utils::OutputFormatter.indent("DEBUG: Pass 3 - Minimal alpha cleanup (quality-preserving)")
      end

      stdout, stderr, status = Open3.capture3(cmd3)

      # Cleanup temp files
      File.delete(temp_file1) if File.exist?(temp_file1)
      File.delete(temp_file2) if File.exist?(temp_file2)

      unless status.success?
        raise ProcessingError, "Background removal pass 3 failed: #{stderr}"
      end

      Utils::FileHelper.validate_exists!(output_file)
      size = Utils::FileHelper.format_size(File.size(output_file))
      Utils::OutputFormatter.success("Background removal complete (#{size})\n")
    end

    # Scale image using ImageMagick (fallback for GIMP 2.x)
    def scale_with_imagemagick(input_file, output_file, percent)
      magick_cmd = Platform.imagemagick_convert_cmd

      # Map interpolation to ImageMagick filters
      interpolation = options[:scale_interpolation] || 'nohalo'
      filter = case interpolation.to_s.downcase
               when 'none' then 'Point'
               when 'linear' then 'Triangle'
               when 'cubic' then 'Catrom'
               when 'nohalo', 'lohalo' then 'Lanczos'  # Best available quality
               else 'Lanczos'
               end

      cmd = [
        magick_cmd,
        Utils::PathHelper.quote_path(input_file),
        '-filter', filter,
        '-resize', "#{percent}%",
        Utils::PathHelper.quote_path(output_file)
      ].join(' ')

      if options[:debug]
        Utils::OutputFormatter.indent("DEBUG: ImageMagick command: #{cmd}")
      end

      stdout, stderr, status = Open3.capture3(cmd)

      unless status.success?
        raise ProcessingError, "ImageMagick scaling failed: #{stderr}"
      end

      Utils::FileHelper.validate_exists!(output_file)
      size = Utils::FileHelper.format_size(File.size(output_file))
      Utils::OutputFormatter.success("Scale complete (#{size})\n")
    end

    # Apply unsharp mask using ImageMagick
    def apply_sharpen_imagemagick(input_file)
      radius = options[:sharpen_radius] || 2.0
      gain = options[:sharpen_gain] || 0.5
      threshold = options[:sharpen_threshold] || 0.03

      desired_output = Utils::FileHelper.output_filename(input_file, "sharpened")
      output_file = Utils::FileHelper.ensure_unique_output(desired_output, overwrite: options[:overwrite])

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
