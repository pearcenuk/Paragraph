# Styling

Paragraph shows emphasis **without hiding the markers**. This is *not* a
preview: the asterisks stay exactly where you typed them, only dimmed, so the
source is still the source.

## What is shown

- **Bold** and *italic*, and ***both together***
- Underscores work too: __bold__ and _italic_
- ~~Strikethrough~~
- Inline `code`, in a monospaced face

## What is deliberately left alone

Things that merely look like markers are not touched. A file called
some_file_name_here stays upright, 2 * 3 * 4 is arithmetic rather than
emphasis, and a \*literal asterisk\* is literal.

```
Nothing in here is styled:
let a = b * c * d
snake_case_name
```

> A blockquote keeps its arrow, and _emphasis inside it_ still works.
