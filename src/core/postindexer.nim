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
import sets
import sequtils

import markdown except toSeq
# excluding toSeq beacuse it breaks every other toSeq
# https://github.com/nim-lang/Nim/issues/7322

import ./envConf


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
  SearchResult* = object
    post*: Post
    score*: float  ## How relevant is result 
  IndexerData* = tuple[posts: seq[Post], totalPages: Natural]


proc getDataDir*(): string {.inline.} =
  result = getAppDataDir()


proc getPostsDir*(): string {.inline.} =
  getDataDir() / "posts"


proc getCacheDir*(): string {.inline.} =
  getDataDir() / "cache"


proc `<`*(a,b: Post): bool =
  a.dateCreated.toUnix > b.dateCreated.toUnix

proc `<`*(a,b: SearchResult): bool =
  a.score > b.score


proc highlightSyntax(source: string, lang: SourceLanguage): string =
  ## Does syntax highlighting
  
  result = ""
  var tokenizer: GeneralTokenizer
  tokenizer.initGeneralTokenizer(source)

  template mark(tk: GeneralTokenizer, cls: string): untyped =
    "<span class=\"" & cls & "\">" &
    substr(source, tokenizer.start, tokenizer.length + tokenizer.start - 1) &
    "</span>"
  while true:
    tokenizer.getNextToken(lang)

    case tokenizer.kind
    of gtEof: break
    of gtKeyword, gtProgram:
      result.add tokenizer.mark "kwd"
    of gtDecNumber, gtHexNumber, gtBinNumber, gtFloatNumber:
      result.add tokenizer.mark "num"
    of gtStringLit:
      result.add tokenizer.mark "str"
    of gtIdentifier:
      result.add tokenizer.mark "ide"
    of gtComment:
      result.add tokenizer.mark "com"
    of gtProgramOutput:
      result.add tokenizer.mark "out"
    of gtOperator:
      result.add tokenizer.mark "op"
    else:
      result.add substr(source, tokenizer.start, tokenizer.length + tokenizer.start - 1)


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
    if element.attrs == nil:
      element.attrs = newStringTable(modeCaseInsensitive)
    case element.tag:
    of "pre":
      # perform syntax highlighting
      for code in element.mitems:
        if code.kind != xnElement: continue
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
          code.add newVerbatimText(highlightSyntax(source.strip(), lang))
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
    of "li":
      for sub in element.mitems:
        case sub.kind
        of xnText:
          var text = sub.text
          if text.startsWith "[ ]":
            text.removePrefix("[ ]")
            sub.text = text
            element.attrs["class"] = "unchk"
          elif text.startsWith "[x]":
            text.removePrefix("[x]")
            sub.text = text
            element.attrs["class"] = "chk"
        of xnElement:
          sub.normalizeHtml()
        else: discard
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
    var relPath = fullPath.relativePath(getPostsDir())
    relPath.removeSuffix(".md")
    getCacheDir() / relPath & ".cache.json"
  
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
  
  var tags: HashSet[string] = initHashSet[string]()
  for i in html.items:
    if i.kind == xnComment:
      let text = i.text.strip
      if text.startsWith "tags:":
        for tag in text.substr(5).strip.split(" "):
          tags.incl tag

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
    tags: toSeq(tags),
    image: image
  )
  let cacheDir = metapath.splitPath[0]
  if not dirExists(cacheDir):
    createDir(cacheDir)
  var f: File
  if f.open(metapath, fmWrite):
    f.write `$`(%result)
    f.close()


iterator walkPostSources(d: string = getPostsDir()): string =
  var dirsToWalk = @[d]
  while dirsToWalk.len > 0:
    let curdir = dirsToWalk.pop
    for (kind, path) in walkDir(curdir):
      if path.extractFilename.startsWith("."):
        continue
      if kind in {pcDir, pcLinkToDir}:
        dirsToWalk.add(path)
        continue
      if path.endsWith(".md"):
        yield path


proc getPostsPage*(pageno: Natural, perPage: Natural): IndexerData =
  var posts: HeapQueue[Post] = initHeapQueue[Post]()
  
  let presentDayPresentTime = now().toTime

  for path in walkPostSources():
    let post = 
      try:
        newPost(path)
      except PostNotExistsError:
        continue
    if post.dateCreated > presentDayPresentTime:
      continue
    posts.push post
  
  result.totalPages = ceilDiv(posts.len, perPage)
  result.posts = @[]
  if pageno <= result.totalPages:
    let firstPost = perPage * pageno
    var current = firstPost
    let limit = min((pageno + 1) * perPage, posts.len)
    while current < limit:
      result.posts.add posts[current]
      inc(current)


proc searchPosts*(query: string, pageno: Natural, perPage: Natural): IndexerData =
  if query.len == 0:
    return getPostsPage(pageno, perPage)

  var results = initHeapQueue[SearchResult]()
  
  let presentDayPresentTime = now().toTime
  
  for path in walkPostSources():
    let post =
      try:
        newPost(path)
      except PostNotExistsError:
        continue
    if post.dateCreated > presentDayPresentTime:
      continue
    # Rate the post
    var score = 0'f
    if query in post.title:
      score += 1
    if query in post.tags:
      score += 0.5
    score += min(post.content.count(query), 10).float / 10
    if score == 0'f:
      continue
    results.push(SearchResult(post: post, score: score))
  

  result.totalPages = ceilDiv(results.len, perPage)
  result.posts = @[]
  if pageno <= result.totalPages:
    let firstPost = perPage * pageno
    var current = firstPost
    let limit = min((pageno + 1) * perPage, results.len)
    while current < limit:
      result.posts.add results[current].post
      inc(current)
