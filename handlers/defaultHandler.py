import logging

import tornado.gen
import tornado.web

from common.web import requestsManager


class handler(requestsManager.asyncRequestHandler):
	MODULE_NAME = "default"

	@tornado.web.asynchronous
	@tornado.gen.engine
	def asyncGet(self):
		logging.info("404: {}".format(self.request.uri))
		self.write("""
				<html>
					<head>
					</head>
					<body onload="location.href = 'https://osu.acrylicstyle.xyz/'">
					</body>
				</html>
				""")
