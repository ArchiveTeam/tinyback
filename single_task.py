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
tracker = "http://tracker.tinyarchive.org/v1/"

for i, value in enumerate(sys.argv):
    if i == 1:
        username = value
    elif i == 2:
        tmp_dir = value
    elif i == 3:
        tracker = value


class StreamHandlerWithProgress(logging.StreamHandler):
    """For use with Seesaw to output progress"""
    def __init__(self):
        self._last_newline = True
        logging.StreamHandler.__init__(self)

    def emit(self, record):
        if not getattr(record, 'progress', None):
            if not self._last_newline:
                sys.stdout.write('\n')

            self._last_newline = True
            return logging.StreamHandler.emit(self, record)

        try:
            self._last_newline = False
            message = record.getMessage()
            sys.stdout.write('\r ')
            sys.stdout.write(message)
            sys.stdout.flush()
        except (KeyboardInterrupt, SystemExit):
            raise
        except:
            self.handleError(record)


handler = StreamHandlerWithProgress()
handler.setFormatter(logging.Formatter("%(asctime)s %(name)s %(levelname)s: %(message)s"))
logger = logging.getLogger()
logger.addHandler(handler)
logger.setLevel(logging.INFO)

tracker = tinyback.tracker.Tracker(tracker)
try:
    task = tracker.fetch()
except:
    sys.exit(1)
if not task:
    time.sleep(300)
    sys.exit(0)

reaper = tinyback.Reaper(task, progress=True)
fileobj = reaper.run(tmp_dir)
tracker.put(task, fileobj, username)
fileobj.close()
