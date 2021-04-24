from common.constants import mods

def getModsList(gm: int):
  # ignored mods: Touch device, Relax, Auto Pilot, Auto, Sudden Death, Perfect
  lst = []
  if gm == 0:
    return lst
  if gm & mods.NOFAIL > 0:
    lst.append("NF")
  if gm & mods.EASY > 0:
    lst.append("EZ")
  if gm & mods.HIDDEN > 0:
    lst.append("HD")
  if gm & mods.HARDROCK > 0:
    lst.append("HR")
  if gm & mods.DOUBLETIME > 0:
    lst.append("DT")
  if gm & mods.HALFTIME > 0:
    lst.append("HT")
  if gm & mods.NIGHTCORE > 0:
    lst.append("NC")
  if gm & mods.FLASHLIGHT > 0:
    lst.append("FL")
  if gm & mods.SPUNOUT > 0:
    lst.append("SO")
  if gm & mods.KEY4 > 0:
    lst.append("4K")
  if gm & mods.KEY5 > 0:
    lst.append("5K")
  if gm & mods.KEY6 > 0:
    lst.append("6K")
  if gm & mods.KEY7 > 0:
    lst.append("7K")
  if gm & mods.KEY8 > 0:
    lst.append("8K")
  if gm & mods.FADEIN > 0:
    lst.append("FI")
  if gm & mods.RANDOM > 0: # Random scores shouldn't be submitted (and its unranked mod)
    lst.append("RD")
  if gm & mods.KEY9 > 0:
    lst.append("9K")
  if gm & mods.KEY10 > 0:
    lst.append("10K")
  if gm & mods.KEY1 > 0:
    lst.append("1K")
  if gm & mods.KEY3 > 0:
    lst.append("3K")
  if gm & mods.KEY2 > 0:
    lst.append("2K")
  return lst

def getModsForPP(gm: int):
  # ignored mods: Touch device, Relax, Auto Pilot, Auto, Sudden Death, Perfect
  s = ""
  if gm == 0:
    return s
  if gm & mods.NOFAIL > 0:
    s += "-m NF "
  if gm & mods.EASY > 0:
    s += "-m EZ "
  if gm & mods.HIDDEN > 0:
    s += "-m HD "
  if gm & mods.HARDROCK > 0:
    s += "-m HR "
  if gm & mods.DOUBLETIME > 0:
    s += "-m DT "
  if gm & mods.HALFTIME > 0:
    s += "-m HT "
  if gm & mods.NIGHTCORE > 0:
    s += "-m NC "
  if gm & mods.FLASHLIGHT > 0:
    s += "-m FL "
  if gm & mods.SPUNOUT > 0:
    s += "-m SO "
  if gm & mods.KEY4 > 0:
    s += "-m 4K "
  if gm & mods.KEY5 > 0:
    s += "-m 5K "
  if gm & mods.KEY6 > 0:
    s += "-m 6K "
  if gm & mods.KEY7 > 0:
    s += "-m 7K "
  if gm & mods.KEY8 > 0:
    s += "-m 8K "
  if gm & mods.FADEIN > 0:
    s += "-m FI "
  if gm & mods.RANDOM > 0: # Random scores shouldn't be submitted (and its unranked mod)
    s += "-m RD "
  if gm & mods.KEY9 > 0:
    s += "-m 9K "
  if gm & mods.KEY10 > 0:
    s += "-m 10K "
  if gm & mods.KEY1 > 0:
    s += "-m 1K "
  if gm & mods.KEY3 > 0:
    s += "-m 3K "
  if gm & mods.KEY2 > 0:
    s += "-m 2K "
  return s

