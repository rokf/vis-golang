local err_filetype = "file is not a go file"

local info = function (cmd, fmt, ...)
	vis:info(string.format("vis-golang: [%s] %s", cmd, string.format(fmt, ...)))
end

vis:command_register('gout', function (argv, force, win, selection, range)
	if win.syntax ~= "go" then
		info("gout", err_filetype)
		return true
	end

	local lines = win.file.lines

	local matching = {}
	
	for i=1, #lines do
		if string.match(lines[i], "type ") or string.match(lines[i], "func ") then
			table.insert(matching, string.format("%-5d %s", i, lines[i]))
		end
	end

	local fzf = io.popen(string.format(
		"echo '%s' | fzf --no-sort --tac",
		table.concat(matching, "\n")
	))
	local out = fzf:read()
	local success, msg, status = fzf:close()

	if status == 0 then
		local line_number = string.match(out, "^(%d+)%s+")
		if line_number ~= nil then
			selection:to(line_number, 1)
		end
	elseif status ~= 130 then -- not exit
		info("gout", "error running fzf %s", msg)
	end
end)

-- is the existing layout vertical or horizontal
local is_vertical = function (width, height)
	return width > height * 2
end

-- decide whether to split window vertically or horizontally
local split_or_vsplit = function (width, height)
	if is_vertical(width, height) then
		return "vsplit"
	end

	return "split"
end

-- check if the file path is already open in some window
-- and return the relevant window or nil
local path_window = function (path)
	for w in vis:windows() do
		if w.file.path == path then
			return w
		end
	end

	return nil
end

vis:command_register('goswap', function (argv, force, win, selection, range)
	local whoami = "goswap"
	
	if win.syntax ~= "go" then
		info(whoami, err_filetype)
		return true
	end

	local file = win.file

	if file.path == nil then
		info(whoami, "file is not named")
		return true
	end

	local suffix_replacement
	if string.match(file.name, "_test.go$") then
		suffix_replacement = string.sub(file.name, 1, -9) .. ".go"
	else
		suffix_replacement = string.sub(file.name, 1, -4) .. "_test.go"
	end

	local ind1 = file.path:find(file.name, 1, true)
	local new_path = file.path:sub(1, ind1 - 1) .. suffix_replacement

	local w = path_window(new_path)
	if w then
		vis.win = w
		return true
	end

	if not vis:command(string.format("%s %s", force and "e" or split_or_vsplit(win.width, win.height), new_path)) then
		info(whoami, "couldn't swap")
	end

	return true
end)

vis:command_register('godef', function (argv, force, win, selection, range)
	if win.syntax ~= "go" then
		info("godef", err_filetype)
		return true
	end

	local file = win.file
	
	local pos = selection.pos

	local command = string.format("godef -i -t -o %d -f %s", pos, file.name)

	local status, output, err = vis:pipe(file, {
		start = 0,
		finish = file.size,
	}, command)
	
	if status ~= 0 or not output then
		info("godef", "error running godef %s", err)
		return true
	end

	local path, line, column, type_info = string.match(output, "([^:]+):([^:]+):([^:\n]+)\n(.+)")

	if not path then
		-- the output doesn't contain the file path, it's relative
		line, column, type_info = string.match(output, "([^:]+):([^:\n]+)\n(.+)")
	else
		if force and string.find(file.path, path, 1, true) == nil then
			-- path is not the current file.path, the symbol is defined in a different file
			local existing_window = path_window(path)
			if existing_window then
				-- the window with the definition is already open, switch to it
				vis.win = existing_window
			else
				vis:command(string.format("%s %s", split_or_vsplit(win.width, win.height), path))
			end
		end
	end

	if force then
		vis.win.selection:to(line, column)
	else
		info("godef", type_info)
	end

	return true
end)

local formatter_f = function (name, cmd, win, range, selection, force)
	if win.syntax ~= "go" then
		info(name, err_filetype)
		return true
	end
	
	local status, output, err = vis:pipe(win.file, range, cmd)

	-- get current position
	local line = selection.line
	
	if status ~= 0 or not output then
		info(name, "error running %s (%s)", cmd, err)
		return true
	end

	if not win.file:delete(range) then
		info(name, "couldn't delete range")
		return true
	end
	
	if not win.file:insert(range.start, output) then
		info(name, "couldn't insert formatted content")
		return true
	end

	if force then
		if not vis:command("w") then
			info(name, "couldn't write changes to file")
			return true
		end
	end

	-- approximately restore position
	selection:to(line, 1)
	
	info(name, "OK")
	
	return true
end

vis:command_register('gofmt', function (argv, force, win, selection, range)
	return formatter_f("gofmt", "gofmt -s", win, range, selection, force)
end)

vis:command_register('goimports', function (argv, force, win, selection, range)
	local command = "goimports"
	local local_flag = os.getenv("GOIMPORTS_LOCAL")
	if local_flag ~= nil and #local_flag ~= 0 then
		command = command .. " -local " .. local_flag
	end
	return formatter_f("goimports", command, win, range, selection, force)
end)

vis:command_register('gotest', function (argv, force, win, selection, range)
	if win.syntax ~= "go" then
		info("gotest", err_filetype)
		return true
	end

	local found_at = string.find(win.file.name, "/%a+_test%.go")
	if found_at == nil then
		info("gotest", "file is not a test file")
		return true
	end

	local flags = os.getenv("GOTEST_FLAGS") or ""

	if force then
		if selection.pos == nil then
			info("gotest", "invalid selection state")
			return true
		end
		
		local content = win.file:content(win.file:text_object_word(selection.pos))
		if string.match(content, "^Test") then
			flags = string.format("%s -run %s", flags, content)
		else
			info("gotest", "word at cursor is not an exported test identifier")
			return true
		end
	end

	local package_path = string.format("./%s", string.sub(win.file.name, 1, found_at))

	local command = string.format("go test %s %s 2>&1", package_path, flags)

	local file = io.popen(command)
	local output = file:read("*all")
	local success, msg, status = file:close()

	if status ~= 0 then
		info("gotest","'%s' (status %d) FAILED", command, status)

		if not vis:command(is_vertical(win.width, win.height) and "vnew" or "new") then
			info("gotest","failed opening empty buffer")
			return true
		end

		if not vis.win.file:insert(0, output) then
			info("gotest", "failed inserting failure report")
		end

		return true
	else
		info("gotest", "%s OK", command)
	end
		
	return true
end)