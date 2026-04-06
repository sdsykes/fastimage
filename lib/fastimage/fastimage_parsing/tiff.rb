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

    def resolution
      exif = Exif.new(@stream, parse_resolution: true)
      return nil unless exif.x_resolution && exif.y_resolution

      unit_sym = case exif.resolution_unit
      when Exif::RESOLUTION_UNIT_NO_UNITS    then :no_units
      when Exif::RESOLUTION_UNIT_CENTIMETERS then :centimeters
      else :inches # TIFF default is 2 (inch) when tag is absent
      end

      [[exif.x_resolution, exif.y_resolution], unit_sym]
    end
  end
end
