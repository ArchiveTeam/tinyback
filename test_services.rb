#!/usr/bin/env ruby

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

threads.each do |thread|
    thread.join
    puts "#{thread[:name]}: #{thread[:status]}"
end
