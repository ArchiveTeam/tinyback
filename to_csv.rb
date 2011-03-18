#!/usr/bin/env ruby

def escape data
    if data.include? "," or data.include? '"' or data.include? "\r\n"
        '"' + data.gsub('"', '""') + '"'
    else
        data
    end
end

STDIN.each_line("\n") do |line|
    line.chomp!("\n")
    if line.empty?
        STDERR.puts "next"
        next
    end
    code, url = line.split("|", 2)

    STDOUT.write(escape(url) + "," + escape(code) + ",,\r\n")
end
