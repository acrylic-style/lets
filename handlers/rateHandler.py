import tornado.gen
import tornado.web

from common.ripple import userUtils
from common.sentry import sentry
from common.web import requestsManager
from constants import exceptions, rankedStatuses
from objects import glob


class handler(requestsManager.asyncRequestHandler):
	MODULE_NAME = "rate"

	@tornado.web.asynchronous
	@tornado.gen.engine
	@sentry.captureTornado
	def asyncGet(self):
		output = ""

		try:
			if not requestsManager.checkArguments(self.request.arguments, ["c", "u", "p"]):
				raise exceptions.invalidArgumentsException(MODULE_NAME)

			ip = self.getRequestIP()
			username = self.get_argument("u").strip()
			password = self.get_argument("p").strip()
			user_id = userUtils.getID(username)
			checksum = self.get_argument("c").strip()
			if not user_id:
				raise exceptions.loginFailedException(self.MODULE_NAME, user_id)
			if not userUtils.checkLogin(user_id, password, ip):
				raise exceptions.loginFailedException(self.MODULE_NAME, username)
			if userUtils.check2FA(user_id, ip):
				raise exceptions.need2FAException(self.MODULE_NAME, user_id, ip)

			res = glob.db.fetch(
				"SELECT `approved` AS `ranked`, `beatmapset_id` FROM osu_beatmaps WHERE checksum = %s LIMIT 1",
				(checksum,)
			)

			if res is None:
				output = "no exist"
				return

			beatmapsetId = res["beatmapset_id"]
			if res["ranked"] < rankedStatuses.RANKED:
				output = "not ranked"
				return

			rating = glob.db.fetch("SELECT rating FROM osu_beatmapsets WHERE beatmapset_id = %s LIMIT 1", (beatmapsetId,))
			has_voted = glob.db.fetch(
				"SELECT user_id FROM osu_user_beatmapset_ratings WHERE user_id = %s AND beatmapset_id = %s LIMIT 1",
				(user_id, beatmapsetId)
			)
			if has_voted is not None:
				output = f"alreadyvoted\n{rating['rating']:.2f}"
				return
			vote = self.get_argument("v", default=None)
			if vote is None:
				output = "ok"
				return
			try:
				vote = int(vote)
			except ValueError:
				raise exceptions.invalidArgumentsException(self.MODULE_NAME)
			if vote < 0 or vote > 10:
				output = "out of range"
				return
			glob.db.execute(
				"REPLACE INTO osu_user_beatmapset_ratings (beatmapset_id, user_id, rating) VALUES (%s, %s, %s)",
				(beatmapsetId, user_id, vote)
			)
			glob.db.execute(
				"UPDATE osu_beatmapsets SET rating = (SELECT SUM(rating)/COUNT(rating) FROM osu_user_beatmapset_ratings "
				"WHERE beatmapset_id = %s) WHERE beatmapset_id = %s LIMIT 1",
				(beatmapsetId, beatmapsetId,)
			)
			rating = glob.db.fetch("SELECT rating FROM osu_beatmapsets WHERE beatmapset_id = %s LIMIT 1", (beatmapsetId,))
			output = f"{rating['rating']:.2f}"
		except exceptions.loginFailedException:
			output = "auth failed"
		except exceptions.invalidArgumentsException:
			output = "no"
		finally:
			self.write(output)
