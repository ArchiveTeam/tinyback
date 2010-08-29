require "socket"

module TinyBack

    module Services

        module TinyURL

            HOST = "tinyurl.com"

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

            def self.fetch code
                begin
                    socket = TCPSocket.new HOST, 80
                    socket.write ["HEAD /#{canonicalize(code)} HTTP/1.0", "Host: #{HOST}"].join("\r\n") + "\r\n\r\n"
                    case (line = socket.gets)
                    when "HTTP/1.0 301 Moved Permanently\r\n"
                        match = (line = socket.gets).match /^Location: (.*)\r\n/
                        raise FetchError.new "Expected Location, but received #{line.inspect}" unless match
                        return match[1]
                    when "HTTP/1.0 200 OK\r\n"
                        raise NoRedirectError.new
                    else
                        raise FetchError.new "Expected 200/301, but received #{line.inspect}"
                    end
                ensure
                    socket.close if socket and not socket.closed?
                end
            end

            def self.advance code
                charset = "abcdefghijklmnopqrstuvwxyz0123456789"
                current = code.size - 1
                while current >= 0
                    if code[current] == charset[-1]
                        code[current] = charset[0]
                    else
                        code[current] = charset[charset.index(code[current]) + 1]
                        return code
                    end
                    current -= 1
                end
                return charset[0].chr + code
            end

        end

    end

end
