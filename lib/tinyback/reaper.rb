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
require "logger"
require "tinyback/services"
require "thread"
require "zlib"

module TinyBack

    class Reaper

        #
        # The Stats class is used to provide some statistics about the fetch
        # process.
        #
        class Stats

            # Number of fetch requests
            attr_accessor :fetched

            # Number of not found results
            attr_accessor :not_found

            # Number of miscellaneous errors
            attr_accessor :error

            # Number of ServiceBlocked errors
            attr_accessor :blocked

            #
            # Creates a new Stats class. Number of fetch requests, not found
            # results, miscellaneous errors and ServiceBlocked errors can be
            # given as arguments in that order.
            #
            def initialize *args
                @fetched = args[0] || 0
                @not_found = args[1] || 0
                @error = args[2] || 0
                @blocked = args[3] || 0
            end

            #
            # Number of fetch requests that returned a long URL.
            #
            def successful
                @fetched - @not_found - @error - @blocked
            end

            #
            # Fill rate: Approximate number of successful fetch requests to
            # total requests.
            #
            def fill_rate
                return 0.0 if @fetched == 0
                1.0 - (@not_found.to_f / @fetched)
            end

            #
            # Error rate: Approximate number of failed requests to number of
            # total requests.
            #
            def error_rate
                return 0.0 if @fetched == 0
                @error.to_f / @fetched
            end

            #
            # Block rate: Approximate number of blocked requests to number of
            # total requests.
            #
            def block_rate
                return 0.0 if @fetched == 0
                @blocked.to_f / @fetched
            end

            #
            # Returns a short string showing the most interesting stats.
            #
            def to_s
                "Requests: #{@fetched}, fill rate: #{(fill_rate * 100).round}%, error rate: #{(error_rate * 100).round}%, block rate: #{(block_rate * 100).round}%"
            end

            #
            # Returns a string showing all recorded values.
            #
            def inspect
                "Requests: #{@fetched}, not found: #{@not_found}, errors: #{@error}, blocked: #{@blocked}"
            end

            #
            # Returns a new Stats instance containing the delta between two
            # points in time.
            #
            def -(other)
                Stats.new(@fetched - other.fetched, @not_found - other.not_found, @error - other.error, @blocked - other.blocked)
            end

        end

        class FetchTimeout < RuntimeError
        end

        MAX_TRIES = 3

        def initialize service, start, stop, fetch_threads = 10, debug = false
            filename = service.to_s.split("::").last + "_" + start + "-" + stop

            # Log
            @logger = Logger.new(filename + ".log")
            @logger.level = if debug
                Logger::DEBUG
            else
                Logger::INFO
            end
            @logger.info "Initializing Reaper"

            @service = service
            @num_fetch_threads = fetch_threads
            @threads = []
            @mutex = Mutex.new

            @stats = Stats.new
            @current_code = start
            @stop_code = stop
            @write_queue = Queue.new

            @monitor = monitor_thread
            @threads << write_thread(filename + ".txt.gz")
            @num_fetch_threads.times do
                @threads << fetch_thread
            end

        end

        #
        # Waits for the reaper to finish.
        #
        def join
            @threads.each do |thread|
                thread.join
            end
            @logger.info "Reaper finished (this is the last line)"
            exit
        end

        private

        #
        # Creates a new monitor thread. The monitor thread is responsible for
        # keeping track of statistics. It is possible to create multiple
        # monitor threads with different stats gathering intervals.
        #
        def monitor_thread interval = 20
            Thread.new do
                old_stats = @mutex.synchronize do
                    @stats.dup
                end
                loop do
                    sleep interval
                    stats = @mutex.synchronize do
                        @stats.dup
                    end
                    diff = stats - old_stats
                    old_stats = stats

                    @logger.info "#{interval}s average stats: #{diff}"
                    @logger.info "Request rate: #{diff.fetched.to_f / interval} req/s"

                    if diff.block_rate >= 0.1
                        @logger.fatal "#{interval}s average block rate is too high (#{diff.block_rate*100}%)"
                        exit 1
                    end
                end
            end
        end

        def fetch_thread
            Thread.new do
                @logger.info "Starting fetch thread"
                service = @service.new
                loop do
                    code = @mutex.synchronize do
                        break if @current_code == @stop_code
                        tmp = @current_code
                        @current_code = @service.advance @current_code
                        @stats.fetched += 1
                        tmp
                    end
                    break if code.nil?

                    tries = 0

                    begin
                        tries += 1
                        retrying = tries < MAX_TRIES

                        child = Thread.new(Thread.current, code) do |mother, code|
                            begin
                                Thread.current[:url] = service.fetch code
                            rescue => e
                                Thread.current[:error] = e
                            end
                            Thread.current[:terminated] = true
                            mother.run
                        end
                        sleep 10
                        child.kill!
                        child[:error] = FetchTimeout.new unless child[:terminated]

                        case child[:error]
                        when nil
                            @logger.debug "Code #{code.inspect} found (#{child[:url].inspect})"
                            @write_queue.push [code, child[:url]]
                            retrying = false
                        when Services::NoRedirectError
                            @mutex.synchronize do
                                @stats.not_found += 1
                            end
                            retrying = false
                        when Services::CodeBlockedError
                            @mutex.synchronize do
                                @stats.error += 1
                            end
                            @logger.debug "Code #{code.inspect} is blocked by service"
                            retrying = false
                        when Services::ServiceBlockedError
                            @logger.info "Service is blocking TinyBack"
                            @mutex.synchronize do
                                @stats.blocked += 1
                                @stats.fetched += 1 if retrying
                            end
                        when Services::FetchError, Errno::ECONNRESET, Errno::ECONNREFUSED, Errno::ETIMEDOUT, FetchTimeout
                            @mutex.synchronize do
                                @stats.error += 1
                                @stats.fetched += 1 if retrying
                            end
                            @logger.error "Fetching code #{code.inspect} triggered #{child[:error].inspect}, recycling service"
                            @logger.warn "Code #{code.inspect} failed #{tries} times, not(!) retrying" if not retrying
                            service = @service.new
                            # Clean up the mess of the old service
                            GC.start
                        else
                            @logger.fatal "Code #{code.inspect} triggered #{child[:error].inspect}"
                            exit
                        end
                    end while retrying
                end

                @write_queue.push :stop
                @logger.info "Fetch thread terminated"
            end
        end

        def write_thread filename
            Thread.new(filename) do |filename|
                @logger.info "Starting write thread"
                Thread.current.priority = -2
                stop = @num_fetch_threads
                handle = Zlib::GzipWriter.open filename, 9
                while stop > 0 do
                    code, url = @write_queue.pop
                    if code == :stop
                        stop -= 1
                        next
                    end
                    if url.include? "\n"
                        @logger.fatal "Newline in url for code #{code.inspect}"
                        exit
                    end
                    handle.write code + "|" + url + "\n"
                end
                handle.close
                @logger.info "Write thread terminated"
            end
        end

    end

end
