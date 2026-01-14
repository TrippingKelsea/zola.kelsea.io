# kelsea.io - Retro Terminal Theme

A retro-terminal inspired theme for Zola static site generator, featuring CRT effects, scanlines, and classic terminal aesthetics.

## Features

- Classic green-on-black terminal color scheme (amber variant available)
- CRT screen effects with scanlines and phosphor glow
- Blinking cursor animation
- Terminal-style navigation and file listings
- Responsive design for mobile devices
- Keyboard shortcuts for navigation
- Syntax highlighting for code blocks

## Quick Start

1. Build and serve your site:
   ```bash
   zola serve
   ```

2. Visit `http://127.0.0.1:1111` to see your terminal blog

## Customization

### Color Scheme

Edit `static/terminal.css` to switch between green and amber terminals:

**Green Terminal (default):**
```css
--primary-bg: #0a0a0a;
--primary-fg: #33ff33;
--secondary-fg: #00cc00;
--dim-fg: #006600;
--glow-color: rgba(51, 255, 51, 0.4);
```

**Amber Terminal:**
```css
--primary-bg: #0a0a0a;
--primary-fg: #ffb000;
--secondary-fg: #ff9500;
--dim-fg: #805500;
--glow-color: rgba(255, 176, 0, 0.4);
```

### Personal Information

Edit `config.toml` to update:
- Your name and bio
- Social media links
- Terminal footer message
- Site title and URL

### Content

- Add blog posts in `content/blog/`
- Each post should have frontmatter with title, date, and optional tags
- Use markdown for content

Example post frontmatter:
```toml
+++
title = "My Post Title"
date = 2026-01-12
description = "A short description"

[taxonomies]
tags = ["tag1", "tag2"]
+++
```

## Directory Structure

```
.
├── config.toml          # Site configuration
├── content/             # Your content
│   ├── _index.md       # Homepage content
│   └── blog/           # Blog posts
│       ├── _index.md   # Blog section config
│       └── *.md        # Individual posts
├── static/             # Static files
│   ├── terminal.css    # Main theme styles
│   └── terminal.js     # Interactive features
└── templates/          # HTML templates
    ├── base.html       # Base template
    ├── index.html      # Homepage
    ├── blog.html       # Blog listing
    └── page.html       # Individual post
```

## Keyboard Shortcuts

- `Ctrl+H`: Go to homepage
- `Ctrl+L`: Go to blog listing
- `ESC`: Return to homepage

## Optional Enhancements

The theme includes optional features you can enable in `static/terminal.js`:

- Matrix rain background effect
- Boot sequence animation on first visit
- Typing effects for text

## Templates

The theme provides these templates:

- `base.html`: Main layout with terminal window structure
- `index.html`: Homepage with ASCII art and recent posts
- `blog.html`: Blog post listing in terminal style
- `page.html`: Individual blog post view

## Browser Compatibility

Works best in modern browsers. CRT effects use CSS animations and may have reduced performance on older devices.

## Credits

Built with Zola static site generator and a love for retro computing aesthetics.
