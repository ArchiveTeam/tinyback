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
import sys
import time

import tinyback
import tinyback.tracker

username = tmp_dir = None
for i, value in enumerate(sys.argv):
    if i == 1:
        username = value
    elif i == 2:
        tmp_dir = value

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(name)s %(levelname)s: %(message)s")

tracker = tinyback.tracker.Tracker("http://tracker.tinyarchive.org/v1/")
task = tracker.fetch()
if not task:
    time.sleep(60)
    sys.exit(0)

reaper = tinyback.Reaper(task)
fileobj = reaper.run(tmp_dir)
tracker.put(task, fileobj, username)
fileobj.close()
