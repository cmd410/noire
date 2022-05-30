## Here lies my own implemetntation of staticFileMiddleware
## this is due to original being limited to relative paths
## issue: https://github.com/planety/prologue/issues/153
## Don't know how secure this is but it shall do for now.

import std/os

import prologue

proc staticFilesMiddleware*(staticPath: string): HandlerAsync =
  result = proc(ctx: Context) {.async.} =
    let requested_res =  staticPath / ctx.request.path
    if requested_res.fileExists:
      await ctx.staticFileResponse(requested_res, "")
    await ctx.switch
