from objects import score
from common.ripple import userUtils
from constants import rankedStatuses, displayModes
from common.constants import mods as modsEnum, gameModes
from objects import glob
from common.log import logUtils as log


class scoreboard:
	def __init__(
		self, username, gameMode, beatmap, setScores = True,
		country = False, friends = False, mods = -1, relax = False,
		display = displayModes.SCORE
	):
		"""
		Initialize a leaderboard object

		username -- username of who's requesting the scoreboard. None if not known
		gameMode -- requested gameMode
		beatmap -- beatmap object relative to this leaderboard
		setScores -- if True, will get personal/top 50 scores automatically. Optional. Default: True
		"""
		self.scores = []				# list containing all top 50 scores objects. First object is personal best
		self.totalScores = 0
		self.personalBestRank = -1		# our personal best rank, -1 if not found yet
		self.personalBestDone = False
		self.username = username		# username of who's requesting the scoreboard. None if not known
		self.userID = userUtils.getID(self.username)	# username's userID
		self.gameMode = gameMode		# requested gameMode
		self.beatmap = beatmap			# beatmap objecy relative to this leaderboard
		self.country = country
		self.friends = friends
		self.mods = mods
		self.isRelax = relax
		self.display = display
		if setScores:
			self.setScores()

	@staticmethod
	def buildQuery(params):
		return "{select} {joins} {country} {mods} {friends} {order} {limit}".format(**params)

	def getPersonalBestID(self):
		if self.userID == 0:
			return None

		mode = gameModes.getGameModeForDB(self.gameMode)
		# Query parts
		cdef str select = ""
		cdef str joins = ""
		cdef str country = ""
		cdef str mods = ""
		cdef str friends = ""
		cdef str order = ""
		cdef str limit = ""
		select = "SELECT score_id FROM osu_scores{}_high " \
				 "WHERE beatmap_id = %(beatmap_id)s " \
				 "AND user_id = %(userid)s ".format(mode)

		# Mods
		if self.mods > -1:
			mods = "AND enabled_mods = %(mods)s"

		# Friends ranking
		if self.friends:
			friends = "AND (osu_scores{}_high.user_id IN (" \
					  "SELECT zebra_id FROM phpbb_zebra " \
					  "WHERE user_id = %(userid)s) " \
					  "OR osu_scores{}_high.user_id = %(userid)s" \
					  ")".format(mode, mode)

		# was 'ORDER BY score DESC'. idk
		order = "ORDER BY score DESC"
		limit = "LIMIT 1"

		# Build query, get params and run query
		query = self.buildQuery(locals())
		id_ = glob.db.fetch(query, {
			"userid": self.userID,
			"beatmap_id": self.beatmap.beatmapId,
			"mods": self.mods
		})
		if id_ is None:
			return None
		return id_["score_id"]

	def setScores(self):
		"""
		Set scores list
		"""
		# Reset score list
		self.scores = []
		self.scores.append(-1)

		mode = gameModes.getGameModeForDB(self.gameMode)
		# Make sure the beatmap is ranked
		if self.beatmap.approved < rankedStatuses.RANKED:
			return

		# Query parts
		cdef str select = ""
		cdef str joins = ""
		cdef str country = ""
		cdef str mods = ""
		cdef str friends = ""
		cdef str order = ""
		cdef str limit = ""

		# Find personal best score
		personalBestScoreID = self.getPersonalBestID()

		# Output our personal best if found
		if personalBestScoreID is not None:
			s = score.score(personalBestScoreID, gameMode = self.gameMode)
			self.scores[0] = s
		else:
			# No personal best
			self.scores[0] = -1

		# Get top 50 scores
		select = "SELECT *"
		if self.country:
			join_stats = "JOIN osu_user_stats{} ON phpbb_users.user_id = osu_user_stats{}.user_id".format(mode, mode)
		else:
			join_stats = ""
		joins = "FROM osu_scores{}_high JOIN phpbb_users " \
				"ON osu_scores{}_high.user_id = phpbb_users.user_id " \
				f" {join_stats} " \
				"WHERE osu_scores{}_high.beatmap_id = %(beatmap_id)s " \
				"AND ((phpbb_users.user_type = 0 AND phpbb_users.user_warnings = 0) OR phpbb_users.user_id = %(userid)s)".format(mode, mode, mode, mode) # this (format) is so stupid

		# Country ranking
		if self.country:
			country = "AND osu_user_stats{}.country_acronym = (SELECT country_acronym FROM osu_user_stats{} WHERE user_id = %(userid)s LIMIT 1)".format(mode, mode)
		else:
			country = ""

		# Mods ranking (ignore auto, since we use it for pp sorting)
		if self.mods > -1 and self.mods & modsEnum.AUTOPLAY == 0:
			mods = "AND osu_scores{}_high.enabled_mods = %(mods)s".format(mode)
		else:
			mods = ""

		# Friends ranking
		if self.friends:
			friends = "AND (osu_scores{}_high.user_id IN (" \
					  "SELECT zebra_id FROM phpbb_zebra " \
					  "WHERE user_id = %(userid)s) " \
					  "OR osu_scores{}_high.user_id = %(userid)s" \
					  ")".format(mode, mode)
		else:
			friends = ""

		# Sort and limit at the end
		#if self.display == displayModes.PP:
		#	order = "ORDER BY pp DESC"
		#else:
		order = "ORDER BY score DESC"
		limit = "LIMIT 50"

		# Build query, get params and run query
		query = self.buildQuery(locals())
		params = {
			"beatmap_md5": self.beatmap.checksum,
			"beatmap_id": self.beatmap.beatmapId,
			"userid": self.userID,
			"mods": self.mods,
		}
		topScores = glob.db.fetchAll(query, params)

		# Set data for all scores
		cdef dict topScore
		cdef int c = 1
		# for c, topScore in enumerate(topScores):
		for topScore in topScores:
			# Create score object
			s = score.score(topScore["score_id"], setData=False, gameMode = self.gameMode)

			# Set data and rank from topScores's row
			s.setDataFromDict(topScore)
			s.rank = c

			# Check if this top 50 score is our personal best
			if s.playerName == self.username:
				self.personalBestRank = c

			# Add this score to scores list and increment rank
			self.scores.append(s)
			c += 1

		# If we have more than 50 scores, run query to get scores count
		if c >= 50:
			# Count all scores on this map and do not order
			select = "SELECT COUNT(*) AS count"
			order = ""
			limit = "LIMIT 1"

			# Build query, get params and run query
			query = self.buildQuery(locals())
			count = glob.db.fetch(query, params)
			self.totalScores = 0 if count is None else count["count"]
		else:
			self.totalScores = c-1

		# If personal best score was not in top 50, try to get it from cache
		if personalBestScoreID is not None and self.personalBestRank < 1:
			self.personalBestRank = glob.personalBestCache.get(
				self.userID,
				self.beatmap.checksum,
				self.country,
				self.friends,
				self.mods
			)

		# It's not even in cache, get it from db
		if personalBestScoreID is not None and self.personalBestRank < 1:
			self.setPersonalBestRank()

		# Cache our personal best rank so we can eventually use it later as
		# before personal best rank" in submit modular when building ranking panel
		if self.personalBestRank >= 1:
			glob.personalBestCache.set(self.userID, self.personalBestRank, self.beatmap.checksum, relax=self.isRelax)

	def setPersonalBestRank(self):
		gm = gameModes.getGameModeForDB(self.gameMode)
		# Before running the HUGE query, make sure we have a score on that map
		cdef str query = "SELECT score_id FROM osu_scores{}_high " \
						 "WHERE beatmap_id = %(bid)s " \
						 "AND user_id = %(userid)s ".format(gm)
		# Mods
		if self.mods > -1:
			query += " AND osu_scores{}_high.enabled_mods = %(mods)s".format(gm)
		# Friends ranking
		if self.friends:
			query += " AND (osu_scores{}_high.user_id IN (" \
					 "SELECT zebra_id FROM phpbb_zebra " \
					 "WHERE user_id = %(userid)s) " \
					 "OR osu_scores{}_high.user_id = %(userid)s" \
					 ")".format(gm, gm)
		# Sort and limit at the end
		query += " LIMIT 1"
		hasScore = glob.db.fetch(
			query,
			{
				"bid": self.beatmap.beatmapId,
				"userid": self.userID,
				"mods": self.mods
			}
		)
		if hasScore is None:
			return

		# We have a score, run the huge query
		# Base query
		if self.country:
			join_stats = "JOIN osu_user_stats{} ON phpbb_users.user_id = osu_user_stats{}.user_id".format(gm, gm)
		else:
			join_stats = ""
		query = f"""SELECT COUNT(*) AS `rank` FROM osu_scores{gm}_high
		JOIN phpbb_users ON osu_scores{gm}_high.user_id = phpbb_users.user_id
		{join_stats}
		WHERE osu_scores{gm}_high.score >= (
			SELECT score FROM osu_scores{gm}_high
			WHERE beatmap_id = %(bid)s
			AND user_id = %(userid)s 
			ORDER BY score DESC
			LIMIT 1
		)
		AND osu_scores{gm}_high.beatmap_id = %(bid)s
		AND phpbb_users.user_id = %(userid)s"""
		# Country
		if self.country:
			query += " AND osu_user_stats{}.country_acronym = (SELECT country_acronym FROM osu_user_stats{} WHERE user_id = %(userid)s LIMIT 1)".format(gm, gm)
		# Mods
		if self.mods > -1:
			query += " AND osu_scores{}_high.enabled_mods = %(mods)s".format(gm)
		# Friends
		if self.friends:
			query += " AND (osu_scores{}_high.user_id IN (" \
					 "SELECT zebra_id FROM phpbb_zebra " \
					 "WHERE user_id = %(userid)s) " \
					 "OR osu_scores{}_high.user_id = %(userid)s" \
					 ")".format(gm, gm)
		# Sort and limit at the end
		query += " ORDER BY score DESC LIMIT 1"
		result = glob.db.fetch(
			query,
			{
				"bid": self.beatmap.beatmapId,
				"userid": self.userID,
				"mode": self.gameMode,
				"mods": self.mods
			}
		)
		self.personalBestDone = True
		if result is not None:
			log.debug("Rank: {}".format(result["rank"]))
			self.personalBestRank = result["rank"]

	def getScoresData(self):
		"""
		Return scores data for getscores

		return -- score data in getscores format
		"""
		data = ""

		# Output personal best
		if self.scores[0] == -1:
			# We don't have a personal best score
			data += "\n"
		else:
			# Set personal best score rank
			if not self.personalBestDone:
				self.setPersonalBestRank()	# sets self.personalBestRank with the huge query
			self.scores[0].rank = self.personalBestRank
			data += self.scores[0].getData()

		# Output top 50 scores
		for i in self.scores[1:]:
			data += i.getData(pp=self.display == displayModes.PP)

		return data
