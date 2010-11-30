require "socket"

module TinyBack

    module Services

        class Trim < Base

            #
            # Returns the character set used by this shortener. This function
            # is probably only useful for the advance method in the base class.
            #
            def self.charset
                "0123456789abcdefghijklmnopqrstuvwxyz_"
            end

            #
            # Returns the complete short-url for a given code.
            #
            def self.url code
                "http://tr.im/#{canonicalize(code)}"
            end


            #
            # The code may contain:
            #   - letters (case insensitive)
            #   - numbers
            #   - underscores
            #   - invalid characters (ignored)
            #   - dots (everything after the first dot is ignored)
            #
            def self.canonicalize code
                code = code.split(".").first.to_s # Remove everything after slash
                code.gsub!(/[^A-Za-z0-9_]/, "") # Remove invalid characters
                code.downcase! # Make everything lowercase
                raise InvalidCodeError if code.empty?
                code
            end

            #
            # Fetches the given code and returns the long url or raises a
            # NoRedirectError when the code is not in use.
            #
            def fetch code
                begin
                    socket = TCPSocket.new "tr.im", 80
                    socket.write "HEAD /#{self.class.canonicalize(code)}\n\n"
                    headers = socket.gets nil
                    raise FetchError.new "Service unexpectedly closed the connection" if headers.nil?

                    headers = headers.split "\r\n"
                    status = headers.shift
                    raise FetchError.new "Expected 200/301/302/404, but received #{status.inspect}" unless status == "HTTP/1.1 301 Moved Permanently"

                    match = headers[-5].match /^Location: (.*)$/
                    raise FetchError.new "No Location found at the expected place in headers" unless match
                    raise NoRedirectError.new if match[1] == "http://localhost:/"
                    match[1]
                ensure
                    socket.close if socket and not socket.closed?
                end
            end


        end

    end

end
