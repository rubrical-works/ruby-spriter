# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubySpriter::Utils::FileHelper do
  describe '.spritesheet_filename' do
    it 'generates correct filename from video' do
      result = described_class.spritesheet_filename('/path/to/video.mp4')
      expect(result).to eq('/path/to/video_spritesheet.png')
    end

    it 'handles different extensions' do
      result = described_class.spritesheet_filename('C:\\videos\\clip.avi')
      expect(result).to match(/clip_spritesheet\.png$/)
    end
  end

  describe '.output_filename' do
    it 'generates filename with suffix' do
      result = described_class.output_filename('/path/to/image.png', 'scaled')
      expect(result).to eq('/path/to/image-scaled.png')
    end

    it 'preserves directory path' do
      result = described_class.output_filename('/some/deep/path/file.png', 'nobg')
      expect(result).to start_with('/some/deep/path/')
    end
  end

  describe '.format_size' do
    it 'formats bytes correctly' do
      expect(described_class.format_size(500)).to eq('500 bytes')
    end

    it 'formats kilobytes correctly' do
      expect(described_class.format_size(2048)).to eq('2.0 KB')
    end

    it 'formats megabytes correctly' do
      expect(described_class.format_size(5_242_880)).to eq('5.0 MB')
    end
  end

  describe '.validate_exists!' do
    it 'raises error for non-existent file' do
      expect {
        described_class.validate_exists!('/nonexistent/file.txt')
      }.to raise_error(RubySpriter::ValidationError, /File not found/)
    end

    it 'does not raise for existing file' do
      file = File.join(@test_dir, 'test.txt')
      File.write(file, 'test')
      
      expect {
        described_class.validate_exists!(file)
      }.not_to raise_error
    end
  end

  describe '.validate_readable!' do
    it 'validates file exists and is readable' do
      file = File.join(@test_dir, 'test.txt')
      File.write(file, 'test')

      expect {
        described_class.validate_readable!(file)
      }.not_to raise_error
    end
  end

  describe '.unique_filename' do
    it 'returns original filename when file does not exist' do
      result = described_class.unique_filename('/path/to/output.png')
      expect(result).to eq('/path/to/output.png')
    end

    it 'adds timestamp when file exists' do
      file = File.join(@test_dir, 'existing.png')
      File.write(file, 'test')

      result = described_class.unique_filename(file)
      expect(result).to match(/existing_\d{8}_\d{6}_\d{3}\.png$/)
      expect(result).not_to eq(file)
    end

    it 'handles files with multiple dots in name' do
      file = File.join(@test_dir, 'my.sprite.sheet.png')
      File.write(file, 'test')

      result = described_class.unique_filename(file)
      expect(result).to match(/my\.sprite\.sheet_\d{8}_\d{6}_\d{3}\.png$/)
    end

    it 'preserves directory path' do
      file = File.join(@test_dir, 'subdir', 'output.png')
      FileUtils.mkdir_p(File.dirname(file))
      File.write(file, 'test')

      result = described_class.unique_filename(file)
      expect(result).to start_with(File.join(@test_dir, 'subdir'))
    end

    it 'generates different filenames for consecutive calls' do
      file = File.join(@test_dir, 'test.png')
      File.write(file, 'test')

      result1 = described_class.unique_filename(file)
      sleep(0.01) # Small delay to ensure different timestamps
      result2 = described_class.unique_filename(file)

      expect(result1).not_to eq(result2)
    end
  end

  describe '.ensure_unique_output' do
    it 'returns original path when overwrite is true' do
      file = File.join(@test_dir, 'output.png')
      File.write(file, 'test')

      result = described_class.ensure_unique_output(file, overwrite: true)
      expect(result).to eq(file)
    end

    it 'returns original path when file does not exist and overwrite is false' do
      file = File.join(@test_dir, 'new_output.png')

      result = described_class.ensure_unique_output(file, overwrite: false)
      expect(result).to eq(file)
    end

    it 'returns unique filename when file exists and overwrite is false' do
      file = File.join(@test_dir, 'existing_output.png')
      File.write(file, 'test')

      result = described_class.ensure_unique_output(file, overwrite: false)
      expect(result).to match(/existing_output_\d{8}_\d{6}_\d{3}\.png$/)
      expect(result).not_to eq(file)
    end

    it 'defaults to overwrite false when not specified' do
      file = File.join(@test_dir, 'default_test.png')
      File.write(file, 'test')

      result = described_class.ensure_unique_output(file)
      expect(result).not_to eq(file)
      expect(result).to match(/default_test_\d{8}_\d{6}_\d{3}\.png$/)
    end
  end
end
