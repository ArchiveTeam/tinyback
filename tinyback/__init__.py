# TinyBack - A tiny web scraper
# Copyright (C) 2012 David Triendl
# Copyright (C) 2012 Sven Slootweg
# Copyright (C) 2012 Alard
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
import sys
import tempfile
import time

from tinyback import exceptions, generators, services

__version__ = "2.8"

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
            except exceptions.ServiceException, e:
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

    def __init__(self, task, progress=False):
        self._log = logging.getLogger("tinyback.Reaper")
        self._task = task
        self._service = services.factory(self._task["service"])
        self._progress = progress

        self._codes_tried = 0
        self._urls_found = 0

        if self._service.rate_limit:
            self._log.info("Rate limit: %i requests per %i seconds" % self._service.rate_limit)
            self._rate_limit_bucket = 0
            self._rate_limit_next = time.time()

    def run(self, temp_dir=None):
        self._log.info("Starting Reaper")
        fileobj = tempfile.TemporaryFile(dir=temp_dir)
        gzip_fileobj = gzip.GzipFile(mode="wb", fileobj=fileobj)

        for code in generators.factory(self._task["generator_type"], self._task["generator_options"]):
            self._codes_tried += 1
            blocked = 0
            tries = 0
            while tries < (self.MAX_TRIES + blocked):
                tries += 1
                self._rate_limit()
                self._log.debug("Fetching code %s, try %i" % (code, tries))
                try:
                    result = self._service.fetch(code)
                except exceptions.NoRedirectException:
                    self._log.debug("Code %s does not exist" % code)
                    break
                except exceptions.BlockedException:
                    if self._service.rate_limit:
                        self._rate_limit_bucket = 0
                    blocked += 1
                    wait = (min(5 ** blocked, 3600))
                    self._log.info("Service blocked us %i times, backing off for %i seconds" % (blocked, wait))
                    time.sleep(wait)
                except exceptions.ServiceException, e:
                    self._log.warn("ServiceException(%s) on code %s" % (e, code))
                else:
                    if "\n" in result or "\r" in result:
                        self._log.warn("URL for code %s contains newline" % code)
                    else:
                        self._urls_found += 1
                        self._log.debug("Code %s leads to URL '%s'" % (code, result.decode("ascii", "replace")))
                        self._print_progress()
                        gzip_fileobj.write(code + "|")
                        gzip_fileobj.write(result)
                        gzip_fileobj.write("\n")
                    break

        gzip_fileobj.close()
        self._log.info("Reaper examined %d codes and found %d URLs" % (self._codes_tried, self._urls_found))
        return fileobj

    def _rate_limit(self):
        if not self._service.rate_limit:
            return

        if self._rate_limit_bucket > 0:
            self._rate_limit_bucket -= 1
            return

        wait = self._rate_limit_next - time.time()
        if wait > 0:
            self._log.debug("Sleeping for %f seconds to satisfy rate limit" % wait)
            time.sleep(wait)

        settings = self._service.rate_limit
        self._rate_limit_bucket = settings[0] - 1
        self._rate_limit_next = time.time() + settings[1]

    def _print_progress(self):
        """Print progress for use in Seesaw"""
        if self._progress and self._codes_tried % 10 == 0:
            # FIXME: Need newline logic to stop messy log msgs due to lack
            # of ending newline
            sys.stdout.write('\r Found %d URLs of %d examined so far' % (
                self._urls_found, self._codes_tried))
            sys.stdout.flush()
