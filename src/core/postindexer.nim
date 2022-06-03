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


proc highlightSyntax(source: string): string =
  ## Does syntax highlighting for markdown code blocks
  ## Assumes first line is language
  ## If not, returns code block unchanged.
  let lines = source.split("\n", 1)
  if not lines.len == 2:
    return "```" & source & "\n```"
  let lang = lines[0].strip()
  let code = lines[1].strip()
  
  let langEnum = getSourceLanguage(lang)
  if langEnum == langNone:
    return "```" & source & "\n```" 
  
  result = "<pre><code lang=\"language-" & lang.toLower & "\">"
  var tokenizer: GeneralTokenizer
  tokenizer.initGeneralTokenizer(code)

  template current(tk: GeneralTokenizer): untyped =
    substr(code, tokenizer.start, tokenizer.length + tokenizer.start - 1)

  while true:
    tokenizer.getNextToken(langEnum)
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
  let originalMd = block:
    # here we freaking go, hold on, this will be a rough ride...
    # this code is responsible for parsing tags and doing syntax-highlighting
    var
      text = fullpath.readFile()
      buff: seq[char] = @[]
      tag = ""
      isCB = false
      codeBlockSource = ""
    
    let nontags = {'#', ' ', '\t', '\r', '\n'}
    for c in text:
      buff.add c
      if buff.len < 2:
        continue
      if buff.len >= 3:
        # Catch ``` in markdown to tell if we are in code block or not
        if buff[buff.high] & buff[buff.high-1] & buff[buff.high-2] == "```":
          for i in 1..3:
            discard buff.pop
          isCB = not isCB

      if isCB: # if we are in code block
        if c != '`':
          discard buff.pop
          codeBlockSource.add c
        continue
      elif codeBLockSource.len > 0:  # if we just left code block
        buff.add highlightSyntax(codeBlockSource) # insert the highlighted code to buffer
        codeBlockSource = ""
        continue

      # Parse tag
      if (buff[buff.high-1] == '#') and c notin nontags:
        discard buff.pop
        discard buff.pop
        tag = tag & c
      elif tag.len > 0:
        if c notin nontags:
          tag = tag & c
          discard buff.pop
        else:
          tags.add tag
          tag = ""
    
    buff.join()

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
