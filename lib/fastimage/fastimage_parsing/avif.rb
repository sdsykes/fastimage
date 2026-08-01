module FastImageParsing
  class Avif < ImageBase # :nodoc:  
    def dimensions
      bmff = IsoBmff.new(@stream)
      return nil unless bmff.width && bmff.height
      [bmff.width, bmff.height]
    end
  
    def animated?
      @stream.peek(12)[4..-1] == "ftypavis"
    end
  end
end
