require "socket"

module TinyBack

    module Services

        class Isgd < Base

            HOST = "is.gd"

            #
            # Returns the character set used by this shortener. This function
            # is probably only useful for the advance method in the base class.
            #
            def self.charset
                "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMONPQRSTUVXYZ0123456789"
            end

            #
            # Returns the complete short-url for a given code.
            #
            def self.url code
                "http://is.gd/#{canonicalize(code)}"
            end


            #
            # The code may contain:
            #   - letters (case sensitive)
            #   - numbers
            # Eveything after the first invalid chracter is ignored.
            # The canonical version may not be longer than 6 characters at the moment.
            #
            def self.canonicalize code
                match = code.match /^([A-Za-z0-9]+)/
                raise InvalidCodeError.new unless match
                raise InvalidCodeError.new if match[1].length > 6
                match[1]
            end

            #
            # Fetches the given code and returns the long url or raises a
            # NoRedirectError when the code is not in use yet.
            # This method is not thread-safe.
            #
            def fetch code
                begin
                    if @socket.nil? or @socket.closed?
                        @socket = TCPSocket.new HOST, 80
                    end
                    data =  ["HEAD /#{self.class.canonicalize(code)} HTTP/1.1", "Host: #{HOST}"].join("\r\n") + "\r\n\r\n"
                    begin
                        @socket.write data
                    rescue Errno::EPIPE
                        @socket = TCPSocket.new HOST, 80
                        @socket.write data
                    end
                    case (line = @socket.gets)
                    when "HTTP/1.1 301 Moved Permanently\r\n"
                        data = @socket.gets("\r\n\r\n").split("\r\n")
                        if data[3] == "Connection: close"
                            @socket = nil
                        elsif data[3] != "Connection: keep-alive"
                            raise FetchError.new "No Connection header found at the expected place in headers"
                        end
                        match = data.last.match /Location: (.*)/
                        raise FetchError.new "No Location found at the expected place in headers" unless match
                        return match[1]
                    when "HTTP/1.1 404 File Not Found\r\n"
                        @socket.gets "\r\n\r\n"
                        raise NoRedirectError.new
                    when nil
                        @socket = nil
                        raise FetchError.new "Socket unexpectedly closed"
                    else
                        raise FetchError.new "Expected 301/404, but received #{line.inspect}"
                    end
                end
            end

        end

    end

end
