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
end
