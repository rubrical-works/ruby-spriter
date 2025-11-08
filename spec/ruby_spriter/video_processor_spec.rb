# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubySpriter::VideoProcessor do
  describe '#create_spritesheet' do
    let(:video_file) { 'test_video.mp4' }
    let(:output_file) { 'spritesheet.png' }
    let(:processor) { described_class.new(frame_count: 16, columns: 4) }

    before do
      allow(RubySpriter::Utils::FileHelper).to receive(:validate_readable!)
      allow(File).to receive(:size).and_return(1000)
      allow(File).to receive(:exist?).and_return(true)
      allow(File).to receive(:delete)
      allow(RubySpriter::MetadataManager).to receive(:embed)
      allow(Open3).to receive(:capture3).and_return(['2.0', '', instance_double(Process::Status, success?: true)])
    end

    it 'creates spritesheet from video file' do
      result = processor.create_spritesheet(video_file, output_file)

      expect(result[:output_file]).to eq(output_file)
      expect(result[:columns]).to eq(4)
      expect(result[:rows]).to eq(4)
      expect(result[:frames]).to eq(16)
    end
  end

  describe '#process_with_background_removal' do
    let(:video_processor) { described_class.new }
    let(:temp_dir) { 'temp_test_dir' }
    let(:video_path) { 'test_video.mp4' }
    let(:output_path) { 'output_spritesheet.png' }

    before do
      allow(Dir).to receive(:mktmpdir).and_return(temp_dir)
      allow(FileUtils).to receive(:rm_rf)
    end

    context 'when by_frame option is true' do
      let(:options) do
        {
          by_frame: true,
          remove_bg: true,
          frames: 4,
          columns: 2,
          gimp_path: '/usr/bin/gimp'
        }
      end

      it 'processes each frame individually with background removal' do
        # Mock frame extraction
        frame_files = ['frame_001.png', 'frame_002.png', 'frame_003.png', 'frame_004.png']
        allow(video_processor).to receive(:extract_frames).and_return(frame_files)

        # Mock background removal for each frame
        gimp_processor = instance_double(RubySpriter::GimpProcessor)
        allow(RubySpriter::GimpProcessor).to receive(:new).and_return(gimp_processor)

        # Expect .process() to be called for EACH frame (4 times)
        # process() returns the output path (same as input for simplicity)
        allow(gimp_processor).to receive(:process) do |input_path|
          # Return the _nobg version of the input path
          input_path.sub('.png', '_nobg.png')
        end
        expect(gimp_processor).to receive(:process).exactly(4).times

        # Mock spritesheet assembly
        allow(video_processor).to receive(:assemble_spritesheet_from_frames)

        # Mock metadata
        allow(RubySpriter::MetadataManager).to receive(:embed)

        video_processor.process_with_background_removal(video_path, output_path, options)
      end

      it 'displays progress indicator for each frame' do
        frame_files = ['frame_001.png', 'frame_002.png', 'frame_003.png', 'frame_004.png']
        allow(video_processor).to receive(:extract_frames).and_return(frame_files)

        gimp_processor = instance_double(RubySpriter::GimpProcessor)
        allow(RubySpriter::GimpProcessor).to receive(:new).and_return(gimp_processor)

        # Mock .process() to return output path
        allow(gimp_processor).to receive(:process) do |input_path|
          input_path.sub('.png', '_nobg.png')
        end

        allow(video_processor).to receive(:assemble_spritesheet_from_frames)
        allow(RubySpriter::MetadataManager).to receive(:embed)

        # Verify progress messages are displayed (use regex that matches any frame number)
        expect { video_processor.process_with_background_removal(video_path, output_path, options) }
          .to output(/Processing frame \d+\/4.*Processing frame \d+\/4.*Processing frame \d+\/4.*Processing frame \d+\/4/m).to_stdout
      end
    end

    context 'when by_frame option is false' do
      let(:options) do
        {
          by_frame: false,
          remove_bg: true,
          frames: 4,
          columns: 2,
          gimp_path: '/usr/bin/gimp'
        }
      end

      it 'processes the entire spritesheet at once (existing behavior)' do
        # Mock frame extraction
        frame_files = ['frame_001.png', 'frame_002.png', 'frame_003.png', 'frame_004.png']
        allow(video_processor).to receive(:extract_frames).and_return(frame_files)

        # Mock spritesheet assembly
        allow(video_processor).to receive(:assemble_spritesheet_from_frames)

        # Mock background removal for spritesheet (called ONCE, not per frame)
        gimp_processor = instance_double(RubySpriter::GimpProcessor)
        allow(RubySpriter::GimpProcessor).to receive(:new).and_return(gimp_processor)

        # Mock .process() to return the same path (no change)
        allow(gimp_processor).to receive(:process).with(output_path).and_return(output_path)
        expect(gimp_processor).to receive(:process).once

        # Mock metadata
        allow(RubySpriter::MetadataManager).to receive(:embed)

        video_processor.process_with_background_removal(video_path, output_path, options)
      end
    end
  end
end
