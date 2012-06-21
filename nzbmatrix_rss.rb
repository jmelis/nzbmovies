#!/usr/bin/env ruby

$: << File.dirname(__FILE__)

require 'nokogiri'
require 'open-uri'

require 'model'

SLEEP_MIN = 1

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

DB = NzbDB.new

loop do
    doc = Nokogiri::XML(open('http://rss.nzbmatrix.com/rss.php?cat=Movies'))

    doc.root.xpath('channel/item').each do |item|
        begin
            data = Hash.new
            data[:description]      = item.xpath('description').text

            imdb_id = data[:description].scan(Regexp.new('http://www.imdb.com/title/tt(\d+)')).flatten.first

            next if imdb_id.nil?

            data[:link]             = item.xpath('link').text
            data[:nzbmatrix_id]     = data[:link].scan(/id=(\d+)/).flatten.first

            next if DB['imdb'].find_one({"nzbmatrix_id"=>data[:nzbmatrix_id]})

            data[:description_data] = parse_description(data[:description])
            data[:title]            = item.xpath('title').text
            data[:guid]             = item.xpath('guid').text
            data[:categoryid]       = item.xpath('categoryid').text

            data[:imdb_id] = imdb_id
            data[:date]    = Time.now

            DB['imdb'].save(data)
        rescue
            xml = item.to_xml
            unless DB['imdb_fail'].find_one({"xml" => xml})
                DB['imdb_fail'].save({"xml" => xml, "date" => Time.now})
            end
        end
    end

    sleep 60*SLEEP_MIN
end
