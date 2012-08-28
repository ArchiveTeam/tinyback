#!/usr/bin/env python

import logging
import sys

from seesaw.externalprocess import *
from seesaw.pipeline import *
from seesaw.project import *
from seesaw.task import *

logging.basicConfig(level=logging.DEBUG)

pipeline = Pipeline(
    ExternalProcess("Tinyback", ["./run.py",
        "-t", "http://10.0.0.154:8080/",
        "-o",
        "-s", "60"])
)


project = Project(
    title = "URLTeam",
    project_html = """
    <h2>URLTeam <span class="links"><a href="http://urlte.am/">Website</a></span></h2>
    <p>The URLTeam is a project to preserve shorturls from various URL shorteners.</p>
    """
)
