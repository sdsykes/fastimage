module FastImageParsing
  class Webp < ImageBase # :nodoc:
    def dimensions
      vp8 = @stream.read(16)[12..15]
      _len = @stream.read(4).unpack("V")
      case vp8
      when "VP8 "
        parse_size_vp8
      when "VP8L"
        parse_size_vp8l
      when "VP8X"
        parse_size_vp8x
      else
        nil
      end
    end
    
    def animated?
      vp8 = @stream.read(16)[12..15]
      _len = @stream.read(4).unpack("V")
      case vp8
      when "VP8 "
        false
      when "VP8L"
        false
      when "VP8X"
        flags = @stream.read(4).unpack("C")[0]
        flags & 2 > 0
      else
        nil
      end
    end
    
    private
  
    def parse_size_vp8
      w, h = @stream.read(10).unpack("@6vv")
      [w & 0x3fff, h & 0x3fff]
    end

    def parse_size_vp8l
      @stream.skip(1) # 0x2f
      b1, b2, b3, b4 = @stream.read(4).bytes.to_a
      [1 + (((b2 & 0x3f) << 8) | b1), 1 + (((b4 & 0xF) << 10) | (b3 << 2) | ((b2 & 0xC0) >> 6))]
    end

    def parse_size_vp8x
      flags = @stream.read(4).unpack("C")[0]
      b1, b2, b3, b4, b5, b6 = @stream.read(6).unpack("CCCCCC")
      width, height = 1 + b1 + (b2 << 8) + (b3 << 16), 1 + b4 + (b5 << 8) + (b6 << 16)

      if flags & 8 > 0 # exif
        # parse exif for orientation
        # TODO: find or create test images for this
      end

      [width, height]
    end
  end
end
