# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubySpriter::DependencyChecker do
  describe '.check_rembg' do
    it 'returns availability hash with version when rembg is installed' do
      result = described_class.check_rembg
      expect(result).to be_a(Hash)
      expect(result).to have_key(:available)
      expect(result).to have_key(:version)
      expect(result).to have_key(:path)
    end

    it 'returns available: false when rembg is not found' do
      allow(Open3).to receive(:capture3).and_return(['', 'command not found', instance_double(Process::Status, success?: false)])
      result = described_class.check_rembg
      expect(result[:available]).to be false
    end
  end
end
