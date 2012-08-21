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

import logging

from tinyback import exceptions, services

class ServiceTester:

    def __init__(self, service_name, fixtures):
        self._name = service_name.capitalize()
        self._log = logging.getLogger("tinyback.ServiceTester.%s" % self._name)
        try:
            service = getattr(services, self._name)
        except AttributeError:
            raise NameError("Unknown service \"%s\"" % self._name)
        self._service = service()
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
                self._log.debug("Code %s, Result: %s" % (code, result))

        f.close()
        self._log.info("Finished testing")
