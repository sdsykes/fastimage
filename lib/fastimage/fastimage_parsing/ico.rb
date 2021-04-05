module FastImageParsing
  class Ico < ImageBase
    def dimensions
      icons = @stream.read(6)[4..5].unpack('v').first
      sizes = icons.times.map { @stream.read(16).unpack('C2').map { |x| x == 0 ? 256 : x } }.sort_by { |w,h| w * h }
      sizes.last
    end
  end
end
