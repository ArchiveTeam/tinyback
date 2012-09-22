#!/usr/bin/env python

from seesaw.externalprocess import *
from seesaw.pipeline import *
from seesaw.project import *

pipeline = Pipeline(
    ExternalProcess("TinyBack", ["./run.py",
        "--tracker=http://tracker.tinyarchive.org/v1/",
        "--sleep=60",
        "--one-task",
        "--temp-dir=./data",
        "--username=" + str(downloader)
        ])
)

project = Project(
    title = "URLTeam",
    project_html = """
    <h2>URLTeam <span class="links"><a href="http://urlte.am/">Website</a></span></h2>
    <p>The URLTeam is a project to preserve shorturls from various URL shorteners.</p>
    """
)
