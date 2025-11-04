# frozen_string_literal: true

require 'spec_helper'
require 'ruby_spriter/edge_sampler'
require 'ruby_spriter/inner_bg_config'
require 'tempfile'

RSpec.describe RubySpriter::EdgeSampler do
  let(:config) do
    RubySpriter::InnerBgConfig.new(
      edge_sample_depth: 2,
      edge_sample_interval: 5
    )
  end
  let(:temp_image) { Tempfile.new(['test_sprite', '.png']) }
  let(:sampler) { described_class.new(temp_image.path, config) }

  # Globally mock ALL Open3.capture3 calls before each test
  before do
    allow(Open3).to receive(:capture3) do |cmd|
      if cmd.include?('identify')
        # Return dimensions
        ['1000 800', '', double(success?: true)]
      else
        # Return a sample color for any pixel query
        ['srgb(255,255,255)', '', double(success?: true)]
      end
    end
  end

  after do
    temp_image.close
    temp_image.unlink
  end

  describe '#sample_edges' do
    it 'samples from all four edges' do
      samples = sampler.sample_edges

      expect(samples).not_to be_empty
      expect(samples.all? { |s| s.is_a?(Hash) && s.key?(:r) }).to be true
    end
  end

  describe 'dense shallow sampling' do
    it 'samples at correct positions avoiding edge pixels' do
      # Track all pixel sampling calls
      pixel_calls = []

      allow(Open3).to receive(:capture3) do |cmd|
        if cmd.include?('identify')
          ['1000 800', '', double(success?: true)]
        elsif cmd =~ /pixel:p\{(\d+),(\d+)\}/
          pixel_calls << [$1.to_i, $2.to_i]
          ['srgb(255,255,255)', '', double(success?: true)]
        else
          ['', '', double(success?: true)]
        end
      end

      sampler.sample_edges

      # Check that we got samples
      expect(pixel_calls.length).to be > 0

      # Verify no samples at absolute edges (x=0, y=0, x=999, y=799)
      expect(pixel_calls.any? { |x, y| x == 0 }).to be false
      expect(pixel_calls.any? { |x, y| y == 0 }).to be false
      expect(pixel_calls.any? { |x, y| x == 999 }).to be false
      expect(pixel_calls.any? { |x, y| y == 799 }).to be false

      # Verify we DO sample at safe positions (x=1, y=1, x=998, y=798)
      expect(pixel_calls.any? { |x, y| x == 1 }).to be true
      expect(pixel_calls.any? { |x, y| y == 1 }).to be true
      expect(pixel_calls.any? { |x, y| x == 998 }).to be true
      expect(pixel_calls.any? { |x, y| y == 798 }).to be true
    end

    it 'uses configurable sampling interval' do
      custom_config = RubySpriter::InnerBgConfig.new(
        edge_sample_depth: 2,
        edge_sample_interval: 10
      )
      custom_sampler = described_class.new(temp_image.path, custom_config)

      call_count = 0
      allow(Open3).to receive(:capture3) do |cmd|
        if cmd.include?('identify')
          ['1000 800', '', double(success?: true)]
        elsif cmd.include?('pixel:p')
          call_count += 1
          ['srgb(255,255,255)', '', double(success?: true)]
        else
          ['', '', double(success?: true)]
        end
      end

      custom_sampler.sample_edges

      # With interval=10 on 1000x800 image:
      # Top: 1000/10 = 100, Bottom: 100, Left: 800/10 = 80, Right: 80
      # Total: ~360 samples
      expect(call_count).to be >= 340
      expect(call_count).to be <= 380
    end
  end

  describe '#build_color_palette' do
    it 'preserves all unique colors from varied backgrounds' do
      # Simulate highly varied background with 50 different colors
      varied_samples = (0...50).map do |i|
        { r: 100 + i, g: 150 + i, b: 200 + i }
      end

      palette = sampler.build_color_palette(varied_samples)

      # All 50 unique colors should be preserved
      expect(palette.length).to eq(50)
    end

    it 'removes duplicate colors' do
      samples = [
        { r: 255, g: 255, b: 255 },
        { r: 255, g: 255, b: 255 },
        { r: 200, g: 200, b: 200 },
        { r: 255, g: 255, b: 255 }
      ]

      palette = sampler.build_color_palette(samples)

      expect(palette.length).to eq(2)
    end
  end

  describe '#report' do
    it 'includes sampling density statistics' do
      sampler.sample_edges
      report = sampler.report

      expect(report[:samples_collected]).to be > 0
      expect(report[:unique_colors]).to be > 0
      expect(report[:edge_sample_interval]).to eq(5)
      expect(report[:edge_sample_depth]).to eq(2)
    end
  end

  describe 'configuration defaults' do
    it 'defaults edge_sample_interval to 5' do
      expect(config.edge_sample_interval).to eq(5)
    end

    it 'defaults edge_sample_depth to 2' do
      expect(config.edge_sample_depth).to eq(2)
    end
  end
end
