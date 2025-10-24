# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubySpriter::Utils::SpritesheetSplitter do
  describe '#split_into_frames' do
    let(:spritesheet_file) { 'spritesheet.png' }
    let(:output_dir) { '/tmp/frames' }
    let(:columns) { 4 }
    let(:rows) { 4 }
    let(:frames) { 16 }
    let(:tile_width) { 100 }
    let(:tile_height) { 100 }

    let(:splitter) { described_class.new }

    before do
      allow(FileUtils).to receive(:mkdir_p)
      allow(File).to receive(:exist?).and_return(true)
      allow(Open3).to receive(:capture3).and_return(['', '', instance_double(Process::Status, success?: true)])

      # Mock ImageMagick identify to return dimensions
      allow(Open3).to receive(:capture3).with(/identify/).and_return(
        ["400x400\n", '', instance_double(Process::Status, success?: true)]
      )
    end

    it 'creates output directory for frames' do
      expect(FileUtils).to receive(:mkdir_p).with(output_dir)

      splitter.split_into_frames(spritesheet_file, output_dir, columns, rows, frames)
    end

    it 'extracts each frame with FR prefix and zero-padded numbers' do
      # Expect ImageMagick convert commands for each frame
      expect(Open3).to receive(:capture3).with(/identify/).once.and_return(
        ["400x400\n", '', instance_double(Process::Status, success?: true)]
      )

      (1..frames).each do |i|
        expect(Open3).to receive(:capture3).with(/convert.*FR#{format('%03d', i)}_/).and_return(
          ['', '', instance_double(Process::Status, success?: true)]
        )
      end

      splitter.split_into_frames(spritesheet_file, output_dir, columns, rows, frames)
    end

    it 'calculates tile dimensions from spritesheet size and grid' do
      # For 400x400 image with 4x4 grid, tiles should be 100x100
      expect(Open3).to receive(:capture3).with(/identify/).and_return(
        ["400x400\n", '', instance_double(Process::Status, success?: true)]
      )

      # Check that crop parameters use 100x100
      expect(Open3).to receive(:capture3).with(/100x100\+0\+0/).and_return(
        ['', '', instance_double(Process::Status, success?: true)]
      )

      allow(Open3).to receive(:capture3).and_return(['', '', instance_double(Process::Status, success?: true)])

      splitter.split_into_frames(spritesheet_file, output_dir, columns, rows, 1)
    end

    it 'includes spritesheet basename in frame output names' do
      basename = File.basename(spritesheet_file, '.*')

      # Mock identify first
      allow(Open3).to receive(:capture3).with(/identify/).and_return(
        ["400x400\n", '', instance_double(Process::Status, success?: true)]
      )

      # Expect convert with frame filename
      expect(Open3).to receive(:capture3).with(/FR001_#{basename}\.png/).and_return(
        ['', '', instance_double(Process::Status, success?: true)]
      )

      splitter.split_into_frames(spritesheet_file, output_dir, columns, rows, 1)
    end

    it 'raises ProcessingError when ImageMagick fails' do
      allow(Open3).to receive(:capture3).with(/identify/).and_return(
        ["400x400\n", '', instance_double(Process::Status, success?: true)]
      )

      allow(Open3).to receive(:capture3).with(/convert/).and_return(
        ['', 'Error message', instance_double(Process::Status, success?: false)]
      )

      expect {
        splitter.split_into_frames(spritesheet_file, output_dir, columns, rows, 1)
      }.to raise_error(RubySpriter::ProcessingError, /Could not extract frame/)
    end

    it 'displays progress information' do
      expect(RubySpriter::Utils::OutputFormatter).to receive(:header).with(/Extracting Frames/)
      expect(RubySpriter::Utils::OutputFormatter).to receive(:indent).with(/Splitting spritesheet into #{frames} frames/)
      expect(RubySpriter::Utils::OutputFormatter).to receive(:indent).with(/Output directory:/)
      expect(RubySpriter::Utils::OutputFormatter).to receive(:indent).with(/Frames extracted successfully/)

      splitter.split_into_frames(spritesheet_file, output_dir, columns, rows, frames)
    end
  end
end
