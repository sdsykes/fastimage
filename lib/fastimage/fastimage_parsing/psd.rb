module FastImageParsing
  class Psd < ImageBase # :nodoc:
    def dimensions
      @stream.read(26).unpack("x14NN").reverse
    end
  end
end
