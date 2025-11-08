# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubySpriter::BatchProcessor do
  let(:test_dir) { 'E:/test/videos' }
  let(:output_dir) { 'E:/test/output' }
  let(:video1) { File.join(test_dir, 'video1.mp4') }
  let(:video2) { File.join(test_dir, 'video2.mp4') }
  let(:video3) { File.join(test_dir, 'video3.mp4') }

  let(:options) do
    {
      batch: true,
      dir: test_dir,
      columns: 4,
      frame_count: 16,
      max_width: 320,
      overwrite: false,
      debug: false
    }
  end

  before do
    # Mock file system
    allow(Dir).to receive(:exist?).and_return(true)
    allow(File).to receive(:exist?).and_return(true)
    allow(File).to receive(:directory?).with(test_dir).and_return(true)
    allow(Dir).to receive(:glob).with(File.join(test_dir, '*.mp4')).and_return([video1, video2, video3])
  end

  describe '#initialize' do
    it 'raises error if directory does not exist' do
      allow(File).to receive(:directory?).with(test_dir).and_return(false)

      expect {
        described_class.new(options)
      }.to raise_error(RubySpriter::ValidationError, /Directory not found/)
    end

    it 'initializes with valid options' do
      processor = described_class.new(options)
      expect(processor.options).to eq(options)
    end
  end

  describe '#find_videos' do
    it 'finds all MP4 files in directory' do
      processor = described_class.new(options)
      videos = processor.find_videos

      expect(videos).to eq([video1, video2, video3])
    end

    it 'raises error if no videos found' do
      allow(Dir).to receive(:glob).with(File.join(test_dir, '*.mp4')).and_return([])

      processor = described_class.new(options)

      expect {
        processor.find_videos
      }.to raise_error(RubySpriter::ValidationError, /No MP4 files found/)
    end
  end

  describe '#process' do
    let(:video_processor_mock) { instance_double(RubySpriter::VideoProcessor) }

    before do
      allow(RubySpriter::VideoProcessor).to receive(:new).and_return(video_processor_mock)
      allow(video_processor_mock).to receive(:create_spritesheet).and_return(
        { output_file: 'output.png', columns: 4, rows: 4, frames: 16 }
      )
      allow(File).to receive(:exist?).and_return(false) # No existing files
      allow(RubySpriter::Utils::FileHelper).to receive(:spritesheet_filename) do |video|
        video.gsub('.mp4', '_spritesheet.png')
      end
    end

    it 'processes all videos in directory' do
      processor = described_class.new(options)

      expect(video_processor_mock).to receive(:create_spritesheet).exactly(3).times

      results = processor.process

      expect(results[:processed_count]).to eq(3)
      expect(results[:outputs].length).to eq(3)
    end

    it 'outputs to same directory by default' do
      processor = described_class.new(options)

      expected_output1 = File.join(test_dir, 'video1_spritesheet.png')
      expect(video_processor_mock).to receive(:create_spritesheet).with(video1, expected_output1)

      processor.process
    end

    it 'outputs to specified outputdir when provided' do
      options_with_output = options.merge(outputdir: output_dir)
      processor = described_class.new(options_with_output)

      allow(File).to receive(:directory?).with(output_dir).and_return(true)

      expected_output1 = File.join(output_dir, 'video1_spritesheet.png')
      expect(video_processor_mock).to receive(:create_spritesheet).with(video1, expected_output1)

      processor.process
    end

    it 'creates output directory if it does not exist' do
      options_with_output = options.merge(outputdir: output_dir)
      processor = described_class.new(options_with_output)

      allow(File).to receive(:directory?).with(output_dir).and_return(false)
      expect(FileUtils).to receive(:mkdir_p).with(output_dir)

      processor.process
    end

    it 'enforces unique filenames unless overwrite is true' do
      allow(File).to receive(:exist?).with(/video1_spritesheet\.png/).and_return(true)
      allow(RubySpriter::Utils::FileHelper).to receive(:ensure_unique_output).and_call_original
      allow(RubySpriter::Utils::FileHelper).to receive(:unique_filename).and_return('video1_spritesheet_20251024_123456_789.png')

      processor = described_class.new(options)

      expect(RubySpriter::Utils::FileHelper).to receive(:ensure_unique_output).at_least(:once)

      processor.process
    end

    it 'continues processing after error in one video' do
      processor = described_class.new(options)

      allow(video_processor_mock).to receive(:create_spritesheet).and_raise(RubySpriter::ProcessingError, 'Test error')

      results = processor.process

      expect(results[:processed_count]).to eq(0)
      expect(results[:errors].length).to eq(3)
    end
  end

  describe 'batch processing with --by-frame flag' do
    let(:options) do
      {
        batch: true,
        dir: test_dir,
        remove_bg: true,
        by_frame: true,
        frame_count: 4,
        columns: 2
      }
    end

    let(:batch_processor) { described_class.new(options) }

    before do
      # Mock directory with video files
      allow(Dir).to receive(:glob).with(File.join(test_dir, '*.mp4')).and_return(['test_videos/video1.mp4', 'test_videos/video2.mp4'])
      allow(File).to receive(:directory?).and_return(true)

      # Mock file validation
      allow(RubySpriter::Utils::FileHelper).to receive(:validate_readable!)

      # Mock DependencyChecker for GIMP path
      dependency_checker = instance_double(RubySpriter::DependencyChecker)
      allow(RubySpriter::DependencyChecker).to receive(:new).and_return(dependency_checker)
      allow(dependency_checker).to receive(:check_all).and_return({
        ffmpeg: { available: true },
        ffprobe: { available: true },
        imagemagick: { available: true },
        gimp: { available: true }
      })
      allow(dependency_checker).to receive(:gimp_path).and_return('/usr/bin/gimp')
      allow(dependency_checker).to receive(:gimp_version).and_return({ major: 3, minor: 0 })
    end

    it 'passes by_frame flag to each video processor' do
      video_processor1 = instance_double(RubySpriter::VideoProcessor)
      video_processor2 = instance_double(RubySpriter::VideoProcessor)

      # VideoProcessor.new is called 4 times total (2 videos × 2 calls each):
      # - First call per video: initial creation (no gimp_path yet)
      # - Second call per video: with gimp_path merged for by-frame processing
      call_count = 0
      expect(RubySpriter::VideoProcessor).to receive(:new).exactly(4).times do |passed_options|
        call_count += 1

        # Every call should have by_frame and remove_bg
        expect(passed_options[:by_frame]).to be true
        expect(passed_options[:remove_bg]).to be true

        # Every 2nd and 4th call should have gimp_path (after merging)
        if call_count.even?
          expect(passed_options[:gimp_path]).to eq('/usr/bin/gimp')
        end

        call_count <= 2 ? video_processor1 : video_processor2
      end

      # Mock process_with_background_removal to return proper result
      allow(video_processor1).to receive(:process_with_background_removal).and_return({
        output_file: 'output1.png',
        columns: 2,
        frames: 4,
        processing_mode: 'by-frame'
      })

      allow(video_processor2).to receive(:process_with_background_removal).and_return({
        output_file: 'output2.png',
        columns: 2,
        frames: 4,
        processing_mode: 'by-frame'
      })

      batch_processor.process
    end

    it 'reports frame-by-frame processing mode in batch summary' do
      video_processor = instance_double(RubySpriter::VideoProcessor)
      allow(RubySpriter::VideoProcessor).to receive(:new).and_return(video_processor)

      # Mock process_with_background_removal
      allow(video_processor).to receive(:process_with_background_removal).and_return({
        output_file: 'output.png',
        columns: 2,
        frames: 4,
        processing_mode: 'by-frame'
      })

      result = batch_processor.process

      expect(result[:processed_count]).to eq(2)
      expect(result[:errors].length).to eq(0)
    end
  end

  describe '#consolidate_results' do
    let(:spritesheet1) { File.join(test_dir, 'video1_spritesheet.png') }
    let(:spritesheet2) { File.join(test_dir, 'video2_spritesheet.png') }
    let(:spritesheet3) { File.join(test_dir, 'video3_spritesheet.png') }
    let(:consolidator_mock) { instance_double(RubySpriter::Consolidator) }

    before do
      allow(RubySpriter::Consolidator).to receive(:new).and_return(consolidator_mock)
      allow(consolidator_mock).to receive(:consolidate).and_return(
        { output_file: 'consolidated.png', columns: 4, rows: 12, frames: 48 }
      )
    end

    it 'consolidates all spritesheets when batch_consolidate is true' do
      options_with_consolidate = options.merge(batch_consolidate: true)
      processor = described_class.new(options_with_consolidate)

      outputs = [spritesheet1, spritesheet2, spritesheet3]

      expect(consolidator_mock).to receive(:consolidate) do |files, output|
        expect(files).to eq(outputs)
        expect(output).to include('batch_consolidated_spritesheet')
        expect(output).to end_with('.png')
      end

      processor.consolidate_results(outputs)
    end

    it 'uses outputdir for consolidated file if specified' do
      options_with_consolidate = options.merge(batch_consolidate: true, outputdir: output_dir)
      processor = described_class.new(options_with_consolidate)

      allow(File).to receive(:directory?).with(output_dir).and_return(true)

      outputs = [spritesheet1, spritesheet2, spritesheet3]

      expect(consolidator_mock).to receive(:consolidate) do |files, output|
        expect(output).to start_with(output_dir)
      end

      processor.consolidate_results(outputs)
    end

    it 'does not consolidate when batch_consolidate is false' do
      processor = described_class.new(options)

      outputs = [spritesheet1, spritesheet2, spritesheet3]

      expect(consolidator_mock).not_to receive(:consolidate)

      result = processor.consolidate_results(outputs)
      expect(result).to be_nil
    end
  end
end
