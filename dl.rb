#!/usr/bin/env ruby

require 'rubygems'
require 'curb'
require 'nokogiri'

#check for a command line arg
if ARGV.count == 1
  store_id = ARGV[0]
else
  raise "Incorrect argument count.\nArgument count: #{ARGV.count}\nUsage: ruby dl.rb store-id"
end

#extracts a URL from an image tag
def parseImageUrl(data)
   data.scan(/http\:\/\/[0-9a-zA-Z\-\.\/_]+/)[0]
end
  
def download(url, filename)
  begin 
    curl = Curl::Easy.download(url, filename)
  rescue => e
    puts "Couldn't download #{filename} because: " + e.message
  else 
    puts "Wrote to #{filename}"
  end
end

def setupDir(store)
  if !FileTest::directory?("data/" + store)
    begin
      Dir::mkdir("data/" + store)
    rescue => e
      puts "Failed to create directory data/#{store}: " + e.message
    end
  end
end

catalogUrl = "http://" + store_id + ".stores.yahoo.net/catalog.xml"
filename = store_id + ".xml"
fullPath = "data/#{store_id}/#{filename}"

# create the file path
setupDir(store_id)

# download the xml
puts "Attempting to download #{catalogUrl}"
download(catalogUrl, fullPath)

#parse it
puts "Reading #{filename}"

@file_handle = File.open(fullPath)
@xml = Nokogiri::XML(@file_handle)

#get items
@xml.css('Item[@ID]').each do |item_node|
  item_node.css('ItemField[@TableFieldID]').each do |item_field_node|
    if item_field_node['TableFieldID'] == 'image'
      if item_field_node['Value'].empty?
        puts "#{item_node['ID']} has a nil image"
      else
        boom = parseImageUrl(item_field_node['Value'])
        imagePath = "data/" + store_id + "/" + item_node['ID'] + ".gif"
        download(boom, imagePath)
      end
    end
  end
end

@file_handle.close

#don't need the xml file anymore
begin 
  File.delete(fullPath)
rescue => e
  puts "Failed to delete the file #{fullPath} because: " + e.message
end

#zip images
puts "Zipping images"
exec("find data/#{store_id}/ | zip #{store_id}.zip -@")
puts "Done zipping images. You can find the file at path_to_dl.rb/#{store_id}.zip"
