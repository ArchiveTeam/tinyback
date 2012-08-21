#!/usr/bin/env python

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
    fixtures = os.path.join(tests_path, filename)
    tinyback.ServiceTester(name, fixtures).run()
