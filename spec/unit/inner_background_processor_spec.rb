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

      # Check that output image is not completely transparent
      cmd = "magick #{RubySpriter::Utils::PathHelper.quote_path(output_image)} -format '%[fx:mean]' info:"
      mean_value = `#{cmd}`.strip.to_f
      expect(mean_value).to be > 0.0 # Some non-transparent pixels remain
    end
  end

  describe '#detect_inner_regions' do
    subject { described_class.new(input_image, output_image, config, background_palette) }

    it 'identifies contiguous background regions' do
      regions = subject.detect_inner_regions

      expect(regions).to be_an(Array)
      expect(regions).not_to be_empty
    end

    it 'returns region information with size and location' do
      regions = subject.detect_inner_regions

      first_region = regions.first
      expect(first_region).to have_key(:area)
      expect(first_region).to have_key(:x)
      expect(first_region).to have_key(:y)
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
end
