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
import re
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

class SimpleService(Service):
    """
    Simple URL shortener client

    This is a generic service for URL shorteners. It is possible to specify
    which HTTP status code corresponds to which result, but it is not required.
    """

    @abc.abstractproperty
    def host(self):
        """
        Returns the hostname of the URL shortener
        """

    @property
    def http_status_redirect(self):
        return [301, 302]

    @property
    def http_status_no_redirect(self):
        return [404]

    @property
    def http_status_code_blocked(self):
        return [410]

    @property
    def http_status_blocked(self):
        return []

    def __init__(self):
        self._conn = httplib.HTTPConnection(self.host)

    def fetch(self, code):
        self._conn.request("HEAD", "/" + code)
        resp = self._conn.getresponse()
        resp.read()

        if resp.status in self.http_status_redirect:
            location = resp.getheader("Location")
            if not location:
                raise exceptions.ServiceException("No Location header after HTTP status 301")
            return location
        elif resp.status in self.http_status_no_redirect:
            raise exceptions.NoRedirectException()
        elif resp.status in self.http_status_code_blocked:
            raise exceptions.CodeBlockedException()
        elif resp.status in self.http_status_blocked:
            raise exceptions.BlockedException()
        else:
            raise exceptions.ServiceException("Unknown HTTP status %i" % resp.status)

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

class Tinyurl(Service):

    @property
    def charset(self):
        return "0123456789abcdefghijklmnopqrstuvwxyz"


    def __init__(self):
        self._conn = httplib.HTTPConnection("tinyurl.com")

    def fetch(self, code):
        self._conn.request("HEAD", "/" + code)
        resp = self._conn.getresponse()
        resp.read()

        if resp.status == 200:
            return self._fetch_200(code)
        elif resp.status == 301:
            location = resp.getheader("Location")
            if not location:
                raise exceptions.CodeBlockedException("No Location header after HTTP status 301")
            return location
        elif resp.status == 302:
            raise exceptions.CodeBlockedException()
        elif resp.status == 404:
            raise exceptions.NoRedirectException()
        elif resp.status == 500:
            # Some "errorhelp" URLs result in HTTP status 500, which goes away when trying a different server
            self._conn.close()
            self._conn.connect()
            raise exceptions.ServiceException("HTTP status 500")
        else:
            raise exceptions.ServiceException("Unknown HTTP status %i" % resp.status)

        return resp.status

    def _fetch_200(self, code):
        self._conn.request("GET", "/" + code)
        resp = self._conn.getresponse()
        data = resp.read()

        if resp.status != 200:
            raise exceptions.ServiceException("HTTP status changed from 200 to %i on second request" % resp.status)

        if "<title>Redirecting...</title>" in data:
            return self._parse_errorhelp(code, data)
        elif "Error: TinyURL redirects to a TinyURL." in data:
            return self._parse_tinyurl_redirect(data)
        else:
            raise exceptions.ServiceException("Unexpected response on status 200")

    def _parse_errorhelp(self, code, data):
        match = re.search('<meta http-equiv="refresh" content="0;url=(.*?)">', data)
        if not match:
            raise exceptions.ServiceException("No redirect on \"errorhelp\" page on HTTP status 200")
        url = urlparse.urlparse(match.group(1))
        if url.scheme != "http" or url.netloc != "tinyurl.com" or url.path != "/errorb.php":
            raise exceptions.ServiceException("Unexpected redirect on \"errorhelp\" page  on HTTP status 200")
        query = urlparse.parse_qs(url.query)
        if not ("url" in query and len(query["url"]) == 1) or not ("path" in query and len(query["path"]) == 1):
            raise exceptions.ServiceException("Unexpected redirect on \"errorhelp\" page  on HTTP status 200")
        if query["path"][0] != ("/" + code):
            raise exceptions.ServiceException("Code mismatch on \"errorhelp\" on HTTP status 200")

        return query["url"][0]

    def _parse_tinyurl_redirect(self, data):
        match = re.search("<p class=\"intro\">The URL you followed redirects back to a TinyURL and therefore we can't directly send you to the site\\. The URL it redirects to is <a href=\"(.*?)\">", data, re.DOTALL)
        if not match:
            raise exceptions.ServiceException("No redirect on \"tinyurl redirect\" page on HTTP status 200")

        return match.group(1)

class Ur1ca(SimpleService):

    @property
    def charset(self):
        return "0123456789abcdefghijklmnopqrstuvwxyz"

    @property
    def host(self):
        return "ur1.ca"

    @property
    def http_status_no_redirect(self):
        return [200]

def factory(name):
    if name == "bitly":
        return Bitly()
    elif name == "isgd":
        return Isgd()
    elif name == "tinyurl":
        return Tinyurl()
    elif name == "ur1ca":
        return Ur1ca()
    raise ValueError("Unknown service %s" % name)

