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

import optparse
import logging
import sys
import threading
import time

import tinyback
import tinyback.tracker

def parse_options():
    parser = optparse.OptionParser()

    parser.add_option("-t", "--tracker", dest="tracker",
        help="Connect to tracker at URL", metavar="URL")
    parser.add_option("-c", "--clear", dest="clear", action="store_true",
        help="Clear all pending tasks from tracker")
    parser.add_option("-n", "--num-threads", dest="num_threads", type="int",
        default=1, help="Use N threads", metavar="N")
    parser.add_option("-s", "--sleep", dest="sleep", type="int", default=0,
        help="Sleep for N seconds when idle (0 means to exit when idle)",
        metavar="N")
    parser.add_option("-o", "--one-task", action="store_true", dest="one_task",
        help="Only fetch a single task (per thread), then terminate")
    parser.add_option("--temp-dir", dest="temp_dir",
        help="Set directory for temporary files to DIR", metavar="DIR")
    parser.add_option("-u", "--username", dest="username",
        help="Set tracker username")
    parser.add_option("-d", "--debug", action="store_const", dest="loglevel",
        const=logging.DEBUG, default=logging.INFO, help="Enable debug output")

    options, args = parser.parse_args()
    if args:
        parser.error("Unexpected argument %s" % args[0])
    if not options.tracker:
        parser.error("Missing required option --tracker")

    return options

def run_thread(options, tracker):
    while True:
        try:
            task = tracker.fetch()
        except:
            task = None

        if not task:
            if options.sleep <= 0:
                return
            time.sleep(options.sleep)
        else:
            reaper = tinyback.Reaper(task)
            fileobj = reaper.run(options.temp_dir)
            tracker.put(task, fileobj, options.username)
            fileobj.close()

        if options.one_task:
            return

def main():
    options = parse_options()

    logging.basicConfig(level=options.loglevel,
        format="%(asctime)s %(name)s %(levelname)s: %(message)s")

    tracker = tinyback.tracker.Tracker(options.tracker)
    if options.clear:
        tracker.clear()

    if options.num_threads == 1:
        run_thread(options, tracker)
    else:
        threads = []

        for i in range(options.num_threads):
            thread = threading.Thread(target=run_thread,args=(options, tracker))
            thread.start()
            threads.append(thread)

        for thread in threads:
            thread.join()

if __name__ == "__main__":
    main()
