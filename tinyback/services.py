# TinyBack - A tiny web scraper
# Copyright (C) 2012 David Triendl
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

import abc

from tinyback.exceptions import *

class Service:
    """
    URL shortener client
    """

    __metaclass__= abc.ABCMeta

    @abc.abstractproperty
    def charset(self):
        """
        Return characters used in shorturls

        Returns a string containing all characters that may appear in a
        (shorturl) code.
        """

    @property
    def rate_limit(self):
        """
        Returns a tuple specifiyng the rate-limit, or None.

        Returns a two-element tuple, with the first element being the number of
        requests that are allowed in the timespan denoted by the second element
        (in seconds). When there is no rate-limit, simply returns None.
        """
        return None

    @abc.abstractmethod
    def fetch(self, code):
        """
        Return long URL for given code

        Fetches the long URL for the given shortcode from the URL shortener and
        returns the URL or throws various exceptions when something went wrong.
        """
