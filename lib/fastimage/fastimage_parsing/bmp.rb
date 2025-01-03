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
  end
end
