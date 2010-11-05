require "hpricot"
require "resolv"
require "singleton"
require "socket"

Hpricot.buffer_size = 131072

module TinyBack

    module Services

        class TinyURL < Base

            class IPManager

                include Singleton

                def initialize
                    @mutex = Mutex.new
                end

                def get_ip
                    @mutex.synchronize do
                        if @time.nil? || @time + 300 < Time.now
                            @time = Time.now
                            @ips = resolve
                        end
                        ip = @ips.pop
                        @ips.unshift ip
                        ip
                    end
                end

                private

                def resolve
                    nameservers = []
                    Resolv::DNS.open do |resolv|
                        resolv.getresources("tinyurl.com", Resolv::DNS::Resource::IN::NS).each do |nameserver|
                            nameservers << nameserver.name.to_s
                        end
                    end

                    ips = []
                    nameservers.each do |nameserver|
                        Resolv::DNS.open(:nameserver => nameserver) do |resolv|
                            resolv.each_address("tinyurl.com") do |ip|
                                ips << ip.to_s
                            end
                            resolv.each_address("www.tinyurl.com") do |ip|
                                ips << ip.to_s
                            end
                        end
                    end

                    ips.uniq
                end

            end

            def initialize
                @ip = IPManager.instance.get_ip
            end

            #
            # Returns the character set used by this shortener. This function
            # is probably only useful for the advance method in the base class.
            #
            def self.charset
                "abcdefghijklmnopqrstuvwxyz0123456789"
            end

            #
            # Returns the complete short-url for a given code.
            #
            def self.url code
                "http://tinyurl.com/#{canonicalize(code)}"
            end


            #
            # The code may contain:
            #   - letters (case insensitive)
            #   - numbers
            #   - dashes (ignored)
            #   - a slash (everything after the slash is ignored)
            # The canonical version may not be longer than 49 characters
            #
            def self.canonicalize code
                code = code.split("/").first.to_s # Remove everything after slash
                code.tr! "-", "" # Remove dashes
                code.downcase! # Make everything lowercase
                raise InvalidCodeError.new unless code.match /^[a-z0-9]{1,49}$/
                code
            end

            #
            # Fetches the given code and returns the long url or raises a
            # NoRedirectError when the code is not in use yet. Only does a HEAD
            # request at first and then switches to GET if required, unless get
            # is set to true.
            #
            def fetch code, get = false
                begin
                    socket = TCPSocket.new @ip, 80
                    method = if get
                        "GET"
                    else
                        "HEAD"
                    end
                    socket.write ["#{method} /#{self.class.canonicalize(code)} HTTP/1.0", "Host: tinyurl.com"].join("\r\n") + "\r\n\r\n"
                    case (line = socket.gets)
                    when "HTTP/1.0 301 Moved Permanently\r\n"
                        while (line = socket.gets)
                            case line
                            when /^Location: (.*)\r\n/
                                return $1
                            when /^X-tiny: (error) [0-9]+\.[0-9]+\r\n/
                            when /X-Powered-By: PHP\/[0-9]\.[0-9]\.[0-9]\r\n/
                            when "\r\n"
                                raise BlockedError.new
                            end
                        end
                        raise FetchError.new "Expected Location, but received #{line.inspect} for code #{code.inspect}"
                    when "HTTP/1.0 404 Not Found\r\n"
                        raise NoRedirectError.new
                    when "HTTP/1.0 200 OK\r\n"
                        if get
                            socket.gets("\r\n\r\n")
                            data = socket.gets nil
                            begin
                                doc = Hpricot data
                            rescue Hpricot::ParseError => e
                                raise FetchError.new "Could not parse HTML data (#{e.inspect})"
                            end
                            if doc.at("/html/head/title").innerText == "Redirecting..."
                                url = doc.at("/html/body").innerText[1..-1]
                                doc = nil
                                return url
                            end
                            if doc.at("html/body/table/tr/td/h1:last").innerText == "Error: TinyURL redirects to a TinyURL."
                                url = doc.at("/html/body/table/tr/td/p.intro/a").attributes["href"]
                                doc = nil
                                return url
                            end
                            doc = nil
                            raise FetchError.new "Could not parse URL for code #{code.inspect}"
                        else
                            socket.close
                            return fetch(code, true)
                        end
                    when "HTTP/1.0 302 Found\r\n"
                        raise BlockedError.new
                    else
                        raise FetchError.new "Expected 200/301/302/404, but received #{line.inspect} for code #{code.inspect}"
                    end
                ensure
                    socket.close if socket and not socket.closed?
                end
            end


        end

    end

end
