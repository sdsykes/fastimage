module FastImageParsing
  class Png < ImageBase # :nodoc:
    def dimensions
      @stream.read(25)[16..24].unpack('NN')
    end
  end
end
