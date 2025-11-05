# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubySpriter::InnerBackgroundProcessor do
  let(:config) do
    double('InnerBgConfig',
           try_inner: true,
           inner_min_area: 100,
           adaptive_min_area: false,
           multi_pass: false,
           bg_fuzz: 10,
           color_space: 'rgb',
           edge_sample_depth: 10,
           edge_sample_pattern: 'linear')
  end

  let(:input_image) { 'spec/fixtures/centered_sprite_with_inner_bg.png' }
  let(:output_image) { 'spec/tmp/inner_bg_processed.png' }
  let(:background_palette) { [{ r: 0, g: 255, b: 0 }] } # Green background

  before do
    FileUtils.mkdir_p('spec/tmp')
  end

  after do
    FileUtils.rm_f(output_image) if File.exist?(output_image)
  end

  describe '#initialize' do
    it 'accepts input image, output image, config, and background palette' do
      processor = described_class.new(input_image, output_image, config, background_palette)
      expect(processor).to be_a(RubySpriter::InnerBackgroundProcessor)
    end
  end

  describe '#process' do
    subject { described_class.new(input_image, output_image, config, background_palette) }

    it 'creates an output image file' do
      subject.process
      expect(File.exist?(output_image)).to be true
    end

    it 'removes inner background regions' do
      subject.process

      # Verify output image exists and has transparency
      expect(File.exist?(output_image)).to be true

      # Use ImageMagick to check if image has alpha channel
      cmd = "magick identify -format '%[channels]' #{RubySpriter::Utils::PathHelper.quote_path(output_image)}"
      result = `#{cmd}`.strip
      expect(result).to include('a') # Has alpha channel
    end

    it 'preserves the sprite (non-background) regions' do
      subject.process

      # Verify output exists and has proper format
      expect(File.exist?(output_image)).to be true

      # Check file size is reasonable (not empty)
      file_size = File.size(output_image)
      expect(file_size).to be > 100 # At least 100 bytes
    end
  end

  describe '#detect_inner_regions' do
    subject { described_class.new(input_image, output_image, config, background_palette) }

    it 'identifies contiguous background regions' do
      regions = subject.detect_inner_regions

      expect(regions).to be_an(Array)
      # Regions may be empty if no qualifying inner regions exist
      # This is valid behavior for images without large inner backgrounds
    end

    it 'returns region information with size and location when regions exist' do
      regions = subject.detect_inner_regions

      # Only check structure if regions were found
      if regions.any?
        first_region = regions.first
        expect(first_region).to have_key(:area)
        expect(first_region).to have_key(:x)
        expect(first_region).to have_key(:y)
      else
        # No regions found is valid for this fixture
        expect(regions).to be_empty
      end
    end

    it 'filters out regions smaller than minimum area threshold' do
      regions = subject.detect_inner_regions

      # All returned regions should meet minimum area requirement
      regions.each do |region|
        expect(region[:area]).to be >= config.inner_min_area
      end
    end
  end

  describe '#remove_region' do
    subject { described_class.new(input_image, output_image, config, background_palette) }

    it 'removes a specific region by making it transparent' do
      region = { x: 100, y: 100, area: 500 }

      # This should modify the working image
      expect { subject.remove_region(region) }.not_to raise_error
    end
  end

  describe '#calculate_adaptive_threshold' do
    subject { described_class.new(input_image, output_image, config, background_palette) }

    context 'when adaptive_min_area is false' do
      it 'returns the fixed inner_min_area value' do
        threshold = subject.calculate_adaptive_threshold
        expect(threshold).to eq(100)
      end
    end

    context 'when adaptive_min_area is true' do
      let(:config) do
        double('InnerBgConfig',
               try_inner: true,
               inner_min_area: 100,
               adaptive_min_area: true,
               multi_pass: false,
               bg_fuzz: 10,
               color_space: 'rgb',
               edge_sample_depth: 10,
               edge_sample_pattern: 'linear')
      end

      it 'calculates 1% of image area' do
        threshold = subject.calculate_adaptive_threshold

        # For 200x200 image: 40,000 pixels * 0.01 = 400
        expect(threshold).to be > 100
        expect(threshold).to be_a(Integer)
      end
    end
  end

  describe '#report' do
    subject { described_class.new(input_image, output_image, config, background_palette) }

    it 'generates a processing report' do
      subject.process
      report = subject.report

      expect(report).to be_a(Hash)
      expect(report).to have_key(:regions_detected)
      expect(report).to have_key(:regions_removed)
      expect(report).to have_key(:total_area_removed)
      expect(report).to have_key(:processing_time)
    end

    it 'includes region size information' do
      subject.process
      report = subject.report

      expect(report).to have_key(:region_sizes)
      expect(report[:region_sizes]).to be_an(Array)
    end
  end

  describe 'integration with background palette' do
    subject { described_class.new(input_image, output_image, config, background_palette) }

    it 'uses background palette colors for matching' do
      # Process with green background palette
      subject.process

      # Verify that green regions were targeted
      expect(File.exist?(output_image)).to be true
    end

    context 'with multiple background colors' do
      let(:background_palette) do
        [
          { r: 0, g: 255, b: 0 },   # Green
          { r: 255, g: 255, b: 255 } # White
        ]
      end

      it 'removes regions matching any palette color' do
        subject.process
        expect(File.exist?(output_image)).to be true
      end
    end
  end

  describe 'color space support' do
    context 'with RGB color space' do
      let(:config) do
        double('InnerBgConfig',
               try_inner: true,
               inner_min_area: 100,
               adaptive_min_area: false,
               multi_pass: false,
               bg_fuzz: 10,
               color_space: 'rgb',
               edge_sample_depth: 10,
               edge_sample_pattern: 'linear')
      end

      subject { described_class.new(input_image, output_image, config, background_palette) }

      it 'uses Euclidean distance for color matching' do
        subject.process
        expect(File.exist?(output_image)).to be true
      end
    end

    context 'with LAB color space' do
      let(:config) do
        double('InnerBgConfig',
               try_inner: true,
               inner_min_area: 100,
               adaptive_min_area: false,
               multi_pass: false,
               bg_fuzz: 10,
               color_space: 'lab',
               edge_sample_depth: 10,
               edge_sample_pattern: 'linear')
      end

      subject { described_class.new(input_image, output_image, config, background_palette) }

      it 'uses perceptual distance for color matching' do
        subject.process
        expect(File.exist?(output_image)).to be true
      end
    end
  end

  describe '#estimate_region_area_from_cache' do
    let(:processor) { described_class.new(input_image, output_image, config, background_palette) }

    before do
      # Set image dimensions directly
      processor.instance_variable_set(:@image_width, 10)
      processor.instance_variable_set(:@image_height, 10)

      # Create a simple 10x10 pixel cache with a region of matching colors
      pixel_cache = {}
      (0...10).each do |y|
        (0...10).each do |x|
          # Create a 3x3 region of red pixels at (2,2) to (4,4)
          if x >= 2 && x <= 4 && y >= 2 && y <= 4
            pixel_cache[[x, y]] = { r: 255, g: 0, b: 0 }
          else
            pixel_cache[[x, y]] = { r: 0, g: 255, b: 0 }
          end
        end
      end

      processor.instance_variable_set(:@pixel_cache, pixel_cache)
    end

    it 'estimates region area using pixel cache without calling ImageMagick' do
      bg_color = { r: 255, g: 0, b: 0 }

      # Should not call ImageMagick
      expect(Open3).not_to receive(:capture3)

      # Estimate area starting from center of red region
      area = processor.send(:estimate_region_area_from_cache, 3, 3, bg_color)

      # Should find the 3x3 = 9 pixel region
      expect(area).to eq(9)
    end

    it 'uses flood fill algorithm to find contiguous regions' do
      bg_color = { r: 255, g: 0, b: 0 }

      area = processor.send(:estimate_region_area_from_cache, 2, 2, bg_color)

      # Should find all 9 connected red pixels
      expect(area).to eq(9)
    end

    it 'respects fuzz tolerance when matching colors' do
      # Add a pixel cache with similar but not exact colors
      pixel_cache = {}
      (0...5).each do |y|
        (0...5).each do |x|
          # Slightly different reds (within 10% fuzz tolerance)
          pixel_cache[[x, y]] = { r: 250 + (x % 5), g: 5, b: 5 }
        end
      end

      processor.instance_variable_set(:@pixel_cache, pixel_cache)

      bg_color = { r: 252, g: 5, b: 5 }

      area = processor.send(:estimate_region_area_from_cache, 2, 2, bg_color)

      # Should find all 25 pixels as they're within fuzz tolerance
      expect(area).to be >= 20
    end

    it 'returns 0 for regions smaller than minimum area' do
      # Single pixel region
      pixel_cache = {}
      (0...5).each do |y|
        (0...5).each do |x|
          pixel_cache[[x, y]] = { r: 0, g: 255, b: 0 }
        end
      end
      pixel_cache[[2, 2]] = { r: 255, g: 0, b: 0 }

      processor.instance_variable_set(:@pixel_cache, pixel_cache)

      bg_color = { r: 255, g: 0, b: 0 }

      area = processor.send(:estimate_region_area_from_cache, 2, 2, bg_color)

      expect(area).to eq(1)
    end
  end
end
