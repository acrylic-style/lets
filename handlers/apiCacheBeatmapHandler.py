import json

import tornado.gen
import tornado.web

from objects import beatmap
from common.log import logUtils as log
from common.web import requestsManager
from constants import exceptions
from helpers import osuapiHelper
from common.sentry import sentry


class handler(requestsManager.asyncRequestHandler):
	"""
	Handler for /api/v1/cacheBeatmap
	"""
	MODULE_NAME = "api/cacheBeatmap"

	@tornado.web.asynchronous
	@tornado.gen.engine
	@sentry.captureTornado
	def asyncPost(self):
		statusCode = 400
		data = {"message": "unknown error"}
		try:
			# Check arguments
			if not requestsManager.checkArguments(self.request.arguments, ["sid", "refresh"]):
				raise exceptions.invalidArgumentsException(self.MODULE_NAME)

			# Get beatmap set data from osu api
			beatmapSetID = self.get_argument("sid")
			refresh = int(self.get_argument("refresh"))
			if refresh == 1:
				log.debug("Forced refresh")
			apiResponse = osuapiHelper.osuApiRequest("get_beatmaps", "s={}".format(beatmapSetID), False)
			if len(apiResponse) == 0:
				raise exceptions.invalidBeatmapException

			# Loop through all beatmaps in this set and save them in db
			data["maps"] = []
			for i in apiResponse:
				log.debug("Saving beatmap {} in db".format(i["file_md5"]))
				bmap = beatmap.beatmap(i["file_md5"], int(i["beatmapset_id"]), refresh=refresh)
				# TODO: reimplement? actually, this seems to be unused
				pp = 0
				data["maps"].append({
					"id": bmap.beatmapId,
					"name": bmap.songName,
					"status": bmap.approved,
					"frozen": False,
					"pp": pp,
				})

			# Set status code and message
			statusCode = 200
			data["message"] = "ok"
		except exceptions.invalidArgumentsException:
			# Set error and message
			statusCode = 400
			data["message"] = "missing required arguments"
		except exceptions.invalidBeatmapException:
			statusCode = 400
			data["message"] = "beatmap not found from osu!api."
		finally:
			# Add status code to data
			data["status"] = statusCode

			# Send response
			self.write(json.dumps(data))
			self.set_header("Content-Type", "application/json")
			#self.add_header("Access-Control-Allow-Origin", "*")
			self.set_status(statusCode)