# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubySpriter::InnerBgConfig do
  describe '#initialize' do
    context 'with no arguments' do
      subject { described_class.new }

      it 'sets try_inner to false by default' do
        expect(subject.try_inner).to be false
      end

      it 'sets inner_min_area to 100 pixels by default' do
        expect(subject.inner_min_area).to eq(100)
      end

      it 'sets adaptive_min_area to false by default' do
        expect(subject.adaptive_min_area).to be false
      end

      it 'sets multi_pass to false by default' do
        expect(subject.multi_pass).to be false
      end

      it 'sets edge_sample_depth to 2 pixels by default' do
        expect(subject.edge_sample_depth).to eq(2)
      end

      it 'sets edge_sample_interval to 5 pixels by default' do
        expect(subject.edge_sample_interval).to eq(5)
      end

      it 'sets color_space to rgb by default' do
        expect(subject.color_space).to eq('rgb')
      end

      it 'sets threshold_stepping to false by default' do
        expect(subject.threshold_stepping).to be false
      end

      it 'sets remove_smoke to false by default' do
        expect(subject.remove_smoke).to be false
      end

      it 'sets bg_fuzz to 10% by default' do
        expect(subject.bg_fuzz).to eq(10)
      end

      it 'sets ghost_threshold to 30 by default' do
        expect(subject.ghost_threshold).to eq(30)
      end
    end

    context 'with custom options' do
      let(:options) do
        {
          try_inner: true,
          inner_min_area: 200,
          adaptive_min_area: true,
          multi_pass: true,
          edge_sample_depth: 15,
          edge_sample_interval: 3,
          color_space: 'lab',
          threshold_stepping: true,
          remove_smoke: true,
          bg_fuzz: 20,
          ghost_threshold: 50
        }
      end

      subject { described_class.new(options) }

      it 'overrides defaults with provided options' do
        expect(subject.try_inner).to be true
        expect(subject.inner_min_area).to eq(200)
        expect(subject.adaptive_min_area).to be true
        expect(subject.multi_pass).to be true
        expect(subject.edge_sample_depth).to eq(15)
        expect(subject.edge_sample_interval).to eq(3)
        expect(subject.color_space).to eq('lab')
        expect(subject.threshold_stepping).to be true
        expect(subject.remove_smoke).to be true
        expect(subject.bg_fuzz).to eq(20)
        expect(subject.ghost_threshold).to eq(50)
      end
    end
  end

  describe '#valid?' do
    context 'with valid configuration' do
      subject { described_class.new }

      it 'returns true for default configuration' do
        expect(subject.valid?).to be true
      end
    end

    context 'with invalid color_space' do
      subject { described_class.new(color_space: 'hsv') }

      it 'returns false' do
        expect(subject.valid?).to be false
      end
    end

    context 'with negative inner_min_area' do
      subject { described_class.new(inner_min_area: -10) }

      it 'returns false' do
        expect(subject.valid?).to be false
      end
    end

    context 'with bg_fuzz out of range' do
      it 'returns false for negative value' do
        config = described_class.new(bg_fuzz: -5)
        expect(config.valid?).to be false
      end

      it 'returns false for value > 100' do
        config = described_class.new(bg_fuzz: 150)
        expect(config.valid?).to be false
      end
    end

    context 'with ghost_threshold out of range' do
      it 'returns false for negative value' do
        config = described_class.new(ghost_threshold: -10)
        expect(config.valid?).to be false
      end

      it 'returns false for value > 255' do
        config = described_class.new(ghost_threshold: 300)
        expect(config.valid?).to be false
      end
    end
  end

  describe '#calculate_adaptive_min_area' do
    context 'when adaptive_min_area is false' do
      subject { described_class.new(inner_min_area: 150, adaptive_min_area: false) }

      it 'returns the fixed inner_min_area value' do
        result = subject.calculate_adaptive_min_area(1000, 1000)
        expect(result).to eq(150)
      end
    end

    context 'when adaptive_min_area is true' do
      subject { described_class.new(adaptive_min_area: true) }

      it 'calculates 1% of image area for 1000x1000 image' do
        result = subject.calculate_adaptive_min_area(1000, 1000)
        expect(result).to eq(10_000)  # 1% of 1,000,000 pixels
      end

      it 'calculates 1% of image area for 500x500 image' do
        result = subject.calculate_adaptive_min_area(500, 500)
        expect(result).to eq(2_500)  # 1% of 250,000 pixels
      end

      it 'calculates 1% of image area for 2048x2048 image' do
        result = subject.calculate_adaptive_min_area(2048, 2048)
        expect(result).to eq(41_943)  # 1% of 4,194,304 pixels
      end
    end
  end

  describe '#enabled?' do
    it 'returns true when try_inner is true' do
      config = described_class.new(try_inner: true)
      expect(config.enabled?).to be true
    end

    it 'returns false when try_inner is false' do
      config = described_class.new(try_inner: false)
      expect(config.enabled?).to be false
    end
  end

  describe '#to_h' do
    subject { described_class.new(try_inner: true, inner_min_area: 200) }

    it 'returns a hash with all configuration values' do
      hash = subject.to_h

      expect(hash).to be_a(Hash)
      expect(hash[:try_inner]).to be true
      expect(hash[:inner_min_area]).to eq(200)
      expect(hash.keys).to include(
        :try_inner, :inner_min_area, :adaptive_min_area, :multi_pass,
        :edge_sample_depth, :edge_sample_interval, :color_space,
        :threshold_stepping, :remove_smoke, :bg_fuzz, :ghost_threshold
      )
    end
  end
end
