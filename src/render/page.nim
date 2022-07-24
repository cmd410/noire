import strutils
from htmlgen as hg import nil
import std/macros

import ../core/envConf


proc buildTags*(tags: openArray[string]): string =
  result = hg.meta(name="keywords", content=tags.join(", "))


macro page*(arg: untyped): string =
  ## A macro to render pages in declarative style
  ## 
  ## Supported elements:
  ## * title: ``string`` - Page title
  ## * tags: ``openArray[string]`` - page keywords for SEO
  ## * content: ``string`` - Main page content
  ## * styles: ``seq[string]`` - a link to custom stylesheet for the page (default: "/css/style.css")
  ## * header: ``string`` - contents of <header> tag of the page
  ## * footer: ``string`` - contents of <footer> tag of the page
  ## * description: ``string`` - page description for meta tag
  runnableExamples:
    from htmlgen as hg import nil

    let pageContent =
      hg.h1("Awesome page headline") &
      hg.p("Here goes the text for this awesome declaratively generated page")
    
    let index =
      page:
        title = "Awesome"
        tags = ["index", "declarative"]
        header = hg.nav(
          hg.a(href="/", "Home"),
          hg.a(href="/about", "About")
        )
        content = pageContent
    
    echo index

  arg.expectKind nnkStmtList
  
  var titleStmt = quote do: ""
  var contentStmt = quote do: ""
  var tagsStmt = quote do: ""
  var styleStmt = quote do: hg.link(rel="stylesheet", href="/css/style.css")
  var headerStmt = quote do: ""
  var footerStmt = quote do: ""
  var descriptionStmt = quote do: ""

  for i in arg:
    i.expectKind nnkAsgn
    let keynode = i[0]
    let valuenode = i[1]
    keynode.expectKind nnkIdent
    if keynode.eqIdent "title":
      titleStmt = quote do:
        hg.title(`valuenode`) & "<meta name=\"og:title\" content=\"" & $(`valuenode`) & "\"/>"
    
    elif keynode.eqIdent "tags":
      tagsStmt = quote do: buildTags(`valuenode`)
    
    elif keynode.eqIdent "content":
      contentStmt = quote do: hg.main(`valuenode`)
    
    elif keynode.eqIdent "styles":
      styleStmt = quote do:
        var s = ""
        for i in `valuenode`:
          s.add hg.link(rel="stylesheet", href=i)
        s
    
    elif keynode.eqIdent "header":
      headerStmt = quote do: hg.header(`valuenode`)
    
    elif keynode.eqIdent "footer":
      footerStmt = quote do: hg.footer(`valuenode`)
    elif keynode.eqIdent "description":
      descriptionStmt = quote do: "<meta name=\"og:description\" content=\"" & $(`valuenode`) & "\"/>"
    else:
      warning("Unknown element: " & repr(keynode).escape & " will be skipped", keynode)

  result = quote do:
    "<!DOCTYPE html>" & "<html prefix=\"og: http://ogp.me/ns#\">" &
      hg.head(
        hg.meta(charset="UTF-8"),
        `titleStmt`,
        `descriptionStmt`,
        "<meta name=\"og:site_name\" content=\"" & getAppName() & "\"/>",
        `tagsStmt`,
        `styleStmt`,
      ) &
      hg.body(
        `headerStmt`,
        `contentStmt`,
        `footerStmt`
      ) & "</html>"
