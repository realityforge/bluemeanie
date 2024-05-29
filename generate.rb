require 'erb'
require 'json'

DIR = File.expand_path(File.dirname(__FILE__))

paths = [File.join(DIR, 'bluemeanie')]

while paths.length > 0 do
  path = paths.pop
  folder_path = File.join(path, 'folder.json')
  album_path = File.join(path, 'album.json')
  if File.exist?(folder_path)
    puts "Generating Folder : #{path.gsub(DIR, '')}"
    data = JSON.load(IO.read(folder_path))
    paths.append(*data['child_nodes'].collect{|n|File.join(path, n)})
  elsif File.exist?(album_path)
    puts "Generating Album  : #{path.gsub(DIR, '')}"
    data = JSON.load(IO.read(album_path))
  else
    raise "Failed to process path #{path.gsub(DIR, '')}"
  end
end
