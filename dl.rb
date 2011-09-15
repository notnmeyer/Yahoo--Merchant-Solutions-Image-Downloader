#!/bin/env ruby

require 'rubygems'
require 'curb'
require 'nokogiri'
require 'active_support/all'

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
    Curl::Easy.download(path, "#{@folder}/#{filename}")
    @log.info "[#{(Time.now - @time_of_init).seconds}] wrote to #{folder}/#{filename}"
  rescue => e
    @log.info "*** Couldn't download #{path} because :\n" + e.message
  end

  def download_resources
    slice = 75
    @resources.each_slice(slice) do |resources|
      @threads << Thread.new {resources.each {|resource| download(resource[0], resource[1])}}
      #@log.info "[#{(Time.now - @time_of_init).seconds}] Queuing more chunks."
    end
    @threads.each{|thread| thread.join}
  end

  def parse
    @xml ||= Nokogiri::XML(file)
    yield @xml, @resources
  end
  
  def clean_up(file_path = "#{@folder}/#{@xml_filename}") 
    File.delete(file_path)
  rescue => e
      @log.info e.message
  end

  def zip(zip = @zip_filename)
    @log.info "Zipping images"
    system "find #{@folder} | zip #{zip} -@"
    @log.info "Done in #{(Time.now - @time_of_init).seconds} seconds."
  end

  protected

  def file
    @opened_file ||= File.open("#{@folder}/#{@xml_filename}")
  end
end

if ARGV.count > 0 && ARGV[0].match(/^[0-9a-zA-Z\-]+$/)
  @store_id = ARGV[0]
  url = "http://#{@store_id}.stores.yahoo.net/catalog.xml"
  parse_bot = XmlParseDownloadZip.new(url, @store_id)

  parse_bot.parse do |xml, resources|
    # start by getting the default image fields: image, icon, inset
    xml.css('Item[@ID]').each do |item_node|
      item_node.css('ItemField[@TableFieldID]').each do |item_field_node|
        case item_field_node['TableFieldID']
        when 'image', 'icon', 'inset'
          @image_name = item_node['ID'] + "-" + item_field_node['TableFieldID'] + ".gif"
          resources << [item_field_node['Value'][/http\:\/\/[0-9a-zA-Z\-\.\/_]+/], @image_name] unless item_field_node['Value'].empty?
        end
      end
    end

    # lets get the custom image fields
    xml.css('Table[@ID]').each do |table_node|
      table_node.css('TableField[@ID]').each do |table_field_node|
        case table_field_node['Type']
        when 'image'
          #puts table_field_node['ID'] # finds all image fields in all tables, need to exclude default fields.
        end
      end
    end
  end

  parse_bot.download_resources
  parse_bot.clean_up
  parse_bot.zip
else
  raise "\nUsage: ruby dl.rb store_id\nCheck your Store ID  and try again."
end
