require 'erb'
require 'json'
require 'fileutils'

DIR = File.expand_path(File.dirname(__FILE__))
SITE_NAME='bluemeanie'
DEBUG=false

folder_html_erb_filename = File.join(DIR, 'folder.html.erb')
FOLDER_ERB = ERB.new(IO.read(folder_html_erb_filename))
FOLDER_ERB.filename = folder_html_erb_filename

album_html_erb_filename = File.join(DIR, 'album.html.erb')
ALBUM_ERB = ERB.new(IO.read(album_html_erb_filename))
ALBUM_ERB.filename = album_html_erb_filename

FOLDERS = {}
ALBUMS = {}
IMAGES = {}

# Image Template Data class
class Image
  attr_reader :parent
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
      @images[:tiny] = image_name if image_name.end_with?('-Ti.jpg') || image_name.end_with?('-Ti.gif') || image_name.end_with?('-Ti.png')
      @images[:thumbnail] = image_name if image_name.end_with?('-Th.jpg') || image_name.end_with?('-Th.gif') || image_name.end_with?('-Th.png')
      @images[:small] = image_name if image_name.end_with?('-S.jpg') || image_name.end_with?('-S.gif') || image_name.end_with?('-S.png')
      @images[:medium] = image_name if image_name.end_with?('-M.jpg') || image_name.end_with?('-M.gif') || image_name.end_with?('-M.png')
      @images[:large] = image_name if image_name.end_with?('-L.jpg') || image_name.end_with?('-L.gif') || image_name.end_with?('-L.png')
      @images[:extra_large] = image_name if image_name.end_with?('-XL.jpg') || image_name.end_with?('-XL.gif') || image_name.end_with?('-XL.png')
      @images[:extra_large2] = image_name if image_name.end_with?('-X2.jpg') || image_name.end_with?('-X2.gif') || image_name.end_with?('-X2.png')
      @images[:extra_large3] = image_name if image_name.end_with?('-X3.jpg') || image_name.end_with?('-X3.gif') || image_name.end_with?('-X3.png')
      @images[:original] = image_name if image_name.end_with?('-Original.jpg') || image_name.end_with?('-Original.gif') || image_name.end_with?('-Original.png')
    end
    @parent = nil
  end

  def register_parent(parent)
    @parent = parent
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

  def highlight_image_html
    <<HTML
<li>
    <a href="#{self.image_key}.html">
      <img src="#{self.highlight_local_image_path}" alt="#{self.title}">
      <div class="overlay"><span>#{self.title}</span></div>
    </a>
</li>
HTML
  end
end

class Container
  def generate_breadcrumbs
    links = []
    back_path = ""

    node = self
    while node
      if node.parent.nil?
        links << "<a href=\"#{back_path}\"><i class=\"fa fa-home\" aria-hidden=\"true\"></i></a>\n"
      else
        links << "<a href=\"#{back_path}\"> #{node.name}</a>\n"
        back_path = "#{back_path}../"
      end
      node = node.parent
    end

    links.reverse.join('<i class="fa fa-caret-right" aria-hidden="true"></i>' + "\n")
  end

  def highlight_image_html
    <<HTML
<li>
    <a href="#{self.url_name}">
      <img src="#{self.url_name}/#{self.highlight_image.highlight_local_image_path}" alt="#{self.name}">
      <div class="overlay"><span title="#{self.title}">#{self.name}</span></div>
    </a>
</li>
HTML
  end
end

# Album Template Data class
class Album < Container

  attr_reader :parent
  attr_reader :node_id
  attr_reader :name
  attr_reader :description
  attr_reader :privacy
  attr_reader :keywords
  attr_reader :url_name
  attr_reader :url_path
  attr_reader :date_added
  attr_reader :highlight_image
  attr_reader :images

  def initialize(node_id, name, description, privacy, keywords, url_name, url_path, date_added, highlight_image, images)
    @node_id, @name, @description, @privacy, @keywords, @url_name, @url_path, @date_added, @highlight_image, @images =
      node_id, name, description, privacy, keywords, url_name, url_path, date_added, highlight_image, images
    @parent = nil
  end

  def register_parent(parent)
    @parent = parent
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

  def path_to_root
    ('../' * (url_path[1..].count('/') + 1))
  end
