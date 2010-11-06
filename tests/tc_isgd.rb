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

    def test_connection_resume
        assert_equal "http://www.example.org/", @instance.fetch("gmYZc")
        assert_raise NoRedirectError do
            @instance.fetch("zzzzzz")
        end
        assert_equal "http://pocketexpress.com/assets/img/channels/icn-extras.jpg", @instance.fetch("mBAh")
        assert_equal "http://example.com/", @instance.fetch("gMpD7")
    end

    def test_http_502_error
        assert_raise BlockedError do
            @instance.fetch("meIw")
        end
    end

    def test_no_html_data
        assert_raise FetchError do
            @instance.fetch("ms7x")
        end
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
        assert_equal "1", Isgd.advance("0")
        assert_equal "a", Isgd.advance("9")
        assert_equal "A", Isgd.advance("z")
        assert_equal "00", Isgd.advance("Z")
        assert_equal "10", Isgd.advance("0Z")
    end

end
