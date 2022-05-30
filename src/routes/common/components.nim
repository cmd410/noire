from htmlgen as hg import nil



proc genNav*(): string =
  result = hg.nav(
    hg.a(
      class="nav-link",
      href="/",
      hg.img(src="/favicon.png", alt="Home")
    ),
    hg.a(
      class="nav-link",
      href="/about",
      "About"
    )
  )
