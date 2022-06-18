import os
import xmltree
import strutils
import times

import prologue

import ../core/postindexer
import ../core/envConf


proc getSiteUrl(): string =
  let port = getAppPort()
  
  let portString = 
    case port
    of 80.Port, 443.Port:
      ""
    else:
      ":" & $(port.uint16)
  
  result = "http://" & getAppHostName() & portString & "/"


template addElem(parent: XmlNode, tag, text: string): untyped =
  var elem = newElement(tag)
  if text.len > 0:
    elem.add newText(text)
  parent.add elem


proc genAtomFeed(title: string, postsData: IndexerData): string =
  var feed = newElement("feed")
  feed.attrs = {"xmlns": "http://www.w3.org/2005/Atom"}.toXmlAttributes

  feed.addElem("title", title)

  var selfLink = newElement("link")
  selfLink.attrs = {"href": getSiteUrl() & "atom.xml", "rel": "self"}.toXmlAttributes
  feed.add selfLink

  var baseLink = newElement("link")
  baseLink.attrs = {"href": getSiteUrl()}.toXmlAttributes
  feed.add baseLink

  feed.addElem("updated", $now())

  for p in postsData.posts:
    var entry = newElement("entry")
    
    entry.addElem("title", p.title)
    entry.addElem("published", $p.dateCreated)
    entry.addElem("updated", $p.dateModified)

    var postLink = getSiteUrl() & p.fullPath.relativePath(getPostsDir())
    postLink.removeSuffix(".md")
    postLink.add ".html"
    var link = newElement("link")
    link.attrs = {"type": "text/html", "href": postLink}.toXmlAttributes
    link.add newText(postLink)
    entry.add link

    entry.addElem("summary", p.exerpt)

    var content = newElement("content")
    content.attrs = {"type": "xhtml"}.toXmlAttributes
    content.add newVerbatimText(p.content)
    entry.add content

    var author = newElement("author")
    author.addElem("name", p.author)
    entry.add author

    feed.add entry

  result = "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n" & $feed


proc atomRoute*(ctx: Context) {.async.} =
  ctx.response.setHeader("Content-Type", "application/atom+xml")
  resp genAtomFeed(getAppName(), getPostsPage(0, 128))
