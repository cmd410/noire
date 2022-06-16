from htmlgen as hg import nil
import strutils

import prologue

import ../render/page
import ../core/postindexer
import ./common/components


proc indexRoute*(ctx: Context) {.async.} =
  let currentPage =
    try:
      ctx.getQueryParams("page", "1").parseInt
    except ValueError:
      1

  # Get posts on current page
  let indexer = getPostsPage(max(0, currentPage - 1), 25)

  # Final page creation
  let index = 
    page:
      title = "Noire"
      header = genNav()
      content = genPostsList(indexer)
      footer = genPageNav(indexer, currentPage)
  resp index
