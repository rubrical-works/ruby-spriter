require 'spec_helper'
require 'ruby_spriter/background_sampler'

RSpec.describe RubySpriter::BackgroundSampler do
  let(:image_path) { 'spec/fixtures/walk_north_sprite-sheet.png' }
  let(:sample_offset) { 5 }
  let(:sample_count) { 10 }
  let(:max_rows) { 20 }

  subject { described_class.new(image_path, sample_offset, sample_count, max_rows) }

  describe '#initialize' do
    it 'sets the image path' do
      expect(subject.image_path).to eq(image_path)
    end

    it 'sets the sample offset' do
      expect(subject.sample_offset).to eq(5)
    end

    it 'sets the sample count' do
      expect(subject.sample_count).to eq(10)
    end

    it 'sets the max rows' do
      expect(subject.max_rows).to eq(20)
    end
  end

  describe '#collect_unique_colors' do
    it 'returns an array of unique RGB color hashes' do
      colors = subject.collect_unique_colors

      expect(colors).to be_an(Array)
      # May return fewer than sample_count if image has limited unique colors
      expect(colors.length).to be > 0

      colors.each do |color|
        expect(color).to have_key(:r)
        expect(color).to have_key(:g)
        expect(color).to have_key(:b)
        expect(color[:r]).to be_between(0, 255)
        expect(color[:g]).to be_between(0, 255)
        expect(color[:b]).to be_between(0, 255)
      end
    end

    it 'collects up to the specified number of unique colors' do
      colors = subject.collect_unique_colors

      expect(colors.length).to be <= sample_count
    end

    it 'returns only unique colors (no duplicates)' do
      colors = subject.collect_unique_colors

      # Convert to strings for comparison
      color_strings = colors.map { |c| "#{c[:r]},#{c[:g]},#{c[:b]}" }
      expect(color_strings.uniq.length).to eq(colors.length)
    end

    it 'samples starting at offset pixels from edge' do
      # Mock ImageMagick calls to verify coordinates
      allow(Open3).to receive(:capture3) do |cmd|
        # Extract x,y from command like: magick <path> -format "%[pixel:p{5,5}]" info:
        if cmd =~ /pixel:p\{(\d+),(\d+)\}/
          x = $1.to_i
          y = $2.to_i

          # Verify x and y are at least offset pixels from edge
          expect(x).to be >= sample_offset
          expect(y).to be >= sample_offset

          # Return mock color
          ["srgb(255,255,255)", "", double(success?: true)]
        else
          ["100 100", "", double(success?: true)]  # Dimensions
        end
      end

      subject.collect_unique_colors
    end

    it 'moves to next row if not enough unique colors found in first row' do
      # Create a sampler that needs more colors than available in one row
      sampler = described_class.new(image_path, 5, 10, 20)

      colors = sampler.collect_unique_colors

      # Should have collected some colors (exact count depends on image)
      expect(colors).to be_an(Array)
      expect(colors.length).to be > 0

      # All colors should be unique
      color_strings = colors.map { |c| "#{c[:r]},#{c[:g]},#{c[:b]}" }
      expect(color_strings.uniq.length).to eq(colors.length)
    end
  end

  describe '#sample_pixel' do
    it 'uses ImageMagick to get pixel color at specific coordinates' do
      # Matches both 'magick' (Windows) and 'convert' (Unix)
      expect(Open3).to receive(:capture3).with(/(magick|convert).*pixel:p\{10,10\}/).and_return(
        ["srgb(128,64,32)", "", double(success?: true)]
      )

      color = subject.send(:sample_pixel, 10, 10)

      expect(color).to eq({ r: 128, g: 64, b: 32 })
    end

    it 'returns nil if ImageMagick command fails' do
      allow(Open3).to receive(:capture3).and_return(
        ["", "error", double(success?: false)]
      )

      color = subject.send(:sample_pixel, 10, 10)

      expect(color).to be_nil
    end

    it 'handles grayscale images' do
      allow(Open3).to receive(:capture3).and_return(
        ["gray(128)", "", double(success?: true)]
      )

      color = subject.send(:sample_pixel, 10, 10)

      expect(color).to eq({ r: 128, g: 128, b: 128 })
    end
  end
end
