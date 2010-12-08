#!/usr/bin/env ruby

previous_code = nil
previous_urls = []

STDIN.each_line("\n") do |line|
    line.chomp!("\n")
    if line.empty?
        STDERR.puts "next"
        next
    end
    code, url = line.split("|", 2)

    if code == previous_code
        if previous_urls.include? url
            next
        else
            STDERR.puts "Duplicate URLs for code #{code.inspect}"
        end
    else
        previous_code = code
        previous_urls = []
    end
    previous_urls << url
    STDOUT.write "#{code}|#{url}\n"
end
