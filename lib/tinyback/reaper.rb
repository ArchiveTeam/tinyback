require "logger"
require "msgpack"
require "timeout"
require "tinyback/services"
require "thread"

module TinyBack

    class Reaper

        FETCH_QUEUE_MIN_SIZE_PER_THREAD = 100
        FETCH_QUEUE_MAX_SIZE_PER_THREAD = 1000

        def initialize service, start, stop, fetch_threads = 10
            filename = service.to_s.split("::").last + "_" + start + "-" + stop
            @logger = Logger.new(filename + ".log")
            @logger.info "Initializing Reaper"

            @service = service
            @fetch_threads = fetch_threads

            @fetch_queue = []
            @fetch_mutex = Mutex.new
            @write_queue = Queue.new
            @failed = {}

            @threads = []
            @threads << generate_thread(start, stop)
            @fetch_threads.times do
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

        private

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
                    if size < (FETCH_QUEUE_MIN_SIZE_PER_THREAD * @fetch_threads)
                        target = (FETCH_QUEUE_MAX_SIZE_PER_THREAD * @fetch_threads) - size
                        new = []
                        while new.size < target
                            new << current.dup
                            break if current == stop
                            current = @service.advance(current)
                        end
                        @logger.info "Filling fetch queue with #{new.size} items (#{new.first.inspect}-#{new.last.inspect})"
                        @fetch_mutex.synchronize do
                            @fetch_queue = new.shuffle + @fetch_queue
                        end
                        sleep_interval -= 1
                        sleep sleep_interval
                    else
                        sleep_interval += 1
                        sleep 1
                    end
                end
                terminate = Array.new(@fetch_threads) do
                    :stop
                end
                @fetch_mutex.synchronize do
                    @fetch_queue = terminate + @fetch_queue
                end
                @logger.info "Generate thread terminated"
            end
        end

        def fetch_thread
            Thread.new do
                @logger.info "Starting fetch thread"
                service = @service.new
                loop do
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
                        Timeout::timeout(10) do
                            url = service.fetch code
                            @logger.debug "Code #{code.inspect} found (#{url.inspect})"
                            @write_queue.push [code, url]
                        end
                    rescue Services::NoRedirectError
                        @logger.debug "Code #{code.inspect} is unknown to service"
                    rescue Services::BlockedError
                        @logger.info "Code #{code.inspect} is blocked by service"
                    rescue Services::FetchError => e
                        @logger.error "Code #{code.inspect} triggered #{e.inspect}"
                    rescue Errno::ECONNRESET, Errno::ECONNREFUSED => e
                        @logger.error "Code #{code.inspect} triggered #{e.inspect}, retrying"
                        requeue code
                    rescue Timeout::Error
                        @logger.error "Fetching code #{code.inspect} triggered a timeout, recycling service"
                        service = @service.new
                        requeue code
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
                stop = @fetch_threads
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

        def requeue code
            fails = @fetch_mutex.synchronize do
                if @failed.key? code
                    @failed[code] += 1
                else
                    @failed[code] = 0
                end
            end
            if fails > 5
                @logger.warn "Code #{code.inspect} failed #{fails} times, not(!) retrying"
            else
                @logger.info "Retrying code #{code.inspect}"
                @fetch_mutex.synchronize do
                    if @fetch_queue[0] == :stop
                        @fetch_queue.insert(@fetch_queue.rindex(:stop), code)
                    else
                        @fetch_queue.unshift code
                    end
                end
            end
        end

    end

end
