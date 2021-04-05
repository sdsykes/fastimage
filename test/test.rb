require 'test/unit'

PathHere = File.dirname(__FILE__)
$LOAD_PATH.unshift File.join(PathHere, "..", "lib")

require 'fastimage'
require 'fakeweb'

FixturePath = File.join(PathHere, "fixtures")

GoodFixtures = {
  "test.bmp"=>[:bmp, [40, 27]],
  "test2.bmp"=>[:bmp, [1920, 1080]],
  "test_coreheader.bmp"=>[:bmp, [40, 27]],
  "test_v5header.bmp"=>[:bmp, [40, 27]],
  "test.gif"=>[:gif, [17, 32]],
  "animated.gif"=>[:gif, [400, 400]],
  "animated_without_gct.gif"=>[:gif, [859, 478]],
  "test.jpg"=>[:jpeg, [882, 470]],
  "test.png"=>[:png, [30, 20]],
  "test2.jpg"=>[:jpeg, [250, 188]],
  "test3.jpg"=>[:jpeg, [630, 367]],
  "test4.jpg"=>[:jpeg, [1485, 1299]],
  "test.tiff"=>[:tiff, [85, 67]],
  "test2.tiff"=>[:tiff, [333, 225]],
  "test.psd"=>[:psd, [17, 32]],
  "exif_orientation.jpg"=>[:jpeg, [600, 450]],
  "infinite.jpg"=>[:jpeg, [160,240]],
  "orient_2.jpg"=>[:jpeg, [230,408]],
  "favicon.ico" => [:ico, [16, 16]],
  "favicon2.ico" => [:ico, [32, 32]],
  "man.ico" => [:ico, [256, 256]],
  "test.cur" => [:cur, [32, 32]],
  "webp_vp8x.webp" => [:webp, [386, 395]],
  "webp_vp8l.webp" => [:webp, [386, 395]],
  "webp_vp8.webp" => [:webp, [550, 368]],
  "test.svg" => [:svg, [200, 300]],
  "test_partial_viewport.svg" => [:svg, [860, 400]],
  "test2.svg" => [:svg, [366, 271]],
  "test3.svg" => [:svg, [255, 48]],
  "test4.svg" => [:svg, [271, 271]],
  "test5.svg" => [:svg, [255, 48]],
  "orient_6.jpg"=>[:jpeg, [1250,2500]],
  "heic/test.heic"=>[:heic, [700,476]],
  "heic/heic-empty.heic"=>[:heic, [3992,2992]],
  "heic/heic-iphone.heic"=>[:heic,[4032,3024]],
  "heic/heic-iphone7.heic"=>[:heic,[4032,3024]],
  "heic/heic-maybebroken.HEIC"=>[:heic,[4032,3024]],
  "heic/heic-single.heic"=>[:heif,[1440,960]],
  "heic/heic-collection.heic"=>[:heif,[1440,960]],
}

BadFixtures = [
  "faulty.jpg",
  "test_rgb.ct",
  "test.xml",
  "test2.xml",
  "a.CR2",
  "a.CRW",
]
# man.ico courtesy of http://www.iconseeker.com/search-icon/artists-valley-sample/business-man-blue.html
# test_rgb.ct courtesy of http://fileformats.archiveteam.org/wiki/Scitex_CT
# test.cur courtesy of http://mimidestino.deviantart.com/art/Clash-Of-Clans-Dragon-Cursor-s-Punteros-489070897

TestUrl = "http://example.nowhere/"

# this image fetch allows me to really test that fastimage is truly fast
# but it's not ideal relying on external resources and connectivity speed
LargeImage = "https://upload.wikimedia.org/wikipedia/commons/b/b4/Mardin_1350660_1350692_33_images.jpg"
LargeImageInfo = [:jpeg, [9545, 6623]]
LargeImageFetchLimit = 2  # seconds

HTTPSImage = "https://upload.wikimedia.org/wikipedia/commons/b/b4/Mardin_1350660_1350692_33_images.jpg"
HTTPSImageInfo = [:jpeg, [9545, 6623]]

DataUriImage = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAIAAAABCAYAAAD0In+KAAAAD0lEQVR42mNk+M9QzwAEAAmGAYCF+yOnAAAAAElFTkSuQmCC"
DataUriImageInfo = [:png, [2, 1]]
DataUriImageContentLength = 72

