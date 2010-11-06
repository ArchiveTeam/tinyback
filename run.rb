#!/usr/bin/env ruby

$: << "lib"

require "tinyback/reaper"
require "thread"

Thread.abort_on_exception = true

service = TinyBack::Services::TinyURL
start = "0"
stop = "z"
threads = 20

reaper = TinyBack::Reaper.new service, start, stop, threads
reaper.join
