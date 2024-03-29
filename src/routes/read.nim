import os
from htmlgen as hg import nil
import uri

import prologue

import ../render/page
import ./common/components
import ../core/postindexer
import ../core/envConf


proc readRoute*(ctx: Context) {.async.} =
  let
    requestedPage = ctx.getPathParams("path", "").decodeUrl(false)
  
  if requestedPage.len == 0:
    resp "Not found.", Http404
    return

  let originalMd = block:
    var parts = requestedPage.splitFile()
    parts[0] & "/" & parts[1] & ".md"

  try:
    let postData = newPost(getPostsDir() / originalMd)
    let finalPage =
      page:
        title = postData.title
        description=postData.exerpt
        header = genNav()
        content = hg.article(postData.content)
        tags = postData.tags
        footer = hg.a(href="/atom.xml", "Atom feed")
        styles = @["/css/style.css", "/css/highlite.css"]
    
    resp finalPage
  except PostNotExistsError:
    resp "Not found.", Http404