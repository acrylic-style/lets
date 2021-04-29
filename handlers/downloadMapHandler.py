import requests
import tornado.gen
import tornado.web
import time
import hashlib

from common.web import requestsManager
from common.sentry import sentry
from objects import glob
import urllib.parse

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

			res = glob.db.fetch("SELECT * FROM osu_beatmapsets WHERE beatmapset_id = %s LIMIT 1", bid)
			if res is None:
				raise ValueError()
			nv = "1" if noVideo else "0"
			artist = res["artist"]
			title = res["title"]
			diskFilename = f"{bid} {artist} - {title}.osz"
			serveFilename = f"{bid} {artist} - {title}"
			if noVideo:
				serveFilename += " [no video]"
			serveFilename += ".osz"
			serveFilename = serveFilename.replace('"', '').replace('?', '')
			currentTime = int(time.time())
			checksum = hashlib.md5(bytes(f"{bid}{diskFilename}{serveFilename}{currentTime}{nv}a", "utf-8")).hexdigest()
			url = f"https://osu.ppy.sh/d/{bid}?fs={urllib.parse.quote_plus(serveFilename)}&fd={urllib.parse.quote_plus(diskFilename)}&ts={currentTime}&cs={checksum}&nv={nv}"
			response = requests.get(url, timeout=5)
			self.write(response.text)
			# self.set_status(302, "Moved Temporarily")
			# self.add_header("Location", url)
			# self.add_header("Cache-Control", "no-cache")
			# self.add_header("Pragma", "no-cache")
		except ValueError:
			self.set_status(400)
			self.write("Invalid set id")
