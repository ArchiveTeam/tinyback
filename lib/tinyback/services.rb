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
require "tinyback/ip_manager"

module TinyBack

    module Services

        class ServiceError < RuntimeError
        end

        class FetchError < ServiceError
        end

        class ServiceBlockedError < FetchError
        end

        class InvalidCodeError < ServiceError
        end

        class NoRedirectError < ServiceError
        end

        class CodeBlockedError < ServiceError
        end


        class Base

            def self.advance code
                code = code.dup
                current = code.size - 1
                while current >= 0
                    if code[current] == charset()[-1]
                        code[current] = charset()[0]
                    else
                        code[current] = charset()[charset().index(code[current]) + 1]
                        return code
                    end
                    current -= 1
                end
                return charset()[0].chr + code
            end

        end

    end

end

directory = File.dirname(__FILE__) + "/services/"
Dir.foreach(directory) do |file|
    next if file[0] == ?.
    require directory + file
end

