require "tinyback/ip_manager"

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

        class CodeBlockedError < ServiceError
        end

        class Base

            def self.advance code
                current = code.size - 1
                while current >= 0
                    if code[current] == charset()[-1]
                        code[current] = charset()[0]
                    else
                        code[current] = charset()[charset().index(code[current]) + 1]
                        return code
                    end
                    current -= 1
                end
                return charset()[0].chr + code
            end

        end

    end

end

directory = File.dirname(__FILE__) + "/services/"
Dir.foreach(directory) do |file|
    next if file[0] == ?.
    require directory + file
end

