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
require "hpricot"
require "socket"

module TinyBack

    module Services

        class Isgd < Base

            #
            # Returns the character set used by this shortener. This function
            # is probably only useful for the advance method in the base class.
            #
            def self.charset
                "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_"
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
                match = code.match /^([A-Za-z0-9_]+)/
                raise InvalidCodeError.new unless match
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
                        @socket = TCPSocket.new "is.gd", 80
                    end
                    data =  ["HEAD /#{code} HTTP/1.1", "Host: is.gd"].join("\n") + "\n\n"
                    begin
                        @socket.write data
                    rescue Errno::EPIPE
                        @socket = TCPSocket.new "is.gd", 80
                        @socket.write data
                    end
                    headers = @socket.gets("\r\n\r\n")
                    raise FetchError.new "Service unexpectedly closed the connection" if headers.nil?
                    headers = headers.split("\r\n")
                    status = headers.shift
                    begin
                        case status
                        when "HTTP/1.1 301 Moved Permanently"
                            match = headers.last.match /^Location: (.*)$/
                            raise FetchError.new "No Location found at the expected place in headers" unless match
                            return match[1]
                        when "HTTP/1.1 404 Not Found"
                            raise NoRedirectError.new
                        when "HTTP/1.1 200 OK"
                            if headers.include? "Connection: close"
                                @socket.close unless @socket.closed?
                                @socket = TCPSocket.new "is.gd", 80
                            end
                            data = ["GET /#{code} HTTP/1.1", "Host: is.gd"].join("\r\n") + "\r\n\r\n"
                            @socket.write data
                            headers = @socket.gets("\r\n\r\n")
                            raise FetchError.new "Service unexpectedly closed the connection" if headers.nil?
                            headers = headers.split("\r\n")
                            unless (status = headers.shift) == "HTTP/1.1 200 OK"
                                raise FetchError.new "Status suddenly changed from 200 to #{status}"
                            end
                            raise FetchError.new "Service unexpectedly closed the connection" if @socket.gets("\r\n").nil?
                            data = @socket.gets("\r\n0\r\n\r\n")
                            raise FetchError.new "Service unexpectedly closed the connection" if data.nil?
                            data.slice!(-7, 7)
                            begin
                                doc = Hpricot data
                            rescue Hpricot::ParserError => e
                                raise FetchError.new "Could not parse HTML data: #{e.inspect}"
                            end
                            begin
                                if doc.at("/html/head/title").innerText == "is.gd - URL disabled"
                                    match = doc.at("/html/body/div[@id='disabled']/p:eq(3)").innerText.match(/^For reference and to help those fighting spam the original destination of this URL is given below \(we strongly recommend you don't visit it since it may damage your PC\): \-(.*)$/)
                                    return match[1] if match
                                end
                                raise FetchError.new "Could not parse URL from HTML"
                            rescue NoMethodError => e
                                raise FetchError.new "Could not parse HTML data: #{e.inspect}"
                            ensure
                                doc = nil
                            end
                        when "HTTP/1.1 502 Bad Gateway"
                            raise CodeBlockedError.new
                        when nil
                            raise FetchError.new "Socket unexpectedly closed"
                        else
                            raise FetchError.new "Expected 200/301/404, but received #{status}"
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
