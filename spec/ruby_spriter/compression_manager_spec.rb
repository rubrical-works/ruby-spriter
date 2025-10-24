# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubySpriter::CompressionManager do
  let(:input_file) { 'E:/test/input.png' }
  let(:output_file) { 'E:/test/output.png' }
  let(:temp_file) { 'E:/test/temp.png' }

  before do
    allow(File).to receive(:exist?).and_return(true)
    allow(File).to receive(:readable?).and_return(true)
    allow(File).to receive(:size).with(input_file).and_return(100000)
    allow(File).to receive(:size).with(output_file).and_return(80000)
    allow(RubySpriter::Utils::FileHelper).to receive(:validate_readable!)
    allow(RubySpriter::Utils::FileHelper).to receive(:validate_exists!)
  end

  describe '.compress' do
    it 'compresses PNG file using ImageMagick' do
      expect(Open3).to receive(:capture3) do |cmd|
        expect(cmd).to include('magick')
        expect(cmd).to include(input_file)
        expect(cmd).to include(output_file)
        expect(cmd).to include('-strip')
        expect(cmd).to include('-define png:compression-level=9')
        expect(cmd).to include('-define png:compression-filter=5')
        expect(cmd).to include('-define png:compression-strategy=1')
        ['', '', double(success?: true)]
      end

      described_class.compress(input_file, output_file)
    end

    it 'raises error if compression fails' do
      allow(Open3).to receive(:capture3).and_return(['', 'error', double(success?: false)])

      expect {
        described_class.compress(input_file, output_file)
      }.to raise_error(RubySpriter::ProcessingError, /Failed to compress/)
    end

    it 'validates input file exists and is readable' do
      expect(RubySpriter::Utils::FileHelper).to receive(:validate_readable!).with(input_file)

      allow(Open3).to receive(:capture3).and_return(['', '', double(success?: true)])

      described_class.compress(input_file, output_file)
    end

    it 'validates output file was created' do
      allow(Open3).to receive(:capture3).and_return(['', '', double(success?: true)])
      expect(RubySpriter::Utils::FileHelper).to receive(:validate_exists!).with(output_file)

      described_class.compress(input_file, output_file)
    end
  end

  describe '.compress_with_metadata' do
    let(:metadata) { { columns: 4, rows: 4, frames: 16 } }

    before do
      allow(RubySpriter::MetadataManager).to receive(:read).and_return(metadata)
      allow(RubySpriter::MetadataManager).to receive(:embed)
      allow(FileUtils).to receive(:mv)
      allow(File).to receive(:exist?).with(temp_file).and_return(true)
      allow(FileUtils).to receive(:rm_f)
    end

    it 'reads metadata before compression' do
      expect(RubySpriter::MetadataManager).to receive(:read).with(input_file)

      allow(Open3).to receive(:capture3).and_return(['', '', double(success?: true)])

      described_class.compress_with_metadata(input_file, output_file)
    end

    it 'compresses file with metadata preservation' do
      allow(Open3).to receive(:capture3).and_return(['', '', double(success?: true)])

      expect(described_class).to receive(:compress).with(input_file, anything, debug: false)
      expect(RubySpriter::MetadataManager).to receive(:embed)

      described_class.compress_with_metadata(input_file, output_file)
    end

    it 're-embeds metadata after compression' do
      allow(Open3).to receive(:capture3).and_return(['', '', double(success?: true)])

      expect(RubySpriter::MetadataManager).to receive(:embed) do |temp, output, **opts|
        expect(opts[:columns]).to eq(4)
        expect(opts[:rows]).to eq(4)
        expect(opts[:frames]).to eq(16)
      end

      described_class.compress_with_metadata(input_file, output_file)
    end

    it 'handles files without metadata' do
      allow(RubySpriter::MetadataManager).to receive(:read).and_return(nil)
      allow(Open3).to receive(:capture3).and_return(['', '', double(success?: true)])

      # Should just compress without re-embedding metadata
      expect(RubySpriter::MetadataManager).not_to receive(:embed)

      described_class.compress_with_metadata(input_file, output_file)
    end

    it 'cleans up temp file after successful compression' do
      allow(Open3).to receive(:capture3).and_return(['', '', double(success?: true)])
      allow(RubySpriter::MetadataManager).to receive(:read).and_return(metadata)
      allow(RubySpriter::MetadataManager).to receive(:embed)

      # Simulate temp file creation
      temp_path = nil
      allow(described_class).to receive(:compress) do |input, output|
        temp_path = output
      end

      expect(FileUtils).to receive(:rm_f).with(anything)

      described_class.compress_with_metadata(input_file, output_file)
    end
  end

  describe '.compression_stats' do
    it 'returns compression statistics' do
      original_size = 100000
      compressed_size = 80000

      allow(File).to receive(:size).with(input_file).and_return(original_size)
      allow(File).to receive(:size).with(output_file).and_return(compressed_size)

      stats = described_class.compression_stats(input_file, output_file)

      expect(stats[:original_size]).to eq(original_size)
      expect(stats[:compressed_size]).to eq(compressed_size)
      expect(stats[:saved_bytes]).to eq(20000)
      expect(stats[:reduction_percent]).to be_within(0.1).of(20.0)
    end

    it 'handles case where compressed file is larger' do
      original_size = 100000
      compressed_size = 120000

      allow(File).to receive(:size).with(input_file).and_return(original_size)
      allow(File).to receive(:size).with(output_file).and_return(compressed_size)

      stats = described_class.compression_stats(input_file, output_file)

      expect(stats[:saved_bytes]).to eq(-20000)
      expect(stats[:reduction_percent]).to be_within(0.1).of(-20.0)
    end
  end
end
