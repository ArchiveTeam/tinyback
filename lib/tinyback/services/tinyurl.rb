require "socket"

module TinyBack

    module Services

        class TinyURL < Base

            HOST = "tinyurl.com"

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
            # NoRedirectError when the code is not in use yet.
            #
            def fetch code
                begin
                    socket = TCPSocket.new HOST, 80
                    socket.write ["HEAD /#{self.class.canonicalize(code)} HTTP/1.0", "Host: #{HOST}"].join("\r\n") + "\r\n\r\n"
                    case (line = socket.gets)
                    when "HTTP/1.0 301 Moved Permanently\r\n"
                        case (line = socket.gets)
                        when /^Location: (.*)\r\n/
                            return $1
                        when /X-Powered-By: PHP\/[0-9]\.[0-9]\.[0-9]$/
                            puts line
                            match = (line = socket.gets).match /^Location: (.*)\r\n/
                            return match[1] if match
                        end
                        raise FetchError.new "Expected Location, but received #{line.inspect}"
                    when "HTTP/1.0 404 Not Found\r\n"
                        raise NoRedirectError.new
                    else
                        raise FetchError.new "Expected 200/301, but received #{line.inspect}"
                    end
                ensure
                    socket.close if socket and not socket.closed?
                end
            end


        end

    end

end
