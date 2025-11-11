require 'spec_helper'
require_relative '../../lib/ruby_spriter/cell_cleanup_processor'
require_relative '../../lib/ruby_spriter/cell_cleanup_gimp_script'
require_relative '../../lib/ruby_spriter/utils/image_helper'

RSpec.describe RubySpriter::CellCleanupProcessor do
  describe '#calculate_cell_dimensions' do
    it 'calculates cell width and height from spritesheet dimensions' do
      # Mock the image helper to return dimensions
      allow(RubySpriter::Utils::ImageHelper).to receive(:get_dimensions)
        .and_return({ width: 1280, height: 960 })

      processor = described_class.new
      options = { columns: 8, frames: 32 }

      dimensions = processor.send(:calculate_cell_dimensions, '/spritesheet.png', options)

      expect(dimensions[:width]).to eq(160)   # 1280 / 8 columns
      expect(dimensions[:height]).to eq(240)  # 960 / 4 rows (32 frames / 8 columns)
    end
  end

  describe '#parse_histogram' do
    it 'parses ImageMagick histogram output into color hash' do
      processor = described_class.new

      histogram_output = <<~HISTOGRAM
        1234: (255,0,0) #FF0000 srgb(255,0,0)
        5678: (0,255,0) #00FF00 srgb(0,255,0)
        910: (0,0,255) #0000FF srgb(0,0,255)
      HISTOGRAM

      colors = processor.send(:parse_histogram, histogram_output)

      expect(colors['rgb(255,0,0)']).to eq(1234)
      expect(colors['rgb(0,255,0)']).to eq(5678)
      expect(colors['rgb(0,0,255)']).to eq(910)
      expect(colors.size).to eq(3)
    end

    it 'skips transparent pixels in histogram' do
      processor = described_class.new

      histogram_output = <<~HISTOGRAM
        1234: (255,0,0) #FF0000 srgb(255,0,0)
        5678: (0,0,0,0) #00000000 srgba(0,0,0,0)
      HISTOGRAM

      colors = processor.send(:parse_histogram, histogram_output)

      expect(colors['rgb(255,0,0)']).to eq(1234)
      expect(colors.size).to eq(1)  # Transparent pixel skipped
    end
  end

  describe '#analyze_cell_colors' do
    let(:processor) { described_class.new(cell_cleanup_threshold: 15.0) }

    it 'detects single dominant color above threshold' do
      # Mock execute_command to return histogram with 85% red, 10% other (below 15% threshold)
      allow(processor).to receive(:execute_command).and_return(<<~HISTOGRAM)
        8500: (255,0,0) #FF0000 srgb(255,0,0)
        1000: (128,128,128) #808080 srgb(128,128,128)
      HISTOGRAM

      dominant_colors = processor.send(:analyze_cell_colors, '/cell.png')

      expect(dominant_colors).to eq(['rgb(255,0,0)'])
    end

    it 'detects multiple dominant colors' do
      # Mock execute_command to return histogram with 45% red, 40% blue, 5% gray (gray below threshold)
      # Total = 10000: Red=4500 (45%), Blue=4000 (40%), Gray=500 (5%)
      allow(processor).to receive(:execute_command).and_return(<<~HISTOGRAM)
        4500: (255,0,0) #FF0000 srgb(255,0,0)
        4000: (0,0,255) #0000FF srgb(0,0,255)
        500: (128,128,128) #808080 srgb(128,128,128)
      HISTOGRAM

      dominant_colors = processor.send(:analyze_cell_colors, '/cell.png')

      expect(dominant_colors).to include('rgb(255,0,0)')
      expect(dominant_colors).to include('rgb(0,0,255)')
      expect(dominant_colors).not_to include('rgb(128,128,128)')  # Below 15% threshold
      expect(dominant_colors.size).to eq(2)
    end

    it 'returns nil when no dominant colors found' do
      # Mock execute_command with 7 equal colors, all below 15% threshold
      # Total = 7000: Each color = 1000/7000 = 14.3% < 15%
      allow(processor).to receive(:execute_command).and_return(<<~HISTOGRAM)
        1000: (255,0,0) #FF0000 srgb(255,0,0)
        1000: (0,255,0) #00FF00 srgb(0,255,0)
        1000: (0,0,255) #0000FF srgb(0,0,255)
        1000: (128,128,128) #808080 srgb(128,128,128)
        1000: (255,255,0) #FFFF00 srgb(255,255,0)
        1000: (255,0,255) #FF00FF srgb(255,0,255)
        1000: (0,255,255) #00FFFF srgb(0,255,255)
      HISTOGRAM

      dominant_colors = processor.send(:analyze_cell_colors, '/cell.png')

      expect(dominant_colors).to be_nil
    end
  end

  describe '#extract_cell' do
    let(:processor) { described_class.new }
    let(:temp_dir) { '/temp/cleanup' }

    it 'extracts cell using ImageMagick crop' do
      # Mock Open3.capture3 to simulate ImageMagick execution
      expect(Open3).to receive(:capture3) do |cmd|
        # Matches 'magick' (Windows) or 'convert' (Unix)
        expect(cmd).to match(/(magick|convert)/)
        expect(cmd).to include('-crop')
        expect(cmd).to include('160x240+320+240')  # Width x Height + X + Y
        expect(cmd).to include('+repage')
        expect(cmd).to include('/spritesheet.png')
        expect(cmd).to include('/temp/cleanup/cell_1_2.png')

        ['', '', double(success?: true)]
      end

      cell_path = processor.send(:extract_cell, '/spritesheet.png', 1, 2, 160, 240, temp_dir)

      expect(cell_path).to eq('/temp/cleanup/cell_1_2.png')
    end

    it 'raises error when ImageMagick fails' do
      allow(Open3).to receive(:capture3).and_return(['', 'Error: invalid image', double(success?: false)])

      expect {
        processor.send(:extract_cell, '/spritesheet.png', 0, 0, 160, 240, temp_dir)
      }.to raise_error(RubySpriter::ProcessingError, /Failed to extract cell/)
    end
  end

  describe '#remove_dominant_colors' do
    let(:processor) { described_class.new(gimp_path: '/path/to/gimp') }
    let(:temp_dir) { '/temp/cleanup' }
    let(:options) { { gimp_path: '/path/to/gimp' } }

    it 'generates GIMP script and executes it to remove colors' do
      cell_path = '/temp/cleanup/cell_0_0.png'
      cleaned_path = '/temp/cleanup/cell_0_0_cleaned.png'
      dominant_colors = ['rgb(255,0,0)', 'rgb(0,255,0)']

      # Expect GIMP script generation
      expect(RubySpriter::CellCleanupGimpScript).to receive(:generate_cleanup_script)
        .with(cell_path, cleaned_path, dominant_colors)
        .and_return('GIMP_SCRIPT_CONTENT')

      # Expect GIMP execution with script content and output file
      mock_gimp = double('GimpProcessor')
      expect(processor.instance_variable_get(:@gimp_processor)).to receive(:execute_python_script)
        .with('GIMP_SCRIPT_CONTENT', cleaned_path)
        .and_return(true)

      # Mock file validation
      allow(RubySpriter::Utils::FileHelper).to receive(:validate_exists!).with(cleaned_path)

      result = processor.send(:remove_dominant_colors, cell_path, dominant_colors, options, temp_dir)

      expect(result).to eq(cleaned_path)
    end

    it 'raises error if cleaned file not created' do
      cell_path = '/temp/cleanup/cell_0_0.png'
      cleaned_path = '/temp/cleanup/cell_0_0_cleaned.png'
      dominant_colors = ['rgb(255,0,0)']

      allow(RubySpriter::CellCleanupGimpScript).to receive(:generate_cleanup_script).and_return('SCRIPT')
      # Mock execute_python_script to return false (indicating GIMP script failed)
      allow(processor.instance_variable_get(:@gimp_processor)).to receive(:execute_python_script).and_return(false)

      expect {
        processor.send(:remove_dominant_colors, cell_path, dominant_colors, options, temp_dir)
      }.to raise_error(RubySpriter::ProcessingError, /GIMP script failed/)
    end
  end

  describe '#reassemble_spritesheet' do
    let(:processor) { described_class.new }

    it 'reassembles cells using ImageMagick montage' do
      cell_paths = [
        '/temp/cell_0_0.png',
        '/temp/cell_0_1.png',
        '/temp/cell_1_0.png',
        '/temp/cell_1_1.png'
      ]
      output_path = '/spritesheet.png'

      # Expect ImageMagick montage command
      expect(Open3).to receive(:capture3) do |cmd|
        # On Windows: 'magick montage', on Unix: just 'montage'
        expect(cmd).to match(/(magick\s+montage|montage)/)
        expect(cmd).to include('-tile')
        expect(cmd).to include('2x2')  # 2 columns × 2 rows
        expect(cmd).to include('-geometry')
        expect(cmd).to include('+0+0')  # No gaps
        expect(cmd).to include('-background')
        expect(cmd).to include('none')
        cell_paths.each { |path| expect(cmd).to include(path) }
        expect(cmd).to include(output_path)

        ['', '', double(success?: true)]
      end

      # Mock file validation
      allow(RubySpriter::Utils::FileHelper).to receive(:validate_exists!).with(output_path)

      processor.send(:reassemble_spritesheet, cell_paths, 2, 2, output_path)
    end

    it 'raises error when ImageMagick montage fails' do
      cell_paths = ['/temp/cell_0_0.png']

      allow(Open3).to receive(:capture3).and_return(['', 'Montage error', double(success?: false)])

      expect {
        processor.send(:reassemble_spritesheet, cell_paths, 1, 1, '/output.png')
      }.to raise_error(RubySpriter::ProcessingError, /Failed to reassemble spritesheet/)
    end
  end

  describe '#cleanup_cells (full workflow)' do
    let(:processor) { described_class.new(cell_cleanup_threshold: 15.0, gimp_path: '/path/to/gimp') }
    let(:options) { { columns: 4, frames: 16, cell_cleanup_threshold: 15.0, gimp_path: '/path/to/gimp' } }

    it 'processes all cells and returns statistics' do
      # Mock the methods we've already tested
      allow(processor).to receive(:calculate_cell_dimensions)
        .and_return({ width: 160, height: 240 })

      # Mock cell extraction (will be implemented)
      allow(processor).to receive(:extract_cell).and_return('/temp/cell.png')

      # Mock color analysis - simulate 8 cells with dominant colors, 8 without
      call_count = 0
      allow(processor).to receive(:analyze_cell_colors) do
        call_count += 1
        call_count <= 8 ? ['rgb(0,0,0)', 'rgb(15,15,17)'] : nil
      end

      # Mock GIMP removal
      allow(processor).to receive(:remove_dominant_colors).and_return('/temp/cell_cleaned.png')

      # Mock reassembly
      allow(processor).to receive(:reassemble_spritesheet)

      stats = processor.cleanup_cells('/spritesheet.png', options)

      expect(stats[:processed]).to eq(16)
      expect(stats[:cleaned]).to eq(8)
      expect(stats[:skipped]).to eq(8)
      expect(stats[:colors_removed]).to eq(16)  # 8 cells × 2 colors each
    end
  end
end
