# vis-golang

A [Go](https://golang.org/) plugin for the [Vis](https://github.com/martanne/vis) editor.

Inspired by [vis-go](https://gitlab.com/timoha/vis-go) but with a slightly different set of features.

## Commands

### `godef[!]`

Displays type information of the symbol at the current cursor position in the info line (bottom). **If forced**, it will open the source file and position the cursor at the definition with respect to the current window layout.

### `gofmt[!]` and `goimports[!]`

The current range is replaced with its formatted version. **If forced**, the changes will be written to disk.

- `gofmt` runs with the `-s` (simplify code) flag
- `goimports`'s `-local` flag can be set through a `GOIMPORTS_LOCAL` environment variable

### `gotest[!]`

Runs `go test` for the currently active file's package. In case of failure a window with the output is opened. The current window layout will be respected.

It looks for a `GOTEST_FLAGS` environment variable at runtime. If it's present then it appends its content to the end of the `go test` command (useful together with `direnv` for example).

**If forced**, only the test under the current cursor possition will be executed. The cursor has to be located on a word matching the `^Test` pattern.

### `gout`

Opens `fzf` with a list of lines containing type or function definitions (outline) of the current file. When an entry is chosen the cursor jumps to its location. If you're looking for the same experience but don't want to be limited to Go I suggest you take a look at [vis-fzf-outline](https://github.com/rokf/vis-fzf-outline).

### `goswap[!]`

Swaps the currently open file with its testing related counterpart (test/implementation). Let's say that you're working on a file named `abc.go`, `goswap` will try to open `abc_test.go` in a split window. **If forced**, it will replace the file in the currently active window instead of splitting. In case that the counterpart is already open in one of the other unfocused windows the focus will move to it. The current window layout should be respected.

## Installation

First clone the repository into your config folder:

```sh
cd ~/.config/vis
git clone https://github.com/rokf/vis-golang
```

Then import the plugin in your `visrc.lua` file:

```lua
require('vis-golang/init')
```

## License

This library is free software; you can redistribute it and/or modify it under the terms of the MIT license. See LICENSE for details.
