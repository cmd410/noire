## Here lies my own implemetntation of staticFileMiddleware
## this is due to original being limited to relative paths
## issue: https://github.com/planety/prologue/issues/153
## Don't know how secure this is but it shall do for now.

import std/os
import std/uri
import std/strutils

import prologue

import ../core/postindexer

proc staticFilesMiddleware*(staticPath: string): HandlerAsync =
  result = proc(ctx: Context) {.async.} =
    let requested_res =  staticPath / ctx.request.path
    
    # If a resource is requested from user's post
    # we need to query files in their posts folder
    # so that users can upload media content for their posts
    block userFile:
      var user = ctx.getQueryParams("owner", "")
      
      if user == "":
        let referer = parseUri(ctx.request.getHeaderOrDefault("Referer", @["/"])[0])
        if referer.path != "/":
          let parts = referer.path.splitPath()
          if parts.head.len == 0:
            break userFile
          if parts.head.rfind("/") != parts.head.low:
            break userFile
          user = parts.head

      let user_res = getPostsDir() / user / ctx.request.path
      if user_res.fileExists:
        await ctx.staticFileResponse(user_res, "")
        await ctx.switch
        return
    
    # If user content not found or is not applicable
    # fallback to common static files dir
    if requested_res.fileExists:
      await ctx.staticFileResponse(requested_res, "")
    await ctx.switch
