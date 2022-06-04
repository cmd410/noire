from htmlgen as hg import nil



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
      href="/srch",
      "Search"
    )
  )


proc genTags*(p: Tagged): string =
  result = "<div class=\"tags-container\">"
  for tag in p.tags:
    result.add hg.div(class="tag", tag)
  result.add "</div>"
