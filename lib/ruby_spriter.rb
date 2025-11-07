# frozen_string_literal: true

# Main module for Ruby Spriter
module RubySpriter
  class Error < StandardError; end
  class DependencyError < Error; end
  class ProcessingError < Error; end
  class ValidationError < Error; end
end

# Load version first
require_relative 'ruby_spriter/version'

# Load utilities (no dependencies)
require_relative 'ruby_spriter/utils/path_helper'
require_relative 'ruby_spriter/utils/file_helper'
require_relative 'ruby_spriter/utils/output_formatter'
require_relative 'ruby_spriter/utils/spritesheet_splitter'

# Load core components
require_relative 'ruby_spriter/platform'
require_relative 'ruby_spriter/dependency_checker'
require_relative 'ruby_spriter/metadata_manager'
require_relative 'ruby_spriter/background_sampler'
require_relative 'ruby_spriter/threshold_stepper'
require_relative 'ruby_spriter/ghost_edge_cleaner'
require_relative 'ruby_spriter/smoke_detector'

# Load processors
require_relative 'ruby_spriter/video_processor'
require_relative 'ruby_spriter/gimp_processor'
require_relative 'ruby_spriter/consolidator'
require_relative 'ruby_spriter/compression_manager'
require_relative 'ruby_spriter/batch_processor'

# Load orchestration
require_relative 'ruby_spriter/processor'
require_relative 'ruby_spriter/cli'
