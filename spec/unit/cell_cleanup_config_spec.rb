require 'spec_helper'
require_relative '../../lib/ruby_spriter/cell_cleanup_config'

RSpec.describe RubySpriter::CellCleanupConfig do
  describe '#initialize' do
    context 'with default options' do
      it 'sets threshold to 15.0' do
        config = described_class.new
        expect(config.threshold).to eq(15.0)
      end
    end

    context 'with custom threshold' do
      it 'accepts valid custom threshold' do
        config = described_class.new(cell_cleanup_threshold: 20.0)
        expect(config.threshold).to eq(20.0)
      end
    end

    context 'with invalid threshold' do
      it 'raises error when threshold is too low' do
        expect { described_class.new(cell_cleanup_threshold: 0.5) }
          .to raise_error(RubySpriter::ValidationError, /between 1.0 and 50.0/)
      end

      it 'raises error when threshold is too high' do
        expect { described_class.new(cell_cleanup_threshold: 55.0) }
          .to raise_error(RubySpriter::ValidationError, /between 1.0 and 50.0/)
      end
    end
  end
end