GoodFixtures.each do |fn, info|
  FakeWeb.register_uri(:get, "#{TestUrl}#{fn}", :body => File.join(FixturePath, fn))
end
BadFixtures.each do |fn|
  FakeWeb.register_uri(:get, "#{TestUrl}#{fn}", :body => File.join(FixturePath, fn))
end

GzipTestImg = "gzipped.jpg"
FakeWeb.register_uri(:get, "#{TestUrl}#{GzipTestImg}", :body => File.join(FixturePath, GzipTestImg), :content_encoding => "gzip")
GzipTestImgTruncated = "truncated_gzipped.jpg"
FakeWeb.register_uri(:get, "#{TestUrl}#{GzipTestImgTruncated}", :body => File.join(FixturePath, GzipTestImgTruncated), :content_encoding => "gzip")
GzipTestImgSize = [970, 450]

ExifDirectories = ["jpg", "tiff-ccitt-rle", "tiff-ccitt4", "tiff-jpeg6", "tiff-jpeg7", "tiff-lzw-bw", "tiff-lzw-color", "tiff-packbits-color"]
ExifDirectories.each do |d|
  1.upto(8) do |n|
    fn = "#{d}/ExifOrientation#{n}.#{d == "jpg" ? "jpg" : "tif"}"
    FakeWeb.register_uri(:get, "#{TestUrl}#{fn}", :body => File.join(FixturePath, "exif-orientation-testimages", fn))
  end
end

