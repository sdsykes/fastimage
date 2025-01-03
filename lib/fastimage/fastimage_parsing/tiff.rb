module FastImageParsing
  class Tiff < ImageBase # :nodoc:
    def initialize(stream)
      @stream = stream
    end
  
    def dimensions
      exif = Exif.new(@stream)
      if exif.rotated?
        [exif.height, exif.width, exif.orientation]
      else
        [exif.width, exif.height, exif.orientation]
      end
    end
  end
end
