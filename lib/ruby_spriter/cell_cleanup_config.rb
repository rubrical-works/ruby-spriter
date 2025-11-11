module RubySpriter
  class CellCleanupConfig
    attr_accessor :threshold, :parallel, :skip_empty

    def initialize(options = {})
      @threshold = options[:cell_cleanup_threshold] || 15.0
      @parallel = options.fetch(:cell_cleanup_parallel, true)
      @skip_empty = options.fetch(:cell_cleanup_skip_empty, true)

      validate!
    end

    private

    def validate!
      unless @threshold.between?(1.0, 50.0)
        raise ValidationError, "cell_cleanup_threshold must be between 1.0 and 50.0 (got: #{@threshold})"
      end
    end
  end
end
