import time

from common.constants import gameModes
from common.log import logUtils as log
from constants import rankedStatuses
from helpers import osuapiHelper
import objects.glob
from helpers.generalHelper import clamp


class beatmap:
	__slots__ = ("songName", "fileMD5", "rankedStatus", "rankedStatusFrozen", "beatmapID", "beatmapSetID", "offset",
	             "rating", "starsStd", "starsTaiko", "starsCtb", "starsMania", "AR", "OD", "maxCombo", "hitLength",
	             "bpm", "playcount" ,"passcount", "refresh", "filename", "beatmapId", "beatmapSetId", "userId",
	             "checksum", "version", "total_length", "hit_length", "countTotal", "countNormal", "countSlider", "countSpinner",
	             "diff_drain", "diff_size", "diff_overall", "diff_approach", "playmode", "approved", "last_update", "difficultyrating",
	             "orphaned", "youtube_preview", "score_version", "deleted_at")

	def __init__(self, md5 = None, beatmapSetID = None, gameMode = 0, refresh=False, fileName=None):
		"""
		Initialize a beatmap object.

		md5 -- beatmap md5. Optional.
		beatmapSetID -- beatmapSetID. Optional.
		"""
		self.beatmapId = 0
		self.beatmapSetId = 0
		self.userId = 0
		self.filename = ""
		self.checksum = ""
		self.version = ""
		self.total_length = 0
		self.hit_length = 0
		self.countTotal = 0
		self.countNormal = 0
		self.countSlider = 0
		self.countSpinner = 0
		self.diff_drain = 0
		self.diff_size = 0
		self.diff_overall = 0
		self.diff_approach = 0
		self.playmode = 0
		self.approved = 0
		self.last_update = 0
		self.difficultyrating = 0
		self.playcount = 0
		self.passcount = 0
		self.orphaned = 0
		self.youtube_preview = ""
		self.score_version = 0
		self.deleted_at = 0
		self.bpm = 0

		self.songName = ""

		# Force refresh from osu api
		self.refresh = refresh

		if md5 is not None and beatmapSetID is not None:
			self.setData(md5, beatmapSetID)

	def addBeatmapToDB(self):
		"""
		Add current beatmap data in db if not in yet
		"""
		# Make sure the beatmap is not already in db
		bdata = objects.glob.db.fetch(
			"SELECT beatmap_id, `approved` FROM osu_beatmaps "
			"WHERE checksum = %s OR beatmap_id = %s LIMIT 1",
			(self.checksum, self.beatmapId)
		)
		if bdata is not None:
			# This beatmap is already in db, remove old record
			self.approved = bdata["approved"]
			log.debug("Deleting old beatmap data ({})".format(bdata["beatmap_id"]))
			objects.glob.db.execute("DELETE FROM osu_beatmaps WHERE beatmap_id = %s LIMIT 1", [bdata["beatmap_id"]])

		# Add new beatmap data
		log.debug("Saving beatmap data in db...")
		params = [
			self.beatmapId,
			self.beatmapSetId,
			self.userId,
			self.filename,
			self.checksum,
			self.version,
			self.total_length,
			self.hit_length,
			self.countTotal,
			self.countNormal,
			self.countSlider,
			self.countSpinner,
			self.diff_drain,
			self.diff_size,
			self.diff_overall,
			self.diff_approach,
			self.playmode,
			self.approved,
			self.last_update,
			self.difficultyrating,
			self.playcount,
			self.passcount,
			self.orphaned,
			self.youtube_preview,
			self.score_version,
			self.deleted_at,
			clamp(self.bpm, -2147483648, 2147483647)
		]
		if self.filename is not None:
			params.append(self.filename)
		objects.glob.db.execute(
			"INSERT INTO `osu_beatmaps` (`beatmap_id`, `beatmapset_id`, `user_id`, `filename`, `checksum`, `version`, `total_length`, `hit_length`, `countTotal`, "
			"`countNormal`, `countSldier`, `countSpinner`, `diff_drain`, `diff_size`, `diff_overall`, `diff_approach`, `playmode`, `approved`, `last_update`, "
			"`difficultyrating`, `playcount`, `passcount`, `orphaned`, `youtube_preview`, `score_version`, `deleted_at`, `bpm` "
			"VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)",
			params
		)

	def saveFileName(self, fileName):
		# Temporary workaround to avoid re-fetching all beatmaps from osu!api
		r = objects.glob.db.fetch("SELECT filename FROM osu_beatmaps WHERE checksum = %s LIMIT 1", (self.checksum,))
		if r is None:
			return
		if r["filename"] is None:
			objects.glob.db.execute(
				"UPDATE osu_beatmaps SET filename = %s WHERE checksum = %s LIMIT 1",
				(self.filename, self.checksum)
			)

	def setDataFromDB(self, md5):
		"""
		Set this object's beatmap data from db.

		md5 -- beatmap md5
		return -- True if set, False if not set
		"""
		# Get data from DB
		data = objects.glob.db.fetch(
			"SELECT osu_beatmapsets.approved, osu_beatmapsets.last_update, osu_beatmapsets.rating, osu_beatmapsets.title, osu_beatmaps.checksum, "
			"osu_beatmaps.hit_length, osu_beatmaps.difficultyrating, osu_beatmaps.bpm, osu_beatmaps.countNormal, osu_beatmaps.countSlider, "
			"osu_beatmaps.countSpinner, osu_beatmaps.diff_drain, osu_beatmaps.diff_size, osu_beatmaps.diff_overall, osu_beatmaps.diff_approach, "
			"osu_beatmaps.playcount, osu_beatmaps.passcount, osu_beatmaps.approved "
			"FROM osu_beatmaps LEFT JOIN osu_beatmapsets ON osu_beatmapsets.beatmapset_id = osu_beatmaps.beatmapset_id WHERE osu_beatmaps.checksum = %s LIMIT 1",
			[md5]
		)

		# Make sure the query returned something
		if data is None:
			return False

		# Set cached data period
		expire = objects.glob.conf["BEATMAP_CACHE_EXPIRE"]

		# If the beatmap is ranked, we don't need to refresh data from osu!api that often
		if data["approved"] >= rankedStatuses.RANKED:
			expire *= 3

		# Make sure the beatmap data in db is not too old
		if int(expire) > 0 and time.time() > int(int(time.mktime(time.strptime(data["last_update"], "%Y-%m-%d %H:%M:%S"))*1000)/1000)+int(expire):
			return False

		# Data in DB, set beatmap data
		log.debug("Got beatmap data from db")
		self.setDataFromDict(data)
		self.rating = data["rating"]	# db only, we don't want the rating from osu! api.
		return True

	def setDataFromDict(self, data):
		"""
		Set this object's beatmap data from data dictionary.

		data -- data dictionary
		return -- True if set, False if not set
		"""
		self.songName = data["song_name"]
		self.fileMD5 = data["beatmap_md5"]
		self.rankedStatus = int(data["ranked"])
		self.rankedStatusFrozen = int(data["ranked_status_freezed"])
		self.beatmapID = int(data["beatmap_id"])
		self.beatmapSetID = int(data["beatmapset_id"])
		self.AR = float(data["ar"])
		self.OD = float(data["od"])
		self.starsStd = float(data["difficulty_std"])
		self.starsTaiko = float(data["difficulty_taiko"])
		self.starsCtb = float(data["difficulty_ctb"])
		self.starsMania = float(data["difficulty_mania"])
		self.maxCombo = int(data["max_combo"])
		self.hitLength = int(data["hit_length"])
		self.bpm = int(data["bpm"])
		self.disablePP = bool(data["disable_pp"])
		# Ranking panel statistics
		self.playcount = int(data["playcount"]) if "playcount" in data else 0
		self.passcount = int(data["passcount"]) if "passcount" in data else 0

	def saveDataFromApi(self, filename, data):
		"""
		Save the data received from osu! api.
		"""
		if data is None:
			return None
		objects.glob.db.execute(
			"INSERT IGNORE INTO osu_beatmaps (`beatmap_id`, `beatmapset_id`, `user_id`, `filename`, `checksum`, `version`, `total_length`, `hit_length`, "
			"`countTotal`, `countNormal`, `countSlider`, `countSpinner`, `diff_drain`, `diff_size`, `diff_overall`, `diff_approach`, `playmode`, "
			"`approved`, `last_update`, `difficultyrating`, `playcount`, `passcount`, `bpm`"
			") VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)",
			(
				data["beatmap_id"],
				data["beatmapset_id"],
				data["creator_id"],
				filename,
				data["file_md5"],
				data["version"],
				data["total_length"],
				data["hit_length"],
				data["max_combo"],
				data["count_normal"],
				data["count_slider"],
				data["count_spinner"],
				data["diff_drain"],
				data["diff_size"],
				data["diff_overall"],
				data["diff_approach"],
				data["mode"],
				data["approved"],
				data["last_update"],
				data["difficultyrating"],
				data["playcount"],
				data["passcount"],
				data["bpm"],
			)
		)
		objects.glob.db.execute(
			"INSERT IGNORE INTO osu_beatmapsets (`beatmapset_id`, `user_id`, `artist`, `artist_unicode`, `title`, `title_unicode`, `creator`, `source`, "
			"`tags`, `video`, `storyboard`, `bpm`, `approved`, `approved_date`, `submit_date`, `filename`, `download_disabled`, "
			"`rating`, `favourite_count`, `genre_id`, `language_id`"
			") VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, '', %s, %s, %s, %s, %s)",
			(
				data["beatmapset_id"],
				data["creator_id"],
				data["artist"],
				data["artist_unicode"],
				data["title"],
				data["title_unicode"],
				data["creator"],
				data["source"],
				data["tags"],
				data["video"],
				data["storyboard"],
				data["bpm"],
				data["approved"],
				data["approved_date"],
				data["submit_date"],
				data["download_unavailable"],
				data["rating"],
				data["favourite_count"],
				data["genre_id"],
				data["language_id"],
			)
		)

	def setDataFromOsuApi(self, md5, beatmapSetID):
		"""
		Set this object's beatmap data from osu!api.

		md5 -- beatmap md5
		beatmapSetID -- beatmap set ID, used to check if a map is outdated
		return -- True if set, False if not set
		"""
		# Check if osuapi is enabled
		mainData = None
		dataStd = osuapiHelper.osuApiRequest("get_beatmaps", "h={}&a=1&m=0".format(md5))
		dataTaiko = osuapiHelper.osuApiRequest("get_beatmaps", "h={}&a=1&m=1".format(md5))
		dataCtb = osuapiHelper.osuApiRequest("get_beatmaps", "h={}&a=1&m=2".format(md5))
		dataMania = osuapiHelper.osuApiRequest("get_beatmaps", "h={}&a=1&m=3".format(md5))
		if dataStd is not None:
			mainData = dataStd
		elif dataTaiko is not None:
			mainData = dataTaiko
		elif dataCtb is not None:
			mainData = dataCtb
		elif dataMania is not None:
			mainData = dataMania

		# If the beatmap is frozen and still valid from osu!api, return True so we don't overwrite anything
		if mainData is not None and self.approved == rankedStatuses.RANKED:
			return True

		# Can't fint beatmap by MD5. The beatmap has been updated. Check with beatmap set ID
		if mainData is None:
			log.debug("osu!api data is None")
			dataStd = osuapiHelper.osuApiRequest("get_beatmaps", "s={}&a=1&m=0".format(beatmapSetID))
			dataTaiko = osuapiHelper.osuApiRequest("get_beatmaps", "s={}&a=1&m=1".format(beatmapSetID))
			dataCtb = osuapiHelper.osuApiRequest("get_beatmaps", "s={}&a=1&m=2".format(beatmapSetID))
			dataMania = osuapiHelper.osuApiRequest("get_beatmaps", "s={}&a=1&m=3".format(beatmapSetID))
			if dataStd is not None:
				mainData = dataStd
			elif dataTaiko is not None:
				mainData = dataTaiko
			elif dataCtb is not None:
				mainData = dataCtb
			elif dataMania is not None:
				mainData = dataMania

			if mainData is None:
				# Still no data, beatmap is not submitted
				return False
			else:
				# We have some data, but md5 doesn't match. Beatmap is outdated
				self.approved = rankedStatuses.NEED_UPDATE
				return True


		# We have data from osu!api, set beatmap data
		log.debug("Got beatmap data from osu!api")
		self.songName = "{} - {} [{}]".format(mainData["artist"], mainData["title"], mainData["version"])
		self.filename = "{} - {} ({}) [{}].osu".format(
			mainData["artist"], mainData["title"], mainData["creator"], mainData["version"]
		).replace("\\", "")
		self.saveDataFromApi(self.filename, dataStd)
		self.saveDataFromApi(self.filename, dataTaiko)
		self.saveDataFromApi(self.filename, dataCtb)
		self.saveDataFromApi(self.filename, dataMania)
		self.checksum = md5
		self.approved = convertRankedStatus(int(mainData["approved"]))
		self.beatmapId = int(mainData["beatmap_id"])
		self.beatmapSetId = int(mainData["beatmapset_id"])
		self.diff_approach = float(mainData["diff_approach"])
		self.diff_overall = float(mainData["diff_overall"])
		self.difficultyrating = float(mainData["difficultyrating"])

		# Determine stars for every mode
		self.starsStd = 0.0
		self.starsTaiko = 0.0
		self.starsCtb = 0.0
		self.starsMania = 0.0
		if dataStd is not None:
			self.starsStd = float(dataStd.get("difficultyrating", 0))
		if dataTaiko is not None:
			self.starsTaiko = float(dataTaiko.get("difficultyrating", 0))
		if dataCtb is not None:
			self.starsCtb = float(
				next((x for x in (dataCtb.get("difficultyrating"), dataCtb.get("diff_aim")) if x is not None), 0)
			)
		if dataMania is not None:
			self.starsMania = float(dataMania.get("difficultyrating", 0))

		self.countTotal = int(mainData["max_combo"]) if mainData["max_combo"] is not None else 0
		self.hit_length = int(mainData["hit_length"])
		if mainData["bpm"] is not None:
			self.bpm = int(float(mainData["bpm"]))
		else:
			self.bpm = -1
		return True

	def setData(self, md5, beatmapSetID):
		"""
		Set this object's beatmap data from highest level possible.

		md5 -- beatmap MD5
		beatmapSetID -- beatmap set ID
		"""
		# Get beatmap from db
		dbResult = self.setDataFromDB(md5)

		# Force refresh from osu api.
		# We get data before to keep frozen maps ranked
		# if they haven't been updated
		if dbResult and self.refresh:
			dbResult = False

		if not dbResult:
			log.debug("Beatmap not found in db")
			# If this beatmap is not in db, get it from osu!api
			apiResult = self.setDataFromOsuApi(md5, beatmapSetID)
			if not apiResult:
				# If it's not even in osu!api, this beatmap is not submitted
				self.approved = rankedStatuses.NOT_SUBMITTED
			elif self.approved != rankedStatuses.NOT_SUBMITTED and self.approved != rankedStatuses.NEED_UPDATE:
				# We get beatmap data from osu!api, save it in db
				self.addBeatmapToDB()
		else:
			log.debug("Beatmap found in db")

		log.debug("{}\n{}\n{}\n{}".format(self.starsStd, self.starsTaiko, self.starsCtb, self.starsMania))

	def getData(self, totalScores=0, version=4):
		"""
		Return this beatmap's data (header) for getscores

		return -- beatmap header for getscores
		"""
		rankedStatusOutput = self.approved

		# Force approved for A/Q/L beatmaps that give PP, so we don't get the alert in game
		if self.approved >= rankedStatuses.APPROVED and self.is_rankable:
			rankedStatusOutput = rankedStatuses.APPROVED

		# Fix loved maps for old clients
		if version < 4 and self.approved == rankedStatuses.LOVED:
			rankedStatusOutput = rankedStatuses.QUALIFIED

		data = "{}|false".format(rankedStatusOutput)
		if self.approved != rankedStatuses.NOT_SUBMITTED and self.approved != rankedStatuses.NEED_UPDATE and self.approved != rankedStatuses.UNKNOWN:
			# If the beatmap is updated and exists, the client needs more data
			data += "|{}|{}|{}\n{}\n{}\n{}\n".format(self.beatmapId, self.beatmapSetId, totalScores, 0, self.songName, self.rating)

		# Return the header
		return data

	@property
	def is_rankable(self):
		return self.approved >= rankedStatuses.RANKED \
			   and self.approved != rankedStatuses.UNKNOWN

	@property
	def is_mode_specific(self):
		if self.starsStd is None:
			return False
		return sum(x > 0 for x in (self.starsStd, self.starsTaiko, self.starsCtb, self.starsMania)) == 1

	@property
	def specific_game_mode(self):
		if not self.is_mode_specific:
			return None
		try:
			return next(
				mode for mode, pp in zip(
					(gameModes.STD, gameModes.TAIKO, gameModes.CTB, gameModes.MANIA),
					(self.starsStd, self.starsTaiko, self.starsCtb, self.starsMania)
				) if pp > 0
			)
		except StopIteration:
			# FUBAR beatmap 🤔
			return None

def convertRankedStatus(approvedStatus):
	"""
	Convert approved_status (from osu!api) to ranked status (for getscores)

	approvedStatus -- approved status, from osu!api
	return -- rankedStatus for getscores
	"""

	approvedStatus = int(approvedStatus)
	if approvedStatus <= 0:
		return rankedStatuses.PENDING
	elif approvedStatus == 1:
		return rankedStatuses.RANKED
	elif approvedStatus == 2:
		return rankedStatuses.APPROVED
	elif approvedStatus == 3:
		return rankedStatuses.QUALIFIED
	elif approvedStatus == 4:
		return rankedStatuses.LOVED
	else:
		return rankedStatuses.UNKNOWN

def incrementPlaycount(md5, passed):
	"""
	Increment playcount (and passcount) for a beatmap

	md5 -- beatmap md5
	passed -- if True, increment passcount too
	"""
	objects.glob.db.execute(
		f"UPDATE beatmaps "
		f"SET playcount = playcount+1{', passcount = passcount+1' if passed else ''} "
		f"WHERE beatmap_md5 = %s LIMIT 1",
		[md5]
	)
