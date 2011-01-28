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
        assert_raise CodeBlockedError do
            @instance.fetch("meIw")
        end
    end

    def test_weird_redirect
        assert_equal "http://div.content {background-color: #;border: 0px solid;border-color: 000000;background-image: url('http://www.unglamorouslife.com/backgrounds/profile/credit-2.0-bw.png');background-repeat: no-repeat;background-position: top center;}/*topnav*/div#header, div#googlebar { background: transparent }#topnav{background:#000000;} #topnav ul { border-right: 1px #000000 solid; }  #topnav ul li { border-left: 1px #000000 solid; }   body{background-image:url('http://i260.photobucket.com/albums/ii32/unglamorouslife/GRAPHICS MAIN/Twilight/wall001.jpg');background-attachment: fixed;background-position:left center;}div.content{background-color:#;padding:5px;border:0px solid #zzzzzz;}div.module{background-color:#ffffff;border:1px solid #000000;}h2{background-color:#ffffff;text-align:left;font-weight:bold;color:#39BEB9;font-family:georgia times;font-size:20px;letter-spacing: -1pt;line-height:10px;}h3.moduleHead{background-color:#39BEB9;text-align:right;font-weight:normal;colo", @instance.fetch("ms7x")
    end

    def test_canonical
        assert_equal "TEsT", Isgd.canonicalize("TEsT") # Case sensitive
        assert_equal "test", Isgd.canonicalize("test-suite") # Ignore characters after invalid character
    end

    def test_invalid
        assert_raise InvalidCodeError do # Too short
            Isgd.canonicalize ""
        end
    end

    def test_advance
        assert_equal "1", Isgd.advance("0")
        assert_equal "a", Isgd.advance("9")
        assert_equal "A", Isgd.advance("z")
        assert_equal "_", Isgd.advance("Z")
        assert_equal "00", Isgd.advance("_")
        assert_equal "10", Isgd.advance("0_")
    end

end