class FastImageTest < Test::Unit::TestCase
  def test_should_report_type_correctly
    GoodFixtures.each do |fn, info|
      assert_equal info[0], FastImage.type(TestUrl + fn), "type of image #{fn} must be #{info[0]}"
      assert_equal info[0], FastImage.type(TestUrl + fn, :raise_on_failure=>true), "type of image #{fn} must be #{info[0]}"
    end
  end

  def test_should_report_size_correctly
    GoodFixtures.each do |fn, info|
      assert_equal info[1], FastImage.size(TestUrl + fn), "size for #{fn} must be #{info[1]}"
      assert_equal info[1], FastImage.size(TestUrl + fn, :raise_on_failure=>true), "size for #{fn} must be #{info[1]}"
    end
  end

  def test_should_report_animated_correctly
    assert_equal nil, FastImage.animated?(TestUrl + "test.png")
    assert_equal false, FastImage.animated?(TestUrl + "test.gif")
    assert_equal true, FastImage.animated?(TestUrl + "animated.gif")
    assert_equal true, FastImage.animated?(TestUrl + "animated_without_gct.gif")
  end

  def test_should_return_nil_on_fetch_failure
    assert_nil FastImage.size(TestUrl + "does_not_exist")
  end

  def test_should_return_nil_for_faulty_jpeg_where_size_cannot_be_found
    assert_nil FastImage.size(TestUrl + "faulty.jpg")
  end

  def test_should_return_nil_when_image_type_not_known
    assert_nil FastImage.size(TestUrl + "test_rgb.ct")
  end

  def test_should_return_nil_if_timeout_occurs
    assert_nil FastImage.size("http://example.com/does_not_exist", :timeout=>0.001)
  end

  def test_should_raise_when_asked_to_when_size_cannot_be_found
    assert_raises(FastImage::SizeNotFound) do
      FastImage.size(TestUrl + "faulty.jpg", :raise_on_failure=>true)
    end
  end

  def test_should_raise_when_asked_to_when_timeout_occurs
    assert_raises(FastImage::ImageFetchFailure) do
      FastImage.size("http://example.com/does_not_exist", :timeout=>0.001, :raise_on_failure=>true)
    end
  end

  def test_should_raise_when_asked_to_when_file_does_not_exist
    assert_raises(FastImage::ImageFetchFailure) do
      FastImage.size("http://www.google.com/does_not_exist_at_all", :raise_on_failure=>true)
    end
  end

  def test_should_raise_when_asked_when_image_type_not_known
    assert_raises(FastImage::UnknownImageType) do
      FastImage.size(TestUrl + "test_rgb.ct", :raise_on_failure=>true)
    end
  end

  def test_should_raise_image_fetch_failure_error_if_net_unreach_exception_happens
    FakeWeb.register_uri(:get, "http://example.com", :exception => Errno::ENETUNREACH)

    assert_raises(FastImage::ImageFetchFailure) do
      FastImage.size("http://example.com", :raise_on_failure=>true)
    end
  end

  def test_should_raise_unknown_image_type_when_file_is_non_svg_xml
    ["test.xml", "test2.xml"].each do |fn|
      assert_raises(FastImage::UnknownImageType) do
        FastImage.size(TestUrl + fn, :raise_on_failure=>true)
      end
    end
  end

  def test_should_report_type_correctly_for_local_files
    GoodFixtures.each do |fn, info|
      assert_equal info[0], FastImage.type(File.join(FixturePath, fn)), "type of image #{fn} must be #{info[0]}"
    end
  end

  def test_should_report_size_correctly_for_local_files
    GoodFixtures.each do |fn, info|
      assert_equal info[1], FastImage.size(File.join(FixturePath, fn)), "size for #{fn} must be #{info[1]}"
    end
  end

  def test_should_report_content_length_correctly_for_local_files
    assert_equal 3296, FastImage.new(File.join(FixturePath, "test.bmp")).content_length
  end

  def test_should_report_type_correctly_for_ios
    GoodFixtures.each do |fn, info|
      File.open(File.join(FixturePath, fn), "r") do |io|
        assert_equal info[0], FastImage.type(io), "type of image #{fn} must be #{info[0]}"
      end
    end
  end

  def test_should_report_size_correctly_for_ios
    GoodFixtures.each do |fn, info|
      File.open(File.join(FixturePath, fn), "r") do |io|
        assert_equal info[1], FastImage.size(io), "size for #{fn} must be #{info[1]}"
      end
    end
  end

  def test_should_report_type_correctly_for_ios_that_have_been_read
    GoodFixtures.each do |fn, info|
      File.open(File.join(FixturePath, fn), "r") do |io|
        io.read
        assert_equal info[0], FastImage.type(io), "type of image #{fn} must be #{info[0]}"
      end
    end
  end

  def test_should_report_size_correctly_for_ios_that_have_been_read
    GoodFixtures.each do |fn, info|
      File.open(File.join(FixturePath, fn), "r") do |io|
        io.read
        assert_equal info[1], FastImage.size(io), "size for #{fn} must be #{info[1]}"
      end
    end
  end

  def test_should_report_size_correctly_on_io_object_twice
    GoodFixtures.each do |fn, info|
      File.open(File.join(FixturePath, fn), "r") do |io|
        assert_equal info[1], FastImage.size(io)
        assert_equal info[1], FastImage.size(io)
      end
    end
  end

  def test_should_report_size_correctly_for_local_files_with_path_that_has_spaces
    Dir.chdir(PathHere) do
      assert_equal GoodFixtures["test.bmp"][1], FastImage.size(File.join("fixtures", "folder with spaces", "test.bmp"))
    end
  end

  def test_should_return_nil_on_fetch_failure_for_local_path
    assert_nil FastImage.size("does_not_exist")
  end

  def test_should_return_nil_for_faulty_jpeg_where_size_cannot_be_found_for_local_file
    assert_nil FastImage.size(File.join(FixturePath, "faulty.jpg"))
  end

  def test_should_return_nil_when_image_type_not_known_for_local_file
    assert_nil FastImage.size(File.join(FixturePath, "test_rgb.ct"))
  end

  def test_should_raise_when_asked_to_when_size_cannot_be_found_for_local_file
    assert_raises(FastImage::SizeNotFound) do
      FastImage.size(File.join(FixturePath, "faulty.jpg"), :raise_on_failure=>true)
    end
  end

  def test_should_handle_permanent_redirect
    url = "http://example.com/foo.jpeg"
    register_redirect(url, TestUrl + GoodFixtures.keys.first)
    assert_equal GoodFixtures[GoodFixtures.keys.first][1], FastImage.size(url, :raise_on_failure=>true)
  end

  def test_should_handle_permanent_redirect_4_times
    first_url = "http://example.com/foo.jpeg"
    register_redirect(first_url, "http://example.com/foo2.jpeg")
    register_redirect("http://example.com/foo2.jpeg", "http://example.com/foo3.jpeg")
    register_redirect("http://example.com/foo3.jpeg", "http://example.com/foo4.jpeg")
    register_redirect("http://example.com/foo4.jpeg", TestUrl + GoodFixtures.keys.first)
    assert_equal GoodFixtures[GoodFixtures.keys.first][1], FastImage.size(first_url, :raise_on_failure=>true)
  end

  def test_should_raise_on_permanent_redirect_5_times
    first_url = "http://example.com/foo.jpeg"
    register_redirect(first_url, "http://example.com/foo2.jpeg")
    register_redirect("http://example.com/foo2.jpeg", "http://example.com/foo3.jpeg")
    register_redirect("http://example.com/foo3.jpeg", "http://example.com/foo4.jpeg")
    register_redirect("http://example.com/foo4.jpeg", "http://example.com/foo5.jpeg")
    register_redirect("http://example.com/foo5.jpeg", TestUrl + GoodFixtures.keys.first)
    assert_raises(FastImage::ImageFetchFailure) do
      FastImage.size(first_url, :raise_on_failure=>true)
    end
  end

  def test_should_handle_permanent_redirect_with_relative_url
    url = "http://example.nowhere/foo.jpeg"
    register_redirect(url, "/" + GoodFixtures.keys.first)
    assert_equal GoodFixtures[GoodFixtures.keys.first][1], FastImage.size(url, :raise_on_failure=>true)
  end

  def test_should_handle_permanent_redirect_with_protocol_relative_url
    url = "http://example.nowhere/foo.jpeg"
    register_redirect(url, "//example.nowhere/" + GoodFixtures.keys.first)
    assert_equal GoodFixtures[GoodFixtures.keys.first][1], FastImage.size(url, :raise_on_failure=>true)
  end

  def test_should_handle_permanent_redirect_with_complex_relative_url
    register_redirect(TestUrl, "/pho to.gne?rb=1&short=Vv4Und")
    register_redirect("#{TestUrl}pho%20to.gne?rb=1&short=Vv4Und", "/" + GoodFixtures.keys.first)
    assert_equal GoodFixtures[GoodFixtures.keys.first][1], FastImage.size(TestUrl, :raise_on_failure=>true)
  end

  def test_should_handle_permanent_redirect_with_encoded_url
    register_redirect(TestUrl, "/pho%20to.gne")
    register_redirect("#{TestUrl}pho%20to.gne", "/" + GoodFixtures.keys.first)
    assert_equal GoodFixtures[GoodFixtures.keys.first][1], FastImage.size(TestUrl, :raise_on_failure=>true)
  end

  def test_should_handle_permanent_redirect_with_missing_location
    register_redirect(TestUrl, nil)
    assert_raises(FastImage::ImageFetchFailure) do
      FastImage.size(TestUrl, :raise_on_failure=>true)
    end
  end

  def register_redirect(from, to)
    resp = Net::HTTPMovedPermanently.new(1.0, 302, "Moved")
    resp['Location'] = to
    FakeWeb.register_uri(:get, from, :response=>resp)
  end

  def test_should_fetch_info_of_large_image_faster_than_downloading_the_whole_thing
    time = Time.now
    size = FastImage.size(LargeImage)
    size_time = Time.now
    assert size_time - time < LargeImageFetchLimit
    assert_equal LargeImageInfo[1], size
    time = Time.now
    type = FastImage.type(LargeImage)
    type_time = Time.now
    assert type_time - time < LargeImageFetchLimit
    assert_equal LargeImageInfo[0], type
  end

  # This test doesn't actually test the proxy function, but at least
  # it excercises the code. You could put anything in the http_proxy and it would still pass.
  # Any ideas on how to actually test this?
  def test_should_fetch_via_proxy
    file = "test.gif"
    actual_size = GoodFixtures[file][1]
    ENV['http_proxy'] = "http://my.proxy.host:8080"
    size = FastImage.size(TestUrl + file)
    ENV['http_proxy'] = nil
    assert_equal actual_size, size
  end

  def test_should_fetch_via_proxy_option
    file = "test.gif"
    actual_size = GoodFixtures[file][1]
    size = FastImage.size(TestUrl + file, :proxy => "http://my.proxy.host:8080")
    assert_equal actual_size, size
  end

  def test_should_handle_https_image
    size = FastImage.size(HTTPSImage)
    assert_equal HTTPSImageInfo[1], size
  end

  require 'pathname'
  def test_should_handle_pathname
    # bad.jpg does not have the size info in the first 256 bytes
    # so this tests if we are able to read past that using a
    # Pathname (which has a different API from an IO).
    path = Pathname.new(File.join(FixturePath, "bad.jpg"))
    assert_equal([500,500], FastImage.size(path))
  end

  def test_should_report_type_and_size_correctly_for_stringios
    GoodFixtures.each do |fn, info|
      string = File.read(File.join(FixturePath, fn))
      stringio = StringIO.new(string)
      assert_equal info[0], FastImage.type(stringio)
      assert_equal info[1], FastImage.size(stringio)
    end
  end

  def test_should_rewind_ios
    string = File.read(File.join(FixturePath, "test.bmp"))
    stringio = StringIO.new(string)
    FastImage.type(stringio)
    assert_equal 0, stringio.pos

    string = File.read(File.join(FixturePath, "test.xml"))
    stringio = StringIO.new(string)
    FastImage.type(stringio)
    assert_equal 0, stringio.pos
  end

  def test_gzipped_file
    url = "http://example.nowhere/#{GzipTestImg}"
    assert_equal([970, 450], FastImage.size(url))
  end

  def test_truncated_gzipped_file
    url = "http://example.nowhere/#{GzipTestImgTruncated}"
    assert_raises(FastImage::SizeNotFound) do
      FastImage.size(url, :raise_on_failure => true)
    end
  end

  def test_cant_access_shell
    url = "|echo>shell_test"
    %x{rm -f shell_test}
    FastImage.size(url)
    assert_raises(Errno::ENOENT) do
      File.open("shell_test")
    end
  ensure
    %x{rm -f shell_test}
  end

  def test_content_length
    url = "#{TestUrl}with_content_length.gif"
    FakeWeb.register_uri(:get, url, :body => File.join(FixturePath, "test.jpg"), :content_length => 52)

    assert_equal 52, FastImage.new(url).content_length
  end

  def test_content_length_not_provided
    url = "#{TestUrl}without_content_length.gif"
    FakeWeb.register_uri(:get, url, :body => File.join(FixturePath, "test.jpg"))

    assert_equal nil, FastImage.new(url).content_length
  end

  def test_should_return_correct_exif_orientation
    ExifDirectories.each do |d|
      1.upto(8) do |n|
        fn = "#{d}/ExifOrientation#{n}.#{d == "jpg" ? "jpg" : "tif"}"
        url = "#{TestUrl}#{fn}"
        fi = FastImage.new(url)
        assert_equal [1240, 1754], fi.size
        assert_equal n, fi.orientation
      end
    end
  end

  def test_should_return_orientation_1_when_exif_not_present
    url = "#{TestUrl}test.gif"
    assert_equal 1, FastImage.new(url).orientation
  end

  def test_should_raise_when_handling_invalid_ico_files
    stringio = StringIO.new("\x00\x00003")
    assert_raises(FastImage::UnknownImageType) do
      FastImage.type(stringio, :raise_on_failure => true)
    end
  end

  def test_should_support_data_uri_scheme_images
    assert_equal DataUriImageInfo[0], FastImage.type(DataUriImage)
    assert_equal DataUriImageInfo[1], FastImage.size(DataUriImage)
    assert_raises(FastImage::ImageFetchFailure) do
      FastImage.type("data:", :raise_on_failure => true)
    end
  end

  def test_should_work_with_domains_with_underscores
    assert_equal :gif, FastImage.type("http://foo_bar.switchstep.com/images/p.gif")
  end

  def test_should_return_content_length_for_data_uri_images
    assert_equal DataUriImageContentLength, FastImage.new(DataUriImage).content_length
  end

  def test_canon_raw_formats_are_not_recognised_as_tiff
    assert_raises(FastImage::UnknownImageType) do
      FastImage.size(TestUrl + "a.CR2", :raise_on_failure=>true)
    end
    assert_raises(FastImage::UnknownImageType) do
      FastImage.size(TestUrl + "a.CRW", :raise_on_failure=>true)
    end
  end
end
