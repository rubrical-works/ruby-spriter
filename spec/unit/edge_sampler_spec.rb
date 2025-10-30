# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubySpriter::EdgeSampler do
  let(:config) do
    double('InnerBgConfig',
           edge_sample_depth: 10,
           edge_sample_pattern: 'linear',
           color_space: 'rgb')
  end

  let(:image_path) { 'spec/fixtures/test_sprite.png' }

  describe '#initialize' do
    it 'accepts image path and configuration' do
      sampler = described_class.new(image_path, config)
      expect(sampler).to be_a(RubySpriter::EdgeSampler)
    end
  end

  describe '#sample_edges' do
    subject { described_class.new(image_path, config) }

    context 'with linear sampling pattern' do
      it 'returns an array of color samples' do
        samples = subject.sample_edges
        expect(samples).to be_an(Array)
        expect(samples).not_to be_empty
      end

      it 'samples from all four edges' do
        samples = subject.sample_edges
        # Should have samples from top, bottom, left, right
        expect(samples.length).to be >= 4
      end

      it 'returns RGB color values as hashes' do
        samples = subject.sample_edges
        first_sample = samples.first

        expect(first_sample).to have_key(:r)
        expect(first_sample).to have_key(:g)
        expect(first_sample).to have_key(:b)
        expect(first_sample[:r]).to be_between(0, 255)
        expect(first_sample[:g]).to be_between(0, 255)
        expect(first_sample[:b]).to be_between(0, 255)
      end
    end

    context 'with weighted sampling pattern' do
      let(:config) do
        double('InnerBgConfig',
               edge_sample_depth: 10,
               edge_sample_pattern: 'weighted',
               color_space: 'rgb')
      end

      it 'returns weighted samples with more corner emphasis' do
        samples = subject.sample_edges
        expect(samples).to be_an(Array)
        expect(samples).not_to be_empty
      end
    end

    context 'with custom edge_sample_depth' do
      let(:config) do
        double('InnerBgConfig',
               edge_sample_depth: 20,
               edge_sample_pattern: 'linear',
               color_space: 'rgb')
      end

      it 'samples deeper into the image' do
        samples = subject.sample_edges
        expect(samples).to be_an(Array)
        # More depth should potentially yield more samples
      end
    end
  end

  describe '#build_color_palette' do
    subject { described_class.new(image_path, config) }

    it 'aggregates samples into a color palette' do
      samples = subject.sample_edges
      palette = subject.build_color_palette(samples)

      expect(palette).to be_an(Array)
      expect(palette).not_to be_empty
    end

    it 'removes duplicate colors' do
      samples = [
        { r: 255, g: 255, b: 255 },
        { r: 255, g: 255, b: 255 },
        { r: 0, g: 0, b: 0 }
      ]

      palette = subject.build_color_palette(samples)
      expect(palette.length).to eq(2)
    end
  end

  describe '#detect_outliers' do
    subject { described_class.new(image_path, config) }

    it 'identifies colors that differ significantly from the majority' do
      samples = [
        { r: 255, g: 255, b: 255 },
        { r: 254, g: 254, b: 254 },
        { r: 253, g: 253, b: 253 },
        { r: 0, g: 0, b: 0 }  # Outlier
      ]

      outliers = subject.detect_outliers(samples)
      expect(outliers).to be_an(Array)
      expect(outliers).to include(hash_including(r: 0, g: 0, b: 0))
    end

    it 'returns empty array when all colors are similar' do
      samples = [
        { r: 255, g: 255, b: 255 },
        { r: 254, g: 254, b: 254 },
        { r: 253, g: 253, b: 253 }
      ]

      outliers = subject.detect_outliers(samples)
      expect(outliers).to be_empty
    end
  end

  describe '#report' do
    subject { described_class.new(image_path, config) }

    it 'generates a report hash with sampling statistics' do
      subject.sample_edges
      report = subject.report

      expect(report).to be_a(Hash)
      expect(report).to have_key(:samples_collected)
      expect(report).to have_key(:unique_colors)
      expect(report).to have_key(:outliers_detected)
      expect(report).to have_key(:sampling_pattern)
    end
  end
end
