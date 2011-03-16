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
                code = code.split(".").first.to_s # Remove everything after dot
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
                    socket.write(["HEAD /#{code} HTTP/1.1", "Host: tr.im", "Cookie: _trim=0"] * "\n" + "\n\n")
                    headers = socket.gets nil
                    raise FetchError, "Service unexpectedly closed the connection" if headers.nil?

                    raise ServiceBlockedError if headers == "<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.1//EN\" \"http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd\">\n<html>\n<head>\n  <title>TR.IM NOT AVAILABLE</title>\n</head>\n<body>\n  TR.IM SERVERS NOT AVAILABLE\n</body>\n</html>\n\n"

                    headers = headers.split "\r\n"
                    status = headers.shift
                    case status
                    when "HTTP/1.1 301 Moved Permanently"
                        match = headers[4].match /^Location: (.*)$/
                        raise FetchError, "No Location found at the expected place in headers" unless match
                        raise NoRedirectError if match[1] == "http://tr.im"
                        return match[1]
                    else
                        raise FetchError, "Expected 200/301/302/404, but received #{status.inspect}"
                    end
                ensure
                    socket.close if socket and not socket.closed?
                end
            end


        end

    end

end
