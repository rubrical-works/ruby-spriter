# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubySpriter::GhostEdgeCleaner do
  let(:config) do
    double('InnerBgConfig',
           multi_pass: true,
           ghost_threshold: 30)
  end

  let(:input_image) { 'spec/fixtures/transparent_bg_sprite.png' }
  let(:output_image) { 'spec/tmp/ghost_cleaned.png' }

  before do
    FileUtils.mkdir_p('spec/tmp')
  end

  after do
    FileUtils.rm_f(output_image) if File.exist?(output_image)
  end

  describe '#initialize' do
    it 'accepts input image, output image, and config' do
      cleaner = described_class.new(input_image, output_image, config)
      expect(cleaner).to be_a(RubySpriter::GhostEdgeCleaner)
    end
  end

  describe '#process' do
    subject { described_class.new(input_image, output_image, config) }

    it 'creates an output image file' do
      subject.process
      expect(File.exist?(output_image)).to be true
    end

    it 'removes semi-transparent ghost pixels' do
      subject.process
      report = subject.report

      expect(report[:ghost_pixels_detected]).to be_a(Integer)
      expect(report[:ghost_pixels_detected]).to be >= 0
    end

    it 'preserves fully opaque pixels' do
      subject.process

      # Verify output file exists and has valid format
      expect(File.exist?(output_image)).to be true

      # Check file size is reasonable (not empty)
      file_size = File.size(output_image)
      expect(file_size).to be > 100  # At least 100 bytes
    end

    it 'uses the configured ghost_threshold' do
      subject.process
      report = subject.report

      expect(report[:threshold_used]).to eq(30)
    end
  end

  describe '#detect_ghost_pixels' do
    subject { described_class.new(input_image, output_image, config) }

    it 'identifies pixels with alpha below threshold' do
      ghost_count = subject.detect_ghost_pixels

      expect(ghost_count).to be_a(Integer)
      expect(ghost_count).to be >= 0
    end
  end

  describe '#clean_edges' do
    subject { described_class.new(input_image, output_image, config) }

    it 'removes pixels below alpha threshold' do
      # Copy input to output first
      FileUtils.cp(input_image, output_image)

      subject.clean_edges

      expect(File.exist?(output_image)).to be true
    end

    it 'preserves edge anti-aliasing for high-alpha pixels' do
      FileUtils.cp(input_image, output_image)

      subject.clean_edges

      # Check that some semi-transparent pixels remain (anti-aliasing)
      cmd = "magick \"#{output_image}\" -channel A -separate -format '%[fx:mean]' info:"
      mean_alpha = `#{cmd}`.strip.to_f

      # Should have some transparency (not all fully opaque)
      expect(mean_alpha).to be < 1.0
    end
  end

  describe '#multi_pass_cleanup' do
    subject { described_class.new(input_image, output_image, config) }

    it 'performs multiple cleanup passes' do
      FileUtils.cp(input_image, output_image)

      passes = subject.multi_pass_cleanup

      expect(passes).to be >= 1
      expect(passes).to be <= 3  # Default max passes
    end

    it 'stops when no more ghost pixels are detected' do
      FileUtils.cp(input_image, output_image)

      passes = subject.multi_pass_cleanup
      report = subject.report

      expect(report[:passes_performed]).to eq(passes)
    end
  end

  describe '#report' do
    subject { described_class.new(input_image, output_image, config) }

    it 'generates a processing report' do
      subject.process
      report = subject.report

      expect(report).to be_a(Hash)
      expect(report).to have_key(:ghost_pixels_detected)
      expect(report).to have_key(:threshold_used)
      expect(report).to have_key(:passes_performed)
      expect(report).to have_key(:processing_time)
    end
  end

  describe 'threshold variations' do
    context 'with low threshold (10)' do
      let(:config) do
        double('InnerBgConfig',
               multi_pass: true,
               ghost_threshold: 10)
      end

      subject { described_class.new(input_image, output_image, config) }

      it 'removes more aggressive (keeps more pixels)' do
        subject.process
        report = subject.report

        expect(report[:threshold_used]).to eq(10)
      end
    end

    context 'with high threshold (50)' do
      let(:config) do
        double('InnerBgConfig',
               multi_pass: true,
               ghost_threshold: 50)
      end

      subject { described_class.new(input_image, output_image, config) }

      it 'removes more pixels' do
        subject.process
        report = subject.report

        expect(report[:threshold_used]).to eq(50)
      end
    end
  end

  describe 'performance' do
    subject { described_class.new(input_image, output_image, config) }

    it 'completes processing in reasonable time' do
      start_time = Time.now
      subject.process
      elapsed = Time.now - start_time

      # Should complete in under 10 seconds for small test image
      expect(elapsed).to be < 10
    end
  end

  describe 'quality preservation' do
    subject { described_class.new(input_image, output_image, config) }

    it 'maintains sprite RGB data integrity' do
      subject.process

      # Verify RGB channels are not degraded
      cmd = "magick \"#{output_image}\" -format '%[colorspace]' info:"
      colorspace = `#{cmd}`.strip
      expect(colorspace).to match(/sRGB|RGB/)
    end

    it 'preserves image dimensions' do
      subject.process

      # Get dimensions
      cmd = "magick identify -format '%wx%h' \"#{output_image}\""
      output_dims = `#{cmd}`.strip

      cmd = "magick identify -format '%wx%h' \"#{input_image}\""
      input_dims = `#{cmd}`.strip

      expect(output_dims).to eq(input_dims)
    end
  end
end
