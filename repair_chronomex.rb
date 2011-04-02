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
