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

### Creating a systemd service

To ensure noire start with your system, you can create a systemd service.
To create one you can edit a file `/etc/systemd/system/noire.service`

Here is a simple example:

```ini
[Unit]
Description=A minimalist blogging website

[Service]
User=noire
WorkingDirectory=/home/noire
ExecStart=/home/noire/noire
Environment="NOIRE_APP_TITLE=YOUR SITE TITLE HERE"
Environment="NOIRE_APP_PORT=20080"
Environment="NOIRE_DATA_DIR=/some/custom/data/dir"

[Install]
WantedBy=multi-user.target
```

> This examples assumes you have a user in the system named `noire`, if you don't you can add one with a command:
> 
> ```sh
> sudo useradd -m noire
> ```
> Moreover it assumes that the binary along with static dir are in this user's dir

Once you've done that you can start the service by executing

```sh
sudo systemctl daemon-reload  # make systemd notice you new .service file
sudo systemctl start noire && sudo systemctl enable noire
```

### Proxying with Nginx

Proxying with nginx is generaly a good idea for a few reasons:

- App won't need superuser priviliges to use 80 and 443 ports
- You might want to have multiple sites on single domain

So, let's do this! Here is an example of simple server section for nginx config.

```nginx
server {
  listen 80;
  listen 443 ssl http2;
  server_name your-domain.tld www.your-domain.tld;
  ssl_certificate /your-certs-dir/www.your-domain.tld;
  ssl_certificate_key /your-certs-dir/www.your-domain.tld.key;

  keepalive_timeout 70;

  gzip on;
  gzip_types
    application/javascript
    application/x-javascript
    application/json
    application/rss+xml
    application/xml
    image/svg+xml
    image/x-icon
    application/vnd.ms-fontobject
    application/font-sfnt
    text/css
    text/plain;
  gzip_min_length 256;
  gzip_comp_level 5;
  gzip_vary on;

  location / {
    proxy_pass http://127.0.0.1:20080;
  }
}
```

Well... not the simplest one, but the only required parts here are `listen`
directives and `location /` section with `proxy_pass` to a port the app is listening to on localhost. Everything else is just some fancy fluff, that
nonetheless one might find useful.

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

For multi-user setup you can make a subdirectory for each user.

You can address files relative to your markdown files with ease, the web server
will normalize the links so they will be valid. For example if your post in
`/posts/me/riddles/1.md` references a file `../cat.jpg` the server will normalize
it to `/posts/me/cat.jpg`

On the index page posts are sorted by their creation date, which is determined by 2 means.
First, Noire attemps to parse filename of post for `YYYY-MM-DD` pattern in the begining.
If a post does not have such a pattern in the name, file meta information is used instead.
You can write a future date in the filename to postpone it's release to the public, it will
not be listed on the homepage or search results until that date.

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


## ROADMAP

- further improve SEO, add more meta tags, etc
