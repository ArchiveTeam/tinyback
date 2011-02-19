#!/usr/bin/env ruby

bad_urls = ["http://4url.cc/error.html"]

STDIN.each_line("\n") do |line|
    line.chomp!("\n")
    next if line.empty?

    code, url = line.split("|", 2)

    code.gsub!(/^0+/, "")
    next if code.empty?

    next if url.nil? or url.empty?
    next if bad_urls.include? url

    STDOUT.write "#{code}|#{url}\n"
end
