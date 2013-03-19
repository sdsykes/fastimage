require 'rubygems'

require 'test/unit'

PathHere = File.dirname(__FILE__)

require File.join(PathHere, "..", "lib", 'fastimage')

require 'fakeweb'

FixturePath = File.join(PathHere, "fixtures")

GoodFixtures = {
  "test.bmp"=>[:bmp, [40, 27]],
  "test.gif"=>[:gif, [17, 32]],
  "test.jpg"=>[:jpeg, [882, 470]],
  "test.png"=>[:png, [30, 20]],
  "test2.jpg"=>[:jpeg, [250, 188]],
  "test3.jpg"=>[:jpeg, [630,367]]
  }

BadFixtures = [
  "faulty.jpg",
  "test.ico"
]

TestUrl = "http://example.nowhere/"

# this image fetch allows me to really test that fastimage is truly fast
# but it's not ideal relying on external resources and connectivity speed
LargeImage = "http://upload.wikimedia.org/wikipedia/commons/b/b4/Mardin_1350660_1350692_33_images.jpg"
LargeImageInfo = [:jpeg, [9545, 6623]]
LargeImageFetchLimit = 2  # seconds

GoodFixtures.each do |fn, info|
  FakeWeb.register_uri(:get, "#{TestUrl}#{fn}", :body => File.join(FixturePath, fn))
end
BadFixtures.each do |fn|
  FakeWeb.register_uri(:get, "#{TestUrl}#{fn}", :body => File.join(FixturePath, fn))
end

class FastImageTest < Test::Unit::TestCase
  def test_should_report_type_correctly
    GoodFixtures.each do |fn, info|
      assert_equal info[0], FastImage.type(TestUrl + fn)
      assert_equal info[0], FastImage.type(TestUrl + fn, :raise_on_failure=>true)
    end
  end

  def test_should_report_size_correctly
    GoodFixtures.each do |fn, info|
      assert_equal info[1], FastImage.size(TestUrl + fn)
      assert_equal info[1], FastImage.size(TestUrl + fn, :raise_on_failure=>true)
    end    
  end

  def test_should_return_nil_on_fetch_failure
    assert_nil FastImage.size(TestUrl + "does_not_exist")
  end
  
  def test_should_return_nil_for_faulty_jpeg_where_size_cannot_be_found
    assert_nil FastImage.size(TestUrl + "faulty.jpg")
  end

  def test_should_return_nil_when_image_type_not_known
    assert_nil FastImage.size(TestUrl + "test.ico")
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
      FastImage.size(TestUrl + "test.ico", :raise_on_failure=>true)
    end
  end
  
  def test_should_report_type_correctly_for_local_files
    GoodFixtures.each do |fn, info|
      assert_equal info[0], FastImage.type(File.join(FixturePath, fn))
    end    
  end
  
  def test_should_report_size_correctly_for_local_files
    GoodFixtures.each do |fn, info|
      assert_equal info[1], FastImage.size(File.join(FixturePath, fn))
    end    
  end

  def test_should_report_type_correctly_for_ios
    GoodFixtures.each do |fn, info|
      File.open(File.join(FixturePath, fn), "r") do |io|
        assert_equal info[0], FastImage.type(io)
      end
    end
  end
  
  def test_should_report_size_correctly_for_ios
    GoodFixtures.each do |fn, info|
      File.open(File.join(FixturePath, fn), "r") do |io|
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
    assert_nil FastImage.size(File.join(FixturePath, "test.ico"))
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
end
