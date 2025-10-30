# frozen_string_literal: true

module RubySpriter
  # Configuration class for inner background removal features (v0.7.0+)
  class InnerBgConfig
    attr_accessor :try_inner,
                  :inner_min_area,
                  :adaptive_min_area,
                  :multi_pass,
                  :edge_sample_depth,
                  :edge_sample_pattern,
                  :color_space,
                  :threshold_stepping,
                  :remove_smoke,
                  :bg_fuzz,
                  :ghost_threshold

    # Default values per requirements
    DEFAULTS = {
      try_inner: false,
      inner_min_area: 100,              # Fixed default: 100 pixels
      adaptive_min_area: false,         # 1% of image area when enabled
      multi_pass: false,
      edge_sample_depth: 10,            # 10 pixels inward from edges
      edge_sample_pattern: 'linear',    # 'linear' or 'weighted'
      color_space: 'rgb',               # 'rgb' or 'lab'
      threshold_stepping: false,
      remove_smoke: false,
      bg_fuzz: 10,                      # 10% tolerance
      ghost_threshold: 30               # Alpha threshold for ghost detection
    }.freeze

    def initialize(options = {})
      DEFAULTS.each do |key, default_value|
        instance_variable_set("@#{key}", options.fetch(key, default_value))
      end
    end

    # Validate configuration
    def valid?
      validate_edge_sample_pattern &&
        validate_color_space &&
        validate_numeric_ranges
    end

    # Calculate adaptive minimum area based on image dimensions
    def calculate_adaptive_min_area(image_width, image_height)
      return @inner_min_area unless @adaptive_min_area

      total_pixels = image_width * image_height
      (total_pixels * 0.01).to_i  # 1% of image area
    end

    # Check if inner background removal is enabled
    def enabled?
      @try_inner
    end

    # Generate report-friendly hash
    def to_h
      {
        try_inner: @try_inner,
        inner_min_area: @inner_min_area,
        adaptive_min_area: @adaptive_min_area,
        multi_pass: @multi_pass,
        edge_sample_depth: @edge_sample_depth,
        edge_sample_pattern: @edge_sample_pattern,
        color_space: @color_space,
        threshold_stepping: @threshold_stepping,
        remove_smoke: @remove_smoke,
        bg_fuzz: @bg_fuzz,
        ghost_threshold: @ghost_threshold
      }
    end

    private

    def validate_edge_sample_pattern
      %w[linear weighted].include?(@edge_sample_pattern)
    end

    def validate_color_space
      %w[rgb lab].include?(@color_space)
    end

    def validate_numeric_ranges
      @inner_min_area > 0 &&
        @edge_sample_depth > 0 &&
        @bg_fuzz >= 0 && @bg_fuzz <= 100 &&
        @ghost_threshold >= 0 && @ghost_threshold <= 255
    end
  end
end
