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
require "cgi"
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
                "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ-_"
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
                raise InvalidCodeError unless code.match /^([A-Za-z0-9\-_]+)$/
                raise InvalidCodeError if ["api", "pro"].include? code
                code
            end

            #
            # Fetches the given code and returns the long url or raises a
            # NoRedirectError when the code is not in use yet.
            # This method is not thread-safe.
            #
            def fetch code
                begin
                    if @socket.nil? or @socket.closed?
                        @socket = TCPSocket.new @ip, 80
                    end
                    data =  ["HEAD /#{code} HTTP/1.1", "Host: j.mp", "Cookie: _bit=0"].join("\n") + "\n\n"
                    begin
                        @socket.write data
                    rescue Errno::EPIPE
                        @socket = TCPSocket.new @ip, 80
                        @socket.write data
                    end
                    headers = @socket.gets("\r\n\r\n")
                    raise FetchError, "Service unexpectedly closed the connection" if headers.nil?
                    headers = headers.split("\r\n")
                    status = headers.shift
                    begin
                        case status
                        when "HTTP/1.1 301 Moved"
                            match = headers[-3].match /^Location: (.*)$/
                            raise FetchError, "No Location found at the expected place in headers" unless match
                            return match[1]
                        when "HTTP/1.1 302 Found"
                            match = headers[-3].match /^Location: (.*)$/
                            raise FetchError, "No Location found at the expected place in headers" unless match
                            target = URI.parse match[1]
                            raise FetchError, "302 Found but unknown redirect URL" unless target.scheme == "http" and target.host == "bit.ly" and target.path == "/a/warning"
                            target = CGI.parse target.query
                            raise FetchError, "Code mismatch on 302 Found" unless target["hash"].first == code
                            raise FetchError, "No URL given" unless target.key? "url"
                            return target["url"].first.strip
                        when "HTTP/1.1 403 Forbidden"
                            raise ServiceBlockedError
                        when "HTTP/1.1 404 Not Found"
                            raise NoRedirectError
                        when nil
                            raise FetchError, "Socket unexpectedly closed"
                        else
                            raise FetchError, "Expected 301/302/404, but received #{status.inspect}"
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
