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
        result = described_class.quote_path("/test/file's.txt")
        # Should wrap in single quotes and escape internal single quotes
        expect(result).to start_with("'")
        expect(result).to end_with("'")
        expect(result).to include("\\'")  # Should contain escaped single quote
      end
    end
  end

  describe '.normalize_for_python' do
    it 'returns absolute path' do
      result = described_class.normalize_for_python('.')
      # Should return an absolute path (Unix: starts with /, Windows: starts with drive letter)
      is_unix_absolute = result.start_with?('/')
      is_windows_absolute = result.match?(/^[A-Z]:/i)
      expect(is_unix_absolute || is_windows_absolute).to be true
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
