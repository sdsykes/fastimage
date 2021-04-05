module FastImageParsing
  class Gif < ImageBase # :nodoc:  
    def dimensions
      @stream.read(11)[6..10].unpack('SS')
    end
  
    # Checks for multiple frames
    def animated?
      frames = 0
  
      # "GIF" + version (3) + width (2) + height (2)
      @stream.skip(10)
  
      # fields (1) + bg color (1) + pixel ratio (1)
      fields = @stream.read(3).unpack("CCC")[0]
      if fields & 0x80 != 0 # Global Color Table
        # 2 * (depth + 1) colors, each occupying 3 bytes (RGB)
        @stream.skip(3 * 2 ** ((fields & 0x7) + 1))
      end
  
      loop do
        block_type = @stream.read(1).unpack("C")[0]
  
        if block_type == 0x21 # Graphic Control Extension
          # extension type (1) + size (1)
          size = @stream.read(2).unpack("CC")[1]
          @stream.skip(size)
          skip_sub_blocks
        elsif block_type == 0x2C # Image Descriptor
          frames += 1
          return true if frames > 1
  
          # left position (2) + top position (2) + width (2) + height (2) + fields (1)
          fields = @stream.read(9).unpack("SSSSC")[4]
          if fields & 0x80 != 0 # Local Color Table
            # 2 * (depth + 1) colors, each occupying 3 bytes (RGB)
            @stream.skip(3 * 2 ** ((fields & 0x7) + 1))
          end
  
          @stream.skip(1) # LZW min code size (1)
          skip_sub_blocks
        else
          break # unrecognized block
        end
      end
  
      false
    end
  
    private
  
    def skip_sub_blocks
      loop do
        size = @stream.read(1).unpack("C")[0]
        if size == 0
          break
        else
          @stream.skip(size)
        end
      end
    end
  end
end
