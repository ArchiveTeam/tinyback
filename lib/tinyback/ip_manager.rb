# TinyBack - A tiny web scraper
# Copyright (C) 2010-2011 David Triendl
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
require "resolv"
require "thread"

module TinyBack

    class IPManager

        def initialize *hosts
            @mutex = Mutex.new
            @hosts = hosts
            raise ArgumentError, "Need at least 1 host" if @hosts.size < 1
        end

        def get_ip
            @mutex.synchronize do
                if @time.nil? || @time + 300 < Time.now
                    @time = Time.now
                    @ips = resolve
                end
                ip = @ips.pop
                @ips.unshift ip
                ip
            end
        end

        private

        def resolve
            nameservers = []
            Resolv::DNS.open do |resolv|
                @hosts.each do |host|
                    begin
                        resources = Timeout::timeout(10) do
                            resolv.getresources(host, Resolv::DNS::Resource::IN::NS)
                        end
                        resources.each do |nameserver|
                            nameservers << nameserver.name.to_s
                        end
                    rescue Timeout::Error
                    end
                end
            end

            ips = []
            nameservers.each do |nameserver|
                Resolv::DNS.open(:nameserver => nameserver) do |resolv|
                    @hosts.each do |host|
                        begin
                            resources = Timeout::timeout(10) do
                                resolv.getresources(host, Resolv::DNS::Resource::IN::A)
                            end
                            resources.each do |ip|
                                ips << ip.address.to_s
                            end
                        rescue Timeout::Error
                        end
                    end
                end
            end

            ips.uniq
        end

    end

end
