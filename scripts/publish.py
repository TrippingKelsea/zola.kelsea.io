#!/usr/bin/env python3
"""
Obsidian to Zola Publishing Script

This script syncs content from your flat Obsidian vault to your Zola site.
It uses frontmatter fields to determine content type (blog vs book) and
supports multiple books via the 'book' field.
"""

import os
import sys
import shutil
import re
from pathlib import Path
from datetime import datetime
import argparse


class ObsidianToZola:
    def __init__(self, vault_path, zola_path):
        self.vault_path = Path(vault_path)
        self.zola_path = Path(zola_path)
        self.blog_dest = self.zola_path / "content" / "blog"
        self.content_dest = self.zola_path / "content"

    def parse_frontmatter(self, content):
        """Extract and parse YAML frontmatter, returning frontmatter dict and body"""
        yaml_pattern = r'^---\s*\n(.*?)\n---\s*\n(.*)$'
        match = re.match(yaml_pattern, content, re.DOTALL)

        if not match:
            return {}, content

        yaml_content, body = match.groups()
        frontmatter = {}

        # Simple YAML parser for our needs
        current_key = None
        for line in yaml_content.strip().split('\n'):
            line = line.strip()
            if not line or line.startswith('#'):
                continue

            if ':' in line and not line.startswith('-'):
                key, value = line.split(':', 1)
                key = key.strip()
                value = value.strip()

                # Normalize field names: lowercase and replace hyphens with underscores
                # This handles both "Book-Title" and "book_title" formats
                key_normalized = key.lower().replace('-', '_')

                # Handle arrays
                if value.startswith('[') and value.endswith(']'):
                    # Parse inline array
                    value = value[1:-1].split(',')
                    value = [v.strip().strip('"').strip("'") for v in value]
                    frontmatter[key_normalized] = value
                elif not value:
                    # Multi-line array
                    current_key = key_normalized
                    frontmatter[key_normalized] = []
                else:
                    # Simple value
                    value = value.strip('"').strip("'")
                    frontmatter[key_normalized] = value
            elif line.startswith('-') and current_key:
                # Array item
                value = line[1:].strip().strip('"').strip("'")
                frontmatter[current_key].append(value)

        return frontmatter, body

    def determine_content_type(self, frontmatter):
        """Determine if content is blog post or book chapter based on frontmatter"""
        # Check for blog-specific site field FIRST (before type check)
        # This allows filtering blog posts by site even if type=blogpost
        if 'blog_site' in frontmatter:
            blog_site = frontmatter['blog_site'].lower()
            if blog_site == 'kelsea.io':
                return 'blog'
            else:
                # Skip posts for other blog sites
                return None

        # Check for explicit type field (accepts 'blogpost' or 'blog')
        if 'type' in frontmatter:
            content_type = frontmatter['type']
            if content_type in ('blogpost', 'blog'):
                return 'blog'
            return content_type

        # Check for book field (indicates book chapter)
        # Handles both 'book_title' (from Book-Title) and 'book'
        if 'book_title' in frontmatter or 'book' in frontmatter:
            return 'book'

        # Check for book-specific fields
        if 'weight' in frontmatter or 'chapter_number' in frontmatter:
            return 'book'

        # Check for publish_to field
        if 'publish_to' in frontmatter:
            return frontmatter['publish_to']

        # Default to blog
        return 'blog'

    def get_book_slug(self, frontmatter):
        """Get the book slug from frontmatter, defaulting to 'default'"""
        # Check both 'book_title' (from Book-Title) and 'book' field
        book = frontmatter.get('book_title') or frontmatter.get('book', 'default')
        # Convert to slug-friendly format
        slug = book.lower().replace(' ', '-').replace('_', '-')
        # Remove any non-alphanumeric characters except hyphens
        slug = re.sub(r'[^a-z0-9-]', '', slug)
        return slug

    def should_publish(self, frontmatter):
        """Check if content should be published based on frontmatter"""
        # Check publish field - DEFAULT TO FALSE (opt-in publishing)
        publish = frontmatter.get('publish', 'false')
        if isinstance(publish, str):
            return publish.lower() in ('true', 'yes', '1')
        return bool(publish)

    def read_existing_file(self, file_path):
        """Read existing published file and extract frontmatter and content"""
        if not file_path.exists():
            return None, None

        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()

            # Parse TOML frontmatter
            toml_pattern = r'^\+\+\+\s*\n(.*?)\n\+\+\+\s*\n(.*)$'
            match = re.match(toml_pattern, content, re.DOTALL)

            if not match:
                return None, None

            toml_content, body = match.groups()

            # Extract date and updated fields from TOML
            existing_data = {}
            for line in toml_content.strip().split('\n'):
                if line.startswith('date ='):
                    date_match = re.search(r'date = "([^"]+)"', line)
                    if date_match:
                        existing_data['date'] = date_match.group(1)
                elif line.startswith('updated ='):
                    updated_match = re.search(r'updated = "([^"]+)"', line)
                    if updated_match:
                        existing_data['updated'] = updated_match.group(1)

            return existing_data, body.strip()

        except Exception as e:
            print(f"  ⚠️  Error reading existing file: {e}")
            return None, None

    def convert_yaml_to_toml_frontmatter(self, frontmatter, existing_data=None, filename=None):
        """Convert frontmatter dict to TOML format"""
        from datetime import datetime

        toml_lines = []

        # Separate fields into sections
        main_fields = {}
        taxonomy_fields = {}
        extra_fields = {}

        # Ensure title exists - use chapter_title, filename, or existing title
        if 'title' not in frontmatter:
            if 'chapter_title' in frontmatter:
                main_fields['title'] = frontmatter['chapter_title']
            elif filename:
                # Use filename without extension as title
                main_fields['title'] = filename.replace('.md', '')
            else:
                main_fields['title'] = 'Untitled'

        # Use chapter_number as weight if no weight specified
        if 'weight' not in frontmatter and 'chapter_number' in frontmatter:
            try:
                main_fields['weight'] = int(frontmatter['chapter_number'])
            except (ValueError, TypeError):
                pass

        # Handle date field - preserve from existing file or use new date
        if 'date' not in frontmatter:
            if existing_data and 'date' in existing_data:
                # Preserve original publish date from existing file
                main_fields['date'] = existing_data['date']
            elif 'publish_date' in frontmatter:
                # Use explicit Publish-Date field if provided
                publish_date_value = frontmatter['publish_date']
                # Extract just date part if it includes time
                if isinstance(publish_date_value, str) and len(publish_date_value) >= 10:
                    main_fields['date'] = publish_date_value[:10]
                else:
                    main_fields['date'] = str(publish_date_value)
            else:
                # Use today's date as the publish date for new files
                main_fields['date'] = datetime.now().strftime('%Y-%m-%d')

        # Add updated field if this is an update to existing file
        if existing_data and 'date' in existing_data:
            # File exists, add updated timestamp
            main_fields['updated'] = datetime.now().strftime('%Y-%m-%d %H:%M:%S')

        for key, value in frontmatter.items():
            # Skip internal fields
            if key in ('publish', 'type', 'publish_to', 'blog_site'):
                continue

            # Tags go in taxonomies section
            # Support both 'tags' and 'blog_tags' (blog_tags takes precedence)
            if key == 'blog_tags':
                taxonomy_fields['tags'] = value
            elif key == 'tags' and 'tags' not in taxonomy_fields:
                taxonomy_fields[key] = value
            # Book-specific fields go in extra section (created is kept, publish_date is skipped since it's used for date)
            elif key in ('chapter_number', 'chapter_title', 'status', 'book', 'book_title', 'created', 'publish_date'):
                # Skip publish_date as it's already used for the main date field
                if key != 'publish_date':
                    extra_fields[key] = value
            # Standard fields stay in main section
            elif key in ('title', 'date', 'description', 'weight'):
                # Skip if already added above
                if key not in main_fields:
                    main_fields[key] = value
            else:
                # Other fields go to extra
                extra_fields[key] = value

        # Build TOML
        for key, value in main_fields.items():
            if isinstance(value, list):
                formatted = '["' + '", "'.join(value) + '"]'
                toml_lines.append(f'{key} = {formatted}')
            elif isinstance(value, bool):
                toml_lines.append(f'{key} = {str(value).lower()}')
            elif isinstance(value, (int, float)):
                toml_lines.append(f'{key} = {value}')
            else:
                toml_lines.append(f'{key} = "{value}"')

        # Add taxonomies section if needed
        if taxonomy_fields:
            toml_lines.append('')
            toml_lines.append('[taxonomies]')
            for key, value in taxonomy_fields.items():
                if isinstance(value, list):
                    formatted = '["' + '", "'.join(value) + '"]'
                    toml_lines.append(f'{key} = {formatted}')

        # Add extra section if needed
        if extra_fields:
            toml_lines.append('')
            toml_lines.append('[extra]')
            for key, value in extra_fields.items():
                if isinstance(value, list):
                    formatted = '["' + '", "'.join(value) + '"]'
                    toml_lines.append(f'{key} = {formatted}')
                elif isinstance(value, bool):
                    toml_lines.append(f'{key} = {str(value).lower()}')
                elif isinstance(value, (int, float)):
                    toml_lines.append(f'{key} = {value}')
                else:
                    toml_lines.append(f'{key} = "{value}"')

        return '\n'.join(toml_lines)

    def validate_and_process_links(self, content, source_file):
        """Validate markdown links and comment out broken ones"""
        # Pattern to match markdown links: [text](url)
        link_pattern = r'\[([^\]]+)\]\(([^\)]+)\)'

        def check_link(match):
            link_text = match.group(1)
            link_url = match.group(2)

            # Skip external URLs (http/https), email, and anchors
            if link_url.startswith(('http://', 'https://', 'mailto:', '#', '/')):
                return match.group(0)  # Keep as-is

            # Check if it's a relative file reference
            # Try to find the file in the vault
            potential_paths = [
                self.vault_path / link_url,
                self.vault_path / f"{link_url}.md",
                self.vault_path / "attachments" / link_url,
            ]

            file_exists = any(p.exists() for p in potential_paths)

            if not file_exists:
                # Preserve link text as plain text, add HTML comment with broken link info
                print(f"  ⚠️  Broken link found: [{link_text}]({link_url})")
                return f'{link_text}<!-- BROKEN LINK: [{link_text}]({link_url}) -->'

            return match.group(0)

        # Process all markdown links
        content = re.sub(link_pattern, check_link, content)
        return content

    def process_wikilinks(self, content):
        """Convert Obsidian [[wikilinks]] to markdown links"""
        # [[Link]] -> [Link](link)
        content = re.sub(r'\[\[([^\]|]+)\]\]', r'[\1](\1)', content)
        # [[Link|Display]] -> [Display](link)
        content = re.sub(r'\[\[([^\]|]+)\|([^\]]+)\]\]', r'[\2](\1)', content)
        return content

    def process_images(self, content, source_file):
        """Handle Obsidian image embeds and copy images to static folder"""
        # Find all ![[image.png]] style embeds
        image_pattern = r'!\[\[([^\]]+)\]\]'
        images = re.findall(image_pattern, content)

        for image in images:
            # Look for image in attachments folder
            vault_image = self.vault_path / "attachments" / image

            if vault_image.exists():
                static_images = self.zola_path / "static" / "images"
                static_images.mkdir(parents=True, exist_ok=True)
                shutil.copy2(vault_image, static_images / image)

                # Replace Obsidian syntax with markdown
                content = content.replace(f'![[{image}]]', f'![{image}](/images/{image})')
            else:
                print(f"  ⚠️  Image not found: {image}")

        return content

    def create_book_index(self, book_dir, book_slug, book_name, dry_run=False):
        """Create _index.md for a book directory if it doesn't exist"""
        index_file = book_dir / "_index.md"

        if index_file.exists():
            return  # Don't overwrite existing index

        if dry_run:
            print(f"  → Would create book index: {index_file}")
            return

        # Create the index content
        index_content = f'''+++
title = "{book_name}"
sort_by = "weight"
template = "book.html"
page_template = "book-chapter.html"
paginate_by = 100

[extra]
book_title = "{book_name}"
book_subtitle = ""
book_status = "In Progress"
+++

# {book_name}

Book description goes here.
'''

        book_dir.mkdir(parents=True, exist_ok=True)
        with open(index_file, 'w', encoding='utf-8') as f:
            f.write(index_content)

        print(f"  📚 Created book index: {index_file}")

    def publish_file(self, source_file, dry_run=False):
        """Publish a single file from Obsidian to Zola"""
        with open(source_file, 'r', encoding='utf-8') as f:
            content = f.read()

        # Parse frontmatter
        frontmatter, body = self.parse_frontmatter(content)

        # Check if should publish
        if not self.should_publish(frontmatter):
            print(f"⏭️  Skipping (publish=false): {source_file.name}")
            return

        # Determine content type
        content_type = self.determine_content_type(frontmatter)

        # Skip if content type is None (e.g., blog post for different site)
        if content_type is None:
            blog_site = frontmatter.get('blog_site', 'unknown')
            print(f"⏭️  Skipping (blog-site={blog_site}): {source_file.name}")
            return

        # Determine destination
        if content_type == 'book':
            book_slug = self.get_book_slug(frontmatter)
            dest_dir = self.content_dest / "books" / book_slug
            # Check both book_title (from Book-Title) and book field
            book_name = frontmatter.get('book_title') or frontmatter.get('book', 'default')
            type_label = f"📖 book chapter ({book_name})"
        else:
            dest_dir = self.blog_dest
            type_label = "📝 blog post"

        # Determine destination filename first
        dest_file = dest_dir / source_file.name

        # Check if file already exists and read its content
        existing_data, existing_body = self.read_existing_file(dest_file)

        print(f"{type_label}: {source_file.name}")

        # Process content
        body = self.process_wikilinks(body)
        body = self.process_images(body, source_file)
        body = self.validate_and_process_links(body, source_file)

        # Check if content has changed
        if existing_body is not None:
            # Compare processed body with existing (ignoring whitespace differences)
            if body.strip() == existing_body.strip():
                print(f"  ⏭️  No changes detected, skipping update")
                return
            else:
                print(f"  ✏️  Content changed, updating...")

        # Convert frontmatter to TOML (pass existing_data to preserve date, filename for title fallback)
        toml_frontmatter = self.convert_yaml_to_toml_frontmatter(frontmatter, existing_data, source_file.name)

        # Combine into final content
        final_content = f'+++\n{toml_frontmatter}\n+++\n\n{body}'

        if dry_run:
            if existing_data:
                print(f"  → Would update: {dest_file}")
            else:
                print(f"  → Would create: {dest_file}")
            return

        # Write to destination
        dest_dir.mkdir(parents=True, exist_ok=True)

        # Create book index if this is a book chapter and index doesn't exist
        if content_type == 'book':
            self.create_book_index(dest_dir, book_slug, book_name, dry_run)

        with open(dest_file, 'w', encoding='utf-8') as f:
            f.write(final_content)

        if existing_data:
            print(f"  ✓ Updated: {dest_file}")
        else:
            print(f"  ✓ Created: {dest_file}")

    def scan_and_publish(self, dry_run=False, content_type=None, skip_confirmation=False):
        """Scan vault for markdown files and publish them"""
        if not self.vault_path.exists():
            print(f"❌ Vault not found: {self.vault_path}")
            return

        print(f"\n🔄 Scanning vault: {self.vault_path}")
        print("=" * 60)

        # Find all markdown files in vault root (not in subdirectories except attachments)
        md_files = [f for f in self.vault_path.glob("*.md")]

        if not md_files:
            print(f"  No markdown files found in vault root")
            return

        # First pass: collect files that will be published
        files_to_publish = []
        skipped_count = 0

        for md_file in sorted(md_files):
            try:
                with open(md_file, 'r', encoding='utf-8') as f:
                    content = f.read()

                frontmatter, _ = self.parse_frontmatter(content)

                # Skip if publish=false or missing
                if not self.should_publish(frontmatter):
                    skipped_count += 1
                    continue

                # Check content type filter
                file_type = self.determine_content_type(frontmatter)

                # Skip if content type is None (e.g., blog for different site)
                if file_type is None:
                    skipped_count += 1
                    continue

                if content_type and file_type != content_type:
                    continue

                files_to_publish.append((md_file, frontmatter, file_type))

            except Exception as e:
                print(f"❌ Error processing {md_file.name}: {e}")

        # Show preview
        if files_to_publish:
            print(f"\n📋 Found {len(files_to_publish)} file(s) marked for publishing:")
            print("=" * 60)
            for md_file, frontmatter, file_type in files_to_publish:
                if file_type == 'book':
                    book_slug = self.get_book_slug(frontmatter)
                    # Check both book_title (from Book-Title) and book field
                    book_name = frontmatter.get('book_title') or frontmatter.get('book', 'default')
                    dest = f"/content/books/{book_slug}/{md_file.name}"
                    print(f"  📖 {md_file.name} ({book_name})")
                    print(f"     → {dest}")
                else:
                    print(f"  📝 {md_file.name}")
                    print(f"     → /content/blog/{md_file.name}")
        else:
            print(f"\n✓ No files marked for publishing (publish: true)")
            if skipped_count > 0:
                print(f"  Found {skipped_count} files with publish: false")
            return

        # Confirmation prompt (unless dry-run or skip_confirmation)
        if not dry_run and not skip_confirmation:
            print("\n" + "=" * 60)
            response = input("Proceed with publishing? [y/N]: ").strip().lower()
            if response not in ('y', 'yes'):
                print("❌ Publishing cancelled")
                return

        # Actually publish files
        print("\n🚀 Publishing files...")
        print("=" * 60)
        published_count = 0

        for md_file, frontmatter, file_type in files_to_publish:
            try:
                self.publish_file(md_file, dry_run)
                published_count += 1
            except Exception as e:
                print(f"❌ Error publishing {md_file.name}: {e}")

        print(f"\n✓ Published: {published_count} files")
        if skipped_count > 0:
            print(f"⏭️  Skipped (no publish: true): {skipped_count} files")


