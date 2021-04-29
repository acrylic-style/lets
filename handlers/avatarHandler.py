import requests
import tornado.gen
import tornado.web
import time

from common.web import requestsManager
from common.sentry import sentry


class handler(requestsManager.asyncRequestHandler):
	"""
	Handler for /<number>
	"""
	MODULE_NAME = "avatar"

	@tornado.web.asynchronous
	@tornado.gen.engine
	@sentry.captureTornado
	def asyncGet(self, uid, *, unused=0):
		try:
			ct = int(time.time()) * 10
			res = requests.get(f"https://osu.acrylicstyle.xyz/uploads-avatar/{uid}?{ct}")
			if res.status_code != 200:
				raise requests.RequestException()
			self.write(res.content)
		except requests.RequestException:
			with open("./guest.png", "rb") as f:
				self.write(f.read())
		finally:
			self.add_header("Content-Type", "image/png")
			self.add_header("Cache-Control", "no-cache")
			self.add_header("Pragma", "no-cache")
