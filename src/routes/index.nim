from htmlgen as hg import nil
import strutils
import times
import uri
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
  let indexer = getPostsPage(max(0, currentPage - 1), 15)

  # Render posts
  for i in indexer.posts:
    let docName = i.filename.splitFile()[1] & ".html"
    let hasImageBg = i.image.len > 0
    
    let bgImg =
      if hasImageBg:
        "background-image: url('" & i.image & "')"
      else:
        ""
    let cls =
      if hasImageBg:
        "post-preview text-on-img"
      else:
        "post-preview"
    let shadowBg =
      if hasImageBg:
        hg.div(class="shadow-bg")
      else:
        ""
    postsArr.add hg.div(
      class=cls,
      shadowBg,
      hg.a(href="/" & i.author.encodeUrl(false) & "/" & docName.encodeUrl(false), hg.h1(i.title)),
      hg.p(i.exerpt),
      i.genTags(),
      hg.span("Posted by " & i.author & " on " & $i.dateCreated.format("ddd MMMM dd yyyy")),
      style=bgImg
    )

  # Generate page navigation
  var pageNav = ""
  if indexer.totalPages > 1:
    if currentPage > 1:
      pageNav.add hg.a(class="nav-link", href="/?page=" & $(currentPage - 1), "Prev")
      for i in max(currentPage-2, 1)..<currentPage:
        pageNav.add hg.a(class="nav-link", href="/?page=" & $i, $i)
    pageNav.add hg.a(class="active-page nav-link", href="/?page=" & $currentPage, $currentPage)
    if currentPage < indexer.totalPages:
      for i in (currentPage + 1)..min(currentPage + 2, indexer.totalPages):
        pageNav.add hg.a(class="nav-link", href="/?page=" & $i, $i)
      pageNav.add hg.a(class="nav-link", href="/?page=" & $(currentPage + 1), "Next")

  # Final page creation
  let index = 
    page:
      title = "Noire"
      header = genNav()
      content = hg.div(class="post-list",postsArr.join("")) & hg.div(class="page-nav", pageNav)
  resp index
