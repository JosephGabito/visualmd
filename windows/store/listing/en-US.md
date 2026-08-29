# Visual MD — Microsoft Store listing

This file is the reviewed English source for fields copied into Partner Center.
It is not imported into the application package.

## Short description

Read folders of Markdown as one quiet, searchable library.

## Description

Your tools and AI agents write more Markdown than ever: READMEs, plans, notes,
specifications, and reports. Reading all of it in cramped preview panes or
editor chrome gets tiring.

Visual MD gives those documents a room of their own. Open one Markdown file or
choose a folder, and every Markdown document inside—nested folders included—is
arranged on a shelf. Pick a document, read it on a measured page, search when
you need something, and use the outline to move through long files.

The reading experience is the product. Visual MD bundles its typefaces, adapts
to light and dark themes, renders code, tables, mathematics, Mermaid diagrams,
images, and footnotes, and keeps the interface out of your way.

Your documents remain on your device. Visual MD has no account, subscription,
advertising, analytics, or document-upload service. It reads only files and
folders you choose. Remote images and links in a document can still contact the
destinations written by that document.

## Features

Enter each line as one feature; Partner Center adds the bullets.

- Open one Markdown file or an entire folder
- Browse nested folders on a clean document shelf
- Search the current document or the whole library
- Navigate long documents from their heading outline
- Read code, tables, math, Mermaid diagrams, images, and footnotes
- Choose bundled reading faces, size, paragraph style, and themes
- Save portable workspaces and reconnect sources on another computer
- Keep documents local with no account or upload service

## Search terms

markdown reader, markdown viewer, readme viewer, documentation reader,
local-first, md reader, developer documentation

## Version 1.0.0 notes

The first Windows release of Visual MD: open Markdown files or folders, browse
them as a library, search, navigate by heading, choose a reading theme, and save
portable workspaces.

## URLs and contact

- Website: https://visualmd.gabi.to/
- Support: https://visualmd.gabi.to/support/
- Privacy: https://visualmd.gabi.to/privacy/
- Support email: support@visualmd.gabi.to

## Certification notes

Visual MD is a local-first desktop reader for user-selected Markdown files and
folders. No login, demo account, payment, subscription, cloud service, or
network connection is required for its core functionality.

Typical review path: launch the app; open the bundled sample; use the left
shelf and right heading outline; choose Open Folder from the Visual MD menu;
select a folder containing `.md` files; open and search a document; optionally
save a workspace. The reviewer may use any Markdown folder.

The package declares `runFullTrust` because Flutter runs as a packaged classic
Win32 desktop application. This capability launches the desktop host; it does
not grant broad filesystem access. Visual MD accesses documents only after the
user selects or drops them. It declares no `broadFileSystemAccess` or Internet
capability.

## Screenshot plan

Partner Center requires at least one 1366 × 768 or larger desktop screenshot;
four or more are recommended. Capture the real Windows app, without marketing
text overlaid, in this order:

1. Sample library open with shelf, reading page, and outline visible.
2. A user-selected folder with nested Markdown documents.
3. Whole-library search results beside the open document.
4. A dark reading theme showing code, a diagram, or mathematics.

Suggested captions:

1. Read every Markdown file in one calm library.
2. Open a folder and keep its structure on the shelf.
3. Search across the documents you chose.
4. Choose the reading environment that suits the work.
