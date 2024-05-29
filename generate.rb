require 'erb'
require 'json'

DIR = File.expand_path(File.dirname(__FILE__))

paths = ['bluemeanie']

while paths.length > 0 do
  path = paths.pop
  full_path = File.join(DIR, path)
  folder_path = File.join(full_path, 'folder.json')
  album_path = File.join(full_path, 'album.json')
  if File.exist?(folder_path)
    data = JSON.load(IO.read(folder_path))
    puts "Generating Folder #{album_path}"
    paths.append(data['child_nodes'].collect{|n| File.join(full_path,n)})
  elsif File.exist?(album_path)
    data = JSON.load(IO.read(album_path))
    puts "Generating Album #{album_path}"
  else
    raise "Failed to process path #{full_path}"
  end
end
