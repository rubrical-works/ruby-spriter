# frozen_string_literal: true

require 'spec_helper'
require 'securerandom'

RSpec.describe RubySpriter::Consolidator do
  let(:spritesheet1) { File.join(__dir__, '..', 'fixtures', 'spritesheet_4x2.png') }
  let(:spritesheet2) { File.join(__dir__, '..', 'fixtures', 'spritesheet_6x2.png') }
  let(:spritesheet3) { File.join(__dir__, '..', 'fixtures', 'spritesheet_4x4.png') }
  let(:output_file) { File.join($test_temp_dir, 'consolidated.png') }

  describe '#initialize' do
    it 'initializes with empty options by default' do
      consolidator = described_class.new

      expect(consolidator.options).to eq({})
    end

    it 'initializes with provided options' do
      consolidator = described_class.new(debug: true, validate_columns: false)

      expect(consolidator.options[:debug]).to be true
      expect(consolidator.options[:validate_columns]).to be false
    end
  end

  describe '#consolidate' do
    let(:consolidator) { described_class.new }

    # Helper to set up common mocks for successful consolidation
    def stub_consolidation_success
      allow(RubySpriter::MetadataManager).to receive(:embed)
      allow(RubySpriter::Utils::FileHelper).to receive(:validate_exists!)
      allow(File).to receive(:rename)
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(/consolidated.*temp/).and_return(true)
      allow(File).to receive(:delete)
    end

    context 'with file validation' do
      it 'raises error when given 0 files' do
        expect {
          consolidator.consolidate([], output_file)
        }.to raise_error(RubySpriter::ValidationError, /Need at least 2 files/)
      end

      it 'raises error when given only 1 file' do
        expect {
          consolidator.consolidate([spritesheet1], output_file)
        }.to raise_error(RubySpriter::ValidationError, /Need at least 2 files/)
      end

      it 'accepts 2 files minimum' do
        stub_consolidation_success
        allow(RubySpriter::MetadataManager).to receive(:read).and_return(
          { columns: 2, rows: 2, frames: 4 }
        )
        allow(Open3).to receive(:capture3).and_return(['', '', instance_double(Process::Status, success?: true)])
        allow(File).to receive(:size).and_return(1000)

        expect {
          consolidator.consolidate([spritesheet1, spritesheet2], output_file)
        }.not_to raise_error
      end

      it 'raises error when file does not exist' do
        non_existent = 'non_existent.png'

        expect {
          consolidator.consolidate([spritesheet1, non_existent], output_file)
        }.to raise_error(RubySpriter::ValidationError, /not found/)
      end
    end

    context 'with metadata reading' do
      it 'reads metadata from all files' do
        stub_consolidation_success
        metadata1 = { columns: 2, rows: 2, frames: 4 }
        metadata2 = { columns: 2, rows: 3, frames: 6 }

        expect(RubySpriter::MetadataManager).to receive(:read).with(spritesheet1).and_return(metadata1)
        expect(RubySpriter::MetadataManager).to receive(:read).with(spritesheet2).and_return(metadata2)

        allow(Open3).to receive(:capture3).and_return(['', '', instance_double(Process::Status, success?: true)])
        allow(File).to receive(:size).and_return(1000)

        consolidator.consolidate([spritesheet1, spritesheet2], output_file)
      end

      it 'raises ValidationError when file missing metadata' do
        allow(RubySpriter::MetadataManager).to receive(:read).with(spritesheet1).and_return(nil)

        expect {
          consolidator.consolidate([spritesheet1, spritesheet2], output_file)
        }.to raise_error(RubySpriter::ValidationError, /missing metadata/)
      end

      it 'raises error with helpful message about Ruby Spriter spritesheets' do
        allow(RubySpriter::MetadataManager).to receive(:read).with(spritesheet1).and_return(nil)

        expect {
          consolidator.consolidate([spritesheet1, spritesheet2], output_file)
        }.to raise_error(RubySpriter::ValidationError, /All files must be Ruby Spriter spritesheets/)
      end
    end

    context 'with column validation enabled (default)' do
      let(:consolidator) { described_class.new(validate_columns: true) }

      it 'passes when all files have same column count' do
        stub_consolidation_success
        metadata1 = { columns: 2, rows: 2, frames: 4 }
        metadata2 = { columns: 2, rows: 3, frames: 6 }

        allow(RubySpriter::MetadataManager).to receive(:read).and_return(metadata1, metadata2)
        allow(Open3).to receive(:capture3).and_return(['', '', instance_double(Process::Status, success?: true)])
        allow(File).to receive(:size).and_return(1000)

        expect {
          consolidator.consolidate([spritesheet1, spritesheet2], output_file)
        }.not_to raise_error
      end

      it 'raises error when column counts do not match' do
        metadata1 = { columns: 2, rows: 2, frames: 4 }
        metadata2 = { columns: 4, rows: 1, frames: 4 }

        allow(RubySpriter::MetadataManager).to receive(:read).and_return(metadata1, metadata2)

        expect {
          consolidator.consolidate([spritesheet1, spritesheet2], output_file)
        }.to raise_error(RubySpriter::ValidationError, /Column count mismatch/)
      end

      it 'error message shows expected and actual column counts' do
        metadata1 = { columns: 2, rows: 2, frames: 4 }
        metadata2 = { columns: 4, rows: 1, frames: 4 }

        allow(RubySpriter::MetadataManager).to receive(:read).and_return(metadata1, metadata2)

        expect {
          consolidator.consolidate([spritesheet1, spritesheet2], output_file)
        }.to raise_error(RubySpriter::ValidationError, /Expected 2, found 4/)
      end

      it 'error message suggests --no-validate-columns flag' do
        metadata1 = { columns: 2, rows: 2, frames: 4 }
        metadata2 = { columns: 4, rows: 1, frames: 4 }

        allow(RubySpriter::MetadataManager).to receive(:read).and_return(metadata1, metadata2)

        expect {
          consolidator.consolidate([spritesheet1, spritesheet2], output_file)
        }.to raise_error(RubySpriter::ValidationError, /--no-validate-columns/)
      end
    end

    context 'with column validation disabled' do
      let(:consolidator) { described_class.new(validate_columns: false) }
      before { stub_consolidation_success }

      it 'allows mismatched column counts' do
        metadata1 = { columns: 2, rows: 2, frames: 4 }
        metadata2 = { columns: 4, rows: 1, frames: 4 }

        allow(RubySpriter::MetadataManager).to receive(:read).and_return(metadata1, metadata2)
        allow(Open3).to receive(:capture3).and_return(['', '', instance_double(Process::Status, success?: true)])
        allow(File).to receive(:size).and_return(1000)

        expect {
          consolidator.consolidate([spritesheet1, spritesheet2], output_file)
        }.not_to raise_error
      end
    end

    context 'with ImageMagick consolidation' do
      before do
        stub_consolidation_success
        allow(RubySpriter::MetadataManager).to receive(:read).and_return(
          { columns: 2, rows: 2, frames: 4 }
        )
        allow(File).to receive(:size).and_return(1000)
      end

      it 'calls ImageMagick with correct command' do
        expect(Open3).to receive(:capture3) do |cmd|
          expect(cmd).to include('convert')
          expect(cmd).to include('-append')
          expect(cmd).to include(spritesheet1)
          expect(cmd).to include(spritesheet2)
          expect(cmd).to include(output_file)
          ['', '', instance_double(Process::Status, success?: true)]
        end

        consolidator.consolidate([spritesheet1, spritesheet2], output_file)
      end

      it 'uses -append flag for vertical stacking' do
        expect(Open3).to receive(:capture3) do |cmd|
          expect(cmd).to include('-append')
          ['', '', instance_double(Process::Status, success?: true)]
        end

        consolidator.consolidate([spritesheet1, spritesheet2], output_file)
      end

      it 'raises ProcessingError when ImageMagick fails' do
        allow(Open3).to receive(:capture3).and_return(
          ['', 'ImageMagick error', instance_double(Process::Status, success?: false)]
        )

        expect {
          consolidator.consolidate([spritesheet1, spritesheet2], output_file)
        }.to raise_error(RubySpriter::ProcessingError, /ImageMagick consolidation failed/)
      end

      it 'shows debug output when debug option enabled' do
        consolidator = described_class.new(debug: true)

        allow(RubySpriter::MetadataManager).to receive(:read).and_return(
          { columns: 2, rows: 2, frames: 4 }
        )
        allow(Open3).to receive(:capture3).and_return(['', '', instance_double(Process::Status, success?: true)])
        allow(File).to receive(:size).and_return(1000)

        expect {
          consolidator.consolidate([spritesheet1, spritesheet2], output_file)
        }.to output(/DEBUG: ImageMagick command/).to_stdout
      end
    end

    context 'with successful consolidation' do
      before do
        stub_consolidation_success
        allow(RubySpriter::MetadataManager).to receive(:read).and_return(
          { columns: 2, rows: 2, frames: 4 },
          { columns: 2, rows: 3, frames: 6 }
        )
        allow(Open3).to receive(:capture3).and_return(['', '', instance_double(Process::Status, success?: true)])
        allow(File).to receive(:size).and_return(5000)
      end

      it 'calculates correct total frames' do
        result = consolidator.consolidate([spritesheet1, spritesheet2], output_file)

        expect(result[:frames]).to eq(10)  # 4 + 6
      end

      it 'calculates correct row count' do
        result = consolidator.consolidate([spritesheet1, spritesheet2], output_file)

        # 10 frames / 2 columns = 5 rows
        expect(result[:rows]).to eq(5)
      end

      it 'uses columns from first spritesheet' do
        result = consolidator.consolidate([spritesheet1, spritesheet2], output_file)

        expect(result[:columns]).to eq(2)
      end

      it 'embeds metadata in output file' do
        expect(RubySpriter::MetadataManager).to receive(:embed).with(
          anything,
          output_file,
          hash_including(columns: 2, rows: 5, frames: 10)
        )

        consolidator.consolidate([spritesheet1, spritesheet2], output_file)
      end

      it 'returns hash with correct keys' do
        result = consolidator.consolidate([spritesheet1, spritesheet2], output_file)

        expect(result).to include(
          output_file: output_file,
          columns: 2,
          rows: 5,
          frames: 10,
          size: 5000
        )
      end

      it 'returns correct file size' do
        result = consolidator.consolidate([spritesheet1, spritesheet2], output_file)

        expect(result[:size]).to eq(5000)
      end
    end

    context 'with 3 spritesheets' do
      before do
        stub_consolidation_success
        allow(RubySpriter::MetadataManager).to receive(:read).and_return(
          { columns: 4, rows: 1, frames: 4 },
          { columns: 4, rows: 1, frames: 4 },
          { columns: 4, rows: 1, frames: 4 }
        )
        allow(Open3).to receive(:capture3).and_return(['', '', instance_double(Process::Status, success?: true)])
        allow(File).to receive(:size).and_return(8000)
      end

      it 'successfully consolidates all 3 files' do
        expect(Open3).to receive(:capture3) do |cmd|
          expect(cmd).to include(spritesheet1)
          expect(cmd).to include(spritesheet2)
          expect(cmd).to include(spritesheet3)
          ['', '', instance_double(Process::Status, success?: true)]
        end

        consolidator.consolidate([spritesheet1, spritesheet2, spritesheet3], output_file)
      end

      it 'calculates correct total frames for 3 files' do
        result = consolidator.consolidate([spritesheet1, spritesheet2, spritesheet3], output_file)

        expect(result[:frames]).to eq(12)  # 4 + 4 + 4
      end

      it 'calculates correct row count for 3 files' do
        result = consolidator.consolidate([spritesheet1, spritesheet2, spritesheet3], output_file)

        # 12 frames / 4 columns = 3 rows
        expect(result[:rows]).to eq(3)
      end
    end

    context 'with output display' do
      before do
        stub_consolidation_success
        allow(RubySpriter::MetadataManager).to receive(:read).and_return(
          { columns: 2, rows: 2, frames: 4 },
          { columns: 2, rows: 3, frames: 6 }
        )
        allow(Open3).to receive(:capture3).and_return(['', '', instance_double(Process::Status, success?: true)])
        allow(File).to receive(:size).and_return(5000)
      end

      it 'displays success message' do
        expect {
          consolidator.consolidate([spritesheet1, spritesheet2], output_file)
        }.to output(/Consolidated spritesheet created/).to_stdout
      end

      it 'displays output file path' do
        expect {
          consolidator.consolidate([spritesheet1, spritesheet2], output_file)
        }.to output(/Output:.*consolidated\.png/).to_stdout
      end

      it 'displays grid layout information' do
        expect {
          consolidator.consolidate([spritesheet1, spritesheet2], output_file)
        }.to output(/Grid Layout:.*Columns: 2.*Rows: 5.*Total Frames: 10/m).to_stdout
      end

      it 'displays Godot AnimatedSprite2D settings' do
        expect {
          consolidator.consolidate([spritesheet1, spritesheet2], output_file)
        }.to output(/Godot AnimatedSprite2D Settings:.*HFrames = 2.*VFrames = 5/m).to_stdout
      end

      it 'displays source breakdown with frame counts' do
        expect {
          consolidator.consolidate([spritesheet1, spritesheet2], output_file)
        }.to output(/Source Breakdown:.*spritesheet_4x2\.png.*grid \(4 frames\).*spritesheet_6x2\.png.*grid \(6 frames\)/m).to_stdout
      end

      it 'displays number of combined spritesheets' do
        expect {
          consolidator.consolidate([spritesheet1, spritesheet2], output_file)
        }.to output(/Combined 2 spritesheets/).to_stdout
      end
    end
  end

  describe '#find_spritesheets_in_directory' do
    let(:consolidator) { described_class.new }
    let(:image_without_meta) { File.join(__dir__, '..', 'fixtures', 'image_without_metadata.png') }

    # Helper to create a unique test directory for each test
    def create_test_dir
      dir = File.join($test_temp_dir, "consolidate_test_#{SecureRandom.hex(8)}")
      FileUtils.mkdir_p(dir)
      dir
    end

    it 'finds all PNG files with metadata in directory' do
      test_dir = create_test_dir
      # Copy spritesheets with metadata to test directory
      sprite1_path = File.join(test_dir, 'sprite1.png')
      sprite2_path = File.join(test_dir, 'sprite2.png')
      FileUtils.cp(spritesheet1, sprite1_path)
      FileUtils.cp(spritesheet2, sprite2_path)

      # Mock metadata reading to return valid metadata for these files
      allow(RubySpriter::MetadataManager).to receive(:read).and_call_original
      allow(RubySpriter::MetadataManager).to receive(:read).with(sprite1_path).and_return(
        { columns: 2, rows: 2, frames: 4, version: '0.6' }
      )
      allow(RubySpriter::MetadataManager).to receive(:read).with(sprite2_path).and_return(
        { columns: 2, rows: 3, frames: 6, version: '0.6' }
      )

      found_files = consolidator.find_spritesheets_in_directory(test_dir)

      expect(found_files.length).to eq(2)
      expect(found_files).to include(sprite1_path)
      expect(found_files).to include(sprite2_path)
    end

    it 'excludes PNG files without metadata' do
      test_dir = create_test_dir
      # Copy two spritesheets with metadata and one image without
      sprite1_path = File.join(test_dir, 'sprite1.png')
      sprite2_path = File.join(test_dir, 'sprite2.png')
      no_meta_path = File.join(test_dir, 'no_meta.png')
      FileUtils.cp(spritesheet1, sprite1_path)
      FileUtils.cp(spritesheet2, sprite2_path)
      FileUtils.cp(image_without_meta, no_meta_path)

      # Mock metadata reading
      allow(RubySpriter::MetadataManager).to receive(:read).and_call_original
      allow(RubySpriter::MetadataManager).to receive(:read).with(sprite1_path).and_return(
        { columns: 2, rows: 2, frames: 4, version: '0.6' }
      )
      allow(RubySpriter::MetadataManager).to receive(:read).with(sprite2_path).and_return(
        { columns: 2, rows: 3, frames: 6, version: '0.6' }
      )
      allow(RubySpriter::MetadataManager).to receive(:read).with(no_meta_path).and_return(nil)

      found_files = consolidator.find_spritesheets_in_directory(test_dir)

      expect(found_files.length).to eq(2)
      expect(found_files).to include(sprite1_path)
      expect(found_files).to include(sprite2_path)
      expect(found_files).not_to include(no_meta_path)
    end

    it 'returns files sorted alphabetically' do
      test_dir = create_test_dir
      # Copy spritesheets with names that test alphabetical sorting
      FileUtils.cp(spritesheet1, File.join(test_dir, 'c_sprite.png'))
      FileUtils.cp(spritesheet2, File.join(test_dir, 'a_sprite.png'))
      FileUtils.cp(spritesheet3, File.join(test_dir, 'b_sprite.png'))

      found_files = consolidator.find_spritesheets_in_directory(test_dir)

      expect(found_files.length).to eq(3)
      expect(found_files[0]).to end_with('a_sprite.png')
      expect(found_files[1]).to end_with('b_sprite.png')
      expect(found_files[2]).to end_with('c_sprite.png')
    end

    it 'raises error when directory does not exist' do
      expect {
        consolidator.find_spritesheets_in_directory('nonexistent_directory')
      }.to raise_error(RubySpriter::ValidationError, /Directory not found/)
    end

    it 'raises error when no PNG files with metadata found' do
      # Create empty directory
      empty_dir = File.join($test_temp_dir, 'empty_dir')
      FileUtils.mkdir_p(empty_dir)

      expect {
        consolidator.find_spritesheets_in_directory(empty_dir)
      }.to raise_error(RubySpriter::ValidationError, /No PNG files with spritesheet metadata found/)
    end

    it 'raises error when directory has PNGs but none with metadata' do
      test_dir = create_test_dir
      # Copy only image without metadata
      FileUtils.cp(image_without_meta, File.join(test_dir, 'no_meta.png'))

      expect {
        consolidator.find_spritesheets_in_directory(test_dir)
      }.to raise_error(RubySpriter::ValidationError, /No PNG files with spritesheet metadata found/)
    end

    it 'handles directory with mixed file types' do
      test_dir = create_test_dir
      # Copy spritesheets and create non-PNG files
      FileUtils.cp(spritesheet1, File.join(test_dir, 'sprite1.png'))
      FileUtils.cp(spritesheet2, File.join(test_dir, 'sprite2.png'))
      File.write(File.join(test_dir, 'readme.txt'), 'test')
      File.write(File.join(test_dir, 'data.json'), '{}')

      found_files = consolidator.find_spritesheets_in_directory(test_dir)

      expect(found_files.length).to eq(2)
      expect(found_files).to all(end_with('.png'))
    end

    it 'requires at least 2 spritesheets' do
      test_dir = create_test_dir
      # Copy only one spritesheet
      FileUtils.cp(spritesheet1, File.join(test_dir, 'sprite1.png'))

      expect {
        consolidator.find_spritesheets_in_directory(test_dir)
      }.to raise_error(RubySpriter::ValidationError, /Found only 1 spritesheet, need at least 2/)
    end
  end
end
