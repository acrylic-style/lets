import io
import os

from botocore.exceptions import ClientError
from timeout_decorator import timeout

from common import generalUtils
from common.log import logUtils as log
from common.sentry import sentry
from constants import exceptions
from constants import dataTypes
from helpers import binaryHelper
from helpers import s3
from objects import glob


def toDotTicks(unixTime):
	"""
	:param unixTime: Unix timestamp
	"""
	return (10000000*unixTime) + 621355968000000000


def _getRawReplayFailedLocal(scoreID):
	try:
		with open(os.path.join(glob.conf["FAILED_REPLAYS_FOLDER"], "replay_{}.osr".format(scoreID)), "rb") as f:
			return f.read()
	except FileNotFoundError:
		with open(os.path.join(glob.conf["REPLAYS_FOLDER"], "replay_{}.osr".format(scoreID)), "rb") as f:
			return f.read()


@timeout(5, use_signals=False)
def getRawReplayS3(scoreID):
	scoreID = int(scoreID)
	if not glob.conf.s3_enabled:
		log.warning("S3 is disabled! Using failed local")
		return _getRawReplayFailedLocal(scoreID)

	fileName = "replay_{}.osr".format(scoreID)
	log.debug("Downloading {} from s3".format(fileName))
	with io.BytesIO() as f:
		bucket = s3.getReadReplayBucketName(scoreID)
		try:
			glob.threadScope.s3.download_fileobj(bucket, fileName, f)
		except ClientError as e:
			# 404 -> no such key
			# 400 -> no such bucket
			code = e.response["Error"]["Code"]
			if code in ("404", "400"):
				log.warning("S3 replay returned {}, trying to get from failed replays".format(code))
				if code == "400":
					sentry.captureMessage("Invalid S3 replays bucket ({})! (got error 400)".format(bucket))
				return _getRawReplayFailedLocal(scoreID)
			raise
		f.seek(0)
		return f.read()


def _getFirstReplayFileName(scoreID):
	"""
	Iterates over all REPLAYS_FOLDERS in config, and returns the
	path of the replay. It starts from the first folder, if the replay
	is not there, it tries with the second folder and so on.
	Returns None if there's no such file in any of the folders.

	:param scoreID:
	:return: path or None
	"""
	for folder in glob.conf["REPLAYS_FOLDERS"]:
		fileName = "{}/replay_{}.osr".format(folder, scoreID)
		if os.path.isfile(fileName):
			return fileName
	return None


def buildFullReplay(scoreID=None, scoreData=None, rawReplay=None):
	if all(v is None for v in (scoreID, scoreData)) or all(v is not None for v in (scoreID, scoreData)):
		raise AttributeError("Either scoreID or scoreData must be provided, not neither or both")

	mode = 0
	# TODO: Implement better way to handle this
	if scoreData is None:
		scoreData = glob.db.fetch(
			"SELECT osu_scores_high.*, phpbb_users.username FROM osu_scores_high LEFT JOIN phpbb_users ON osu_scores_high.user_id = phpbb_users.user_id "
			"WHERE osu_scores_high.score_id = %s",
			[scoreID]
		)
		if scoreData is None:
			mode = 1
			scoreData = glob.db.fetch(
				"SELECT osu_scores_taiko_high.*, phpbb_users.username FROM osu_scores_taiko_high LEFT JOIN phpbb_users ON osu_scores_taiko_high.user_id = phpbb_users.user_id "
				"WHERE osu_scores_taiko_high.score_id = %s",
				[scoreID]
			)
			if scoreData is None:
				mode = 2
				scoreData = glob.db.fetch(
					"SELECT osu_scores_fruits_high.*, phpbb_users.username FROM osu_scores_fruits_high LEFT JOIN phpbb_users ON osu_scores_fruits_high.user_id = phpbb_users.user_id "
					"WHERE osu_scores_fruits_high.score_id = %s",
					[scoreID]
				)
				if scoreData is None:
					mode = 3
					scoreData = glob.db.fetch(
						"SELECT osu_scores_mania_high.*, phpbb_users.username FROM osu_scores_mania_high LEFT JOIN phpbb_users ON osu_scores_mania_high.user_id = phpbb_users.user_id "
						"WHERE osu_scores_mania_high.score_id = %s",
						[scoreID]
					)
	else:
		scoreID = scoreData["id"]
	if scoreData is None or scoreID is None:
		raise exceptions.scoreNotFoundError()
	scoreID = int(scoreID)

	if rawReplay is None:
		rawReplay = getRawReplayS3(scoreID)

	# Calculate missing replay data
	rank = generalUtils.getRank(
		int(mode),
		int(scoreData["mods"]),
		int(scoreData["accuracy"]),
		int(scoreData["count300"]),
		int(scoreData["count100"]),
		int(scoreData["count50"]),
		int(scoreData["countmiss"])
	)
	checksum = glob.db.fetch("SELECT checksum FROM osu_beatmaps WHERE beatmap_id = %s LIMIT 1", (scoreData["beatmap_id"]))
	magicHash = generalUtils.stringMd5(
		"{}p{}o{}o{}t{}a{}r{}e{}y{}o{}u{}{}{}".format(
			int(scoreData["count100"]) + int(scoreData["count300"]),
			scoreData["count50"],
			scoreData["countgeki"],
			scoreData["countkatu"],
			scoreData["countmiss"],
			checksum,
			scoreData["maxcombo"],
			"True" if int(scoreData["perfect"]) == 1 else "False", # TODO: check whether full combo or not (or "perfect" means "full combo"?)
			scoreData["username"],
			scoreData["score"],
			rank,
			scoreData["enabled_mods"],
			"True"
		)
	)
	# Add headers (convert to full replay)
	fullReplay = binaryHelper.binaryWrite([
		[mode, dataTypes.byte],
		[20150414, dataTypes.uInt32],
		[scoreData["checksum"], dataTypes.string],
		[scoreData["username"], dataTypes.string],
		[magicHash, dataTypes.string],
		[scoreData["count300"], dataTypes.uInt16],
		[scoreData["count100"], dataTypes.uInt16],
		[scoreData["count50"], dataTypes.uInt16],
		[scoreData["countgeki"], dataTypes.uInt16],
		[scoreData["countkatu"], dataTypes.uInt16],
		[scoreData["countmiss"], dataTypes.uInt16],
		[scoreData["score"], dataTypes.uInt32],
		[scoreData["maxcombo"], dataTypes.uInt16],
		[scoreData["perfect"], dataTypes.byte],
		[scoreData["enabled_mods"], dataTypes.uInt32],
		[0, dataTypes.byte],
		[toDotTicks(int(scoreData["date"])), dataTypes.uInt64],
		[rawReplay, dataTypes.rawReplay],
		[0, dataTypes.uInt32],
		[0, dataTypes.uInt32],
	])

	# Return full replay
	return fullReplay