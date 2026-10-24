module FastImageParsing
  class Png < ImageBase # :nodoc:
    def dimensions
      @stream.read(25)[16..24].unpack('NN')
    end

    def resolution
      # Signature (8) + IHDR chunk (4 + 4 + 13 + 4 = 25 bytes)
      @stream.read(33)

      loop do
        length = @stream.read(4).unpack("L>")[0]
        type = @stream.read(4)

        case type
        when "pHYs"
          data = @stream.read(9)
          x_ppu, y_ppu = data[0, 8].unpack("NN")
          unit = data[8].ord
          unit_sym = unit == 1 ? :meters : :no_units
          return [[x_ppu, y_ppu], unit_sym]
        when "IDAT", "IEND"
          return nil
        end

        @stream.skip(length + 4) # skip chunk data + CRC
      end
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
