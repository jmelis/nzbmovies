#!/usr/bin/env ruby

require 'nokogiri'
require 'open-uri'
require 'pp'
require 'awesome_print'
require 'imdb'
require 'mongo'

@conn = Mongo::Connection.new
@db   = @conn['nzbmovies']

@coll_imdb      = @db['imdb']
@coll_nzbmovie  = @db['nzbmovie']

USER, API_KEY = File.read('api.txt').split(':')

def nzbmatrix_info(id)
    url  = "http://api.nzbmatrix.com/v1.1/details.php?id=#{id}&username=#{USER}&apikey=#{API_KEY}"

    info_request = open(url)

    info = Hash.new
    info_request.read.split("\n").each do |line|
        key, value = line.split(":",2)
        key = key.downcase.to_sym
        value = value.gsub(/;$/,"")
        info[key] = value
    end
    info
end

def imdb_info(imdb_id)
    info = Hash.new
    movie = Imdb::Movie.new(imdb_id)
    %w(title rating votes poster cast_members director genres languages length
    plot tagline year release_date).each do |key|
        info[key.to_sym] = movie.send(key)
    end

    info
end

def parse_description(description)
    description_hash = Hash.new
    description.split(/<(?:br|BR)\s?\/>/).each do |element|

        element.gsub!(/<\/?(b|B)>/,"")
        key, value = element.split(":", 2)

        key = key.downcase.gsub(" ","_")
        value.strip!

        if value.match(/<a .*<\/a>/)
            begin
                value = Nokogiri::XML(value).root.attr('href')
            rescue
                value = "Error while parsing"
            end
        end
        description_hash[key.to_sym] = value
    end
    description_hash
end

doc = Nokogiri::XML(open('http://rss.nzbmatrix.com/rss.php?cat=Movies'))

doc.root.xpath('channel/item').each do |item|
    data = Hash.new
    data[:description]      = item.xpath('description').text

    imdb_id = data[:description].scan(Regexp.new('http://www.imdb.com/title/tt(\d+)')).flatten.first

    next if imdb_id.nil?

    @coll_imdb.save(imdb_info(imdb_id))

    next

    data[:description_data] = parse_description(data[:description])
    data[:title]            = item.xpath('title').text
    data[:guid]             = item.xpath('guid').text
    data[:link]             = item.xpath('link').text
    data[:categoryid]       = item.xpath('categoryid').text

    data[:nzbmatrix_id]     = data[:link].scan(/id=(\d+)/).flatten.first
    data[:nzbmatrix_info]   = nzbmatrix_info(data[:nzbmatrix_id])
end
