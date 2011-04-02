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
require "test/unit"
require "tinyback/services"

class TC_TinyURL < Test::Unit::TestCase

    include TinyBack::Services

    def setup
        @instance = TinyURL.new unless @instance
    end

    def test_existant
        assert_equal "http://www.example.org/", @instance.fetch("4o8vk")
    end

    def test_nonexistant
        assert_raise NoRedirectError do
            @instance.fetch("NoRedirectErrorExpected")
        end
    end

    def test_existant_404
        # Without line break
        assert_equal "http://www.unicyclist.com/newgateway/get.php", @instance.fetch("cs")
        # With line break
        assert_equal "http://www.philly.com/mld/inquirer/news/local/states/pennsylvania/counties/philadelphia_county/philadelphia/14051913.htm?source=rss&channel=inquirer_philadelphia", @instance.fetch("0agy1")
    end

    def test_existant_self
        # Without line break
        assert_equal "http://tinyurl.com/create.php?url=http://translate.google.com/translate?hl=en&u=http%3A%2F%2Fwww.buy-tees.com&langpair=en%7Cfr", @instance.fetch("w")
        # With line break
        assert_equal "http://tinyurl.com/npxpr", @instance.fetch("0i61s")
    end

    def test_blocked
        assert_raise CodeBlockedError do
            @instance.fetch("dick")
        end
    end

    def test_blocked_no_location
        assert_raise CodeBlockedError do
            @instance.fetch("bvkke")
        end
    end

    def test_canonical
        assert_equal "test", TinyURL.canonicalize("TEsT") # Lowercase
        assert_equal "test", TinyURL.canonicalize("--te---st--") # Dash
        assert_equal "test", TinyURL.canonicalize("test/another-test") # Slash
    end

    def test_invalid
        assert_raise InvalidCodeError do # Invalid character
            TinyURL.canonicalize "test&"
        end
        assert_raise InvalidCodeError do # Too short
            TinyURL.canonicalize ""
        end
        assert_raise InvalidCodeError do # Too long
            TinyURL.canonicalize "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789ABCD"
        end
    end

    def test_advance
        assert_equal "1", TinyURL.advance("0")
        assert_equal "a", TinyURL.advance("9")
        assert_equal "00", TinyURL.advance("z")
        assert_equal "10", TinyURL.advance("0z")
    end

end
