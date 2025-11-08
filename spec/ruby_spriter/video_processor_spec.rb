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

      # Mock file operations for metadata embedding
      allow(FileUtils).to receive(:mv)
      allow(File).to receive(:delete)
      allow(File).to receive(:exist?).and_return(true)
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

      it 'passes temp_dir in options to assemble_spritesheet_from_frames' do
        allow(video_processor).to receive(:extract_frames).and_return(['frame_001.png'])
        allow(video_processor).to receive(:process_frames_individually)
        allow(RubySpriter::MetadataManager).to receive(:embed)

        expect(video_processor).to receive(:assemble_spritesheet_from_frames) do |frames, output, opts|
          expect(opts[:temp_dir]).to be_a(String)
          expect(opts[:temp_dir]).to eq('temp_test_dir')
        end

        video_processor.process_with_background_removal(video_path, output_path, options)
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
describe '#extract_frames' do
  let(:video_processor) { described_class.new }
  let(:video_file) { 'test_video.mp4' }
  let(:temp_dir) { 'temp_frames' }
  let(:options) { { frames: 16, max_width: 320, debug: false } }

  before do
    # Mock get_duration to return 2.0 seconds
    allow(video_processor).to receive(:get_duration).and_return(2.0)

    # Mock Open3.capture3 for FFmpeg execution
    allow(Open3).to receive(:capture3).and_return(['', '', double(success?: true)])
  end

  it 'extracts frames from video using FFmpeg' do
    expect(Open3).to receive(:capture3) do |cmd|
      expect(cmd).to include('ffmpeg')
      expect(cmd).to include('-i')
      expect(cmd).to include(video_file)
      expect(cmd).to include('fps=8.0')  # 16 frames / 2.0 seconds
      expect(cmd).to include('scale=320:-1')
      expect(cmd).to include('-frames:v 16')
      ['', '', double(success?: true)]
    end

    result = video_processor.send(:extract_frames, video_file, temp_dir, options)

    expect(result).to be_an(Array)
    expect(result.length).to eq(16)
  end

  it 'returns array of frame filenames' do
    result = video_processor.send(:extract_frames, video_file, temp_dir, options)

    expect(result).to eq([
      'frame_001.png', 'frame_002.png', 'frame_003.png', 'frame_004.png',
      'frame_005.png', 'frame_006.png', 'frame_007.png', 'frame_008.png',
      'frame_009.png', 'frame_010.png', 'frame_011.png', 'frame_012.png',
      'frame_013.png', 'frame_014.png', 'frame_015.png', 'frame_016.png'
    ])
  end

  it 'raises ProcessingError if FFmpeg fails' do
    allow(Open3).to receive(:capture3).and_return(['', 'FFmpeg error', double(success?: false)])

    expect {
      video_processor.send(:extract_frames, video_file, temp_dir, options)
    }.to raise_error(RubySpriter::ProcessingError, /Failed to extract frames/)
  end
end
describe '#assemble_spritesheet_from_frames' do
  let(:video_processor) { described_class.new }
  let(:frame_files) { ['frame_001.png', 'frame_002.png', 'frame_003.png', 'frame_004.png'] }
  let(:output_path) { 'output_spritesheet.png' }
  let(:temp_dir) { 'temp_frames' }
  let(:options) { { columns: 2, temp_dir: temp_dir, debug: false } }

  before do
    # Mock Open3.capture3 for FFmpeg execution
    allow(Open3).to receive(:capture3).and_return(['', '', double(success?: true)])

    # Mock file validation
    allow(RubySpriter::Utils::FileHelper).to receive(:validate_exists!)
  end

  it 'assembles frames into spritesheet using FFmpeg tile filter' do
    expect(Open3).to receive(:capture3) do |cmd|
      expect(cmd).to include('ffmpeg')
      expect(cmd).to include('-i')
      expect(cmd).to include('frame_%03d.png')
      expect(cmd).to include('tile=2x2')  # 4 frames / 2 columns = 2 rows
      expect(cmd).to include('-frames:v 1')
      expect(cmd).to include(output_path)
      ['', '', double(success?: true)]
    end

    video_processor.send(:assemble_spritesheet_from_frames, frame_files, output_path, options)
  end

  it 'calculates rows correctly from frame count and columns' do
    # 4 frames / 2 columns = 2 rows
    expect(Open3).to receive(:capture3) do |cmd|
      expect(cmd).to include('tile=2x2')
      ['', '', double(success?: true)]
    end

    video_processor.send(:assemble_spritesheet_from_frames, frame_files, output_path, options)
  end

  it 'handles non-evenly divisible frame counts with ceiling' do
    # 5 frames / 2 columns = 2.5 → 3 rows (ceiling)
    frame_files_odd = ['frame_001.png', 'frame_002.png', 'frame_003.png', 'frame_004.png', 'frame_005.png']

    expect(Open3).to receive(:capture3) do |cmd|
      expect(cmd).to include('tile=2x3')
      ['', '', double(success?: true)]
    end

    video_processor.send(:assemble_spritesheet_from_frames, frame_files_odd, output_path, options)
  end

  it 'raises ProcessingError if FFmpeg fails' do
    allow(Open3).to receive(:capture3).and_return(['', 'FFmpeg error', double(success?: false)])

    expect {
      video_processor.send(:assemble_spritesheet_from_frames, frame_files, output_path, options)
    }.to raise_error(RubySpriter::ProcessingError, /Failed to assemble spritesheet/)
  end

it 'validates output file exists after assembly' do
  expect(RubySpriter::Utils::FileHelper).to receive(:validate_exists!).with(output_path)

  video_processor.send(:assemble_spritesheet_from_frames, frame_files, output_path, options)
end

it 'handles frame files with _nobg suffix' do
  frame_files_nobg = ['frame_001_nobg.png', 'frame_002_nobg.png', 'frame_003_nobg.png', 'frame_004_nobg.png']

  expect(Open3).to receive(:capture3) do |cmd|
    expect(cmd).to include('frame_%03d_nobg.png')
    expect(cmd).to include('tile=2x2')
    ['', '', double(success?: true)]
  end

  video_processor.send(:assemble_spritesheet_from_frames, frame_files_nobg, output_path, options)
end
end

end