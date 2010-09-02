require "test/unit"
require "tinyback/services"

class TC_TinyURL < Test::Unit::TestCase

    include TinyBack::Services

    def setup
        @instance = TinyBack::Services::TinyURL.new unless @instance
    end

    def test_existant
        assert_equal "http://www.example.org/", @instance.fetch("4o8vk")
    end

    def test_nonexistant
        assert_raise NoRedirectError do
            @instance.fetch("NoRedirectErrorExpected")
        end
    end

    def test_canonical
        assert_equal "test", @instance.canonicalize("TEsT") # Lowercase
        assert_equal "test", @instance.canonicalize("--te---st--") # Dash
        assert_equal "test", @instance.canonicalize("test/another-test") # Slash
    end

    def test_invalid
        assert_raise InvalidCodeError do # Invalid character
            @instance.canonicalize "test&"
        end
        assert_raise InvalidCodeError do # Too short
            @instance.canonicalize ""
        end
        assert_raise InvalidCodeError do # Too long
            @instance.canonicalize "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789ABCD"
        end
    end

    def test_advance
        assert_equal "b", @instance.advance("a")
        assert_equal "0", @instance.advance("z")
        assert_equal "aa", @instance.advance("9")
        assert_equal "ba", @instance.advance("a9")
    end

end
