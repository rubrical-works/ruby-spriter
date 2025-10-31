# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubySpriter::ThresholdStepper do
  let(:config) do
    double('InnerBgConfig',
           threshold_stepping: true,
           try_inner: false,
           bg_fuzz: 10)
  end

  let(:input_image) { 'spec/fixtures/test_sprite.png' }
  let(:output_image) { 'spec/tmp/threshold_stepped.png' }

  before do
    FileUtils.mkdir_p('spec/tmp')
  end

  after do
    FileUtils.rm_f(output_image) if File.exist?(output_image)
  end

  describe '#initialize' do
    it 'accepts input image, output image, and config' do
      stepper = described_class.new(input_image, output_image, config)
      expect(stepper).to be_a(RubySpriter::ThresholdStepper)
    end
  end

  describe '#process' do
    subject { described_class.new(input_image, output_image, config) }

    it 'creates an output image file' do
      subject.process
      expect(File.exist?(output_image)).to be true
    end

    it 'processes multiple threshold values' do
      subject.process
      report = subject.report

      expect(report[:thresholds_processed]).to be_an(Array)
      expect(report[:thresholds_processed].length).to be > 1
    end

    it 'uses default threshold values when not specified' do
      subject.process
      report = subject.report

      # Default thresholds: [0.0, 0.5, 1.0, 3.0, 5.0, 10.0]
      expect(report[:thresholds_processed]).to include(0.0, 0.5, 1.0, 3.0, 5.0, 10.0)
    end

    it 'flattens multiple results into final image' do
      subject.process

      # Verify output is a valid PNG
      cmd = "magick identify -format '%m' \"#{output_image}\""
      format = `#{cmd}`.strip.gsub("'", '')
      expect(format).to eq('PNG')
    end
  end

  describe '#default_thresholds' do
    subject { described_class.new(input_image, output_image, config) }

    it 'returns the standard threshold array' do
      thresholds = subject.default_thresholds
      expect(thresholds).to eq([0.0, 0.5, 1.0, 3.0, 5.0, 10.0])
    end
  end

  describe '#process_with_threshold' do
    subject { described_class.new(input_image, output_image, config) }

    it 'processes image with a specific threshold value' do
      temp_output = subject.process_with_threshold(1.0)

      expect(File.exist?(temp_output)).to be true
      FileUtils.rm_f(temp_output)
    end

    it 'returns path to temporary processed image' do
      temp_output = subject.process_with_threshold(5.0)

      expect(temp_output).to be_a(String)
      expect(temp_output).to include('threshold')
      FileUtils.rm_f(temp_output)
    end
  end

  describe '#flatten_results' do
    subject { described_class.new(input_image, output_image, config) }

    it 'combines multiple processed images into one' do
      # Create mock processed images
      temp_images = [
        'spec/tmp/temp1.png',
        'spec/tmp/temp2.png'
      ]

      temp_images.each do |img|
        FileUtils.cp(input_image, img)
      end

      subject.flatten_results(temp_images, output_image)

      expect(File.exist?(output_image)).to be true

      # Cleanup
      temp_images.each { |img| FileUtils.rm_f(img) }
    end
  end

  describe '#report' do
    subject { described_class.new(input_image, output_image, config) }

    it 'generates a processing report' do
      subject.process
      report = subject.report

      expect(report).to be_a(Hash)
      expect(report).to have_key(:thresholds_processed)
      expect(report).to have_key(:processing_time)
      expect(report).to have_key(:temp_files_created)
    end
  end

  describe 'integration with --try-inner' do
    let(:config) do
      double('InnerBgConfig',
             threshold_stepping: true,
             try_inner: true,
             bg_fuzz: 10,
             inner_min_area: 100,
             adaptive_min_area: false,
             edge_sample_depth: 10,
             edge_sample_pattern: 'linear',
             color_space: 'rgb')
    end

    subject { described_class.new(input_image, output_image, config) }

    it 'can work sequentially with inner background removal' do
      # Threshold stepping should be applied first, then inner removal
      subject.process
      expect(File.exist?(output_image)).to be true
    end
  end

  describe 'performance' do
    subject { described_class.new(input_image, output_image, config) }

    it 'completes processing in reasonable time' do
      start_time = Time.now
      subject.process
      elapsed = Time.now - start_time

      # Should complete in under 30 seconds for small test image
      expect(elapsed).to be < 30
    end
  end
end
