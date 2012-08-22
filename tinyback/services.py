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
import httplib
import urlparse

from tinyback import exceptions

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

class Bitly(Service):
    """
    http://bit.ly/ URL shortener
    """

    @property
    def charset(self):
        return "012356789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ-_"

    def __init__(self):
        self._conn = httplib.HTTPConnection("bit.ly")

    def fetch(self, code):
        self._conn.request("HEAD", "/" + code)
        resp = self._conn.getresponse()
        resp.read()

        if resp.status == 301:
            location = resp.getheader("Location")
            if not location:
                raise exceptions.ServiceException("No Location header after HTTP status 301")
            if resp.reason == "Moved": # Normal bit.ly redirect
                return location
            elif resp.reason == "Moved Permanently":
                # Weird "bundles" redirect, forces connection close despite
                # sending Keep-Alive header
                self._conn.close()
                self._conn.connect()
                raise exceptions.CodeBlockedException()
            else:
                raise exceptions.ServiceException("Unknown HTTP reason %s after HTTP status 301" % resp.reason)
        elif resp.status == 302:
            location = resp.getheader("Location")
            if not location:
                raise exceptions.ServiceException("No Location header after HTTP status 302")
            return self._parse_warning_url(code, location)
        elif resp.status == 404:
            raise exceptions.NoRedirectException()
        elif resp.status == 410:
            raise exceptions.CodeBlockedException()
        else:
            raise exceptions.ServiceException("Unknown HTTP status %i" % resp.status)

    def _parse_warning_url(self, code, url):
        url = urlparse.urlparse(url)
        if url.scheme != "http" or url.netloc != "bitly.com" or url.path != "/a/warning":
            raise exceptions.ServiceException("Unexpected Location header after HTTP status 302")
        query = urlparse.parse_qs(url.query)
        if not ("url" in query and len(query["url"]) == 1) or not ("hash" in query and len(query["hash"]) == 1):
            raise exceptions.ServiceException("Unexpected Location header after HTTP status 302")
        if query["hash"][0] != code:
            raise exceptions.ServiceException("Hash mismatch forr HTTP status 302")
        return query["url"][0]

class Isgd(Service):
    """
    http://is.gd/ URL shortener
    """

    RATE_LIMIT_STRING = "<div id=\"main\"><p>Rate limit exceeded - please wait 1 minute before accessing more shortened URLs</p></div>"
    BLOCKED_STRING_START = "<p>For reference and to help those fighting spam the original destination of this URL is given below (we strongly recommend you don't visit it since it may damage your PC): -<br />"
    BLOCKED_STRING_END = "</p><h2>is.gd</h2><p>is.gd is a free service used to shorten long URLs."

    @property
    def charset(self):
        return "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_"

    @property
    def rate_limit(self):
        return (60, 60)

    def __init__(self):
        self._conn = httplib.HTTPConnection("is.gd")

    def fetch(self, code):
        self._conn.request("HEAD", "/" + code)
        resp = self._conn.getresponse()
        resp.read() # Head only

        if resp.status == 200:
            return self._fetch_blocked(code)
        elif resp.status == 301:
            location = resp.getheader("Location")
            if not location:
                raise exceptions.ServiceException("No Location header after HTTP status 301")
            return location
        elif resp.status == 404:
            raise exceptions.NoRedirectException()
        elif resp.status == 502:
            raise exceptions.CodeBlockedException("HTTP status 502")
        else:
            raise exceptions.ServiceException("Unknown HTTP status %i" % resp.status)

    def _fetch_blocked(self, code):
        self._conn.request("GET", "/" + code)
        resp = self._conn.getresponse()
        data = resp.read()

        if resp.status != 200:
            raise exceptions.ServiceException("HTTP status changed from 200 to %i on second request" % resp.status)
        if not data:
            raise exceptions.CodeBlockedException("Empty response on status 200")

        if self.RATE_LIMIT_STRING in data:
            raise exceptions.BlockedException()

        position = data.find(self.BLOCKED_STRING_START)
        if position == -1:
            raise exceptions.ServiceException("Unexpected response on status 200")
        data = data[position + len(self.BLOCKED_STRING_START):]

        position = data.find(self.BLOCKED_STRING_END)
        if position == -1:
            raise exceptions.ServiceException("Unexpected response on status 200")

        return data[:position]
