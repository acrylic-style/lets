import os

from common import generalUtils
from common.log import logUtils as log
from constants import exceptions
from helpers import osuapiHelper
from objects import glob


def isBeatmap(fileName=None, content=None):
    if fileName is not None:
        with open(fileName, "rb") as f:
            firstLine = f.readline().decode("utf-8-sig").strip()
    elif content is not None:
        try:
            firstLine = content.decode("utf-8-sig").split("\n")[0].strip()
        except IndexError:
            return False
    else:
        raise ValueError("Either `fileName` or `content` must be provided.")
    return firstLine.lower().startswith("osu file format v")

def shouldDownloadMap(mapFile, _beatmap):
    # Check if we have to download the .osu file
    if not os.path.isfile(mapFile):
        # .osu file doesn't exist. We must download it
        return True
    else:
        # File exists, check md5
        if generalUtils.fileMd5(mapFile) != _beatmap.checksum or not isBeatmap(mapFile):
            # MD5 don't match, redownload .osu file
            return True

    # File exists and md5 matches. There's no need to download it again.
    return False

def cacheMap(mapFile, _beatmap):
    # Check if we have to download the .osu file
    download = shouldDownloadMap(mapFile, _beatmap)

    # Download .osu file if needed
    if download:
        log.debug("maps ~> Downloading {} osu file".format(_beatmap.beatmapId))

        # Get .osu file from osu servers
        fileContent = osuapiHelper.getOsuFileFromID(_beatmap.beatmapId)

        # Make sure osu servers returned something
        if fileContent is None or not isBeatmap(content=fileContent):
            raise exceptions.osuApiFailException("maps")

        # Delete old .osu file if it exists
        if os.path.isfile(mapFile):
            os.remove(mapFile)

        # Save .osu file
        with open(mapFile, "wb+") as f:
            f.write(fileContent)
    else:
        # Map file is already in folder
        log.debug("maps ~> Beatmap found in cache!")


def cachedMapPath(beatmap_id):
    return "{}/{}.osu".format(glob.conf["BEATMAPS_FOLDER"], beatmap_id)
