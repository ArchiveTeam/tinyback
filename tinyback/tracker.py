import httplib
import json
import logging
import urllib
import urlparse

import tinyback

class Tracker:

    def __init__(self, tracker_url):
        self._log = logging.getLogger("tinyback.Tracker")
        self._log.info("Initializing tracker at %s" % tracker_url)

        if tracker_url[-1] != "/":
            tracker_url += "/"
        self._url = urlparse.urlparse(tracker_url)

    def clear(self):
        self._log.info("Clearing all tasks")
        status, data = self._request("GET", "task/clear")
        if status != httplib.OK:
            raise Exception("Unexpected status %i" % status)

    def fetch(self):
        status, task = self._request("GET", "task/get")
        if status != httplib.OK:
            raise Exception("Unexpected status %i" % status)
        task = json.loads(task)
        if task:
            self._log.info("Received task %s for service %s" % (task["id"], task["service"]))
        else:
            self._log.info("No tasks available")
        return task

    def put(self, task, data_file, username=None):
        task_id = task["id"]
        data_file.seek(0)

        params = {"id": task_id}
        if username:
            params["username"] = username

        status, task= self._request("POST", "task/put", params, data_file)
        if status == httplib.CONFLICT:
            self._log.warn("Server refused data for task %s" % task_id)
        elif status == httplib.OK:
            self._log.info("Successfully submitted task %s" % task_id)
        else:
            raise Exception("Unexpected status %i" % status)

    def _request(self, method, path, params={}, body=None):
        params["version"] = tinyback.__version__

        conn = httplib.HTTPConnection(self._url.netloc)
        path = self._url.path + path
        if len(params):
            path += "?" + urllib.urlencode(params)

        if body:
            conn.request(method, path, body=body)
        else:
            conn.request(method, path)

        resp = conn.getresponse()
        if resp.status == 403:
            self._log.warn("Received 403 Forbidden from tracker")
            self._log.warn("Tracker says: %s" % resp.read())
            raise Exception("403 Forbidden")
        return (resp.status, resp.read())
