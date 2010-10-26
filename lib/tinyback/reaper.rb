require "logger"
require "msgpack"
require "tinyback/services"
require "thread"

module TinyBack

    class Reaper

        FETCH_QUEUE_MIN_SIZE = 100
        FETCH_QUEUE_MAX_SIZE = 1000

        FETCH_THREADS = 10

        def initialize service, start, stop
            filename = service.to_s.split("::").last + "_" + start + "-" + stop
            @logger = Logger.new(filename + ".log")
            @logger.info "Initializing Reaper"

            @run = true
            @service = service

            @fetch_queue = []
            @fetch_mutex = Mutex.new
            @write_queue = Queue.new

            @threads = []
            @threads << generate_thread(start, stop)
            FETCH_THREADS.times do
                @threads << fetch_thread
            end
            @threads << write_thread(filename + ".mpac")
        end

        #
        # Waits for the reaper to finish.
        #
        def join
            @threads.each do |thread|
                thread.join
            end
            @logger.info "Reaper finished (this is the last line)"
        end

        #
        # Creates a new generate thread. The generate thread fills the fetch
        # queue up to the limit of FETCH_QUEUE_MAX_SIZE items and sleeps for
        # the estimated time it takes for the queue to reach
        # FETCH_QUEUE_MIN_SIZE items. The first code inserted into the queue is
        # given by the parameter start, the last code by the parameter stop.
        #
        def generate_thread start, stop
            Thread.new(start, stop) do |start, stop|
                @logger.info "Starting generate thread (#{start.inspect} to #{stop.inspect})"
                current = start
                sleep_interval = 30
                until current == stop
                    size = @fetch_mutex.synchronize do
                        @fetch_queue.size
                    end
                    if size < FETCH_QUEUE_MIN_SIZE
                        target = FETCH_QUEUE_MAX_SIZE - size
                        new = []
                        while new.size < target
                            new << current.dup
                            break if current == stop
                            current = @service.advance(current)
                        end
                        @fetch_mutex.synchronize do
                            @fetch_queue.concat new.shuffle
                        end
                        @logger.info "Filled fetch queue with #{new.size} items (#{new.first.inspect}-#{new.last.inspect})"
                        sleep_interval -= 1
                        sleep sleep_interval
                    else
                        sleep_interval += 1
                        sleep 1
                    end
                end
                terminate = Array.new(FETCH_THREADS) do
                    :stop
                end
                @fetch_mutex.synchronize do
                    @fetch_queue.concat terminate
                end
                @logger.info "Generate thread terminated"
            end
        end

        def fetch_thread
            Thread.new do
                @logger.info "Starting fetch thread"
                service = @service.new
                while @run do
                    code = @fetch_mutex.synchronize do
                        @fetch_queue.pop
                    end
                    break if code == :stop
                    if code.nil?
                        @logger.warn "Empty fetch queue caused fetch stall"
                        sleep 1
                        next
                    end
                    begin
                        url = service.fetch code
                        @logger.debug "Code #{code.inspect} found (#{url.inspect})"
                        @write_queue.push [code, url]
                    rescue Services::NoRedirectError
                        @logger.debug "Code #{code.inspect} is unknown to service"
                    rescue Services::BlockedError
                        @logger.info "Code #{code.inspect} is blocked by service"
                    rescue Services::FetchError => e
                        @logger.error "Code #{code.inspect} triggered #{e.inspect}"
                    rescue => e
                        @logger.fatal "Code #{code.inspect} triggered #{e.inspect}"
                        exit
                    end
                end
                @write_queue.push :stop
                @logger.info "Fetch thread terminated"
            end
        end

        def write_thread filename
            Thread.new(filename) do |filename|
                @logger.info "Starting write thread"
                stop = FETCH_THREADS
                handle = File.open filename, "w"
                while stop > 0 do
                    code, url = @write_queue.pop
                    if code == :stop
                        stop -= 1
                        next
                    end
                    handle.write [code, url].to_msgpack
                end
                handle.close
                @logger.info "Write thread terminated"
            end
        end

    end

end
