module TinyBack

    module Services

        class ServiceError < RuntimeError
        end

        class FetchError < ServiceError
        end

        class InvalidCodeError < ServiceError
        end

        class NoRedirectError < ServiceError
        end

    end

end

directory = File.dirname(__FILE__) + "/services/"
Dir.foreach(directory) do |file|
    next if file[0] == ?.
    require directory + file
end
