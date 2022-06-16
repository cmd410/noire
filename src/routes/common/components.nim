from htmlgen as hg import nil
import strutils
import uri

import ../../core/postindexer


type
  Tagged = concept o
    o.tags is seq[string]


proc genNav*(): string =
  result = hg.nav(
    hg.a(
      class="nav-link",
      href="/",
      "Home"
    ),
    hg.a(
      class="nav-link",
      href="/search",
      "Search"
    )
  )


proc genTags*(p: Tagged): string =
  result = "<div class=\"tags-container\">"
  for tag in p.tags:
    result.add hg.div(class="tag", tag)
  result.add "</div>"


proc genPostsList*(indexer: IndexerData): string =
  var postsArr: seq[string] = @[]
  for i in indexer.posts:
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
  result = hg.div(class="post-list",postsArr.join(""))

proc genPageNav*(indexer: IndexerData, currentPage: Natural, currentPath: string = "/"): string =
  result = "<div class=\"page-nav\">"
  let currentUri = currentPath.parseUri

  template getPageUri(pageno: Natural): string =
    var newQuery: seq[(string, string)] = @[]
    for (key, value) in currentUri.query.decodeQuery:
      if key == "page":
        continue
      else:
        newQuery.add (key, value)
    newQuery.add ("page", $pageno)
    $(currentUri ? newQuery)

  if indexer.totalPages > 1:
    if currentPage > 1:
      result.add hg.a(class="page-link", id="prev", href=getPageUri(currentPage - 1), "Prev")
      for i in max(currentPage-2, 1)..<currentPage:
        result.add hg.a(class="page-link", href=getPageUri(i), $i)
    result.add hg.a(class="active-page page-link", href=getPageUri(currentPage), $currentPage)
    if currentPage < indexer.totalPages:
      for i in (currentPage + 1)..min(currentPage + 2, indexer.totalPages):
        result.add hg.a(class="page-link", href=getPageUri(i), $i)
      result.add hg.a(class="page-link", id="next", href=getPageUri(currentPage + 1), "Next")
  result &= "</div>"