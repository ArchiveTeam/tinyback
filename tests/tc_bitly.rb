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

class TC_Bitly < Test::Unit::TestCase

    include TinyBack::Services

    def setup
        @instance = Bitly.new unless @instance
    end

    def test_existant
        assert_equal "http://www.example.org/", @instance.fetch("bj6ufn")
    end

    def test_nonexistant
        assert_raise NoRedirectError do
            @instance.fetch("NoRedirectErrorExpected")
        end
    end

    def test_existant_302
        assert_equal "http://parent-directory.com", @instance.fetch("dick")
        assert_equal "http://tr.im/2j38", @instance.fetch("O4q")
        assert_equal "http://www.infocart.jp/t/37940/shinshin96/", @instance.fetch("m1SXT") # Trailing whitespace
    end

    def test_invalid
        assert_raise InvalidCodeError do # Invalid character
            Bitly.canonicalize "test&"
        end
        assert_raise InvalidCodeError do # Too short
            Bitly.canonicalize ""
        end
        assert_raise InvalidCodeError do # Keyword
            Bitly.canonicalize "api"
        end
        assert_raise InvalidCodeError do # Keyword
            Bitly.canonicalize "pro"
        end
    end

    def test_advance
        assert_equal "1", Bitly.advance("0")
        assert_equal "a", Bitly.advance("9")
        assert_equal "A", Bitly.advance("z")
        assert_equal "-", Bitly.advance("Z")
        assert_equal "_", Bitly.advance("-")
        assert_equal "00", Bitly.advance("_")
        assert_equal "10", Bitly.advance("0_")
    end

end
