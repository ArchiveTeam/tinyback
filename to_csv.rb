#!/usr/bin/env ruby

def escape data
    if data.include? "," or data.include? '"' or data.include? "\r\n"
        '"' + data.gsub('"', '""') + '"'
    else
        data
    end
end

if ARGV[0].empty?
    prefix = ""
    STDERR.puts "No prefix specified - using empty string"
else
    prefix = ARGV[0]
    STDERR.puts "Prefix: #{prefix}"
end

STDIN.each_line("\n") do |line|
    line.chomp!("\n")
    if line.empty?
        STDERR.puts "next"
        next
    end
    code, url = line.split("|", 2)

    STDOUT.write(escape(url) + "," + escape(prefix + code) + ",,\r\n")
end
