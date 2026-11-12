<p align="center">
  <img src="Assets/AppIcon.png" alt="MarkyMark app icon" width="144">
</p>

<h1 align="center">MarkyMark</h1>

<p align="center"><strong>Good reads. Plain text. A little Markdown magic.</strong></p>

<p align="center">
  A small, read-only Markdown viewer for macOS, built with SwiftUI and WebKit.<br>
  Drop in a file, settle in, and let your words do the talking.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-13%2B-111827?logo=apple&logoColor=white" alt="macOS 13 or later">
  <img src="https://img.shields.io/badge/Swift-5.9%2B-F05138?logo=swift&logoColor=white" alt="Swift 5.9 or later">
  <img src="https://img.shields.io/badge/SwiftUI-%2B%20WebKit-2563EB" alt="Built with SwiftUI and WebKit">
</p>

---

## Markdown, dressed for the Mac

- **Drop it like it's Markdown.** Drag a file into the window, open it from Finder, or hit **⌘O**.
- **All the good formatting.** Headings, lists, tables, blockquotes, code blocks, links, and images.
- **Light or dark, naturally.** The reader follows your system appearance.
- **Terminal soul.** Bundled JetBrains Mono Nerd Font, green and cyan accents, and crisp code panels. No font installation needed.
- **Local files, local reading.** Markdown rendering works offline, with the parser and sanitizer bundled into the app. Remote images need a connection.
- **Follow the thread.** Relative Markdown links open in the viewer; web links open in your browser.
- **Your editor's reading companion.** Edit in your favourite app, then press **⌘R** to refresh the view.

## Up and reading

You'll need **macOS 13+** and a **Swift 5.9+ toolchain** (Xcode or the Xcode Command Line Tools).

```sh
git clone https://github.com/pyrat/markymark.git
cd markymark
bash scripts/build-app.sh
open dist/MarkyMark.app
```

The build script creates a release app bundle and signs it locally. Drag `dist/MarkyMark.app` into **Applications** to keep it handy.

### Make it your Markdown sidekick

In Finder, right-click a `.md` or `.markdown` file and choose **Open With → MarkyMark**.
To make it the default, choose **Get Info → Open with → MarkyMark → Change All**.

## The controls

| Action | How |
| --- | --- |
| Open a file | **⌘O**, the folder button, or drag and drop |
| Reload after editing | **⌘R** |
| Export as PDF | **⇧⌘E**, File → Export as PDF, or the export button |
| Open a linked Markdown file | Click a relative Markdown link |
| Open a web link | Click to launch your browser |

Relative images load from the document's directory and its subdirectories. Keep linked documents and images alongside your Markdown files for a portable reading setup.

PDF exports preserve the reader’s current light/dark appearance, bundled font, and layout at the window’s width. The full document is saved as one continuous PDF page.

## Under the hood

**SwiftUI** handles the native window and controls. **WebKit** renders the reading view, with bundled **Marked** parsing Markdown and **DOMPurify** sanitizing HTML.

```text
Sources/MarkyMark/         App, renderer, and bundled web resources
Tests/MarkyMarkTests/      Rendering tests
Assets/                   App icon
scripts/                  App packaging and icon generation
```

For development, open `Package.swift` in Xcode or run:

```sh
swift run
```

Run the tests:

```sh
swift test
```

Regenerate the app icon from its vector drawing:

```sh
swift scripts/generate-icon.swift
```

## License & credits

MarkyMark is released under the [MIT License](LICENSE). Bundled third-party libraries retain their own licenses:

- [Marked 17.0.1](https://github.com/markedjs/marked) — MIT; [bundled license](Sources/MarkyMark/Resources/Marked-LICENSE.txt).
- [DOMPurify 3.3.0](https://github.com/cure53/DOMPurify) — Apache-2.0 or MPL-2.0; [bundled licenses](Sources/MarkyMark/Resources/DOMPurify-LICENSE.txt).
- [JetBrains Mono Nerd Font](https://www.nerdfonts.com/) — bundled from Nerd Fonts v3.4.0, SIL Open Font License 1.1; [bundled license](Sources/MarkyMark/Resources/JetBrainsMono-LICENSE.txt).

---

<p align="center"><em>Made for reading the README. And everything after it.</em></p>
