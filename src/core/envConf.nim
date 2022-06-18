import os
import net
import strutils


proc getAppName*(): string =
  getEnv("NOIRE_APP_TITLE", "Noire")

proc getAppAddress*(): string =
  getEnv("NOIRE_APP_ADDRESS", "")

proc getAppPort*(): Port =
  getEnv("NOIRE_APP_PORT", "8080").parseInt.Port

proc getAppDebug*(): bool =
  getEnv("NOIRE_DEBUG", "off").parseBool

proc getAppReusePort*(): bool =
  getEnv("NOIRE_REUSE_PORT", "on").parseBool

proc getAppBufSize*(): int =
  getEnv("NOIRE_BUFSIZE", "40960").parseInt

proc getAppDataDir*(): string =
  getEnv("NOIRE_DATA_DIR", getAppDir() / "data")

proc getAppPostsPerPage*(): Natural =
  max(getEnv("NOIRE_POSTS_PER_PAGE", "25").parseInt, 1)

proc getAppHostName*(): string =
  getEnv("NOIRE_HOSTNAME", "localhost")
