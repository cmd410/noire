import os
import logging

import prologue
export prologue

import ./middleware/static
import ./routes/init


addHandler(newConsoleLogger(fmtStr="[$datetime] - $levelname: "))
addHandler(newRollingFileLogger("rolling.log", fmtStr="[$datetime] - $levelname: "))


proc readConfig(): Settings =
  ## Read prologue configuration from json file.
  ## 
  ## Searches for ``config.release.json`` and ``config.debug.json``
  ## in release and debug builds respectively. Search directories
  ## are in order: ``./``, ``getAppDir()``, ``~/.config/noire``.
  ## First found config file is used.
  let
    filename = 
      when defined(release):
        "config.release.json"
      else:
        "config.debug.json"
    configPath = block:
      let searchPaths = [".", getAppDir(), getHomeDir() / ".config/noire"]
      var configLocation = ""
      for dir in searchPaths:
        let candidate = dir / filename
        if fileExists(candidate):
          configLocation = candidate
          break
      configLocation
  
  if configPath.len == 0:
    raise OSError.newException:
      "Config file '" & filename & "' was not found!"

  info "Using config: " & configPath
  result = loadSettings(configPath)


proc noireMain*() =
  var app = newApp(settings = readConfig())
  app.use staticFilesMiddleware(getAppDir() / "static")
  app.mountRoutes()
  app.run()
