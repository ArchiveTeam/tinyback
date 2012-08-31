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

import gzip
import hashlib
import logging
import tempfile
import time

from tinyback import exceptions, generators, services

__version__ = "2.0"

class ServiceTester:

    def __init__(self, name, fixtures):
        self._log = logging.getLogger("tinyback.ServiceTester.%s" % name)
        self._service = services.factory(name)
        self._fixtures = fixtures

    def run(self):
        self._log.info("Testing service")
        f = open(self._fixtures, "r")

        for line in f:
            line = line.rstrip("\r\n")
            if not line or line[0] == "#":
                continue
            line = line.split("|", 1)

            code = line[0]
            if line[1] == "notfound":
                expected = exceptions.NoRedirectException
            elif line[1] == "blocked":
                expected = exceptions.CodeBlockedException
            else:
                expected = line[1]

            success = False
            try:
                result = self._service.fetch(code)
                success = isinstance(expected, str) and result == expected
            except exceptions.ServiceException as e:
                result = e
                success = (not isinstance(expected, str)) and issubclass(expected, exceptions.ServiceException) and isinstance(result, expected)

            if not success:
                self._log.warn("Code %s, Expected: %s, Result: %s" % (code, expected, result))
            else:
                self._log.debug("Code %s, Expected: %s, Result: %s" % (code, expected, result))

        f.close()
        self._log.info("Finished testing")

class Reaper:

    MAX_TRIES = 3

    def __init__(self, task):
        self._log = logging.getLogger("tinyback.Reaper")
        self._task = task
        self._service = services.factory(self._task["service"])

        if self._service.rate_limit:
            self._log.info("Rate limit: %i requests per %i seconds" % self._service.rate_limit)
        else:
            self._log.info("Service specifies no rate limit, using default of 5 requests per 5 seconds")
        self._rate_limit_bucket = 0
        self._rate_limit_next = time.time()

    def run(self):
        self._log.info("Starting Reaper")
        fileobj = tempfile.TemporaryFile()
        gzip_fileobj = gzip.GzipFile(mode="wb", fileobj=fileobj)
        for code in generators.factory(self._task["generator_type"], self._task["generator_options"]):
            tries = 0
            for i in range(self.MAX_TRIES):
                self._rate_limit()
                self._log.debug("Fetching code %s, try %i" % (code, i))
                try:
                    result = self._service.fetch(code)
                except exceptions.NoRedirectException:
                    self._log.debug("Code %s does not exist" % code)
                    break
                except exceptions.BlockedException:
                    self._log.info("Service is blocking us")
                    self._rate_limit_bucket = 0
                except exceptions.ServiceException as e:
                    self._log.warn("ServiceException(%s) on code %s" % (e, code))
                else:
                    if "\n" in result or "\r" in result:
                        self._log.warn("URL for code %s contains newline" % code)
                    else:
                        self._log.debug("Code %s leads to URL '%s'" % (code, result.decode("ascii", "replace")))
                        gzip_fileobj.write(code + "|")
                        gzip_fileobj.write(result)
                        gzip_fileobj.write("\n")
                    break
        gzip_fileobj.close()
        return fileobj

    def _rate_limit(self):
        if self._rate_limit_bucket > 0:
            self._rate_limit_bucket -= 1
            return

        wait = self._rate_limit_next - time.time()
        if wait > 0:
            self._log.debug("Sleeping for %f seconds to satisfy rate limit" % wait)
            time.sleep(wait)

        settings = self._service.rate_limit or (5, 5)
        self._rate_limit_bucket = settings[0] - 1
        self._rate_limit_next = time.time() + settings[1]
