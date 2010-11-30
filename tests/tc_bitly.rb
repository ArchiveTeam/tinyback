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
