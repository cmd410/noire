## Here lies my own implemetntation of staticFileMiddleware
## this is due to original being limited to relative paths
## issue: https://github.com/planety/prologue/issues/153
## Don't know how secure this is but it shall do for now.

import std/os
import std/strutils

import prologue

from ../core/postindexer import getPostsDir

proc staticFilesMiddleware*(staticPath: string): HandlerAsync =
  result = proc(ctx: Context) {.async.} =
    let path = ctx.request.path

    # First check user resource
    let user_res = getPostsDir() / path
    if user_res.fileExists:
      await ctx.staticFileResponse(user_res, "")
    
    # Then fallback to common static dir
    let common_res =  staticPath / path
    if common_res.fileExists:
      await ctx.staticFileResponse(common_res, "")
    await ctx.switch
