from htmlgen as hg import nil
import strutils

import prologue

import ../render/page
import ../core/postindexer
import ./common/components


proc searchRoute*(ctx: Context) {.async.} =
  let query = ctx.getQueryParams("q", "")
  let pageno =
    try:
      ctx.getQueryParams("page", "").parseInt
    except ValueError:
      1
  
  let indexer = searchPosts(query, max(0, pageno - 1), 1)
  
  let searchPage =
    page:
      title = "Noire - Search"
      header = genNav()
      content = hg.form(
        hg.input(
          id="query", name="q",
          placeholder="What are you looking for?",
          value=query
        ),
        hg.button("Search")
      ) & genPostsList(indexer)
      footer = genPageNav(indexer, pageno, ctx.request.path & "?" & ctx.request.query)
  
  resp searchPage
