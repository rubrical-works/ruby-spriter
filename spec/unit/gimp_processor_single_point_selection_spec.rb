require 'spec_helper'
require 'ruby_spriter/gimp_processor'
require 'ruby_spriter/platform'

RSpec.describe RubySpriter::GimpProcessor, 'single point selection (not 4 corners)' do
  let(:gimp_path) { 'gimp-console' }
  let(:input_file) { 'spec/fixtures/test_sprite.png' }
  let(:output_file) { 'spec/tmp/output.png' }

  describe '#generate_fuzzy_select_code' do
    it 'selects from a single point, not multiple corners' do
      options = {
        remove_bg: true,
        fuzzy_select: true,
        threshold: 52.0
      }

      processor = described_class.new(gimp_path, options)
      code = processor.send(:generate_fuzzy_select_code)

      # Should NOT loop through multiple corners
      expect(code).not_to include('for i, (x, y) in enumerate(corners):')
      expect(code).not_to include('enumerate(corners)')

      # Should NOT use ADD operation (only REPLACE)
      expect(code).not_to include('Gimp.ChannelOps.ADD')

      # Should use REPLACE operation for single selection
      expect(code).to include('Gimp.ChannelOps.REPLACE')

      # Should use x and y variables (defined in parent script)
      expect(code).to include('float(x)')
      expect(code).to include('float(y)')
    end
  end

  describe '#generate_global_select_code' do
    it 'selects from a single point, not multiple corners' do
      options = {
        remove_bg: true,
        fuzzy_select: false,
        threshold: 52.0
      }

      processor = described_class.new(gimp_path, options)
      code = processor.send(:generate_global_select_code)

      # Should NOT loop through multiple corners
      expect(code).not_to include('for i, (x, y) in enumerate(corners):')

      # Should NOT use ADD operation
      expect(code).not_to include('Gimp.ChannelOps.ADD')

      # Should use REPLACE operation
      expect(code).to include('Gimp.ChannelOps.REPLACE')
    end
  end

  describe '#generate_remove_bg_script' do
    it 'does not define a corners array with 4 points' do
      options = {
        remove_bg: true,
        fuzzy_select: true
      }

      processor = described_class.new(gimp_path, options)
      script = processor.send(:generate_remove_bg_script, input_file, output_file)

      # Should NOT define corners array with 4 points
      expect(script).not_to include('(0, 0),           # Top-left')
      expect(script).not_to include('(w-1, 0),         # Top-right')
      expect(script).not_to include('(0, h-1),         # Bottom-left')
      expect(script).not_to include('(w-1, h-1)        # Bottom-right')

      # Should define a single sampling point
      # Example: x = 5, y = 5 (interior point to avoid edge artifacts)
      expect(script).to match(/x\s*=\s*\d+/)
      expect(script).to match(/y\s*=\s*\d+/)
    end
  end
end
