local info = function (cmd, fmt, ...)
	vis:info(string.format("vis-golang: [%s] %s", cmd, string.format(fmt, ...)))
end

local err_filetype = "file is not a go file"

vis:command_register('gout', function (argv, force, win, selection, range)
	if win.syntax ~= "go" then
		info("gout", err_filetype)
		return true
	end

	local lines = win.file.lines

	local matching = {}
	
	for i=1, #lines do
		if string.match(lines[i], "type ") or string.match(lines[i], "func ") then
			table.insert(matching, string.format("%d: %s", i, lines[i]))
		end
	end

	local fzf = io.popen(string.format("echo '%s' | fzf", table.concat(matching, "\n")))
	local out = fzf:read()
	local success, msg, status = fzf:close()

	if status == 0 then
		local line_number = string.match(out, "^(%d+):")
		if line_number ~= nil then
			selection:to(line_number, 1)
		end
	elseif status ~= 130 then -- not exit
		info("gout", "error running fzf %s", msg)
	end
end)

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

	local new_path = string.gsub(file.path, file.name, suffix_replacement)

	-- check if new_path is already open in some window
	for win in vis:windows() do
		if win.file.path == new_path then
			-- switch to the existing window
			vis.win = win
			return true
		end
	end
	
	if not vis:command(string.format("%s %s", force and "e" or "split", new_path)) then
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
		line, column, type_info = string.match(output, "([^:]+):([^:\n]+)\n(.+)")
	else
		if force and path ~= file.path then
			vis:command(string.format("split %s", path))
		end
	end

	info("godef", type_info)

	if force then
		vis.win.selection:to(line, column)
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

	local package_path = string.format("./%s", string.sub(win.file.name, 1, found_at))

	local command = string.format("go test %s %s 2>&1", package_path, flags)

	local file = io.popen(command)
	local output = file:read("*all")
	local success, msg, status = file:close()

	if status ~= 0 then
		info("gotest","'%s' (status %d) FAILED", command, status)

		if not vis:command("new") then
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

