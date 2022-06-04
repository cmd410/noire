import os
import times
import heapqueue
import strutils
import json
import logging
import htmlparser
import xmltree
import strtabs
import math
import packages/docutils/highlite
import uri

import markdown


type
  PostNotExistsError* = object of CatchableError
  Post* = object
    # Fully parsed md file
    filename*: string
    fullPath*: string
    dateCreated*: Time
    dateModified*: Time
    author*: string
    title*: string
    content*: string
    exerpt*: string
    tags*: seq[string]
    image*: string
  IndexerData* = tuple[posts: seq[Post], totalPages: Natural]


proc getDataDir*(): string =
  result = getEnv("NOIRE_DATA_DIR", getAppDir() / "data")


proc getPostsDir*(): string =
  getDataDir() / "posts"


proc getCacheDir*(): string =
  getDataDir() / "cache"


proc `<`*(a,b: Post): bool =
  a.dateCreated.toUnix > b.dateCreated.toUnix


proc highlightSyntax(source: string, lang: SourceLanguage): string =
  ## Does syntax highlighting
  
  result = ""
  var tokenizer: GeneralTokenizer
  tokenizer.initGeneralTokenizer(source)

  template current(tk: GeneralTokenizer): untyped =
    substr(source, tokenizer.start, tokenizer.length + tokenizer.start - 1)

  while true:
    tokenizer.getNextToken(lang)
    case tokenizer.kind
    of gtEof: break
    of gtKeyword:
      result.add "<span class=\"kwd\">" & tokenizer.current & "</span>"
    of gtDecNumber, gtHexNumber, gtBinNumber:
      result.add "<span class=\"num\">" & tokenizer.current & "</span>"
    of gtStringLit:
      result.add "<span class=\"str\">" & tokenizer.current & "</span>"
    of gtIdentifier:
      result.add "<span class=\"ide\">" & tokenizer.current & "</span>"
    of gtComment:
      result.add "<span class=\"com\">" & tokenizer.current & "</span>"
    else:
      result.add tokenizer.current

  result.add "</code></pre>"


proc normalizeLink(link: string, ctxDir: string): string =
  ## Make absolute link from relative to given ctxDir

  let url = parseUri(link)
  if url.hostname.len > 0:
    return link
  
  let
    ctx = parseUri(ctxDir)
  
  var 
    partsRes = url.path.split("/")
    partsCtx = ctx.path.split("/")
    newResParts: seq[string] = @[]
    i: Natural = 0
  
  while i <= partsRes.high:
    let el = partsRes[i]
    case el
    of "..":
      partsRes.delete(i)
      if partsCtx.len > 0: discard partsCtx.pop
      continue
    of ".":
      i.inc
    else:
      newResParts.add el
      i.inc
  result = partsCtx.join("/") & "/" & newResParts.join("/")


proc normalizeHtml(node: var XmlNode, ctxDir: string = "") =
  if node.kind != xnElement:
    return
  var
    deletionQueue: seq[Natural] = @[]
    i = 0
  
  for element in node.mitems:
    if element.kind != xnElement:
      i.inc
      continue
    
    case element.tag:
    of "pre":
      # perform syntax highlighting
      for code in element.mitems:
        if code.tag != "code": continue
        let lang = block:
          var s = code.attrs.getOrDefault("class", "")
          s.removePrefix("language-")
          getSourceLanguage(s)
        
        case lang
        of langNone:
          continue
        else:
          let source = code.innerText
          code.clear
          code.add newVerbatimText(highlightSyntax(source, lang))
    of "a":
      # Normalize local links to md files, to point to html pages
      var link = element.attrs.getOrDefault("href", "")
      link = normalizeLink(link, ctxDir)
      if link.endsWith(".md"):
        link.removeSuffix ".md"
        link.add ".html"
        element.attrs["href"] = link
    
    of "img", "source", "video", "audio":
      # Normalize links to resources
      let originalSrc = element.attr("src")
      if originalSrc.len > 0:
        element.attrs["src"] = normalizeLink(originalSrc, ctxDir)
    
    of "script":
      deletionQueue.add i
      continue
    else:
      element.normalizeHtml(ctxDir)
    i.inc
  
  for i in deletionQueue:
    node.delete i


proc newPost*(fullPath: string): Post =
  let author = block:
    let parts = fullPath.replace(r"\", "/").split("/")
    parts[0]

  var info: FileInfo
  try:
    info = fullPath.getFileInfo
  except OSError:
    raise PostNotExistsError.newException:
      "Post" & fullPath & " was not found."
  
  let metapath = block:
    var parts = fullPath.splitFile()
    let filename = parts[1]
    let usr = parts[0].extractFilename
    getCacheDir() / usr / filename & ".cache.json"
  
  block loadCached:
    if fileExists(metapath):
      let post = 
        try:
          metapath.readFile().parseJson().to(Post)
        except:
          break loadCached
      if post.dateModified.toUnix < info.lastWriteTime.toUnix:
        break loadCached
      debug "Using cached: " & metapath.extractFilename
      return post
  
  var tags: seq[string] = @[]
  let originalMd = fullpath.readFile()

  let content = markdown(originalMd)
  var title = "Untitled"
  var exerpt = ""
  var image = ""
  
  var html = parseHtml(content)
  for i in html.findAll("h1"):
    title = i.innerText()
    break
  for i in html.findAll("p"):
    exerpt = i.innerText()
    if exerpt.len == 0:
      continue
    else:
      break
  
  # very cringe way to get path relative to posts dir
  when defined(windows):
    var ctx = fullPath.replace(r"\", "/").rsplit("/", 1)[0]
    ctx.removePrefix(getPostsDir().replace(r"\", "/"))
  else:
    var ctx = fullPath.rsplit("/", 1)[0]
    ctx.removePrefix(getPostsDir())
  
  html.normalizeHtml(ctx)
  
  for i in html.findAll("img"):
    let link = i.attrs.getOrDefault("src")
    image = link
    break

  # Attempt parse creation date from filename
  let createdAt =
    try:
      parse(fullPath.extractFilename.substr(0, 9), "yyyy-MM-dd").toTime
    except ValueError:
      info.creationTime
  
  # Some more things to parse here
  result = Post(
    filename: fullPath.extractFilename,
    fullPath: fullPath,
    dateCreated: createdAt,
    dateModified: info.lastWriteTime,
    author: author,
    # the following line looks cringe, but is the most efficient way to get rid of <document> tag I know of
    content: ($html).multiReplace(("<document>", ""), ("</document>", "")),
    title: title,
    exerpt: exerpt,
    tags: tags,
    image: image
  )
  let cacheDir = metapath.splitPath[0]
  if not dirExists(cacheDir):
    createDir(cacheDir)
  var f: File
  if f.open(metapath, fmWrite):
    f.write `$`(%result)
    f.close()


proc getPostsPage*(pageno: Natural, perPage: Natural): IndexerData =
  var
    posts: HeapQueue[Post] = initHeapQueue[Post]()
  
  for path in walkDirRec(getDataDir() / "posts"):
    if not path.endsWith ".md":
      continue
    try:
      posts.push newPost(path)
    except PostNotExistsError:
      continue
  
  result.totalPages = ceilDiv(posts.len, perPage)
  result.posts = @[]
  if pageno <= result.totalPages:
    let firstPost = perPage * pageno
    var current = firstPost
    let limit = min((pageno + 1) * perPage, posts.len)
    while current < limit:
      result.posts.add posts[current]
      inc(current)
