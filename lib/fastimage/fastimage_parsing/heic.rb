module FastImageParsing
  class Heic < ImageBase # :nodoc:
    def dimensions
      bmff = IsoBmff.new(@stream)
      return nil unless bmff.width && bmff.height
      [bmff.width, bmff.height]
    end
  end
end