# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubySpriter::Utils::PathHelper do
  describe '.quote_path' do
    context 'on Windows' do
      before do
        allow(RubySpriter::Platform).to receive(:windows?).and_return(true)
      end

      it 'wraps path in double quotes' do
        expect(described_class.quote_path('C:\\test\\file.txt')).to eq('"C:\\test\\file.txt"')
      end
    end

    context 'on Unix-like systems' do
      before do
        allow(RubySpriter::Platform).to receive(:windows?).and_return(false)
      end

      it 'wraps path in single quotes' do
        expect(described_class.quote_path('/test/file.txt')).to eq("'/test/file.txt'")
      end

      it 'escapes single quotes in path' do
        expect(described_class.quote_path("/test/file's.txt")).to eq("'/test/file\\'s.txt'")
      end
    end
  end

  describe '.normalize_for_python' do
    it 'returns absolute path' do
      result = described_class.normalize_for_python('.')
      expect(result).to start_with('/')
        .or start_with('C:')
        .or start_with('D:')
    end

    context 'on Windows' do
      before do
        allow(RubySpriter::Platform).to receive(:windows?).and_return(true)
      end

      it 'converts backslashes to forward slashes' do
        allow(File).to receive(:absolute_path).and_return('C:\\test\\file.txt')
        expect(described_class.normalize_for_python('file.txt')).to eq('C:/test/file.txt')
      end
    end
  end

  describe '.to_native' do
    context 'on Windows' do
      before do
        allow(RubySpriter::Platform).to receive(:windows?).and_return(true)
      end

      it 'converts forward slashes to backslashes' do
        expect(described_class.to_native('C:/test/file.txt')).to eq('C:\\test\\file.txt')
      end
    end

    context 'on Unix-like systems' do
      before do
        allow(RubySpriter::Platform).to receive(:windows?).and_return(false)
      end

      it 'converts backslashes to forward slashes' do
        expect(described_class.to_native('C:\\test\\file.txt')).to eq('C:/test/file.txt')
      end
    end
  end
end
