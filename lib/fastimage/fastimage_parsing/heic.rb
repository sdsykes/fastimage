module FastImageParsing
  class Heic < ImageBase # :nodoc:
    def dimensions
      bmff = IsoBmff.new(@stream)
      [bmff.width, bmff.height]
    end
  end
end