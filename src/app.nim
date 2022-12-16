import os
import logging

import prologue
export prologue

import ./middleware/static
import ./routes/init
import ./core/envConf


addHandler(newConsoleLogger(fmtStr="[$datetime] - $levelname: "))

when defined(filelog):
addHandler(newRollingFileLogger("rolling.log", fmtStr="[$datetime] - $levelname: "))


proc readConfig(): Settings =
  result = newSettings(
    address=getAppAddress(),
    port=getAppPort(),
    debug=getAppDebug(),
    reusePort=getAppReusePort(),
    appName=getAppName(),
    bufSize=getAppBufSize(),
  )


proc noireMain*() =
  var app = newApp(settings = readConfig())
  app.use staticFilesMiddleware(getAppDir() / "static")
  app.mountRoutes()
  app.run()
