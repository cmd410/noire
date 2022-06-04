from htmlgen as hg import nil
import strutils
import os

import prologue

import ../render/page
import ../core/postindexer
import ./common/components


proc indexRoute*(ctx: Context) {.async.} =
  var postsArr: seq[string] = @[]

  let currentPage =
    try:
      ctx.getQueryParams("page", "1").parseInt
    except ValueError:
      1

  # Get posts on current page
  let indexer = getPostsPage(max(0, currentPage - 1), 25)

  # Render posts
  for i in indexer.posts:
    let docName = i.filename.splitFile()[1] & ".html"
    let hasImageBg = i.image.len > 0
    
    let bgImg =
      if hasImageBg:
        hg.img(class="post-img", src=i.image, alt="Post preview")
      else:
        ""
    var href = i.fullPath
    href.removePrefix(getPostsDir())
    href.removeSuffix(".md")
    href.add ".html"
    href.removePrefix("/")
    href = href.replace(r"\", "/")

    postsArr.add hg.div(
      class="post-preview",
      hg.a(href=href, hg.h1(i.title)),
      bgImg,
      hg.p(i.exerpt),
      i.genTags()
    )
  # Generate page navigation
  var pageNav = ""
  if indexer.totalPages > 1:
    if currentPage > 1:
      pageNav.add hg.a(class="page-link", id="prev", href="/?page=" & $(currentPage - 1), "Prev")
      for i in max(currentPage-2, 1)..<currentPage:
        pageNav.add hg.a(class="page-link", href="/?page=" & $i, $i)
    pageNav.add hg.a(class="active-page page-link", href="/?page=" & $currentPage, $currentPage)
    if currentPage < indexer.totalPages:
      for i in (currentPage + 1)..min(currentPage + 2, indexer.totalPages):
        pageNav.add hg.a(class="page-link", href="/?page=" & $i, $i)
      pageNav.add hg.a(class="page-link", id="next", href="/?page=" & $(currentPage + 1), "Next")

  # Final page creation
  let index = 
    page:
      title = "Noire"
      header = genNav()
      content = hg.div(class="post-list",postsArr.join(""))
      footer = hg.div(class="page-nav", pageNav)
  resp index
