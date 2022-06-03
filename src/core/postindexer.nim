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
import sequtils

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
  PostOpt = object
    ## Used for optimised sorting of posts by date
    dateCreated*: Time
    fullPath*: string
  IndexerData* = tuple[posts: seq[Post], totalPages: Natural]


proc getDataDir*(): string =
  result = getEnv("NOIRE_DATA_DIR", getAppDir() / "data")


proc getPostsDir*(): string =
  getDataDir() / "posts"


proc getCacheDir*(): string =
  getDataDir() / "cache"


proc `<`*(a,b: PostOpt): bool =
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
    of gtCommand:
      result.add "<span class=\"cmd\">" & tokenizer.current & "</span>"
    else:
      result.add tokenizer.current

  result.add "</code></pre>"



proc sanitizeJS(node: var XmlNode) =
  ## Make <script> tags in html harmless
  
  iterator scriptKiddies(node: var XmlNode): Natural =
    var i = 0
    for child in node.mitems:
      if child.tag == "script":
        yield i
        continue
      i.inc  # only increment on non-script tags
      child.sanitizeJS()
  
  for i in node.scriptKiddies().toSeq:
    node.delete i

proc newPost*(fullPath: string): Post =
  let author = fullPath.splitPath[0].extractFilename

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
  for i in html.findAll("img"):
    # replace all img src to user-local paths
    let imgUrl = parseUri("/") / author / i.attrs.getOrDefault("src", "")
    i.attrs["src"] = imgUrl.path
    i.attrs["lazy"] = ""
  for i in html.findAll("img"):
    let link = i.attrs.getOrDefault("src")
    if link.startsWith "/?":
      break
    image = link

  html.sanitizeJS()

  # perform syntax highlighting
  for pre in html.mitems:
    if pre.tag != "pre": continue
    for code in pre.mitems:
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
        code.insert(newVerbatimText(highlightSyntax(source, lang)), 0)

  # Some more things to parse here
  result = Post(
    filename: fullPath.extractFilename,
    fullPath: fullPath,
    dateCreated: info.creationTime,
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
    posts: HeapQueue[PostOpt] = initHeapQueue[PostOpt]()
  
  for path in walkDirRec(getDataDir() / "posts"):
    if not path.endsWith ".md":
      continue
    try:
      posts.push PostOpt(dateCreated: getFileInfo(path).creationTime, fullPath: path)
    except OSError:
      continue
  
  result.totalPages = ceilDiv(posts.len, perPage)
  result.posts = @[]
  if pageno <= result.totalPages:
    let firstPost = perPage * pageno
    var current = firstPost
    let limit = min((pageno + 1) * perPage, posts.len)
    while current < limit:
      result.posts.add newPost(posts[current].fullPath)
      inc(current)
