require "test/unit"
require "tinyback/services"

class TC_Trim < Test::Unit::TestCase

    include TinyBack::Services

    def setup
        @instance = Trim.new unless @instance
    end

    def test_existant
        assert_equal "http://news.nationalgeographic.com/news/2002/10/1010_021010_dinomummy.html", @instance.fetch("ex")
    end

    def test_nonexistant
        assert_raise NoRedirectError do
            @instance.fetch("NoRedirectErrorExpected")
        end
    end

    def test_canonical
        assert_equal "test", Trim.canonicalize("TEsT") # Lowercase
        assert_equal "test", Trim.canonicalize("te%st/") # Invalid character
        assert_equal "test", Trim.canonicalize("-te-%-st-") # Invalid character
        assert_equal "test", Trim.canonicalize("test.bla") # Dot
        assert_equal "test_", Trim.canonicalize("Te-St_.B&lA") # All together
    end

    def test_invalid
        assert_raise InvalidCodeError do # Too short
            Trim.canonicalize ""
        end
        assert_raise InvalidCodeError do # Only invalid characters
            Trim.canonicalize "--/"
        end
        assert_raise InvalidCodeError do # Dot as first character
            Trim.canonicalize ".test"
        end
    end

    def test_advance
        assert_equal "1", Trim.advance("0")
        assert_equal "a", Trim.advance("9")
        assert_equal "_", Trim.advance("z")
        assert_equal "00", Trim.advance("_")
        assert_equal "10", Trim.advance("0_")
    end

end
