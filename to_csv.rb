#!/usr/bin/env ruby
# TinyBack - A tiny web scraper
# Copyright (C) 2011 David Triendl
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

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
