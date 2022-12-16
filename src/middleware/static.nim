## Here lies my own implemetntation of staticFileMiddleware
## this is due to original being limited to relative paths
## issue: https://github.com/planety/prologue/issues/153
## Don't know how secure this is but it shall do for now.

import std/os
import std/strutils

import prologue

import ../core/envConf
from ../core/util import walkVisible

proc staticFilesMiddleware*(staticPath: string): HandlerAsync =
  result = proc(ctx: Context) {.async.} =
    let path = ctx.request.path

    # First check user resource
    let userRes = getPostsDir() / path
    for i in walkVisible(getPostsDir()):
      if cmpPaths(i, userRes) == 0:
        await ctx.staticFileResponse(userRes, "")
    
    # Then fallback to common static dir
    let commonRes =  staticPath / path
    if commonRes.fileExists:
      await ctx.staticFileResponse(commonRes, "")
    await ctx.switch
