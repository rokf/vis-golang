local info = function (cmd, fmt, ...)
	vis:info(string.format("vis-golang: [%s] %s", cmd, string.format(fmt, ...)))
end

vis:command_register('godef', function (argv, force, win, selection, range)
	if win.syntax ~= "go" then
		info("godef", "file is not a go file")
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
		if force then
			vis:command(string.format("split %s", path))
		end
	end

	info("godef", type_info)

	if force then
		vis.win.selection:to(line, column)
	end

	return true
end)

local formatter_f = function (name, cmd, win, range)
	if win.syntax ~= "go" then
		info(name, "file is not a go file")
		return true
	end
	
	local status, output, err = vis:pipe(win.file, range, cmd)
	
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
	end

	info(name, "OK")
	
	return true
end

vis:command_register('gofmt', function (argv, force, win, selection, range)
	return formatter_f("gofmt", "gofmt -s", win, range)
end)

vis:command_register('goimports', function (argv, force, win, selection, range)
	local command = "goimports"
	local local_flag = os.getenv("GOIMPORTS_LOCAL")
	if local_flag ~= nil and #local_flag ~= 0 then
		command = command .. " -local " .. local_flag
	end
	return formatter_f("goimports", command, win, range)
end)

vis:command_register('gotest', function (argv, force, win, selection, range)
	if win.syntax ~= "go" then
		info("gotest", "file is not a go file")
		return true
	end

	local found_at = string.find(win.file.name, "/%a+_test%.go")
	if found_at == nil then
		info("gotest", "file is not a test file")
		return true
	end

	local flags = os.getenv("GOTEST_FLAGS") or ""

	local package_path = string.format("./%s", string.sub(win.file.name, 1, found_at))

	local command = string.format("go test %s %s", package_path, flags)

	local file = io.popen(command)
	local output = file:read("*all")
	local success, msg, status = file:close()

	vis:feedkeys("<vis-redraw>")

	-- something is wrong
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

