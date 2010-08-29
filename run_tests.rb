#!/usr/bin/env ruby

$: << "lib"

require "test/unit"

Dir.foreach "tests" do |file|
    next if file[0] == ?.
    require "tests/#{file}"
end
