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
end
