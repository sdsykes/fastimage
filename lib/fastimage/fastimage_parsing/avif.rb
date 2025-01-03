module FastImageParsing
  class Avif < ImageBase # :nodoc:  
    def dimensions
      bmff = IsoBmff.new(@stream)
      [bmff.width, bmff.height]
    end
  
    def animated?
      @stream.peek(12)[4..-1] == "ftypavis"
    end
  end
end
