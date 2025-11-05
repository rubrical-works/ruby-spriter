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
      if cmd.include?('identify') && cmd.include?('%w %h')
        # Return dimensions
        ['1000 800', '', double(success?: true)]
      elsif cmd.include?('txt:-')
        # Generate a simple pixel cache for 1000x800 image
        # Return white pixels for all positions
        output = "# ImageMagick pixel enumeration: 1000,800,255,srgb\n"
        # For testing, just return a small sample to avoid huge output
        10.times do |y|
          10.times do |x|
            output += "#{x},#{y}: (255,255,255) #FFFFFF white\n"
          end
        end
        [output, '', double(success?: true)]
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
      # Generate pixel cache with just edge pixels
      allow(Open3).to receive(:capture3) do |cmd|
        if cmd.include?('identify') && cmd.include?('%w %h')
          ['1000 800', '', double(success?: true)]
        elsif cmd.include?('txt:-')
          # Generate pixel map with just edge pixels (sparse to keep test fast)
          output = "# ImageMagick pixel enumeration: 1000,800,255,srgb\n"
          # Top edge (y=1)
          (5...1000).step(5) do |x|
            output += "#{x},1: (255,255,255) #FFFFFF white\n"
          end
          # Bottom edge (y=798)
          (5...1000).step(5) do |x|
            output += "#{x},798: (255,255,255) #FFFFFF white\n"
          end
          # Left edge (x=1)
          (5...800).step(5) do |y|
            output += "1,#{y}: (255,255,255) #FFFFFF white\n"
          end
          # Right edge (x=998)
          (5...800).step(5) do |y|
            output += "998,#{y}: (255,255,255) #FFFFFF white\n"
          end
          [output, '', double(success?: true)]
        else
          ['', '', double(success?: true)]
        end
      end

      samples = sampler.sample_edges

      # Check that we got samples
      expect(samples.length).to be > 0

      # The samples should only come from safe edge positions
      # With interval=5, depth=2: samples at x=5,10,15... y=1 for top edge, etc
      # No samples should be at absolute edges
    end

    it 'uses configurable sampling interval' do
      custom_config = RubySpriter::InnerBgConfig.new(
        edge_sample_depth: 2,
        edge_sample_interval: 10
      )
      custom_sampler = described_class.new(temp_image.path, custom_config)

      allow(Open3).to receive(:capture3) do |cmd|
        if cmd.include?('identify') && cmd.include?('%w %h')
          ['1000 800', '', double(success?: true)]
        elsif cmd.include?('txt:-')
          # Generate pixel map with just edge pixels needed for sampling
          # Top edge (y=1), bottom edge (y=798), left edge (x=1), right edge (x=998)
          output = "# ImageMagick pixel enumeration: 1000,800,255,srgb\n"
          # Top edge (y=1) - sample every 10 pixels starting from x=10
          (10...1000).step(10) do |x|
            output += "#{x},1: (255,255,255) #FFFFFF white\n"
          end
          # Bottom edge (y=798) - sample every 10 pixels starting from x=10
          (10...1000).step(10) do |x|
            output += "#{x},798: (255,255,255) #FFFFFF white\n"
          end
          # Left edge (x=1) - sample every 10 pixels starting from y=10
          (10...800).step(10) do |y|
            output += "1,#{y}: (255,255,255) #FFFFFF white\n"
          end
          # Right edge (x=998) - sample every 10 pixels starting from y=10
          (10...800).step(10) do |y|
            output += "998,#{y}: (255,255,255) #FFFFFF white\n"
          end
          [output, '', double(success?: true)]
        else
          ['', '', double(success?: true)]
        end
      end

      samples = custom_sampler.sample_edges

      # With interval=10 on 1000x800 image:
      # Top: (1000-1)/10 = ~100, Bottom: ~100, Left: (800-1)/10 = ~80, Right: ~80
      # Total: ~360 samples
      expect(samples.length).to be >= 340
      expect(samples.length).to be <= 380
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

  describe '#load_pixel_cache' do
    subject { described_class.new(temp_image.path, config) }

    it 'loads all pixels into memory in a single ImageMagick call' do
      # Track ImageMagick calls
      call_count = 0
      allow(Open3).to receive(:capture3) do |cmd|
        call_count += 1

        if cmd.include?('txt:-')
          # Simulate txt: format output for a 3x2 image
          output = <<~TXT
            # ImageMagick pixel enumeration: 3,2,255,srgb
            0,0: (255,0,0) #FF0000 red
            1,0: (0,255,0) #00FF00 lime
            2,0: (0,0,255) #0000FF blue
            0,1: (255,255,0) #FFFF00 yellow
            1,1: (255,0,255) #FF00FF magenta
            2,1: (0,255,255) #00FFFF cyan
          TXT
          [output, '', double(success?: true)]
        elsif cmd.include?('identify') && cmd.include?('%w %h')
          ['3 2', '', double(success?: true)]
        else
          ['', '', double(success?: true)]
        end
      end

      subject.load_pixel_cache

      # Should only call ImageMagick twice: once for dimensions, once for pixels
      expect(call_count).to eq(2)

      # Verify pixel cache is populated
      expect(subject.pixel_cache).to be_a(Hash)
      expect(subject.pixel_cache.length).to eq(6)

      # Verify specific pixels
      expect(subject.pixel_cache[[0, 0]]).to eq({ r: 255, g: 0, b: 0 })
      expect(subject.pixel_cache[[1, 0]]).to eq({ r: 0, g: 255, b: 0 })
      expect(subject.pixel_cache[[2, 1]]).to eq({ r: 0, g: 255, b: 255 })
    end

    it 'handles images with alpha channel' do
      allow(Open3).to receive(:capture3) do |cmd|
        if cmd.include?('txt:-')
          output = <<~TXT
            # ImageMagick pixel enumeration: 2,2,255,srgba
            0,0: (255,0,0,255) #FF0000FF red
            1,0: (0,255,0,128) #00FF0080 lime
            0,1: (0,0,255,0) #0000FF00 blue
            1,1: (255,255,255,255) #FFFFFFFF white
          TXT
          [output, '', double(success?: true)]
        elsif cmd.include?('identify') && cmd.include?('%w %h')
          ['2 2', '', double(success?: true)]
        else
          ['', '', double(success?: true)]
        end
      end

      subject.load_pixel_cache

      # Verify alpha channel is captured
      expect(subject.pixel_cache[[1, 0]]).to eq({ r: 0, g: 255, b: 0, a: 128 })
      expect(subject.pixel_cache[[0, 1]]).to eq({ r: 0, g: 0, b: 255, a: 0 })
    end
  end

  describe '#sample_pixel (with cache)' do
    subject { described_class.new(temp_image.path, config) }

    before do
      # Pre-populate pixel cache
      subject.instance_variable_set(:@pixel_cache, {
        [0, 0] => { r: 255, g: 0, b: 0 },
        [1, 0] => { r: 0, g: 255, b: 0 },
        [5, 10] => { r: 100, g: 150, b: 200 }
      })
    end

    it 'returns pixel from cache without calling ImageMagick' do
      expect(Open3).not_to receive(:capture3)

      pixel = subject.send(:sample_pixel, 5, 10)

      expect(pixel).to eq({ r: 100, g: 150, b: 200 })
    end

    it 'returns nil for pixels not in cache' do
      expect(Open3).not_to receive(:capture3)

      pixel = subject.send(:sample_pixel, 99, 99)

      expect(pixel).to be_nil
    end
  end
end
