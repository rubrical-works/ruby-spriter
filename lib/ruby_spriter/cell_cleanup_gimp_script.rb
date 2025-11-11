module RubySpriter
  module CellCleanupGimpScript
    def self.generate_cleanup_script(input_path, output_path, dominant_colors)
      # Normalize paths for Python
      input_normalized = Utils::PathHelper.normalize_for_python(input_path)
      output_normalized = Utils::PathHelper.normalize_for_python(output_path)

      # Convert RGB strings to Python color strings
      colors_py = dominant_colors.map do |color_str|
        # Parse "rgb(255,0,0)" format
        match = color_str.match(/rgb\((\d+),(\d+),(\d+)\)/)
        r = match[1].to_i
        g = match[2].to_i
        b = match[3].to_i
        "{'r': #{r}, 'g': #{g}, 'b': #{b}}"
      end.join(', ')

      <<~PYTHON
        import sys
        import gc
        from gi.repository import Gimp, Gio, Gegl

        img = None
        layer = None

        try:
            print("Loading image...")
            img = Gimp.file_load(Gimp.RunMode.NONINTERACTIVE,
                                Gio.File.new_for_path(r'#{input_normalized}'))

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

            # Select dominant colors for removal
            print("Selecting dominant colors...")
            select_proc = pdb.lookup_procedure('gimp-image-select-color')
            if not select_proc:
                raise Exception("Could not find gimp-image-select-color procedure")

            for i, color_dict in enumerate([#{colors_py}]):
                r, g, b = color_dict['r'], color_dict['g'], color_dict['b']
                print(f"  Selecting color {i+1}: RGB({r}, {g}, {b})")

                # Create Gegl.Color from normalized RGB values
                color = Gegl.Color.new(f"rgb({r/255.0}, {g/255.0}, {b/255.0})")

                config = select_proc.create_config()
                config.set_property('image', img)
                # Use REPLACE for first color, ADD for subsequent colors
                if i == 0:
                    config.set_property('operation', Gimp.ChannelOps.REPLACE)
                else:
                    config.set_property('operation', Gimp.ChannelOps.ADD)
                config.set_property('drawable', layer)
                config.set_property('color', color)
                select_proc.run(config)

            print("Colors selected")

            # Delete selection (make transparent)
            print("Removing selected colors...")
            edit_clear = pdb.lookup_procedure('gimp-drawable-edit-clear')
            if edit_clear:
                config = edit_clear.create_config()
                config.set_property('drawable', layer)
                edit_clear.run(config)
                print("Selection cleared")

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
                config.set_property('file', Gio.File.new_for_path(r'#{output_normalized}'))
                export_proc.run(config)
                print("SUCCESS - Cell cleanup complete!")
            else:
                raise Exception("Could not find file-png-export procedure")

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
  end
end
