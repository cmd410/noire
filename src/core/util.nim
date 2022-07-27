import os, strutils

iterator walkVisible*(d: string): string =
  ## Walk over files in a directory, hidden files and folders
  ## (starting with `.` char) are ignored
  var dirsToWalk = @[d]
  while dirsToWalk.len > 0:
    let curdir = dirsToWalk.pop
    for (kind, path) in walkDir(curdir):
      if path.extractFilename.startsWith("."):
        continue
      if kind in {pcDir, pcLinkToDir}:
        dirsToWalk.add(path)
        continue
      yield path