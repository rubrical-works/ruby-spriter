# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubySpriter::RembgProcessor do
  describe '#initialize' do
    it 'raises error if rembg is not available' do
      allow(RubySpriter::DependencyChecker).to receive(:check_rembg)
        .and_return({ available: false, version: nil, path: nil })

      expect {
        described_class.new
      }.to raise_error(/rembg is not installed/)
    end

    it 'succeeds when rembg is available' do
      allow(RubySpriter::DependencyChecker).to receive(:check_rembg)
        .and_return({ available: true, version: '2.0.0', path: '/usr/bin/rembg' })

      expect { described_class.new }.not_to raise_error
    end
  end

  describe '#remove_background' do
    let(:processor) do
      allow(RubySpriter::DependencyChecker).to receive(:check_rembg)
        .and_return({ available: true, version: '2.0.0', path: '/usr/bin/rembg' })
      described_class.new
    end

    before do
      allow(RubySpriter::Utils::FileHelper).to receive(:validate_readable!)
      allow(File).to receive(:size).and_return(1000)
    end

    it 'calls rembg with correct arguments' do
      input = 'input.png'
      output = 'output.png'

      expect(Open3).to receive(:capture3)
        .with(/rembg i/)
        .and_return(['', '', instance_double(Process::Status, success?: true)])

      processor.remove_background(input, output)
    end

    it 'handles spaces in paths' do
      input = 'path with spaces/input.png'
      output = 'output path/output.png'

      expect(Open3).to receive(:capture3)
        .with(/rembg i.*".*path with spaces.*".*".*output path.*"/)
        .and_return(['', '', instance_double(Process::Status, success?: true)])

      processor.remove_background(input, output)
    end

    it 'raises error if rembg command fails' do
      allow(Open3).to receive(:capture3)
        .and_return(['', 'Error message', instance_double(Process::Status, success?: false)])

      expect {
        processor.remove_background('input.png', 'output.png')
      }.to raise_error(/rembg failed/)
    end

    it 'returns output path on success' do
      allow(Open3).to receive(:capture3)
        .and_return(['', '', instance_double(Process::Status, success?: true)])

      result = processor.remove_background('input.png', 'output.png')
      expect(result).to eq('output.png')
    end
  end
end
