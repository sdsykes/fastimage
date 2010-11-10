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
end
