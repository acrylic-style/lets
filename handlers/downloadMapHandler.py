import requests
import tornado.gen
import tornado.web

from common.web import requestsManager
from common.sentry import sentry

class handler(requestsManager.asyncRequestHandler):
	"""
	Handler for /d/
	"""
	MODULE_NAME = "direct_download"

	@tornado.web.asynchronous
	@tornado.gen.engine
	@sentry.captureTornado
	def asyncGet(self, bid):
		try:
			noVideo = bid.endswith("n")
			if noVideo:
				bid = bid[:-1]
			bid = int(bid)

			nv = "0" if noVideo else "1"
			response = requests.get(f"https://api.chimu.moe/v1/download/{bid}?n={nv}", timeout=5)
			self.write(response.content)
		except ValueError:
			self.set_status(400)
			self.write("Invalid set id")
