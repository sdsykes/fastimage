module FastImageParsing
  class Png < ImageBase # :nodoc:
    def dimensions
      @stream.read(25)[16..24].unpack('NN')
    end
    
    def animated?
      # Signature (8) + IHDR chunk (4 + 4 + 13 + 4)
      @stream.read(33)

      loop do
        length = @stream.read(4).unpack("L>")[0]
        type = @stream.read(4)

        case type
        when "acTL"
          return true
        when "IDAT"
          return false
        end

        @stream.skip(length + 4)
      end
    end
  end
end
