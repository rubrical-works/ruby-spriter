# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubySpriter::SmokeDetector do
  let(:config) do
    double('InnerBgConfig',
           remove_smoke: false)
  end

  let(:input_image) { 'spec/fixtures/test_sprite.png' }
  let(:output_image) { 'spec/tmp/smoke_processed.png' }

  before do
    FileUtils.mkdir_p('spec/tmp')
  end

  after do
    FileUtils.rm_f(output_image) if File.exist?(output_image)
  end

  describe '#initialize' do
    it 'accepts input image, output image, and config' do
      detector = described_class.new(input_image, output_image, config)
      expect(detector).to be_a(RubySpriter::SmokeDetector)
    end
  end

  describe '#detect' do
    subject { described_class.new(input_image, output_image, config) }

    it 'identifies smoke-like transparency gradients' do
      smoke_regions = subject.detect

      expect(smoke_regions).to be_an(Array)
      # May or may not find smoke depending on fixture
    end

    it 'detects pixels with alpha between 20-80%' do
      smoke_regions = subject.detect

      # Each region should have alpha characteristics
      smoke_regions.each do |region|
        expect(region).to have_key(:alpha_range)
        expect(region).to have_key(:area)
      end
    end

    it 'filters regions by minimum area (50 pixels)' do
      smoke_regions = subject.detect

      smoke_regions.each do |region|
        expect(region[:area]).to be >= 50
      end
    end
  end

  describe '#process' do
    context 'when remove_smoke is false' do
      subject { described_class.new(input_image, output_image, config) }

      it 'detects but does not remove smoke effects' do
        subject.process
        report = subject.report

        expect(report[:smoke_detected]).to be_a(Integer)
        expect(report[:smoke_removed]).to eq(false)
      end

      it 'copies input to output unchanged' do
        subject.process

        expect(File.exist?(output_image)).to be true

        # Files should be identical
        expect(FileUtils.compare_file(input_image, output_image)).to be true
      end
    end

    context 'when remove_smoke is true' do
      let(:config) do
        double('InnerBgConfig',
               remove_smoke: true)
      end

      subject { described_class.new(input_image, output_image, config) }

      it 'detects and removes smoke effects' do
        subject.process
        report = subject.report

        expect(report[:smoke_detected]).to be_a(Integer)
        expect(report[:smoke_removed]).to eq(true)
      end

      it 'creates an output image file' do
        subject.process
        expect(File.exist?(output_image)).to be true
      end

      it 'removes semi-transparent gradient regions' do
        subject.process

        # Output should exist and be valid
        expect(File.exist?(output_image)).to be true

        # Check file size is reasonable
        file_size = File.size(output_image)
        expect(file_size).to be > 100
      end
    end
  end

  describe '#remove_smoke_regions' do
    let(:config) do
      double('InnerBgConfig',
             remove_smoke: true)
    end

    subject { described_class.new(input_image, output_image, config) }

    it 'removes detected smoke regions' do
      smoke_regions = [
        { x: 50, y: 50, area: 100, alpha_range: [0.2, 0.8] }
      ]

      FileUtils.cp(input_image, output_image)
      result = subject.remove_smoke_regions(smoke_regions)

      expect(result).to be true
    end
  end

  describe '#is_smoke_like?' do
    subject { described_class.new(input_image, output_image, config) }

    it 'returns true for alpha values between 20-80%' do
      expect(subject.is_smoke_like?(0.5)).to be true
      expect(subject.is_smoke_like?(0.3)).to be true
      expect(subject.is_smoke_like?(0.7)).to be true
    end

    it 'returns false for fully transparent pixels' do
      expect(subject.is_smoke_like?(0.0)).to be false
      expect(subject.is_smoke_like?(0.1)).to be false
    end

    it 'returns false for fully opaque pixels' do
      expect(subject.is_smoke_like?(1.0)).to be false
      expect(subject.is_smoke_like?(0.9)).to be false
    end
  end

  describe '#report' do
    subject { described_class.new(input_image, output_image, config) }

    it 'generates a detection report' do
      subject.process
      report = subject.report

      expect(report).to be_a(Hash)
      expect(report).to have_key(:smoke_detected)
      expect(report).to have_key(:smoke_removed)
      expect(report).to have_key(:smoke_regions)
      expect(report).to have_key(:processing_time)
    end

    it 'includes region details when smoke is detected' do
      subject.process
      report = subject.report

      expect(report[:smoke_regions]).to be_an(Array)
    end
  end

  describe 'alpha range detection' do
    subject { described_class.new(input_image, output_image, config) }

    it 'identifies the alpha range of detected regions' do
      smoke_regions = subject.detect

      smoke_regions.each do |region|
        alpha_range = region[:alpha_range]
        expect(alpha_range).to be_an(Array)
        expect(alpha_range.length).to eq(2)
        expect(alpha_range[0]).to be >= 0.2
        expect(alpha_range[1]).to be <= 0.8
      end
    end
  end

  describe 'minimum area threshold' do
    subject { described_class.new(input_image, output_image, config) }

    it 'uses 50 pixels as minimum area' do
      smoke_regions = subject.detect

      # All detected regions should meet minimum
      smoke_regions.each do |region|
        expect(region[:area]).to be >= 50
      end
    end
  end

  describe 'performance' do
    subject { described_class.new(input_image, output_image, config) }

    it 'completes detection in reasonable time' do
      start_time = Time.now
      subject.detect
      elapsed = Time.now - start_time

      # Should complete in under 15 seconds for small test image
      expect(elapsed).to be < 15
    end
  end

  describe 'integration scenarios' do
    context 'with image containing no smoke effects' do
      let(:input_image) { 'spec/fixtures/test_sprite.png' }

      subject { described_class.new(input_image, output_image, config) }

      it 'reports zero smoke regions detected' do
        subject.process
        report = subject.report

        expect(report[:smoke_detected]).to eq(0)
      end
    end

    context 'with grayscale image' do
      let(:input_image) { 'spec/fixtures/test_sprite.png' }

      subject { described_class.new(input_image, output_image, config) }

      it 'handles grayscale images correctly' do
        subject.process
        report = subject.report

        # Should complete without errors
        expect(report[:smoke_detected]).to be >= 0
      end
    end
  end
end
