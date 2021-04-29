import tornado.gen
import tornado.web

from common.sentry import sentry
from common.web import requestsManager
from common.web import cheesegull
from constants import exceptions
from common.log import logUtils as log
from objects import glob

class handler(requestsManager.asyncRequestHandler):
	"""
	Handler for /web/osu-search.php
	"""
	MODULE_NAME = "osu_direct_search"

	@tornado.web.asynchronous
	@tornado.gen.engine
	@sentry.captureTornado
	def asyncGet(self):
		# Print arguments
		if glob.conf["DEBUG"]:
			requestsManager.printArguments(self)

		output = ""
		try:
			try:
				# Get arguments
				gameMode = self.get_argument("m", None)
				if gameMode is not None:
					gameMode = int(gameMode)
				if gameMode < 0 or gameMode > 3:
					gameMode = None

				rankedStatus = self.get_argument("r", None)
				if rankedStatus is not None:
					rankedStatus = int(rankedStatus)

				query = self.get_argument("q", "")
				page = int(self.get_argument("p", "0"))
			except ValueError:
				raise exceptions.invalidArgumentsException(self.MODULE_NAME)

			# Get data from cheesegull API
			log.info("Requested osu!direct search: {}".format(query if query != "" else "index"))
			approved = cheesegull.directToApiStatus(rankedStatus)
			if approved is None:
				raise exceptions.noAPIDataError()
			if approved == 999:
				approved = "1 OR 2"
			sort = ""
			if query.lower() == "newest":
				if rankedStatus == 5 or rankedStatus == 2:
					field = "last_update"
				else:
					field = "approved_date"
				sort = f"ORDER BY {field} DESC"
			if query.lower() == "top rated":
				sort = "ORDER BY rating DESC"
			if query.lower() == "most played":
				sort = "ORDER BY play_count DESC"

			res = glob.db.fetchAll(
				f"SELECT * FROM (SELECT * FROM osu_beatmapsets WHERE approved = {approved} {sort} LIMIT %s, 100) a LEFT JOIN (SELECT * FROM osu_beatmaps) b ON a.beatmapset_id = b.beatmapset_id",
				(
					page * 100,
				)
			)
			if res is None:
				raise exceptions.noAPIDataError()

			searchData = {}
			for data in res:
				if data["beatmapset_id"] in searchData:
					searchData[data["beatmapset_id"]].append(data)
				else:
					searchData[data["beatmapset_id"]] = [data]

			# Write output
			output += "999" if len(searchData) == 100 else str(len(list(searchData.values())))
			output += "\n"
			for beatmapSet in list(searchData.values()):
				try:
					output += cheesegull.toDirect(beatmapSet) + "\r\n"
				except ValueError:
					# Invalid cheesegull beatmap
					pass
		except (exceptions.noAPIDataError, exceptions.invalidArgumentsException):
			output = "0\n"
		finally:
			self.write(output)
