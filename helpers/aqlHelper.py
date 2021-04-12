from common.constants import gameModes
from objects import glob
from common.log import logUtils as log


class AqlThresholds:
    """
    A class representing the AQL thresholds configuration.
    """

    def __init__(self):
        """
        Initializes a new AQL thresholds configuration.
        """
        self._thresholds = {}

    def reload(self):
        """
        Reloads the AQL thresholds configuration from DB

        :return:
        """
        log.debug("Reloading AQL thresholds")
        self._thresholds = {}
        self._thresholds[''] = float(1000)
        self._thresholds['_taiko'] = float(1000)
        self._thresholds['_fruits'] = float(1000)
        self._thresholds['_mania'] = float(1000)
        self._thresholds['std'] = float(1000)
        self._thresholds['taiko'] = float(1000)
        self._thresholds['ctb'] = float(1000)
        self._thresholds['mania'] = float(1000)
        log.debug([(gameModes.getGameModeForDB(x), self[x]) for x in self])
        if not all(x in self._thresholds for x in range(gameModes.STD, gameModes.MANIA)):
            raise RuntimeError("Invalid AQL thresholds. Please check your system_settings table.")

    def __getitem__(self, item):
        """
        Magic method that makes it possible to use an AqlThresholds object as a dictionary:
        ```
        >>> glob.aqlThresholds[gameModes.STD]
        <<< 1333.77
        ```

        :param item:
        :return:
        """
        return self._thresholds[item]

    def __iter__(self):
        """
        Magic method that makes it possible to use iterate over an AqlThresholds object:
        ```
        >>> tuple(gameModes.getGameModeForDB(x) for x in glob.aqlThresholds)
        <<< ('std', 'taiko', 'ctb', 'mania')
        ```

        :return:
        """
        return iter(self._thresholds.keys())

    def __contains__(self, item):
        """
        Magic method that makes it possible to use the "in" operator on an AqlThresholds object:
        ```
        >>> gameModes.STD in glob.aqlThresholds
        <<< True
        >>> "not_a_game_mode" in glob.aqlThresholds
        <<< False
        ```

        :param item:
        :return:
        """
        return item in self._thresholds
