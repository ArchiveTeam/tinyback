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
        assert_equal "http://www.unicyclist.com/newgateway/get.php", @instance.fetch("cs")
    end

    def test_existant_self
        assert_equal "http://tinyurl.com/create.php?url=http://translate.google.com/translate?hl=en&u=http%3A%2F%2Fwww.buy-tees.com&langpair=en%7Cfr", @instance.fetch("w")
    end

    def test_blocked
        assert_raise BlockedError do
            @instance.fetch("dick")
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
        assert_equal "b", TinyURL.advance("a")
        assert_equal "0", TinyURL.advance("z")
        assert_equal "aa", TinyURL.advance("9")
        assert_equal "ba", TinyURL.advance("a9")
    end

end
