module RubySpriter
  module Utils
    module ImageHelper
      def self.get_dimensions(image_path)
        # Execute ImageMagick to get image dimensions
        cmd = "magick identify -format \"%wx%h\" #{PathHelper.quote_path(image_path)}"
        stdout, _stderr, status = Open3.capture3(cmd)

        raise ProcessingError, "Failed to get image dimensions: #{image_path}" unless status.success?

        dimensions = stdout.strip.split('x')
        { width: dimensions[0].to_i, height: dimensions[1].to_i }
      end
    end
  end
end
