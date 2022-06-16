# Noire

Noire is a minimalistic blogging website implemented entirely in
Nim and CSS.

It's features include:

- Author posts in plain markdown
- Elegant CSS styling, no clutter
- No javascript, easily accesible on all platforms across all browsers
- Server-side syntax highlighting for code blocks
   - Supported languages: Nim, C++, C#, C, Java, Yaml, Python, Console

## Why?

I originally designed it for my own blog, as i was dissatisfied with the current state of modern
web and particulary blogging solutions. They are either bloated or ugly, or both(imho, of course). So I decided
to take matters into my hands an develop a minimal blogging site that would stay out of the way
for both writer and reader, and being able to run on every possible potato one can find both server and clientside.

Thus, the design principles:

- Keep it stupid simple
- No clientside javascript (there is literally no need to script text documents)

## Usage

### Build from source

Provided that you have Nim programming language and nimble package mananger installed
you can build Noire with one command:

```sh
nimble build
```

The executable is compiled to `_build` subdirectory, where static files reside aswell.
This directory is self-contained, and you can copy it to any location on your machine
and run executalbe from there.

### Configuration

Noire executable has decently reasonable defaults, however
one might want to customize their site to their liking.

Here are the options that Noire provides:

#### Environment

Noire runtime configuration relies on environment variables.

This is a list of all the options available, expected type, and default value.

| Variable name          | Expected type | Default value                     | Explanation                                                      |
|------------------------|---------------|-----------------------------------|------------------------------------------------------------------|
| `NOIRE_APP_TITLE`      | string        | "Noire"                           | App title, displayed in the page's `title` tag                   |
| `NOIRE_APP_ADDRESS`    | string        | ""                                | Bind an address for server to listen to                          |
| `NOIRE_APP_PORT`       | uint16        | 8080                              | Server port                                                      |
| `NOIRE_DEBUG`          | boolean       | false                             | Enable/disable server debuggin features                          |
| `NOIRE_REUSE_PORT`     | boolean       | true                              | Prologue server setting                                          |
| `NOIRE_BUFSIZE`        | Natural       | 40960                             | Prologue server setting                                          |
| `NOIRE_DATA_DIR`       | string        | "./data" (relative to executable) | Directory where application will store data                      |
| `NOIRE_POSTS_PER_PAGE` | Natural       | 25                                | Maximum amount of posts allowed to be displayed on a single page |

> Note: When setting `NOIRE_DATA_DIR`, make sure user running the application has read and write permissions for this directory

#### Custom static files

All the static files are in the `static` directory relative to executalbe file. You can modify them to your liking.
Want a custom favicon? Change the styling of you site? No problem here.

### Authoring posts

One can create posts in simple markdown files on their server.
Just put them in `NOIRE_DATA_DIR/posts` and they will appear on your site.

For multi-user setup you can make a subirectory for each user.

You can address files relative to your markdown files with ease, the web server
will normalize the links so they will be valid. For example if your post in
`/posts/me/riddles/1.md` references a file `../cat.jpg` the server will normalize
it to `/posts/me/cat.jpg`

One the index page posts are sorted by their creation date, which is determined by 2 means.
First, Noire attemps to parse filename of post for `YYYY-MM-DD` pattern in the begining.
If a post does not have such a pattern in the name, file meta information is used instead.
You can write a future date in the filename to postpone it's release to the public, it will
not be listed on the homepage or search results.

You can add tags or keywords to your post to help with SEO with a simple HTML comment:

```html
<!-- tags: this is your tags-here -->
```

So the main requirement is to start a comment with `tags:` and follow it up with tags separated by spaces. Thats it.

You can use markdown code blocks with syntax highlighting, no problem, besides a limited number of supported languages.

You can absolutely abondon the idea of adding javascript to your pages, we don't allow it, nah-ah.
Every script block will be removed, without exception.

## License

Source code in this repository is under MIT license.
Everything that cannot be classified as source code, for example pictures
and other multimedia assets are under CC BY-SA 4.0 unless stated otherwise.
(there are LICENSE and COPYRIGHT files that apply per-folder)
