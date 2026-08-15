# Image resources

## Emoji icons

The `emoji-*.png` files are from [OpenMoji](https://openmoji.org)
(color set, 72x72). Status icons are resized to 36x36 with `sips` for
crisp rendering at UI sizes; icons added since (gear, headphone,
package, folder, spreadsheet, csv, wav) keep the original 72x72. License: [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/).

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