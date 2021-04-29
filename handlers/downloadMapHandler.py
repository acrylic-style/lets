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
			self.set_status(302, "Moved Temporarily")
			self.add_header("Location", f"https://api.chimu.moe/v1/download/{bid}?n={nv}")
			self.add_header("Cache-Control", "no-cache")
			self.add_header("Pragma", "no-cache")
		except ValueError:
			self.set_status(400)
			self.write("Invalid set id")
