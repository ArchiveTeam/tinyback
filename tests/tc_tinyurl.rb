require "test/unit"
require "tinyback/services"

class TC_TinyURL < Test::Unit::TestCase

    include TinyBack::Services

    def test_existant
        assert_equal "http://www.example.org/", TinyURL::fetch("4o8vk")
    end

    def test_nonexistant
        assert_raise NoRedirectError do
            TinyURL::fetch("NoRedirectErrorExpected")
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
