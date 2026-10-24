module FastImageParsing
  class Bmp < ImageBase # :nodoc:
    def dimensions
      d = @stream.read(32)[14..28]
      header = d.unpack("C")[0]

      result = if header == 12
                 d[4..8].unpack('SS')
               else
                 d[4..-1].unpack('l<l<')
               end

      # ImageHeight is expressed in pixels. The absolute value is necessary because ImageHeight can be negative
      [result.first, result.last.abs]
    end

    def resolution
      data = @stream.read(46)
      header_size = data[14, 4].unpack("V")[0]
      return nil if header_size < 40 # BITMAPCOREHEADER has no resolution fields

      x_ppm, y_ppm = data[38, 8].unpack("l<l<")
      return nil if x_ppm == 0 && y_ppm == 0

      [[x_ppm, y_ppm], :meters]
    end
  end
end
