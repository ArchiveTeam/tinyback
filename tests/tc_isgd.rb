require "test/unit"
require "tinyback/services"

class TC_Isgd < Test::Unit::TestCase

    include TinyBack::Services

    def setup
        @instance = Isgd.new unless @instance
    end

    def test_existant
        assert_equal "http://www.example.org/", @instance.fetch("gmYZc")
    end

    def test_nonexistant
        assert_raise NoRedirectError do
            @instance.fetch("zzzzzz")
        end
    end

    def test_existant_spam
        assert_equal "http://pocketexpress.com/assets/img/channels/icn-extras.jpg", @instance.fetch("mBAh")
    end

    def test_canonical
        assert_equal "TEsT", Isgd.canonicalize("TEsT") # Case sensitive
        assert_equal "test", Isgd.canonicalize("test-suite") # Ignore characters after invalid character
    end

    def test_invalid
        assert_raise InvalidCodeError do # Too short
            Isgd.canonicalize ""
        end
        assert_raise InvalidCodeError do # Too long
            Isgd.canonicalize "01234567"
        end
    end

    def test_advance
        assert_equal "b", Isgd.advance("a")
        assert_equal "A", Isgd.advance("z")
        assert_equal "0", Isgd.advance("Z")
        assert_equal "aa", Isgd.advance("9")
        assert_equal "ba", Isgd.advance("a9")
    end

end
