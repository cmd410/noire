from htmlgen as hg import nil
import strutils

import prologue

import ../render/page
import ../core/postindexer
import ../core/envConf
import ./common/components


proc indexRoute*(ctx: Context) {.async.} =
  let currentPage =
    try: max(ctx.getQueryParams("page", "1").parseInt, 1)
    except ValueError: 1

  # Get posts on current page
  let indexer = getPostsPage(currentPage - 1, getAppPostsPerPage())

  # Final page creation
  let index = 
    page:
      title = getAppName()
      header = genNav()
      content = genPostsList(indexer)
      footer = genPageNav(indexer, currentPage) & hg.a(href="/atom.xml", "Atom feed")
  resp index