def main():
    parser = argparse.ArgumentParser(
        description="Publish content from flat Obsidian vault to Zola site with multi-book support",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
How it works:
  The script scans your vault root for .md files and uses frontmatter to
  determine where to publish:

  Content Type Detection (in order of priority):
    1. type: "blog" or type: "book" in frontmatter
    2. publish_to: "blog" or publish_to: "book" in frontmatter
    3. Has 'book' field → book chapter (goes to /content/books/{book-slug}/)
    4. Has 'weight' or 'chapter_number' field → book chapter (default book)
    5. Otherwise → blog post

  Multi-Book Support (nested under /books/):
    - book: "My First Book" → /content/books/my-first-book/
    - book: "Second Book" → /content/books/second-book/
    - No book field → /content/books/default/ (default book)

  Publishing Control (OPT-IN):
    - publish: true (or yes/1) → publishes file
    - publish: false (or no/0) → skips file
    - No publish field → SKIPS (safe default)

Examples:
  # Publish all files marked for publishing
  %(prog)s --vault ~/Obsidian/Notes

  # Publish only blog posts
  %(prog)s --vault ~/Obsidian/Notes --type blog

  # Publish only book chapters (all books)
  %(prog)s --vault ~/Obsidian/Notes --type book

  # Dry run (preview without copying)
  %(prog)s --vault ~/Obsidian/Notes --dry-run

Frontmatter Examples:

  Blog Post:
    ---
    title: "My Post"
    date: 2026-01-12
    tags: [tech, tutorial]
    publish: true
    ---

  Book Chapter (Default Book):
    ---
    title: "Chapter 1"
    date: 2026-01-12
    weight: 1
    chapter_number: 1
    status: "Complete"
    publish: true
    ---
    → Goes to /content/books/default/

  Book Chapter (Specific Book):
    ---
    title: "Chapter 1"
    date: 2026-01-12
    book: "My First Book"
    weight: 1
    chapter_number: 1
    status: "Complete"
    publish: true
    ---
    → Goes to /content/books/my-first-book/

  Another Book:
    ---
    title: "Introduction"
    date: 2026-01-12
    book: "Second Book"
    weight: 1
    chapter_number: 1
    publish: true
    ---
    → Goes to /content/books/second-book/
        """
    )

    parser.add_argument(
        '--vault',
        required=True,
        help='Path to your Obsidian vault'
    )

    parser.add_argument(
        '--zola',
        default='.',
        help='Path to your Zola site (default: current directory)'
    )

    parser.add_argument(
        '--type',
        choices=['blog', 'book'],
        help='Only publish specific content type (blog or book)'
    )

    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Preview changes without actually copying files'
    )

    parser.add_argument(
        '--yes', '-y',
        action='store_true',
        help='Skip confirmation prompt and publish immediately'
    )

    args = parser.parse_args()

    publisher = ObsidianToZola(args.vault, args.zola)
    publisher.scan_and_publish(args.dry_run, args.type, args.yes)

    print("\n✅ Publishing complete!")

    if not args.dry_run:
        print("\nNext steps:")
        print("  1. Create _index.md for each book folder if needed")
        print("  2. Review the changes: zola serve")
        print("  3. Build for production: zola build")


if __name__ == "__main__":
    main()
