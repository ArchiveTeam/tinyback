#!/usr/bin/env ruby

$: << "lib"

require "tinyback/reaper"
require "thread"

Thread.abort_on_exception = true

service = TinyBack::Services::TinyURL
start = "a"
stop = "9"
threads = 20

reaper = TinyBack::Reaper.new service, start, stop, threads
reaper.join
