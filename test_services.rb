#!/usr/bin/env ruby
# TinyBack - A tiny web scraper
# Copyright (C) 2010-2011 David Triendl
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

$: << "lib"

require "tinyback/services"
require "thread"

Thread.abort_on_exception = true

threads = []

ObjectSpace.each_object(Class) do |obj|
    next unless obj < TinyBack::Services::Base
    threads << Thread.new(obj) do |klass|
        Thread.current[:name] = klass.to_s.split("::").last
        Thread.current[:status] = "ok"
        service = klass.new
        begin
            service.fetch "a"
        rescue TinyBack::Services::NoRedirectError
        rescue TinyBack::Services::ServiceBlockedError
            Thread.current[:status] = "blocked"
        rescue => e
            Thread.current[:status] = "error (#{e.class})"
        end
    end
end

threads.sort! do |a, b|
    a[:name] <=> b[:name]
end

threads.each do |thread|
    thread.join
    puts "#{thread[:name]}: #{thread[:status]}"
end
