require 'erb'
require 'json'
require 'fileutils'

DIR = File.expand_path(File.dirname(__FILE__))
SITE_NAME='bluemeanie'


FOLDERS = {}
ALBUMS = {}
IMAGES = {}

# Image Template Data class
class Image
  attr_reader :image_key
  attr_reader :title
  attr_reader :caption
  attr_reader :keywords
  attr_reader :latitude
  attr_reader :longitude
  attr_reader :altitude
  attr_reader :hidden
  attr_reader :filename
  attr_reader :date_time_uploaded
  attr_reader :original_height
  attr_reader :original_width
  attr_reader :original_size
  attr_reader :date_time_original

  def initialize(image_key, path, title, caption, keywords, latitude, longitude, altitude, hidden, filename, date_time_uploaded, original_height, original_width, original_size, images, date_time_original)
    @image_key, @path, @title, @caption, @keywords, @latitude, @longitude, @altitude, @hidden, @filename, @date_time_uploaded, @original_height, @original_width, @original_size, @date_time_original =
      image_key, path, title, caption, keywords, latitude, longitude, altitude, hidden, filename, date_time_uploaded, original_height, original_width, original_size, date_time_original
    @images = {}
    images.each do |image_name|
      @images[:tiny] = image_name if image_name.end_with?('-Ti.jpg') || image_name.end_with?('-Ti.gif')
      @images[:thumbnail] = image_name if image_name.end_with?('-Th.jpg') || image_name.end_with?('-Th.gif')
      @images[:small] = image_name if image_name.end_with?('-S.jpg') || image_name.end_with?('-S.gif')
      @images[:medium] = image_name if image_name.end_with?('-M.jpg') || image_name.end_with?('-M.gif')
      @images[:large] = image_name if image_name.end_with?('-L.jpg') || image_name.end_with?('-L.gif')
      @images[:extra_large] = image_name if image_name.end_with?('-XL.jpg') || image_name.end_with?('-XL.gif')
      @images[:extra_large2] = image_name if image_name.end_with?('-X2.jpg') || image_name.end_with?('-X2.gif')
      @images[:extra_large3] = image_name if image_name.end_with?('-X3.jpg') || image_name.end_with?('-X3.gif')
      @images[:original] = image_name if image_name.end_with?('-Original.jpg') || image_name.end_with?('-Original.gif')
    end
  end

  def size_present?(size)
    !!@images[size]
  end

  def local_image_path(size)
    raise "Unable to locate image of size #{size}" unless size_present?(size)
    @images[size]
  end

  def image_path(size)
    raise "Unable to locate image of size #{size} for image #{image_key} at #{@path}" unless size_present?(size)
    "#{@path[1...]}/#{@images[size]}"
  end

  def highlight_local_image_path
    return local_image_path(:small) if size_present?(:small)
    return local_image_path(:thumbnail) if size_present?(:thumbnail)
    return local_image_path(:tiny) if size_present?(:tiny)
    image_path(:original)
  end

  def highlight_image_path
    return image_path(:small) if size_present?(:small)
    return image_path(:thumbnail) if size_present?(:thumbnail)
    return image_path(:tiny) if size_present?(:tiny)
    image_path(:original)
  end
end

# Album Template Data class
class Album
  attr_reader :node_id
  attr_reader :name
  attr_reader :description
  attr_reader :privacy
  attr_reader :keywords
  attr_reader :url_name
  attr_reader :url_path
  attr_reader :date_added
  attr_reader :highlight_image

  def initialize(node_id, name, description, privacy, keywords, url_name, url_path, date_added, highlight_image)
    @node_id, @name, @description, @privacy, @keywords, @url_name, @url_path, @date_added, @highlight_image =
      node_id, name, description, privacy, keywords, url_name, url_path, date_added, highlight_image
  end

  def title
    if self.name
      if self.description
        return "#{self.name}: #{self.description}"
      else
        return self.name
      end
    elsif self.description
      return self.description
    else
      ''
    end
  end
end

# Folder Template Data class
class Folder
  attr_reader :node_id
  attr_reader :name
  attr_reader :description
  attr_reader :privacy
  attr_reader :keywords
  attr_reader :url_name
  attr_reader :url_path
  attr_reader :date_added
  attr_reader :highlight_image
  attr_reader :children

  def initialize(node_id, name, description, privacy, keywords, url_name, url_path, date_added, highlight_image, children)
    @node_id, @name, @description, @privacy, @keywords, @url_name, @url_path, @date_added, @highlight_image, @children =
      node_id, name, description, privacy, keywords, url_name, url_path, date_added, highlight_image, children
  end

  def path_to_root
    '../' * (url_path.count('/') - 1)
  end

  def title
    if self.name
      if self.description
        return "#{self.name}: #{self.description}"
      else
        return self.name
      end
    elsif self.description
      return self.description
    else
      ''
    end
  end
end

def load_folder(path)
  folder_path = File.join(path, 'folder.json')
  return nil unless File.exist?(folder_path)

  puts "Loading Folder : #{path.gsub("#{DIR}/", '')}"
  raise "Duplicate Folder : #{path}" if FOLDERS.key?(path)
  data = JSON.load(IO.read(folder_path))

  children = []
  data['child_nodes'].each do |child_name|
    child_folder_path = File.join(path, child_name, 'folder.json')
    if File.exist?(child_folder_path)
      children << load_folder(File.join(path, child_name))
    else
      children << load_album(File.join(path, child_name))
    end
  end

  FOLDERS[path] = Folder.new(data['node_id'], data['name'], data['description'],
                             data['privacy'], data['keywords'],
                             data['url_name'], data['url_path'], data['date_added'],
                             IMAGES[data['highlight_image_key']],
                             children)
end

def load_album(path)
  album_path = File.join(path, 'album.json')
  puts "Loading Album  : #{path.gsub("#{DIR}/", '')}"
  raise "Duplicate Album  : #{path}" if FOLDERS.key?(path)
  data = JSON.load(IO.read(album_path))

  data['images'].each do |image_name|
    # puts "Loading Image : #{path.gsub("#{DIR}/", '')}/#{image_name}"
    image_data = JSON.load(IO.read(File.join(path, "#{image_name}.json")))
    IMAGES[image_name] = Image.new(image_data['image_key'], data['url_path'], image_data['title'],
                                   image_data['caption'], image_data['keywords'],
                                   image_data['latitude'], image_data['longitude'],
                                   image_data['altitude'], image_data['hidden'],
                                   image_data['filename'], image_data['date_time_uploaded'],
                                   image_data['original_height'], image_data['original_width'],
                                   image_data['original_size'], image_data['images'],
                                   image_data['date_time_original'])
  end

  highlight_image = IMAGES[data['highlight_image_key']]
  ALBUMS[path] = Album.new(data['node_id'], data['name'], data['description'],
                           data['privacy'], data['keywords'],
                           data['url_name'], data['url_path'], data['date_added'],
                           highlight_image)
end

root_folder = load_folder(File.join(DIR, SITE_NAME))
