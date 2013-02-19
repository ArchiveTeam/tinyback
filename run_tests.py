#!/usr/bin/env python

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
import os
import re

import tinyback

logging.basicConfig(level=logging.DEBUG)

tests_path = os.path.join(os.path.dirname(__file__), "test-definitions")
for filename in os.listdir(tests_path):
    match = re.match("^([a-z0-9]+)\.txt", filename)
    if not match:
        continue
    name = match.group(1)
    if name != "isgd":
        continue
    fixtures = os.path.join(tests_path, filename)
    tinyback.ServiceTester(name, fixtures).run()
