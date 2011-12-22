#!/usr/bin/env ruby

require 'digest/md5'

resolution = "640 480";

#hile url = gets
# puts "From stdin: #{url}"
# qid = Digest::MD5.hexdigest(url)
# url.gsub!(/\n/, '')
# outfile = "/var/www/hosts/www.websnapit.com/docs/out/#{qid}.png"
# if File.exists?(outfile)
#    puts "allready cached file #{qid}.png\n"
# else
#    puts "creating thread for #{qid}.png\n"
#    #thread = Thread.new { 
#    cmd = "xvfb-run --server-args=\"-screen 0, 1024x768x24\" websnap \ #{url} #{outfile} #{resolution}"
#    puts cmd
#    system(cmd)
# end 
#nd

require 'gserver'

class BasicServer < GServer
  def serve(io)
    url = io.gets
    io.puts(url)
  end
end

server = BasicServer.new(1234)
server.start

loop do
  break if server.stopped?
end

puts "Server has been terminated"
