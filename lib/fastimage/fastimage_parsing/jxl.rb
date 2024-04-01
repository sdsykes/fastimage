module FastImageParsing
  class Jxl < ImageBase # :nodoc:
    def dimensions
      if @stream.peek(2) == "\xFF\x0A".b
        jxlc = Jxlc.new(@stream)
        [jxlc.width, jxlc.height]
      else
        bmff = IsoBmff.new(@stream)
        [bmff.width, bmff.height]
      end
    end
  end
end
