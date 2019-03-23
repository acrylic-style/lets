"""Some console related functions"""

from common.constants import bcolors
from objects import glob

ASCII = """ (                 (     
 )\\ )        *   ) )\\ )  
(()/(  (   ` )  /((()/(  
 /(_)) )\\   ( )(_))/(_)) 
(_))  ((_) (_(_())(_))   
| |   | __||_   _|/ __|  
| |__ | _|   | |  \\__ \\  
|____||___|  |_|  |___/  \n"""

def printServerStartHeader(asciiArt):
	"""
	Print server start header with optional ascii art

	asciiArt -- if True, will print ascii art too
	"""

	if asciiArt:
		ascii_list = ASCII.split("\n")
		for i, x in enumerate(ascii_list):
			printColored(x, bcolors.YELLOW if i < len(ascii_list) - 4 else bcolors.GREEN)

	printColored("> Welcome to the Latest Essential Tatoe Server v{}".format(glob.VERSION), bcolors.GREEN)
	printColored("> Made by the Ripple team", bcolors.GREEN)
	printColored("> {}https://zxq.co/ripple/lets".format(bcolors.UNDERLINE), bcolors.GREEN)
	printColored("> Press CTRL+C to exit\n", bcolors.GREEN)


def printNoNl(string):
	"""
	Print string without new line at the end

	string -- string to print
	"""

	print(string, end="")


def printColored(string, color, end="\n"):
	"""
	Print colored string

	string -- string to print
	color -- see bcolors.py
	"""

	print("{}{}{}".format(color, string, bcolors.ENDC), end=end)


def printError(end="\n"):
	"""Print error text FOR LOADING"""

	printColored("Error", bcolors.RED, end=end)


def printDone(end="\n"):
	"""Print error text FOR LOADING"""

	printColored("Done", bcolors.GREEN, end=end)


def printWarning(end="\n"):
	"""Print error text FOR LOADING"""

	printColored("Warning", bcolors.YELLOW, end=end)


def printWait(end="\n"):
	"""Print error text FOR LOADING"""

	printColored("Please wait...", bcolors.BLUE, end=end)

def printGetScoresMessage(message):
	printColored("[get_scores] {}".format(message), bcolors.PINK)

def printSubmitModularMessage(message):
	printColored("[submit_modular] {}".format(message), bcolors.YELLOW)

def printBanchoConnectMessage(message):
	printColored("[bancho_connect] {}".format(message), bcolors.YELLOW)

def printGetReplayMessage(message):
	printColored("[get_replay] {}".format(message), bcolors.PINK)

def printMapsMessage(message):
	printColored("[maps] {}".format(message), bcolors.PINK)

def printRippMessage(message):
	printColored("[ripp] {}".format(message), bcolors.GREEN)

# def printRippoppaiMessage(message):
# 	printColored("[rippoppai] {}".format(message), bcolors.GREEN)

def printWifiPianoMessage(message):
	printColored("[wifipiano] {}".format(message), bcolors.GREEN)

def printDebugMessage(message):
	printColored("[debug] {}".format(message), bcolors.BLUE)

def printScreenshotsMessage(message):
	printColored("[screenshots] {}".format(message), bcolors.YELLOW)

def printApiMessage(module, message):
	printColored("[{}] {}".format(module, message), bcolors.GREEN)
