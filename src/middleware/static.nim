## Here lies my own implemetntation of staticFileMiddleware
## this is due to original being limited to relative paths
## issue: https://github.com/planety/prologue/issues/153
## Don't know how secure this is but it shall do for now.

import std/os
import std/strutils

import prologue

from ../core/postindexer import getPostsDir
from ../core/util import walkVisible

proc staticFilesMiddleware*(staticPath: string): HandlerAsync =
  result = proc(ctx: Context) {.async.} =
    let path = ctx.request.path

    # First check user resource
    let user_res = getPostsDir() / path
    for i in walkVisible(getPostsDir()):
      if cmpPaths(i, user_res) == 0:
        await ctx.staticFileResponse(user_res, "")
    
    # Then fallback to common static dir
    let common_res =  staticPath / path
    if common_res.fileExists:
      await ctx.staticFileResponse(common_res, "")
    await ctx.switch
