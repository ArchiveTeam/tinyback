#!/usr/bin/env python

# TinyBack - A tiny web scraper
# Copyright (C) 2012 David Triendl
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

from seesaw.externalprocess import *
from seesaw.pipeline import *
from seesaw.project import *

if downloader:
    username = downloader
else:
    username = "warrior"

pipeline = Pipeline(
    ExternalProcess("TinyBack", ["./run.py",
        "--tracker=http://tracker.tinyarchive.org/v1/",
        "--sleep=60",
        "--one-task",
        "--temp-dir=./data",
        "--username", username
        ])
)

project = Project(
    title = "URLTeam",
    project_html = """
    <h2>URLTeam <span class="links"><a href="http://urlte.am/">Website</a></span></h2>
    <p>The URLTeam is a project to preserve shorturls from various URL shorteners.</p>
    """
)
