require 'spec_helper'
require 'ruby_spriter/gimp_processor'
require 'ruby_spriter/background_sampler'

RSpec.describe 'No-Fuzzy Mode Integration' do
  let(:gimp_path) { 'gimp-console' }
  let(:input_file) { 'spec/fixtures/walk_north_sprite-sheet.png' }
  let(:output_file) { 'spec/tmp/no_fuzzy_output.png' }

  before do
    FileUtils.mkdir_p(File.dirname(output_file))
  end

  after do
    FileUtils.rm_f(output_file) if File.exist?(output_file)
  end

  describe 'GimpProcessor with --no-fuzzy mode' do
    it 'generates script with global select at (5,5) plus additional background colors' do
      options = {
        remove_bg: true,
        fuzzy_select: false,
        bg_sample_offset: 5,
        bg_sample_count: 10
      }

      processor = RubySpriter::GimpProcessor.new(gimp_path, options)

      # Collect background colors
      sampler = RubySpriter::BackgroundSampler.new(input_file, 5, 10, 20)
      background_colors = sampler.collect_unique_colors

      expect(background_colors).not_to be_empty

      # Generate script with background colors
      script = processor.send(:generate_remove_bg_script, input_file, output_file, background_colors)

      # Should include single-point global select at (5,5)
      expect(script).to include('x = 5')
      expect(script).to include('y = 5')
      expect(script).to include('gimp-image-select-color')

      # Should include global color select for inner backgrounds
      expect(script).to include('Selecting inner background colors')
      expect(script).to include('gimp-image-select-color')
      expect(script).to include('Gimp.ChannelOps.ADD')

      # Should include the background colors in Python dict format
      colors_pattern = background_colors.map { |c| "{'r': #{c[:r]}, 'g': #{c[:g]}, 'b': #{c[:b]}}" }.join(', ')
      expect(script).to include("[#{colors_pattern}]")
    end

    it 'does not include global select when fuzzy_select is true' do
      options = {
        remove_bg: true,
        fuzzy_select: true
      }

      processor = RubySpriter::GimpProcessor.new(gimp_path, options)
      script = processor.send(:generate_remove_bg_script, input_file, output_file, nil)

      # Should include fuzzy select
      expect(script).to include('gimp-image-select-contiguous-color')

      # Should NOT include global color select for inner backgrounds
      expect(script).not_to include('Selecting inner background colors')
    end

    it 'handles empty background_colors array gracefully' do
      options = {
        remove_bg: true,
        fuzzy_select: false
      }

      processor = RubySpriter::GimpProcessor.new(gimp_path, options)
      script = processor.send(:generate_remove_bg_script, input_file, output_file, [])

      # Should still work with just global select at (5,5)
      expect(script).to include('gimp-image-select-color')
      expect(script).not_to include('Selecting inner background colors')
    end
  end

  describe 'BackgroundSampler integration' do
    it 'collects colors from the test image' do
      sampler = RubySpriter::BackgroundSampler.new(input_file, 5, 10, 20)
      colors = sampler.collect_unique_colors

      expect(colors).to be_an(Array)
      expect(colors.length).to be > 0
      expect(colors.length).to be <= 10

      colors.each do |color|
        expect(color).to have_key(:r)
        expect(color).to have_key(:g)
        expect(color).to have_key(:b)
      end
    end
  end
end
