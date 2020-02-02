local info = function (fmt, ...)
	vis:info("vis-golang: " .. string.format(fmt, ...))
end

vis:command_register('godef', function (argv, force, win, selection, range)
	if win.syntax ~= "go" then
		info("file is not a go file")
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
		info("error running godef %s", err)
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

	info(type_info)

	if force then
		vis.win.selection:to(line, column)
	end

	return true
end)

vis:command_register('gofmt', function (argv, force, win, selection, range)
	if win.syntax ~= "go" then
		info("file is not a go file")
		return true
	end
	
	local status, output, err = vis:pipe(win.file, range, "gofmt -s")
	
	if status ~= 0 or not output then
		info("error running gofmt -s (%s)", err)
		return true
	end

	if not win.file:delete(range) then
		info("couldn't delete range")
		return true
	end
	
	if not win.file:insert(range.start, output) then
		info("couldn't insert formatted content")
	end
	
	return true
end)