end

# Folder Template Data class
class Folder < Container
  attr_reader :parent
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
    @name = nil if @name.chop.empty?
    @description = nil if @description.chop.empty?
    @parent = nil
  end

  def register_parent(parent)
    @parent = parent
  end

  def is_root?
    self.url_path == '/'
  end

  def path_to_root
    return '' if is_root?
    ('../' * (url_path[1..].count('/') + 1))
  end

  def subfolders
    self.children.select{|c|c.is_a?(Folder)}
  end

  def public_subfolders
    # "privacy": "Public",
    self.subfolders.select{|c| 'Public' == c.privacy }
  end

  def albums
    self.children.select{|c|c.is_a?(Album)}
  end

  def public_albums
    self.albums.select{|c| 'Public' == c.privacy }
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

  puts "Loading Folder : #{path.gsub("#{DIR}/", '')}" if DEBUG
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

  folder = Folder.new(data['node_id'], data['name'], data['description'],
                          data['privacy'], data['keywords'],
                          data['url_name'], data['url_path'], data['date_added'],
                          IMAGES[data['highlight_image_key']],
                          children)

  children.each do |child|
    child.register_parent(folder)
  end

  FOLDERS[path] = folder
end

def load_image(url_path, image_name, path)
  puts "Loading Image : #{path.gsub("#{DIR}/", '')}/#{image_name}" if DEBUG
  image_data = JSON.load(IO.read(File.join(path, "#{image_name}.json")))
  IMAGES[image_name] = Image.new(image_data['image_key'], url_path, image_data['title'],
                                 image_data['caption'], image_data['keywords'],
                                 image_data['latitude'], image_data['longitude'],
                                 image_data['altitude'], image_data['hidden'],
                                 image_data['filename'], image_data['date_time_uploaded'],
                                 image_data['original_height'], image_data['original_width'],
                                 image_data['original_size'], image_data['images'],
                                 image_data['date_time_original'])
end

def load_album(path)
  album_path = File.join(path, 'album.json')
  puts "Loading Album  : #{path.gsub("#{DIR}/", '')}" if DEBUG
  raise "Duplicate Album  : #{path}" if FOLDERS.key?(path)
  data = JSON.load(IO.read(album_path))

  images = []
  data['images'].each do |image_name|
    images << load_image(data['url_path'], image_name, path)
  end

  load_image(data['url_path'], data['highlight_image_key'], path) unless IMAGES[data['highlight_image_key']]

  album = Album.new(data['node_id'], data['name'], data['description'],
                        data['privacy'], data['keywords'],
                        data['url_name'], data['url_path'], data['date_added'],
                        IMAGES[data['highlight_image_key']],
                        images)
  images.each do |image|
    image.register_parent(album)
  end
  ALBUMS[path] = album
end

def generate_folder(folder)
  output_dir = File.join(DIR, SITE_NAME, folder.url_path)
  output_path = File.join(output_dir, 'index.html')

  puts "Generating Folder : #{folder.url_path[1...]}" if DEBUG

  output = FOLDER_ERB.result_with_hash(:folder => folder)

  FileUtils.mkdir_p(output_dir)
  IO.write(output_path, output)

  folder.subfolders.each do |subfolder|
    generate_folder(subfolder)
  end

  folder.albums.each do |album|
    generate_album(album)
  end
end

def generate_album(album)
  output_dir = File.join(DIR, SITE_NAME, album.url_path)
  output_path = File.join(output_dir, 'index.html')

  puts "Generating Album  : #{album.url_path[1...]}" if DEBUG

  output = ALBUM_ERB.result_with_hash(:album => album)

  FileUtils.mkdir_p(output_dir)
  IO.write(output_path, output)

  album.images.each do |images|
    #generate_image(images)
  end
end

root_folder = load_folder(File.join(DIR, SITE_NAME))
generate_folder(root_folder)
