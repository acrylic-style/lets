import math
import time

import pp
from common import generalUtils
from common.constants import gameModes, mods
from constants import scoreOverwrite
from objects import beatmap
from common.log import logUtils as log
from common.ripple import userUtils
from common.ripple import scoreUtils
from objects import glob
from datetime import datetime

# TODO: GIVE THEM GAMEMODE PARAM IN CONSTRUCTOR!!!!!
class score:
	__slots__ = ["scoreID", "playerName", "score", "maxCombo", "c50", "c100", "c300", "cMiss", "cKatu", "cGeki",
	             "fullCombo", "mods", "playerUserID","rank","date", "hasReplay", "fileMd5", "passed", "playDateTime",
	             "gameMode", "completed", "accuracy", "pp", "oldPersonalBest", "rankedScoreIncrease",
				 "_playTime", "_fullPlayTime", "quit", "failed", "beatmapId"]
	def __init__(self, scoreID = None, rank = None, setData = True):
		"""
		Initialize a (empty) score object.

		scoreID -- score ID, used to get score data from db. Optional.
		rank -- score rank. Optional
		setData -- if True, set score data from db using scoreID. Optional.
		"""
		self.scoreID = 0
		self.playerName = "me@acrylicstyle.xyz" # get some help pls
		self.score = 0
		self.maxCombo = 0
		self.c50 = 0
		self.c100 = 0
		self.c300 = 0
		self.cMiss = 0
		self.cKatu = 0
		self.cGeki = 0
		self.fullCombo = False
		self.mods = 0
		self.playerUserID = 0
		self.rank = rank	# can be empty string too
		self.date = 0
		self.hasReplay = 0
		self.beatmapId = 1

		self.fileMd5 = None
		self.passed = False
		self.playDateTime = 0
		self.gameMode = 0
		self.completed = 0

		self.accuracy = 0.00

		self.pp = 0.00

		self.oldPersonalBest = 0
		self.rankedScoreIncrease = 0

		self._playTime = None
		self._fullPlayTime = None
		self.quit = None
		self.failed = None

		if scoreID is not None and setData:
			self.setDataFromDB(scoreID, rank)

	def _adjustedSeconds(self, x):
		if (self.mods & mods.DOUBLETIME) > 0:
			return x // 1.5
		elif (self.mods & mods.HALFTIME) > 0:
			return x // 0.75
		return x

	@property
	def isRelax(self):
		return self.mods & (mods.RELAX | mods.RELAX2) > 0

	@property
	def fullPlayTime(self):
		return self._fullPlayTime

	@fullPlayTime.setter
	def fullPlayTime(self, value):
		value = max(0, value)
		self._fullPlayTime = self._adjustedSeconds(value)

	@property
	def playTime(self):
		return self._playTime

	@playTime.setter
	def playTime(self, value):
		value = max(0, value)
		value = self._adjustedSeconds(value)
		# Do not consider the play time at all if it's greater than the length of the map + 1/3
		# This is because the client sends the ms when the player failed relative to the
		# song (audio file) start, so compilations and maps with super long introductions
		# break the system without this check
		if self.fullPlayTime is not None and value > self.fullPlayTime * 1.33:
			value = 0
		self._playTime = value

	def calculateAccuracy(self):
		"""
		Calculate and set accuracy for that score
		"""
		if self.gameMode == 0:
			# std
			totalPoints = self.c50*50+self.c100*100+self.c300*300
			totalHits = self.c300+self.c100+self.c50+self.cMiss
			if totalHits == 0:
				self.accuracy = 1
			else:
				self.accuracy = totalPoints/(totalHits*300)
		elif self.gameMode == 1:
			# taiko
			totalPoints = (self.c100*50)+(self.c300*100)
			totalHits = self.cMiss+self.c100+self.c300
			if totalHits == 0:
				self.accuracy = 1
			else:
				self.accuracy = totalPoints / (totalHits * 100)
		elif self.gameMode == 2:
			# ctb
			fruits = self.c300+self.c100+self.c50
			totalFruits = fruits+self.cMiss+self.cKatu
			if totalFruits == 0:
				self.accuracy = 1
			else:
				self.accuracy = fruits / totalFruits
		elif self.gameMode == 3:
			# mania
			totalPoints = self.c50*50+self.c100*100+self.cKatu*200+self.c300*300+self.cGeki*300
			totalHits = self.cMiss+self.c50+self.c100+self.c300+self.cGeki+self.cKatu
			self.accuracy = totalPoints / (totalHits * 300)
		else:
			# unknown gamemode
			self.accuracy = 0

	def setDataFromDB(self, scoreID, rank = None):
		"""
		Set this object's score data from db
		Sets playerUserID too

		scoreID -- score ID
		rank -- rank in scoreboard. Optional.
		"""
		# TODO: gamemode
		data = glob.db.fetch("SELECT osu_scores.*, phpbb_users.username FROM osu_scores LEFT JOIN phpbb_users ON phpbb_users.user_id = osu_scores.user_id WHERE osu_scores.high_score_id = %s LIMIT 1", [scoreID])
		high_data = glob.db.fetch("SELECT * FROM osu_scores_high WHERE score_id = %s LIMIT 1", [scoreID])
		if data is None:
			data = high_data

		if data is not None:
			bm = glob.db.fetch("SELECT checksum FROM osu_beatmaps WHERE beatmap_id = %s LIMIT 1", [data["beatmap_id"]])
			if high_data is not None:
				data["pp"] = high_data["pp"]
				data["high"] = 1
			data["beatmap_md5"] = bm["checksum"]
			self.setDataFromDict(data, rank)

	def setDataFromDict(self, data, rank = None):
		"""
		Set this object's score data from dictionary
		Doesn't set playerUserID

		data -- score dictionarty
		rank -- rank in scoreboard. Optional.
		"""
		if "high" not in data:
			data["high"] = 0
		self.scoreID = data["score_id"]
		if "username" in data:
			self.playerName = data["username"]
		else:
			self.playerName = userUtils.getUsername(data["user_id"])
		self.playerUserID = data["user_id"]
		self.score = data["score"]
		self.maxCombo = data["maxcombo"]
		self.gameMode = 0 # TODO: FIX THIS PLEASE
		self.c50 = data["count50"]
		self.c100 = data["count100"]
		self.c300 = data["count300"]
		self.cMiss = data["countmiss"]
		self.cKatu = data["countkatu"]
		self.cGeki = data["countgeki"]
		self.fullCombo = data["perfect"] == 1
		self.mods = data["enabled_mods"]
		self.rank = rank if rank is not None else ""
		self.date = data["date"]
		self.fileMd5 = data["beatmap_md5"] if "beatmap_md5" in data else None
		if self.fileMd5 is None:
			res = glob.db.fetch("SELECT checksum FROM osu_beatmaps WHERE beatmap_id = %s LIMIT 1", (data["beatmap_id"],))
			if res is not None:
				self.fileMd5 = res["checksum"]
		self.beatmapId = data["beatmap_id"] if "beatmap_id" in data else 1
		self.completed = 3 if data["high"] == 1 else 0
		#if "pp" in data:
		self.pp = data["pp"]
		self.calculateAccuracy()

	def setDataFromScoreData(self, scoreData, quit_=None, failed=None):
		"""
		Set this object's score data from scoreData list (submit modular)

		scoreData -- scoreData list
		"""
		if len(scoreData) >= 16:
			self.fileMd5 = scoreData[0]
			self.playerName = scoreData[1].strip()
			# %s%s%s = scoreData[2]
			self.c300 = int(scoreData[3])
			self.c100 = int(scoreData[4])
			self.c50 = int(scoreData[5])
			self.cGeki = int(scoreData[6])
			self.cKatu = int(scoreData[7])
			self.cMiss = int(scoreData[8])
			self.score = int(scoreData[9])
			self.maxCombo = int(scoreData[10])
			self.fullCombo = scoreData[11] == 'True'
			#self.rank = scoreData[12]
			self.mods = int(scoreData[13])
			self.passed = scoreData[14] == 'True'
			log.debug("passed: {}".format(self.passed))
			self.gameMode = int(scoreData[15])
			#self.playDateTime = int(scoreData[16])
			self.playDateTime = int(time.time())
			self.calculateAccuracy()
			#osuVersion = scoreData[17]
			self.quit = quit_
			self.failed = failed


	def getData(self, pp=False):
		"""Return score row relative to this score for getscores"""
		return "{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|1\n".format(
			self.scoreID,
			self.playerName,
			int(self.pp) if pp else self.score,
			self.maxCombo,
			self.c50,
			self.c100,
			self.c300,
			self.cMiss,
			self.cKatu,
			self.cGeki,
			1 if self.fullCombo == True else 0,
			self.mods,
			self.playerUserID,
			self.rank,
			self.date
		)

	def setCompletedStatus(self, overwritePolicy=scoreOverwrite.PP):
		"""
		Set this score completed status and rankedScoreIncrease
		"""
		try:
			self.completed = 0
			if not scoreUtils.isRankable(self.mods):
				log.debug("Unrankable mods")
				return
			if self.passed:
				log.debug("Passed")
				# Get userID
				userID = userUtils.getID(self.playerName)

				# Make sure we don't have another score identical to this one
				# This is problematic, consider removing it entirely,
				# a few duplicate rows aren't going to hurt anyone
				r = glob.db.fetch(
					"SELECT beatmap_id FROM osu_beatmaps WHERE checksum = %s LIMIT 1",
					(self.fileMd5)
				)
				if r is None:
					beatmapId = 0
				else:
					beatmapId = r["beatmap_id"]
				duplicate = glob.db.fetch(
					"SELECT score_id FROM osu_scores{} "
					"WHERE user_id = %s AND beatmap_id = %s "
					"AND score = %s AND enabled_mods = %s AND `date` >= %s "
					"LIMIT 1".format(gameModes.getGameModeForDB(self.gameMode)),
					(
						userID, beatmapId, self.score, self.mods, datetime.fromtimestamp(int(time.time()) - 120).strftime('%Y-%m-%d %H:%M:%S'),
					)
				)
				if duplicate is not None:
					# Found same score in db. Don't save this score.
					log.debug("Score duplicate")
					self.completed = -1
					return

				# No duplicates found.
				# Get right "completed" value
				log.debug("No duplicated")
				personalBest = glob.db.fetch(
					"SELECT score_id, score, pp FROM osu_scores{}_high "
					"WHERE user_id = %s AND beatmap_id = %s "
					"LIMIT 1".format(gameModes.getGameModeForDB(self.gameMode)),
					(userID, beatmapId)
				)
				if personalBest is None:
					# This is our first score on this map, so it's our best score
					self.completed = 3
					self.rankedScoreIncrease = self.score
					self.oldPersonalBest = 0
				else:
					# Compare personal best's score with current score
					self.rankedScoreIncrease = self.score-personalBest["score"]
					self.oldPersonalBest = personalBest["score_id"]
					if overwritePolicy == scoreOverwrite.PP and \
							personalBest["pp"] is not None and \
							not math.isclose(self.pp, personalBest["pp"], abs_tol=0.01):
						# User prioritizes pp
						self.completed = 3 if self.pp >= personalBest["pp"] else 2
					else:
						# User prioritizes score, or we have no pp, or we have same pp
						self.completed = 3 if self.score >= personalBest["score"] else 2
			elif self.quit:
				log.debug("Quit")
				self.completed = 0
			elif self.failed:
				log.debug("Failed")
				self.completed = 1
		finally:
			log.debug("Completed status: {}".format(self.completed))

	def saveScoreInDB(self):
		"""
		Save this score in DB (if passed and mods are valid)
		"""
		# Add this score
		if self.completed >= 0:
			bm = glob.db.fetch(
				"SELECT osu_beatmaps.approved, osu_beatmapsets.title, osu_beatmaps.version, osu_beatmaps.beatmap_id, osu_beatmaps.beatmapset_id FROM osu_beatmaps LEFT JOIN osu_beatmapsets ON osu_beatmapsets.beatmapset_id = osu_beatmaps.beatmapset_id WHERE osu_beatmaps.checksum = %s LIMIT 1",
				(self.fileMd5)
			)
			if bm is None or self.mods & 536870912 != 0 or self.mods & 2048 != 0:
				# - No beatmap information available
				# - or is score v2
				# - or is auto play (should not be able to submit though)
				# but submit relax/auto pilot because they're cool
				return
			# don't give pp for unrankable statuses
			if int(bm["approved"]) >= 3 or int(bm["approved"]) <= 0:
				self.pp = 0
			userID = userUtils.getID(self.playerName)
			rank = generalUtils.getRank(score_=self)
			countryRes = glob.db.fetch("SELECT country_acronym FROM phpbb_users WHERE user_id = %s LIMIT 1", (userID,))
			if countryRes is None:
				country = "XX"
			else:
				country = countryRes["country_acronym"]
				countryUserCountRes = glob.db.fetch("SELECT COUNT(*) AS `userCount` FROM phpbb_users WHERE country_acronym = %s", (country,))
				# yes, rankedscore doesn't match with osu!.
				if countryUserCountRes is not None:
					glob.db.execute(
						"UPDATE osu_countries SET playcount = playcount + 1, usercount = %s, pp = pp + %s, rankedscore = rankedscore + %s WHERE acronym = %s",
						(countryUserCountRes["userCount"], self.pp, self.score, country,)
					)
			gm = gameModes.getGameModeForDB(self.gameMode)
			if self.passed:
				query = "INSERT INTO osu_scores{}_high (score_id, beatmap_id, user_id, `score`, maxcombo, `rank`, count50, count100, count300, countmiss, countgeki, countkatu, `perfect`, enabled_mods, `date`, `pp`, `country_acronym`) VALUES (NULL, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s);".format(gm)
				self.scoreID = int(glob.db.execute(query, [bm["beatmap_id"], userID, self.score, self.maxCombo, rank, self.c50, self.c100, self.c300, self.cMiss, self.cGeki, self.cKatu, int(self.fullCombo), self.mods, datetime.fromtimestamp(self.playDateTime).strftime('%Y-%m-%d %H:%M:%S'), self.pp, country]))
				# set replay id
				glob.db.execute("UPDATE osu_scores{}_high SET `replay` = %s WHERE score_id = %s LIMIT 1".format(gm), (self.scoreID, self.scoreID,))
				pn = self.playerName
				bid = bm["beatmap_id"]
				gmm = self.gameMode
				bt = bm["title"]
				bv = bm["version"]
				gmf = gameModes.getGamemodeFull(gmm)
				# Update max combo count
				glob.db.execute(f"UPDATE osu_user_stats{gm} SET max_combo = %s WHERE user_id = %s AND max_combo < %s", (self.maxCombo, userID, self.maxCombo,))
				rankRes = glob.db.fetch(
					f"SELECT COUNT(*) as `rank` FROM osu_scores{gm}_high WHERE beatmap_id = %s AND user_id = %s AND score >= (SELECT score from osu_scores{gm}_high WHERE beatmap_id = %s LIMIT 1)",
					(bid, userID, bid,)
				)
				if rankRes is not None:
					rankNumber = rankRes["rank"]
				else:
					rankNumber = 0
				eventText = f"<img src='/images/{rank}_small.png'/> <b><a href='/u/{userID}'>{pn}</a></b> achieved rank #{rankNumber} on <a href='/b/{bid}?m={gmm}'>{bt} [{bv}]</a> ({gmf})"
				glob.db.execute(
					"INSERT INTO osu_events (`text`, `text_clean`, `beatmap_id`, `beatmapset_id`, `user_id`) VALUES (%s, %s, %s, %s, %s)",
					(
						eventText,
						eventText,
						bm["beatmap_id"],
						bm["beatmapset_id"],
						userID,
					)
				)
				if rank == "XH":
					glob.db.execute("UPDATE osu_user_stats{} SET xh_rank_count = xh_rank_count + 1 WHERE user_id = %s LIMIT 1".format(gm), (userID,))
				if rank == "X":
					glob.db.execute("UPDATE osu_user_stats{} SET x_rank_count = x_rank_count + 1 WHERE user_id = %s LIMIT 1".format(gm), (userID,))
				if rank == "SH":
					glob.db.execute("UPDATE osu_user_stats{} SET sh_rank_count = sh_rank_count + 1 WHERE user_id = %s LIMIT 1".format(gm), (userID,))
				if rank == "S":
					glob.db.execute("UPDATE osu_user_stats{} SET s_rank_count = s_rank_count + 1 WHERE user_id = %s LIMIT 1".format(gm), (userID,))
				if rank == "A":
					glob.db.execute("UPDATE osu_user_stats{} SET a_rank_count = a_rank_count + 1 WHERE user_id = %s LIMIT 1".format(gm), (userID,))
				if rankNumber == 1:
					glob.db.execute("DELETE FROM osu_leaders{} WHERE beatmap_id = %s".format(gm), bid)
					glob.db.execute(
						"INSERT INTO osu_leaders{} (`beatmap_id`, `user_id`, `score_id`) VALUES (%s, %s, %s)".format(gm),
						(bid, userID, self.scoreID,)
					)

			query = "INSERT INTO osu_scores{} (scorechecksum, beatmap_id, beatmapset_id, user_id, `score`, maxcombo, `rank`, count50, count100, count300, countmiss, countgeki, countkatu, `perfect`, enabled_mods, `date`, high_score_id) VALUES (0, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s);".format(gm)
			if self.scoreID is None or self.scoreID is 0:
				sid = None
			else:
				sid = self.scoreID

			sid = int(glob.db.execute(query, [bm["beatmap_id"], bm["beatmapset_id"], userID, self.score, self.maxCombo, rank, self.c50, self.c100, self.c300, self.cMiss, self.cGeki, self.cKatu, int(self.fullCombo), self.mods, datetime.fromtimestamp(self.playDateTime).strftime('%Y-%m-%d %H:%M:%S'), sid]))
			glob.db.execute(
				"UPDATE osu_user_stats{} SET accuracy_total = accuracy_total + %s, accuracy_count = accuracy_count + 1 WHERE user_id = %s LIMIT 1".format(gm),
				(self.accuracy * 10000, userID,)
			)

			if self.scoreID is None or self.scoreID is 0:
				self.scoreID = sid

			# Set old personal best to completed = 2
			# if self.oldPersonalBest != 0 and self.completed == 3:
			# 	glob.db.execute("UPDATE scores SET completed = 2 WHERE id = %s AND completed = 3 LIMIT 1", [self.oldPersonalBest])

			# Update counters in redis
			glob.redis.incr("ripple:total_submitted_scores", 1)
			glob.redis.incr("ripple:total_pp", int(self.pp))
		glob.redis.incr("ripple:total_plays", 1)

	def calculatePP(self, b = None):
		"""
		Calculate this score's pp value if completed == 3
		"""
		# Create beatmap object
		if b is None:
			b = beatmap.beatmap(self.fileMd5, 0)

		# Calculate pp
		if b.is_rankable and scoreUtils.isRankable(self.mods) and self.gameMode in pp.PP_CALCULATORS:
			calculator = pp.PP_CALCULATORS[self.gameMode](b, self)
			self.pp = calculator.pp
		else:
			self.pp = 0

class PerfectScoreFactory:
	@staticmethod
	def create(beatmap, game_mode=gameModes.STD):
		"""
		Factory method that creates a perfect score.
		Used to calculate max pp amount for a specific beatmap.

		:param beatmap: beatmap object
		:param game_mode: game mode number. Default: `gameModes.STD`
		:return: `score` object
		"""
		s = score()
		s.accuracy = 1.
		# max combo cli param/arg gets omitted if it's < 0 and oppai/catch-the-pp set it to max combo.
		# maniapp ignores max combo entirely.
		s.maxCombo = -1
		s.fullCombo = True
		s.passed = True
		s.gameMode = game_mode
		if s.gameMode == gameModes.MANIA:
			s.score = 1000000
		return s
