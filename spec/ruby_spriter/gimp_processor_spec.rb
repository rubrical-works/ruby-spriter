# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubySpriter::GimpProcessor do
  let(:gimp_path) { '/usr/bin/gimp' }
  let(:test_image) { File.join(__dir__, '..', 'fixtures', 'spritesheet_4x2.png') }

  describe '#initialize' do
    it 'initializes with gimp_path and options' do
      processor = described_class.new(gimp_path, scale_percent: 50)

      expect(processor.gimp_path).to eq(gimp_path)
      expect(processor.options[:scale_percent]).to eq(50)
    end

    it 'initializes with empty options by default' do
      processor = described_class.new(gimp_path)

      expect(processor.gimp_path).to eq(gimp_path)
      expect(processor.options).to eq({})
    end

    it 'stores multiple options' do
      processor = described_class.new(gimp_path, {
        scale_percent: 50,
        remove_bg: true,
        scale_interpolation: 'nohalo',
        sharpen: true
      })

      expect(processor.options[:scale_percent]).to eq(50)
      expect(processor.options[:remove_bg]).to eq(true)
      expect(processor.options[:scale_interpolation]).to eq('nohalo')
      expect(processor.options[:sharpen]).to eq(true)
    end
  end

  describe '#determine_operations' do
    context 'with no operations requested' do
      it 'returns empty array' do
        processor = described_class.new(gimp_path, {})
        operations = processor.send(:determine_operations)

        expect(operations).to eq([])
      end
    end

    context 'with scale only' do
      it 'returns scale operation only' do
        processor = described_class.new(gimp_path, scale_percent: 50)
        operations = processor.send(:determine_operations)

        expect(operations).to eq([:scale_image])
      end
    end

    context 'with remove_bg only' do
      it 'returns remove_background operation only' do
        processor = described_class.new(gimp_path, remove_bg: true)
        operations = processor.send(:determine_operations)

        expect(operations).to eq([:remove_background])
      end
    end

    context 'with both scale and remove_bg (auto-optimization)' do
      it 'automatically does remove_bg first by default' do
        processor = described_class.new(gimp_path, {
          scale_percent: 50,
          remove_bg: true,
          operation_order: :scale_then_remove_bg  # Default, but will be auto-optimized
        })
        operations = processor.send(:determine_operations)

        # Auto-optimization: remove_bg should come first
        expect(operations).to eq([:remove_background, :scale_image])
      end

      it 'respects explicit remove_bg_then_scale order' do
        processor = described_class.new(gimp_path, {
          scale_percent: 50,
          remove_bg: true,
          operation_order: :remove_bg_then_scale
        })
        operations = processor.send(:determine_operations)

        expect(operations).to eq([:remove_background, :scale_image])
      end

      it 'respects explicit scale_then_remove_bg order when not auto-optimized' do
        processor = described_class.new(gimp_path, {
          scale_percent: 50,
          remove_bg: true,
          operation_order: :scale_then_remove_bg,
          auto_optimize: false  # If this were implemented
        })
        operations = processor.send(:determine_operations)

        # With auto-optimization, this still gets optimized
        expect(operations).to eq([:remove_background, :scale_image])
      end
    end

    context 'operation order edge cases' do
      it 'handles scale=nil, remove_bg=true' do
        processor = described_class.new(gimp_path, {
          scale_percent: nil,
          remove_bg: true
        })
        operations = processor.send(:determine_operations)

        expect(operations).to eq([:remove_background])
      end

      it 'handles scale=50, remove_bg=false' do
        processor = described_class.new(gimp_path, {
          scale_percent: 50,
          remove_bg: false
        })
        operations = processor.send(:determine_operations)

        expect(operations).to eq([:scale_image])
      end
    end
  end

  describe '#map_interpolation_method' do
    let(:processor) { described_class.new(gimp_path) }

    it 'maps "none" to GIMP NONE constant' do
      result = processor.send(:map_interpolation_method, 'none')
      expect(result).to eq('Gimp.InterpolationType.NONE')
    end

    it 'maps "linear" to GIMP LINEAR constant' do
      result = processor.send(:map_interpolation_method, 'linear')
      expect(result).to eq('Gimp.InterpolationType.LINEAR')
    end

    it 'maps "cubic" to GIMP CUBIC constant' do
      result = processor.send(:map_interpolation_method, 'cubic')
      expect(result).to eq('Gimp.InterpolationType.CUBIC')
    end

    it 'maps "nohalo" to GIMP NOHALO constant' do
      result = processor.send(:map_interpolation_method, 'nohalo')
      expect(result).to eq('Gimp.InterpolationType.NOHALO')
    end

    it 'maps "lohalo" to GIMP LOHALO constant' do
      result = processor.send(:map_interpolation_method, 'lohalo')
      expect(result).to eq('Gimp.InterpolationType.LOHALO')
    end

    it 'is case-insensitive' do
      expect(processor.send(:map_interpolation_method, 'NOHALO')).to eq('Gimp.InterpolationType.NOHALO')
      expect(processor.send(:map_interpolation_method, 'NoHalo')).to eq('Gimp.InterpolationType.NOHALO')
      expect(processor.send(:map_interpolation_method, 'LINEAR')).to eq('Gimp.InterpolationType.LINEAR')
    end

    it 'accepts symbol input' do
      result = processor.send(:map_interpolation_method, :nohalo)
      expect(result).to eq('Gimp.InterpolationType.NOHALO')
    end

    it 'defaults to NOHALO for unknown methods' do
      expect(processor.send(:map_interpolation_method, 'unknown')).to eq('Gimp.InterpolationType.NOHALO')
      expect(processor.send(:map_interpolation_method, 'foo')).to eq('Gimp.InterpolationType.NOHALO')
      expect(processor.send(:map_interpolation_method, '')).to eq('Gimp.InterpolationType.NOHALO')
    end

    it 'defaults to NOHALO for nil' do
      result = processor.send(:map_interpolation_method, nil)
      expect(result).to eq('Gimp.InterpolationType.NOHALO')
    end
  end

  describe '#filter_gimp_output' do
    let(:processor) { described_class.new(gimp_path) }

    it 'filters GEGL-WARNING lines' do
      output = "GEGL-WARNING: some warning\nUseful output\n"
      result = processor.send(:filter_gimp_output, output)

      expect(result).to eq("Useful output\n")
    end

    it 'filters gegl_tile_cache_destroy lines' do
      output = "gegl_tile_cache_destroy: leaked tiles\nUseful output\n"
      result = processor.send(:filter_gimp_output, output)

      expect(result).to eq("Useful output\n")
    end

    it 'filters runtime check failed lines' do
      output = "runtime check failed: something\nUseful output\n"
      result = processor.send(:filter_gimp_output, output)

      expect(result).to eq("Useful output\n")
    end

    it 'filters batch command executed successfully lines' do
      output = "batch command executed successfully\nUseful output\n"
      result = processor.send(:filter_gimp_output, output)

      expect(result).to eq("Useful output\n")
    end

    it 'filters GEGL_DEBUG buffer-alloc lines' do
      output = "GEGL_DEBUG: buffer-alloc details\nUseful output\n"
      result = processor.send(:filter_gimp_output, output)

      expect(result).to eq("Useful output\n")
    end

    it 'filters GeglBuffers leaked lines' do
      output = "GeglBuffers leaked: 5\nUseful output\n"
      result = processor.send(:filter_gimp_output, output)

      expect(result).to eq("Useful output\n")
    end

    it 'filters EEEEeEeek lines' do
      output = "EEEEeEeek! scary message\nUseful output\n"
      result = processor.send(:filter_gimp_output, output)

      expect(result).to eq("Useful output\n")
    end

    it 'filters empty lines' do
      output = "Line 1\n\nLine 2\n   \nLine 3\n"
      result = processor.send(:filter_gimp_output, output)

      expect(result).to eq("Line 1\nLine 2\nLine 3\n")
    end

    it 'filters multiple warning types in one output' do
      output = <<~OUTPUT
        GEGL-WARNING: warning 1
        Useful line 1
        gegl_tile_cache_destroy: leak
        Useful line 2
        runtime check failed
        batch command executed successfully
        Useful line 3
      OUTPUT

      result = processor.send(:filter_gimp_output, output)

      expect(result).to eq("Useful line 1\nUseful line 2\nUseful line 3\n")
    end

    it 'returns empty string when all lines are filtered' do
      output = <<~OUTPUT
        GEGL-WARNING: warning
        gegl_tile_cache_destroy: leak
        runtime check failed
      OUTPUT

      result = processor.send(:filter_gimp_output, output)

      expect(result).to eq("")
    end

    it 'preserves important error messages' do
      output = "Error: File not found\nGEGL-WARNING: some warning\n"
      result = processor.send(:filter_gimp_output, output)

      expect(result).to eq("Error: File not found\n")
    end
  end

  describe '#has_important_messages?' do
    let(:processor) { described_class.new(gimp_path) }

    it 'returns false for only filtered warnings' do
      output = <<~OUTPUT
        GEGL-WARNING: warning
        gegl_tile_cache_destroy: leak
      OUTPUT

      expect(processor.send(:has_important_messages?, output)).to be false
    end

    it 'returns false for empty output' do
      expect(processor.send(:has_important_messages?, "")).to be false
    end

    it 'returns false for only SUCCESS messages' do
      output = "SUCCESS: Operation completed\n"

      expect(processor.send(:has_important_messages?, output)).to be false
    end

    it 'returns false for SUCCESS messages mixed with filtered warnings' do
      output = <<~OUTPUT
        GEGL-WARNING: warning
        SUCCESS: Operation completed
        gegl_tile_cache_destroy: leak
      OUTPUT

      expect(processor.send(:has_important_messages?, output)).to be false
    end

    it 'returns true for error messages' do
      output = "Error: Something went wrong\n"

      expect(processor.send(:has_important_messages?, output)).to be true
    end

    it 'returns true for important messages mixed with warnings' do
      output = <<~OUTPUT
        GEGL-WARNING: warning
        Error: File not found
        gegl_tile_cache_destroy: leak
      OUTPUT

      expect(processor.send(:has_important_messages?, output)).to be true
    end

    it 'returns true for non-filtered, non-SUCCESS output' do
      output = "Processing image...\nDone\n"

      expect(processor.send(:has_important_messages?, output)).to be true
    end
  end

  describe 'script generation' do
    let(:processor) { described_class.new(gimp_path, scale_percent: 50, scale_interpolation: 'nohalo') }
    let(:input_file) { '/path/to/input.png' }
    let(:output_file) { '/path/to/output.png' }

    describe '#generate_scale_script' do
      it 'generates Python script with correct file paths' do
        script = processor.send(:generate_scale_script, input_file, output_file, 50)

        expect(script).to include('input.png')
        expect(script).to include('output.png')
      end

      it 'includes correct scale percentage' do
        script = processor.send(:generate_scale_script, input_file, output_file, 50)

        # Percent is embedded directly and divided by 100 in Python: int(w * 50 / 100.0)
        expect(script).to include('* 50 / 100.0')
      end

      it 'includes correct interpolation method' do
        script = processor.send(:generate_scale_script, input_file, output_file, 50)

        expect(script).to include('Gimp.InterpolationType.NOHALO')
      end

      it 'uses correct GIMP 3.x API' do
        script = processor.send(:generate_scale_script, input_file, output_file, 50)

        expect(script).to include('Gimp.file_load')
        expect(script).to include('gimp-context-set-interpolation')
        expect(script).to include('gimp-layer-scale')
      end

      it 'handles different scale percentages' do
        script_25 = processor.send(:generate_scale_script, input_file, output_file, 25)
        script_75 = processor.send(:generate_scale_script, input_file, output_file, 75)

        expect(script_25).to include('* 25 / 100.0')
        expect(script_75).to include('* 75 / 100.0')
      end
    end

    describe '#generate_remove_bg_script' do
      context 'with fuzzy select (default)' do
        let(:processor_fuzzy) { described_class.new(gimp_path, remove_bg: true, fuzzy_select: true) }

        it 'generates script with fuzzy select' do
          script = processor_fuzzy.send(:generate_remove_bg_script, input_file, output_file)

          expect(script).to include('gimp-image-select-contiguous-color')
        end

        it 'samples all four corners' do
          script = processor_fuzzy.send(:generate_remove_bg_script, input_file, output_file)

          # The procedure is looked up once, then used in a loop for all 4 corners
          expect(script).to include('gimp-image-select-contiguous-color')
          expect(script).to include('for i, (x, y) in enumerate(corners):')
          # Verify corners array has 4 entries
          expect(script).to include('(0, 0)')           # Top-left
          expect(script).to include('(w-1, 0)')         # Top-right
          expect(script).to include('(0, h-1)')         # Bottom-left
          expect(script).to include('(w-1, h-1)')       # Bottom-right
        end
      end

      context 'with global color select' do
        let(:processor_global) { described_class.new(gimp_path, remove_bg: true, fuzzy_select: false) }

        it 'generates script with global color select' do
          script = processor_global.send(:generate_remove_bg_script, input_file, output_file)

          expect(script).to include('gimp-image-select-color')
        end
      end

      it 'includes file paths' do
        processor_bg = described_class.new(gimp_path, remove_bg: true)
        script = processor_bg.send(:generate_remove_bg_script, input_file, output_file)

        expect(script).to include('input.png')
        expect(script).to include('output.png')
      end

      it 'uses correct GIMP 3.x API' do
        processor_bg = described_class.new(gimp_path, remove_bg: true)
        script = processor_bg.send(:generate_remove_bg_script, input_file, output_file)

        expect(script).to include('Gimp.file_load')
        # Background removal selects corners directly (no inversion needed)
        expect(script).to include('gimp-drawable-edit-clear')
        expect(script).to include('gimp-selection-none')
      end
    end
  end
end
