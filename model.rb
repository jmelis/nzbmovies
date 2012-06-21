require 'mongo'

class NzbDB
    attr_reader :db
    def initialize
        @conn = Mongo::Connection.new
        @db   = @conn['nzbmovies']
    end

    def [](coll)
        @db[coll]
    end
end
