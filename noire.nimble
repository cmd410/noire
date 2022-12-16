# Package

version       = "0.2.0"
author        = "Crystal Melting Dot"
description   = "A minimalist blogging solution"
license       = "MIT"
srcDir        = "src"
bin           = @["noire"]
binDir        = "_build"


# Dependencies

requires "nim >= 1.6.2"
requires "prologue == 0.5.8"
requires "markdown == 0.8.5"

import os

task pretty, "Prettify source files using nimpretty":
  for f in walkDirRec("."):
    if not f.endsWith(".nim"):
      continue
    try:
      exec "nimpretty --indent:2 " & f.escape
      echo f & " [OK]"
    except OSError:
      echo f & " [Error]"
