DIRNAME = File.dirname(File.realpath(__FILE__))

God.watch do |w|
  w.name = "nzbmatrix_rss"
  w.start = "ruby #{DIRNAME}/nzbmatrix_rss.rb"
  w.keepalive
  w.log = "#{DIRNAME}/log/nzbmatrix_rss.log"
end
