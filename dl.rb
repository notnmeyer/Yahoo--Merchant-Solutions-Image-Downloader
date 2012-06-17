#!/usr/bin/env ruby

require 'rubygems'
require 'optparse'
require 'curb'
require 'nokogiri'
require 'active_support/all'

# parse args
options = {}
OptionParser.new do |opts|
  opts.on( "-s",
           "--storeid storeid", 
           "the store id we're fetching data from" ) do |storeid|
             options[:store] = storeid
           end
  opts.on( "-t", 
           "--threads threads", 
           Numeric, 
           "the number of concurrent image downloads", 
           "default: 100" ) do |threads|
             options[:threads] = threads
           end
end.parse!

class XmlParseDownloadZip
  attr_accessor :url_to_xml, :download, :folder, :zip_filename, :xml, :resources, :threads

  def initialize(url, store_id)
    @url = url
    @data_loc = 'data'
    @zip_filename = "#{store_id}.zip"
    @xml_filename = "catalog.xml"
    @folder = "#{@data_loc}/#{store_id}"
    @resources = []
    @time_of_init = Time.now
    @threads = []
    @log = Logger.new(STDOUT)

    setup_temp_directory
    download
  end

  def setup_temp_directory(data_loc = @data_loc, folder = @folder)
    Dir::mkdir("#{data_loc}") unless FileTest::directory? "#{data_loc}"
    Dir::mkdir("#{folder}") unless FileTest::directory? "#{folder}"
  end

  def download(path = @url, filename = @xml_filename)
    log_info "downloading #{filename}"
    Curl::Easy.download(path, "#{@folder}/#{filename}")
    log_info "wrote to #{folder}/#{filename}"
  rescue => e
    log_info "Couldn't download #{path} because :\n" + e.message
    # should be doing something here. if we cant grab an image, we should 
    # set it aside and try again later.
  end

  def download_resources( slice )
    # slice is the number of threads we are going to create
    # i see more "cant resolve host errors" if i raise this
    log_info "#{@resources.count} items preparing to download"
    @resources.each_slice(slice) do |resources|
      @threads << Thread.new {resources.each {|resource| download(resource[0], resource[1])}}
    end
    @threads.each{|thread| thread.join}
  end

  def parse
    @xml ||= Nokogiri::XML(file)
    yield @xml, @resources
  end
  
  def clean_up(file_path = "#{@folder}/#{@xml_filename}") 
    File.delete(file_path)
    #File.delete(@folder)
  rescue => e
      @log.info e.message
  end

  def zip(zip = @zip_filename)
    log_info "Zipping images"
    system "find #{@folder} | zip #{zip} -@"
    log_info "Done!"
  end

  protected

  def file
    @opened_file ||= File.open("#{@folder}/#{@xml_filename}")
  end
  
  def run_time
    age = (Time.now - @time_of_init)
    age.seconds unless age < 0.003
  end 
  
  def log_info(msg)
    @log.info "#{run_time} #{msg}"
  end
end

# main logic

store_id_regex = /^[0-9a-zA-Z\-]+$/
if options[:store] && options[:store].match( store_id_regex )
  @store_id = options[:store]
  url = "http://#{@store_id}.stores.yahoo.net/catalog.xml"
  extracted_image_fields = []

  parse_bot = XmlParseDownloadZip.new(url, @store_id)

  parse_bot.parse do |xml, resources|
    # get all image fields
    xml.css('Table[@ID]').each do |table_node|
      table_node.css('TableField[@ID]').each do |table_field_node|
        if table_field_node['Type'] == 'image'
          extracted_image_fields << table_field_node['ID']
        end
      end
    end   
    # alright, lets grab some images
    xml.css('Item[@ID]').each do |item_node|
      item_node.css('ItemField[@TableFieldID]').each do |item_field_node|
        extracted_image_fields.uniq.each do |image_field|
          if item_field_node['TableFieldID'] == image_field
            @image_name = item_node['ID'] + "-" + item_field_node['TableFieldID'] + ".gif"
            resources << [item_field_node['Value'][/http\:\/\/[0-9a-zA-Z\-\.\/_]+/], @image_name] \
              unless item_field_node['Value'].empty?
          end
        end   
      end
    end
  end
  parse_bot.download_resources( options[:threads] )
  parse_bot.clean_up
  parse_bot.zip
else
  raise "\nUsage: dl.rb -s/--storeid your_storeid -t/--threads number_of_concurrent_downloads\nCheck your Store ID  and try again."
end
