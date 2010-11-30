require "cgi"
require "hpricot"
require "socket"
require "uri"

module TinyBack

    module Services

        class Bitly < Base

            @@ip_manager = IPManager.new "bit.ly", "www.bit.ly", "j.mp", "www.j.mp"

            def initialize
                @ip = @@ip_manager.get_ip
            end

            #
            # Returns the character set used by this shortener. This function
            # is probably only useful for the advance method in the base class.
            #
            def self.charset
                "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMONPQRSTUVWXYZ-_"
            end

            #
            # Returns the complete short-url for a given code.
            #
            def self.url code
                "http://bit.ly/#{canonicalize(code)}"
            end


            #
            # The code may contain:
            #   - letters (case sensitive)
            #   - numbers
            #   - dash
            #   - underscore
            #
            def self.canonicalize code
                raise InvalidCodeError.new unless code.match /^([A-Za-z0-9\-_]+)$/
                code
            end

            #
            # Fetches the given code and returns the long url or raises a
            # NoRedirectError when the code is not in use yet.
            # This method is not thread-safe.
            #
            def fetch code
                code = self.class.canonicalize code
                begin
                    if @socket.nil? or @socket.closed?
                        @socket = TCPSocket.new @ip, 80
                    end
                    data =  ["HEAD /#{code} HTTP/1.1", "Host: j.mp", "Cookie: _bit="].join("\n") + "\n\n"
                    begin
                        @socket.write data
                    rescue Errno::EPIPE
                        @socket = TCPSocket.new @ip, 80
                        @socket.write data
                    end
                    headers = @socket.gets("\r\n\r\n")
                    raise FetchError.new "Service unexpectedly closed the connection" if headers.nil?
                    headers = headers.split("\r\n")
                    status = headers.shift
                    begin
                        case status
                        when "HTTP/1.1 301 Moved"
                            match = headers[-3].match /Location: (.*)/
                            raise FetchError.new "No Location found at the expected place in headers" unless match
                            return match[1]
                        when "HTTP/1.1 404 Not Found"
                            raise NoRedirectError.new
                        when "HTTP/1.1 302 Found"
                            match = headers[-3].match /Location: (.*)/
                            raise FetchError.new "No Location found at the expected place in headers" unless match
                            target = URI.parse match[1]
                            raise FetchError.new "302 Found but unknown redirect URL" unless target.scheme == "http" and target.host == "bit.ly" and target.path == "/a/warning"
                            target = CGI.parse target.query
                            raise FetchError.new "Code mismatch on 302 Found" unless target["hash"].first == code
                            raise FetchError.new "No URL given" unless target.key? "url"
                            return target["url"].first
                        when nil
                            raise FetchError.new "Socket unexpectedly closed"
                        else
                            raise FetchError.new "Expected 301/302/404, but received #{status}"
                        end
                    ensure
                        if headers.include? "Connection: close"
                            @socket.close unless @socket.closed?
                        end
                    end
                end
            end

        end

    end

end
