# Image resources

## Emoji icons

The `emoji-*.png` files are from [OpenMoji](https://openmoji.org)
(color set). License: [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/).

To add an icon:

1. Save the 72x72 OpenMoji PNG here as `emoji-<name>.png`. No resizing
   is needed: `EmojiText` scales icons to the text line height when
   drawing. (The original status icons - accepted, check, error,
   hourglass, pin, progress, rejected, search, stopped, warning - were
   downscaled to 36x36 with `sips` before this was the case; either
   size works.)
2. Run `make` in this directory to generate the matching `.lua` file
   (see "How to build" below).
3. Register the tag in the `EmojiText.ICONS` table
   (`source/ui/EmojiText.lua`) so `:<name>:` renders it.

## How to build

Using WSL/Ubuntu on Windows, or Ubuntu Linux:
```sh
    sudo apt install ruby ruby-chunky-png
    make
```

Using RubyGems:
```sh
    sudo gem install chunky_png
    make
```