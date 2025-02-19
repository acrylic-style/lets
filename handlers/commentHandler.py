import tornado.gen
import tornado.web

from common.log import logUtils as log
from common.ripple import userUtils
from common.sentry import sentry
from common.web import requestsManager
from constants import exceptions
from objects import glob


class handler(requestsManager.asyncRequestHandler):
	MODULE_NAME = "comments"
	CLIENT_WHO = {"normal": "", "player": "player", "admin": "bat", "donor": "subscriber"}

	@tornado.web.asynchronous
	@tornado.gen.engine
	@sentry.captureTornado
	def asyncPost(self):
		try:
			# Required arguments check
			if not requestsManager.checkArguments(self.request.arguments, ("u", "p", "a")):
				raise exceptions.invalidArgumentsException(self.MODULE_NAME)

			# Get arguments
			username = self.get_argument("u")
			password = self.get_argument("p")
			action = self.get_argument("a").strip().lower()

			# IP for session check
			ip = self.getRequestIP()

			# Login and ban check
			userID = userUtils.getID(username)
			if userID == 0:
				raise exceptions.loginFailedException(self.MODULE_NAME, userID)
			if not userUtils.checkLogin(userID, password, ip):
				raise exceptions.loginFailedException(self.MODULE_NAME, username)
			if userUtils.check2FA(userID, ip):
				raise exceptions.need2FAException(self.MODULE_NAME, userID, ip)
			if userUtils.isBanned(userID):
				raise exceptions.userBannedException(self.MODULE_NAME, username)

			# Action (depends on 'action' parameter, not on HTTP method)
			if action == "get":
				#self.write(self._getComments())
				return None
			elif action == "post":
				# TODO: How do we get gamemode needed to fetch score?
				# disabled for now
				# self._addComment()
				return None
		except (exceptions.loginFailedException, exceptions.need2FAException, exceptions.userBannedException):
			self.write("error: no")

	@staticmethod
	def clientWho(y):
		return handler.CLIENT_WHO[y["who"]] + (
			("|{}".format(y["special_format"])) if y["special_format"] is not None else ""
		)

	def _getComments(self):
		output = ""

		try:
			beatmapId = int(self.get_argument("b", default=0))
			beatmapSetID = int(self.get_argument("s", default=0))
			scoreID = int(self.get_argument("r", default=0))
		except ValueError:
			raise exceptions.invalidArgumentsException(self.MODULE_NAME)

		if beatmapId <= 0:
			return

		log.info("Requested comments for beatmap id {}".format(beatmapId))

		# Merge beatmap, beatmapset and score comments
		for x in (
				{"db_type": "beatmap_id", "client_type": "map", "value": beatmapId},
				{"db_type": "beatmapset_id", "client_type": "song", "value": beatmapSetID},
				{"db_type": "score_id", "client_type": "replay", "value": scoreID},
		):
			# Add this set of comments only if the client has set the value
			if x["value"] <= 0:
				continue

			# Fetch these comments
			comments = glob.db.fetchAll(
				"SELECT * FROM comments WHERE {} = %s ORDER BY `time`".format(x["db_type"]),
				(x["value"],)
			)

			# Output comments
			output += "\n".join([
				"{y[time]}\t{client_name}\t{client_who}\t{y[comment]}".format(
					y=y,
					client_name=x["client_type"],
					client_who=self.clientWho(y)
				) for y in comments
			]) + "\n"
		return output

	def _addComment(self):
		username = self.get_argument("u")
		target = self.get_argument("target", default=None)
		specialFormat = self.get_argument("f", default=None)
		userID = userUtils.getID(username)

		# Technically useless
		if userID < 0:
			return

		# Get beatmap/set/score ids
		try:
			beatmapId = int(self.get_argument("b", default=0))
			beatmapSetID = int(self.get_argument("s", default=0))
			scoreID = int(self.get_argument("r", default=0))
		except ValueError:
			raise exceptions.invalidArgumentsException(self.MODULE_NAME)

		# Add a comment, removing all illegal characters and trimming after 128 characters
		comment = self.get_argument("comment").replace("\r", "").replace("\t", "").replace("\n", "")[:128]
		try:
			time_ = int(self.get_argument("starttime"))
		except ValueError:
			raise exceptions.invalidArgumentsException(self.MODULE_NAME)

		# Type of comment
		who = "normal"
		if target == "replay" and glob.db.fetch(
				"SELECT COUNT(*) AS c FROM osu_scores WHERE id = %s AND user_id = %s AND pass = 1",
				(scoreID, userID)
		)["c"] > 0:
			# From player, on their score
			who = "player"
		elif userUtils.isInAnyPrivilegeGroup(userID, ("dev", "gmt", "nat")):
			# From BAT/Admin
			who = "admin"
		elif userUtils.isInPrivilegeGroup(userID, "supporter"):
			# Supporter
			who = "donor"

		if target == "song":
			# Set comment
			if beatmapSetID <= 0:
				return
			value = beatmapSetID
			column = "beatmapset_id"
		elif target == "map":
			# Beatmap comment
			if beatmapId <= 0:
				return
			value = beatmapId
			column = "beatmap_id"
		elif target == "replay":
			# Score comment
			if scoreID <= 0:
				return
			value = scoreID
			column = "score_id"
		else:
			# Invalid target
			return

		# Make sure the user hasn't submitted another comment on the same map/set/song in a 5 seconds range
		if glob.db.fetch(
			"SELECT COUNT(*) AS c FROM comments WHERE user_id = %s AND {} = %s AND `time` BETWEEN %s AND %s".format(
				column
			), (userID, value, time_ - 5000, time_ + 5000)
		)["c"] > 0:
			return

		# Store the comment
		glob.db.execute(
			"INSERT INTO comments ({}, user_id, comment, `time`, who, special_format) "
			"VALUES (%s, %s, %s, %s, %s, %s)".format(column),
			(value, userID, comment, time_, who, specialFormat)
		)
		log.info("Submitted {} ({}) comment, user {}: '{}'".format(column, value, userID, comment))
