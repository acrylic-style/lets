import timeout_decorator
import tornado.gen
import tornado.web

from common.log import logUtils as log
from common.ripple import userUtils
from common.web import requestsManager
from constants import exceptions
from helpers import replayHelper
from objects import glob
from common.sentry import sentry
from common.constants import gameModes

class handler(requestsManager.asyncRequestHandler):
	"""
	Handler for osu-getreplay.php
	"""
	MODULE_NAME = "get_replay"

	@tornado.web.asynchronous
	@tornado.gen.engine
	@sentry.captureTornado
	def asyncGet(self):
		try:
			# Get request ip
			ip = self.getRequestIP()

			# Print arguments
			if glob.conf["DEBUG"]:
				requestsManager.printArguments(self)

			# Check arguments
			if not requestsManager.checkArguments(self.request.arguments, ["c", "u", "h", "m"]):
				raise exceptions.invalidArgumentsException(self.MODULE_NAME)

			# Get arguments
			username = self.get_argument("u")
			password = self.get_argument("h")
			replayID = self.get_argument("c")
			game_mode = int(self.get_argument("m"))

			# Login check
			userID = userUtils.getID(username)
			if userID == 0:
				raise exceptions.loginFailedException(self.MODULE_NAME, userID)
			if not userUtils.checkLogin(userID, password, ip):
				raise exceptions.loginFailedException(self.MODULE_NAME, username)
			if userUtils.check2FA(userID, ip):
				raise exceptions.need2FAException(self.MODULE_NAME, username, ip)

			# Get user ID
			replayData = glob.db.fetch("SELECT osu_scores.*, phpbb_users.username FROM osu_scores LEFT JOIN phpbb_users ON osu_scores.user_id = phpbb_users.user_id WHERE osu_scores.score_id = %s", [replayID])

			# Increment 'replays watched by others' if needed
			if replayData is not None:
				if username != replayData["username"]:
					userUtils.incrementReplaysWatched(replayData["user_id"], game_mode)

			# Serve replay
			log.info(f"Serving replay_{gameModes.getSafeGameMode(game_mode)}_{replayID}.osr (gm: {game_mode})")
			r = ""
			replayID = int(replayID)
			try:
				r = replayHelper.getRawReplayS3(replayID, game_mode)
			except timeout_decorator.TimeoutError:
				log.warning("S3 timed out")
				sentry.captureMessage("S3 timeout while fetching replay.")
				glob.stats["replay_download_failures"].labels(type="raw_s3_timeout").inc()
			except FileNotFoundError:
				log.warning("Replay {} doesn't exist".format(replayID))
			except:
				glob.stats["replay_download_failures"].labels(type="raw_other").inc()
				raise
			finally:
				self.write(r)
		except exceptions.invalidArgumentsException:
			pass
		except exceptions.need2FAException:
			pass
		except exceptions.loginFailedException:
			pass