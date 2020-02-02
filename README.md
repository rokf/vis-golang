# vis-golang

A Go plugin for the [Vis](https://github.com/martanne/vis) editor.

Inspired by [vis-go](https://gitlab.com/timoha/vis-go) but with a slightly different set of features.

## Features

It contains a `godef` command. It displays type information of the symbol at the current cursor location in the info line (bottom).

If forced (with `!` suffix) it will also open the source file and position the cursor at the definition in a `split` window.

The second feature is `gofmt` integration. There's a `gofmt` command that replaces the current range with its formatted version.

The third feature is `go test` integration. A `gotest` command has been added that runs the package tests in the package that the current active file is located in. In case of failure a no-name buffer with the report content will be opened.

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
