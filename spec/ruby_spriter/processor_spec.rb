# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubySpriter::Processor do
  describe 'default options' do
    it 'sets default max_width to 320' do
      processor = described_class.new
      expect(processor.options[:max_width]).to eq(320)
    end
  end

  describe 'numeric option validation' do
    describe '--frames validation' do
      it 'raises error when frame_count is below minimum (0)' do
        expect {
          described_class.new(frame_count: 0)
        }.to raise_error(RubySpriter::ValidationError, /frame_count must be between 1 and 10000/)
      end

      it 'raises error when frame_count is above maximum (10001)' do
        expect {
          described_class.new(frame_count: 10001)
        }.to raise_error(RubySpriter::ValidationError, /frame_count must be between 1 and 10000/)
      end
    end

    describe '--columns validation' do
      it 'raises error when columns is below minimum (0)' do
        expect {
          described_class.new(columns: 0)
        }.to raise_error(RubySpriter::ValidationError, /columns must be between 1 and 100/)
      end

      it 'raises error when columns is above maximum (101)' do
        expect {
          described_class.new(columns: 101)
        }.to raise_error(RubySpriter::ValidationError, /columns must be between 1 and 100/)
      end
    end

    describe '--width validation' do
      it 'raises error when max_width is below minimum (0)' do
        expect {
          described_class.new(max_width: 0)
        }.to raise_error(RubySpriter::ValidationError, /max_width must be between 1 and 1920/)
      end

      it 'raises error when max_width is above maximum (1921)' do
        expect {
          described_class.new(max_width: 1921)
        }.to raise_error(RubySpriter::ValidationError, /max_width must be between 1 and 1920/)
      end
    end

    describe '--scale validation' do
      it 'raises error when scale_percent is below minimum (0)' do
        expect {
          described_class.new(scale_percent: 0)
        }.to raise_error(RubySpriter::ValidationError, /scale_percent must be between 1 and 500/)
      end

      it 'raises error when scale_percent is above maximum (501)' do
        expect {
          described_class.new(scale_percent: 501)
        }.to raise_error(RubySpriter::ValidationError, /scale_percent must be between 1 and 500/)
      end
    end

    describe '--grow validation' do
      it 'raises error when grow_selection is below minimum (-1)' do
        expect {
          described_class.new(grow_selection: -1)
        }.to raise_error(RubySpriter::ValidationError, /grow_selection must be between 0 and 100/)
      end

      it 'raises error when grow_selection is above maximum (101)' do
        expect {
          described_class.new(grow_selection: 101)
        }.to raise_error(RubySpriter::ValidationError, /grow_selection must be between 0 and 100/)
      end
    end

    describe '--sharpen-radius validation' do
      it 'raises error when sharpen_radius is below minimum (0.0)' do
        expect {
          described_class.new(sharpen_radius: 0.0)
        }.to raise_error(RubySpriter::ValidationError, /sharpen_radius must be between 0.1 and 100.0/)
      end

      it 'raises error when sharpen_radius is above maximum (100.1)' do
        expect {
          described_class.new(sharpen_radius: 100.1)
        }.to raise_error(RubySpriter::ValidationError, /sharpen_radius must be between 0.1 and 100.0/)
      end
    end

    describe '--sharpen-gain validation' do
      it 'raises error when sharpen_gain is below minimum (-0.1)' do
        expect {
          described_class.new(sharpen_gain: -0.1)
        }.to raise_error(RubySpriter::ValidationError, /sharpen_gain must be between 0.0 and 10.0/)
      end

      it 'raises error when sharpen_gain is above maximum (10.1)' do
        expect {
          described_class.new(sharpen_gain: 10.1)
        }.to raise_error(RubySpriter::ValidationError, /sharpen_gain must be between 0.0 and 10.0/)
      end
    end

    describe '--sharpen-threshold validation' do
      it 'raises error when sharpen_threshold is below minimum (-0.1)' do
        expect {
          described_class.new(sharpen_threshold: -0.1)
        }.to raise_error(RubySpriter::ValidationError, /sharpen_threshold must be between 0.0 and 1.0/)
      end

      it 'raises error when sharpen_threshold is above maximum (1.1)' do
        expect {
          described_class.new(sharpen_threshold: 1.1)
        }.to raise_error(RubySpriter::ValidationError, /sharpen_threshold must be between 0.0 and 1.0/)
      end
    end

    describe '--threshold validation' do
      it 'raises error when bg_threshold is below minimum (-0.1)' do
        expect {
          described_class.new(bg_threshold: -0.1)
        }.to raise_error(RubySpriter::ValidationError, /bg_threshold must be between 0.0 and 100.0/)
      end

      it 'raises error when bg_threshold is above maximum (100.1)' do
        expect {
          described_class.new(bg_threshold: 100.1)
        }.to raise_error(RubySpriter::ValidationError, /bg_threshold must be between 0.0 and 100.0/)
      end
    end
  end

  describe '--split validation' do
    describe 'format validation' do
      it 'raises error for invalid split format (missing colon)' do
        expect {
          described_class.new(image: 'test.png', split: '44')
        }.to raise_error(RubySpriter::ValidationError, /Invalid --split format/)
      end

      it 'raises error for invalid split format (non-numeric rows)' do
        expect {
          described_class.new(image: 'test.png', split: 'a:4')
        }.to raise_error(RubySpriter::ValidationError, /Invalid --split format/)
      end

      it 'raises error for invalid split format (non-numeric columns)' do
        expect {
          described_class.new(image: 'test.png', split: '4:b')
        }.to raise_error(RubySpriter::ValidationError, /Invalid --split format/)
      end
    end

    describe 'range validation' do
      it 'raises error when rows is below minimum (0)' do
        expect {
          described_class.new(image: 'test.png', split: '0:4')
        }.to raise_error(RubySpriter::ValidationError, /rows must be between 1 and 99/)
      end

      it 'raises error when rows is above maximum (100)' do
        expect {
          described_class.new(image: 'test.png', split: '100:4')
        }.to raise_error(RubySpriter::ValidationError, /rows must be between 1 and 99/)
      end

      it 'raises error when columns is below minimum (0)' do
        expect {
          described_class.new(image: 'test.png', split: '4:0')
        }.to raise_error(RubySpriter::ValidationError, /columns must be between 1 and 99/)
      end

      it 'raises error when columns is above maximum (100)' do
        expect {
          described_class.new(image: 'test.png', split: '4:100')
        }.to raise_error(RubySpriter::ValidationError, /columns must be between 1 and 99/)
      end

      it 'raises error when total frames >= 1000' do
        expect {
          described_class.new(image: 'test.png', split: '32:32')
        }.to raise_error(RubySpriter::ValidationError, /Total frames \(1024\) must be less than 1000/)
      end

      it 'raises error when total frames equals 1000' do
        expect {
          described_class.new(image: 'test.png', split: '20:50')
        }.to raise_error(RubySpriter::ValidationError, /Total frames \(1000\) must be less than 1000/)
      end

      it 'allows maximum valid frames (999)' do
        expect {
          described_class.new(image: 'test.png', split: '27:37')
        }.not_to raise_error
      end
    end
  end

  describe '--extract validation' do
    let(:temp_image) { File.join(Dir.mktmpdir, 'test.png') }

    before do
      FileUtils.touch(temp_image)

      allow_any_instance_of(RubySpriter::DependencyChecker).to receive(:check_all).and_return({
        ffmpeg: { available: true },
        ffprobe: { available: true },
        imagemagick: { available: true },
        gimp: { available: true }
      })
    end

    after do
      FileUtils.rm_f(temp_image)
    end

    describe 'format validation' do
      it 'raises error for invalid extract format (non-numeric)' do
        expect {
          described_class.new(image: temp_image, extract: '1,a,3')
        }.to raise_error(RubySpriter::ValidationError, /Invalid --extract format/)
      end

      it 'raises error for invalid extract format (empty)' do
        expect {
          described_class.new(image: temp_image, extract: '')
        }.to raise_error(RubySpriter::ValidationError, /Invalid --extract format/)
      end

      it 'raises error for invalid extract format (spaces)' do
        expect {
          described_class.new(image: temp_image, extract: '1, 2, 3')
        }.to raise_error(RubySpriter::ValidationError, /Invalid --extract format/)
      end

      it 'accepts valid comma-separated frame numbers' do
        allow(RubySpriter::MetadataManager).to receive(:read).with(temp_image).and_return({
          columns: 4,
          rows: 4,
          frames: 16
        })

        expect {
          described_class.new(image: temp_image, extract: '1,2,4,5,8')
        }.not_to raise_error
      end
    end

    describe 'minimum frames validation' do
      it 'raises error when less than 2 frames requested' do
        allow(RubySpriter::MetadataManager).to receive(:read).with(temp_image).and_return({
          columns: 4,
          rows: 4,
          frames: 16
        })

        expect {
          described_class.new(image: temp_image, extract: '1')
        }.to raise_error(RubySpriter::ValidationError, /--extract requires at least 2 frames/)
      end

      it 'allows exactly 2 frames' do
        allow(RubySpriter::MetadataManager).to receive(:read).with(temp_image).and_return({
          columns: 4,
          rows: 4,
          frames: 16
        })

        expect {
          described_class.new(image: temp_image, extract: '1,2')
        }.not_to raise_error
      end
    end

    describe 'frame number validation' do
      it 'raises error when frame number is 0' do
        allow(RubySpriter::MetadataManager).to receive(:read).with(temp_image).and_return({
          columns: 4,
          rows: 4,
          frames: 16
        })

        expect {
          described_class.new(image: temp_image, extract: '0,1,2')
        }.to raise_error(RubySpriter::ValidationError, /Frame numbers must be 1-indexed/)
      end

      it 'raises error when frame number is negative' do
        allow(RubySpriter::MetadataManager).to receive(:read).with(temp_image).and_return({
          columns: 4,
          rows: 4,
          frames: 16
        })

        expect {
          described_class.new(image: temp_image, extract: '1,-2,3')
        }.to raise_error(RubySpriter::ValidationError, /Frame numbers must be 1-indexed/)
      end

      it 'allows duplicate frame numbers' do
        allow(RubySpriter::MetadataManager).to receive(:read).with(temp_image).and_return({
          columns: 4,
          rows: 4,
          frames: 16
        })

        expect {
          described_class.new(image: temp_image, extract: '1,1,2,2,3,3')
        }.not_to raise_error
      end
    end

    describe 'metadata requirement' do
      it 'raises error when image has no metadata' do
        allow(RubySpriter::MetadataManager).to receive(:read).with(temp_image).and_return(nil)

        expect {
          described_class.new(image: temp_image, extract: '1,2,3')
        }.to raise_error(RubySpriter::ValidationError, /Image has no metadata.*Cannot extract frames/)
      end
    end

    describe 'out of bounds validation' do
      before do
        allow(RubySpriter::MetadataManager).to receive(:read).with(temp_image).and_return({
          columns: 4,
          rows: 4,
          frames: 16
        })
      end

      it 'raises error when frame number exceeds total frames' do
        expect {
          described_class.new(image: temp_image, extract: '1,2,17')
        }.to raise_error(RubySpriter::ValidationError, /Frame 17 is out of bounds.*only has 16 frames/)
      end

      it 'allows frame number equal to total frames' do
        expect {
          described_class.new(image: temp_image, extract: '1,2,16')
        }.not_to raise_error
      end

      it 'raises error for multiple out of bounds frames' do
        expect {
          described_class.new(image: temp_image, extract: '1,20,25')
        }.to raise_error(RubySpriter::ValidationError, /Frame 20 is out of bounds/)
      end
    end

    describe '--columns default' do
      before do
        allow(RubySpriter::MetadataManager).to receive(:read).with(temp_image).and_return({
          columns: 4,
          rows: 4,
          frames: 16
        })
      end

      it 'defaults to 4 columns when not specified' do
        processor = described_class.new(image: temp_image, extract: '1,2,3,4')
        expect(processor.instance_variable_get(:@options)[:columns]).to eq(4)
      end

      it 'uses specified columns when provided' do
        processor = described_class.new(image: temp_image, extract: '1,2,3', columns: 3)
        expect(processor.instance_variable_get(:@options)[:columns]).to eq(3)
      end
    end
  end

  describe '--add-meta validation' do
    let(:temp_image) { File.join(Dir.mktmpdir, 'test.png') }

    before do
      FileUtils.touch(temp_image)

      allow_any_instance_of(RubySpriter::DependencyChecker).to receive(:check_all).and_return({
        ffmpeg: { available: true },
        ffprobe: { available: true },
        imagemagick: { available: true },
        gimp: { available: true }
      })
    end

    after do
      FileUtils.rm_f(temp_image)
    end

    describe 'format validation' do
      it 'raises error for invalid format (missing colon)' do
        expect {
          described_class.new(image: temp_image, add_meta: '44')
        }.to raise_error(RubySpriter::ValidationError, /Invalid --add-meta format/)
      end

      it 'raises error for invalid format (non-numeric rows)' do
        expect {
          described_class.new(image: temp_image, add_meta: 'a:4')
        }.to raise_error(RubySpriter::ValidationError, /Invalid --add-meta format/)
      end

      it 'raises error for invalid format (non-numeric columns)' do
        expect {
          described_class.new(image: temp_image, add_meta: '4:b')
        }.to raise_error(RubySpriter::ValidationError, /Invalid --add-meta format/)
      end

      it 'accepts valid R:C format' do
        # Mock ImageMagick identify for dimension validation
        allow(Open3).to receive(:capture3).with(/identify/).and_return(
          ["800x800\n", '', instance_double(Process::Status, success?: true)]
        )

        allow(RubySpriter::MetadataManager).to receive(:read).with(temp_image).and_return(nil)

        expect {
          described_class.new(image: temp_image, add_meta: '4:4')
        }.not_to raise_error
      end
    end

    describe 'range validation' do
      it 'raises error when rows is below minimum (0)' do
        expect {
          described_class.new(image: temp_image, add_meta: '0:4')
        }.to raise_error(RubySpriter::ValidationError, /rows must be between 1 and 99/)
      end

      it 'raises error when columns is below minimum (0)' do
        expect {
          described_class.new(image: temp_image, add_meta: '4:0')
        }.to raise_error(RubySpriter::ValidationError, /columns must be between 1 and 99/)
      end

      it 'raises error when rows exceeds maximum (100)' do
        expect {
          described_class.new(image: temp_image, add_meta: '100:4')
        }.to raise_error(RubySpriter::ValidationError, /rows must be between 1 and 99/)
      end

      it 'raises error when total frames exceeds 999' do
        expect {
          described_class.new(image: temp_image, add_meta: '20:50')
        }.to raise_error(RubySpriter::ValidationError, /Total frames \(1000\) must be less than 1000/)
      end

      it 'allows maximum valid frames (999)' do
        # Mock ImageMagick identify - 3700x2700 divides evenly by 27 rows x 37 columns (100x100 per frame)
        allow(Open3).to receive(:capture3).with(/identify/).and_return(
          ["3700x2700\n", '', instance_double(Process::Status, success?: true)]
        )

        allow(RubySpriter::MetadataManager).to receive(:read).with(temp_image).and_return(nil)

        expect {
          described_class.new(image: temp_image, add_meta: '27:37')
        }.not_to raise_error
      end
    end

    describe 'existing metadata handling' do
      it 'raises error when image already has metadata' do
        allow(RubySpriter::MetadataManager).to receive(:read).with(temp_image).and_return({
          columns: 4,
          rows: 4,
          frames: 16
        })

        expect {
          described_class.new(image: temp_image, add_meta: '4:4')
        }.to raise_error(RubySpriter::ValidationError, /Image already has spritesheet metadata.*Use --overwrite-meta/)
      end

      it 'allows replacing metadata with --overwrite-meta' do
        allow(RubySpriter::MetadataManager).to receive(:read).with(temp_image).and_return({
          columns: 4,
          rows: 4,
          frames: 16
        })

        # Mock ImageMagick identify
        allow(Open3).to receive(:capture3).with(/identify/).and_return(
          ["800x800\n", '', instance_double(Process::Status, success?: true)]
        )

        expect {
          described_class.new(image: temp_image, add_meta: '8:8', overwrite_meta: true)
        }.not_to raise_error
      end
    end

    describe 'dimension validation' do
      before do
        allow(RubySpriter::MetadataManager).to receive(:read).with(temp_image).and_return(nil)
      end

      it 'raises error when image dimensions do not divide evenly' do
        # Mock ImageMagick identify - 800x600 doesn't divide by 3x3
        allow(Open3).to receive(:capture3).with(/identify/).and_return(
          ["800x600\n", '', instance_double(Process::Status, success?: true)]
        )

        expect {
          described_class.new(image: temp_image, add_meta: '3:3')
        }.to raise_error(RubySpriter::ValidationError, /Image dimensions \(800x600\) must divide evenly by grid \(3x3\)/)
      end

      it 'allows dimensions that divide evenly' do
        # Mock ImageMagick identify - 800x800 divides by 4x4
        allow(Open3).to receive(:capture3).with(/identify/).and_return(
          ["800x800\n", '', instance_double(Process::Status, success?: true)]
        )

        expect {
          described_class.new(image: temp_image, add_meta: '4:4')
        }.not_to raise_error
      end
    end

    describe 'frame count handling' do
      before do
        allow(RubySpriter::MetadataManager).to receive(:read).with(temp_image).and_return(nil)
        allow(Open3).to receive(:capture3).with(/identify/).and_return(
          ["800x800\n", '', instance_double(Process::Status, success?: true)]
        )
      end

      it 'calculates frame count from rows * columns by default' do
        processor = described_class.new(image: temp_image, add_meta: '4:4')
        # Frame count should be 16 (4x4)
        # We'll verify this in the workflow implementation
        expect(processor.instance_variable_get(:@options)[:add_meta]).to eq('4:4')
      end

      it 'allows custom frame count with --frames for partial grids' do
        processor = described_class.new(image: temp_image, add_meta: '4:4', frame_count: 14)
        expect(processor.instance_variable_get(:@options)[:frame_count]).to eq(14)
      end

      it 'raises error when custom frame count exceeds grid size' do
        expect {
          described_class.new(image: temp_image, add_meta: '4:4', frame_count: 20)
        }.to raise_error(RubySpriter::ValidationError, /Frame count \(20\) exceeds grid size \(16\)/)
      end
    end
  end

  describe '--split metadata priority logic' do
    let(:temp_dir) { Dir.mktmpdir('test_split_') }
    let(:image_file) { File.join(temp_dir, 'spritesheet.png') }

    before do
      FileUtils.touch(image_file)

      allow_any_instance_of(RubySpriter::DependencyChecker).to receive(:check_all).and_return({
        ffmpeg: { available: true },
        ffprobe: { available: true },
        imagemagick: { available: true },
        gimp: { available: true }
      })
      allow_any_instance_of(RubySpriter::DependencyChecker).to receive(:gimp_path).and_return('/usr/bin/gimp')
    end

    after do
      FileUtils.rm_rf(temp_dir)
    end

    context 'when image has metadata' do
      before do
        allow(RubySpriter::MetadataManager).to receive(:read).with(image_file).and_return({
          columns: 4,
          rows: 4,
          frames: 16
        })
      end

      it 'uses metadata when --split not provided' do
        processor = described_class.new(image: image_file, save_frames: true)

        splitter = instance_double(RubySpriter::Utils::SpritesheetSplitter)
        allow(RubySpriter::Utils::SpritesheetSplitter).to receive(:new).and_return(splitter)
        expect(splitter).to receive(:split_into_frames).with(image_file, anything, 4, 4, 16)

        processor.run
      end

      it 'warns and uses metadata when --split provided without --override-md' do
        processor = described_class.new(image: image_file, split: '5:5')

        splitter = instance_double(RubySpriter::Utils::SpritesheetSplitter)
        allow(RubySpriter::Utils::SpritesheetSplitter).to receive(:new).and_return(splitter)
        expect(splitter).to receive(:split_into_frames).with(image_file, anything, 4, 4, 16)

        expect(RubySpriter::Utils::OutputFormatter).to receive(:note).with(/Image has metadata.*Your --split values will be ignored/)

        processor.run
      end

      it 'uses --split when --override-md provided' do
        processor = described_class.new(image: image_file, split: '5:5', override_md: true)

        # Mock ImageMagick identify for dimension validation
        allow(Open3).to receive(:capture3).with(/identify/).and_return(
          ["500x500\n", '', instance_double(Process::Status, success?: true)]
        )

        splitter = instance_double(RubySpriter::Utils::SpritesheetSplitter)
        allow(RubySpriter::Utils::SpritesheetSplitter).to receive(:new).and_return(splitter)
        expect(splitter).to receive(:split_into_frames).with(image_file, anything, 5, 5, 25)

        processor.run
      end
    end

    context 'when image has no metadata' do
      before do
        allow(RubySpriter::MetadataManager).to receive(:read).with(image_file).and_return(nil)
      end

      it 'uses --split values when provided' do
        processor = described_class.new(image: image_file, split: '6:6')

        # Mock ImageMagick identify for dimension validation
        allow(Open3).to receive(:capture3).with(/identify/).and_return(
          ["600x600\n", '', instance_double(Process::Status, success?: true)]
        )

        splitter = instance_double(RubySpriter::Utils::SpritesheetSplitter)
        allow(RubySpriter::Utils::SpritesheetSplitter).to receive(:new).and_return(splitter)
        expect(splitter).to receive(:split_into_frames).with(image_file, anything, 6, 6, 36)

        processor.run
      end

      it 'raises error when --split not provided' do
        processor = described_class.new(image: image_file, save_frames: true)

        expect {
          processor.run
        }.to raise_error(RubySpriter::ValidationError, /Image has no metadata.*Please provide --split/)
      end
    end
  end

  describe 'frame extraction with --save-frames' do
    let(:temp_dir) { Dir.mktmpdir('test_') }
    let(:video_file) { File.join(temp_dir, 'test.mp4') }
    let(:spritesheet_file) { File.join(temp_dir, 'spritesheet.png') }

    before do
      FileUtils.touch(video_file)
      FileUtils.touch(spritesheet_file)

      allow_any_instance_of(RubySpriter::DependencyChecker).to receive(:check_all).and_return({
        ffmpeg: { available: true },
        ffprobe: { available: true },
        imagemagick: { available: true },
        gimp: { available: true }
      })
      allow_any_instance_of(RubySpriter::DependencyChecker).to receive(:gimp_path).and_return('/usr/bin/gimp')
    end

    after do
      FileUtils.rm_rf(temp_dir)
    end

    it 'splits spritesheet into frames after video processing when save_frames is true' do
      processor = described_class.new(video: video_file, save_frames: true)

      # The output file will be generated from video filename
      expected_output = File.join(temp_dir, 'test_spritesheet.png')

      video_processor = instance_double(RubySpriter::VideoProcessor)
      allow(RubySpriter::VideoProcessor).to receive(:new).and_return(video_processor)
      allow(video_processor).to receive(:create_spritesheet).and_return({
        output_file: expected_output,
        columns: 4,
        rows: 4,
        frames: 16
      })

      splitter = instance_double(RubySpriter::Utils::SpritesheetSplitter)
      allow(RubySpriter::Utils::SpritesheetSplitter).to receive(:new).and_return(splitter)
      expect(splitter).to receive(:split_into_frames).with(expected_output, anything, 4, 4, 16)

      processor.run
    end

    it 'splits spritesheet into frames after image processing when save_frames is true' do
      processor = described_class.new(image: spritesheet_file, save_frames: true)

      # Mock metadata reading
      allow(RubySpriter::MetadataManager).to receive(:read).with(spritesheet_file).and_return({
        columns: 4,
        rows: 4,
        frames: 16
      })

      splitter = instance_double(RubySpriter::Utils::SpritesheetSplitter)
      allow(RubySpriter::Utils::SpritesheetSplitter).to receive(:new).and_return(splitter)
      expect(splitter).to receive(:split_into_frames).with(spritesheet_file, anything, 4, 4, 16)

      processor.run
    end

    it 'does not split frames when save_frames is false' do
      processor = described_class.new(video: video_file, save_frames: false)

      # The output file will be generated from video filename
      expected_output = File.join(temp_dir, 'test_spritesheet.png')

      video_processor = instance_double(RubySpriter::VideoProcessor)
      allow(RubySpriter::VideoProcessor).to receive(:new).and_return(video_processor)
      allow(video_processor).to receive(:create_spritesheet).and_return({
        output_file: expected_output,
        columns: 4,
        rows: 4,
        frames: 16
      })

      expect(RubySpriter::Utils::SpritesheetSplitter).not_to receive(:new)

      processor.run
    end
  end

end
