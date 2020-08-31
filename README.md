# vis-golang

A Go plugin for the [Vis](https://github.com/martanne/vis) editor.

Inspired by [vis-go](https://gitlab.com/timoha/vis-go) but with a slightly different set of features.

## Features

It contains a `godef` command. It displays type information of the symbol at the current cursor location in the info line (bottom).

If forced (with `!` suffix) it will also open the source file and position the cursor at the definition in a `split` window.

The second feature is formatter integration. There are `gofmt` and `goimports` commands that replace the current range with its formatted version. If forced (with `!` suffix) they'll try writing to the file at the end (execute `w`).

- `gofmt` runs with the `-s` (simplify code) flag
- `goimports` `-local` flag can be set through a `GOIMPORTS_LOCAL` environment variable

The third feature is `go test` integration. A `gotest` command has been added that runs the package tests in the package that the current active file is located in. In case of failure a no-name buffer with the report content will be opened.

`gotest` looks for a `GOTEST_FLAGS` environment variable at runtime. If it is present then it appends its content to the end of the `go test` command (useful together with `direnv` for example).

The fourth feature is a `gout` command (go outline). It opens `fzf` with a list of lines containing type or function definitions of the current file. When an entry is chosen the cursor appears on the line of its definition.

The fifth feature is a `goswap` command which swaps the currently open file with its counterpart (test/implementation). Lets say that you're working on a file named `abc.go`, `goswap` will try to open `abc_test.go` in a split window and vice versa. If forced (with `!` suffix) it will replace the file in the current window instead of splitting. In case that the counterpart is already open in one of the other unfocused windows the focus will move to it.

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
