-- luacheck: no max line length
-- luacheck: globals console os.isfile NONL
-- luacheck: globals flexprompt

local normal = "\x1b[m"
local bold = "\x1b[1m"
local brightgreen = "\x1b[92m"
local brightyellow = "\x1b[93m"
local static_cursor = "\x1b[7m " .. normal

local _transient
local _striptime
local _timeformat

local clink_prompt_spacing = (settings.get("prompt.spacing") ~= nil)

local function spairs(t, order)
    local keys = {}
    local num = 0
    for k in pairs(t) do
        num = num + 1
        keys[num] = k
    end

    if order then
        table.sort(keys, function(a,b) return order(t, a, b) end)
    else
        table.sort(keys)
    end

    local i = 0
    return function()
        i = i + 1
        if keys[i] then
            return keys[i], t[keys[i]]
        end
    end
end

local function readinput()
    if console.readinput then
        local key = console.readinput()
        return key
    else
        clink.print("\x1b[s", NONL)
        local line = io.read("*l")
        clink.print("\x1b[u\x1b[J", NONL)
        return line
    end
end

local function readchoice(choices)
    if not choices then error("missing choices") end

    repeat
        clink.print("Choice [" .. choices .. "]: ", NONL)
        local s = readinput()
        clink.print("\x1b[G\x1b[K", NONL)

        if not s then -- Happens when resizing the terminal.
            s = ""
        end

        if #s == 1 and string.find(choices, s) then
            return s
        end
    until false
end

local function refresh_width(preview)
    preview.width = console.getwidth() - 10 -- Align with "(1)  <-Here".
end

local function clear_screen()
    clink.print("\x1b[H\x1b[J", NONL)
end

local function get_settings_filename()
    local script_name
    local profile_name

    local force_dir = flexprompt_autoconfig_dir -- luacheck: no global
    if force_dir then
        script_name = path.join(force_dir, "flexprompt_autoconfig.lua")
    end

    if not script_name then
        local info = debug.getinfo(1, 'S')
        if info.source and info.source:sub(1, 1) == "@" then
            local dir = path.toparent(info.source:sub(2))
            if os.isdir(dir) then
                script_name = path.join(dir, "flexprompt_autoconfig.lua")
            end
        end
    end

    local dir = os.getenv("=clink.profile")
    if dir then
        profile_name = path.join(dir, "flexprompt_autoconfig.lua")
    end

    local name = script_name or profile_name
    local delete_name = (script_name ~= profile_name) and profile_name
    if not name then
        error("Unable to write settings; file location unknown.")
    end

    return name, delete_name
end

local function inc_line(line)
    line[1] = line[1] + 1
end

local function order_table(a, b)
    local typea = type(a)
    local typeb = type(b)
    if typea == typeb then
        return a < b
    elseif typea == "number" then
        return true
    elseif typeb == "number" then
        return false
    else
        return tostring(a) < tostring(b)
    end
end

local function write_var(file, line, name, value, indent)
    local t = type(value)
    if not indent then indent = "" end

    local comma = ((#indent > 0) and "," or "")

    if t == "table" then
        if type(name) == "string" then
            file:write(indent .. name .. " =\n")
            inc_line(line)
        end

        file:write(indent .. "{\n")
        inc_line(line)

        for n,v in ipairs(value) do
            write_var(file, line, tonumber(n), v, indent .. "    ")
        end

        for n,v in spairs(value, order_table) do
            if type(n) == "string" then
                write_var(file, line, n, v, indent .. "    ")
            end
        end

        file:write(indent .. "}" .. comma .. "\n")
        inc_line(line)
        return
    end

    if t == "string" then
        value = string.format("%q", value)
    elseif t == "boolean" then
        value = value and "true" or "false"
    elseif t == "number" then
        value = tostring(value)
    else
        local msg
        if type(name) == "string" then
            msg = "flexprompt couldn't write '" .. name .. "' at line " .. line[1] .. "; unknown type '" .. t .. "'."
        else
            msg = "flexprompt couldn't write [" .. name .. "] at line " .. line[1] .. "; unknown type '" .. t .. "'."
        end
        log.info(msg)
        return msg
    end

    if name and tonumber(name) then
        name = ""
    else
        name = name .. " = "
    end

    file:write(indent .. name .. value .. comma .. "\n")
    inc_line(line)
end

local function write_settings(settings)
    local name, delete_name = get_settings_filename()
    local file = io.open(name, "w")
    if not file then
        error("Unable to write settings; unable to write to '" .. name .. "'.")
    end

    file:write("-- WARNING:  This file gets overwritten by the 'flexprompt configure' wizard!\n")
    file:write("--\n")
    file:write("-- If you want to make changes, consider copying the file to\n")
    file:write("-- 'flexprompt_config.lua' and editing that file instead.\n\n")

    -- Avoid errors if flexprompt isn't present or hasn't been initialized yet.
    file:write("flexprompt = flexprompt or {}\n")
    file:write("flexprompt.settings = flexprompt.settings or {}\n")

    local line = { 8 }

    local errors
    for n,v in spairs(settings) do
        if n ~= "wizard" and n ~= "width" then
            local msg = write_var(file, line, "flexprompt.settings."..n, v)
            if msg then
                errors = errors or {}
                table.insert(errors, msg)
            end
        end
    end

    file:close()

    if delete_name then
        os.remove(delete_name)
    end

    if _transient then
        local command = string.format('2>nul >nul "%s" set prompt.transient %s', CLINK_EXE, _transient)
        os.execute(command)
    end

    if clink_prompt_spacing then
        local command = string.format('2>nul >nul "%s" set prompt.spacing %s', CLINK_EXE, settings.spacing)
        os.execute(command)
    end

    return errors
end

local function copy_table(settings)
    local copy = {}
    for n,v in pairs(settings) do
        if type(v) == "table" then
            copy[n] = copy_table(v)
        else
            copy[n] = v
        end
    end
    return copy
end

local function display_callout(row, col, text)
    clink.print("\x1b[s\x1b[" .. row .. ";" .. col .. "H" .. text .. "\x1b[u", NONL)
end

local function display_centered(s)
    local cells = console.cellcount(s)
    local width = console.getwidth()
    if width > 80 then width = 80 end

    if cells < width then
        clink.print(string.rep(" ", (width - cells) / 2), NONL)
    end
    clink.print(s)
end

local function display_title(s)
    display_centered(bold .. s .. normal)
end

local function replace_arg(s, module, arg, value)
    if s:find("{" .. module) then
        local args = s:match("{" .. module .. "(:[^}]*)}")
        value = value and (":" .. arg .. "=" .. value) or ""
        if not args then
            args = value
        elseif args:find(":" .. arg) then
            args = args:gsub(":" .. arg .. "=[^:]*", value)
        else
            args = args .. value
        end
        s = s:gsub("{" .. module .. "[^}]*}", "{" .. module .. args .. "}")
    end
    return s
end

local function apply_time_format(s)
    if not s then return end

    if _striptime then
        s = s:gsub("{time[^}]*}", "")
        s = replace_arg(s, "rbubble", "format", nil)
    elseif _timeformat then
        if _timeformat == "2" then
            s = replace_arg(s, "time", "format", "%%H:%%M:%%S")
            s = replace_arg(s, "rbubble", "format", "%%H:%%M:%%S")
        elseif _timeformat == "3" then
            s = replace_arg(s, "time", "format", "%%a %%H:%%M")
            s = replace_arg(s, "rbubble", "format", "%%a %%H:%%M")
        elseif _timeformat == "4" then
            s = replace_arg(s, "time", "format", "%%I:%%M:%%S %%p")
            s = replace_arg(s, "rbubble", "format", "%%I:%%M:%%S %%p")
        elseif _timeformat == "5" then
            s = replace_arg(s, "time", "format", "%%a %%I:%%M %%p")
            s = replace_arg(s, "rbubble", "format", "%%a %%I:%%M %%p")
        else
            s = replace_arg(s, "time", "format", "")
            s = replace_arg(s, "rbubble", "format", "")
        end
    end
    return s
end

local function replace_modules(s)
    if not s then return end

    s = s:gsub("{histlabel[^}]*}", "")
    s = apply_time_format(s)
    return s
end

local function translate_bubbles(settings, final)
    if settings.style == "bubbles" then
        settings.style = "lean"
        settings.top_prompt = "{tbubble}"
        settings.left_prompt = "{lbubble}"
        settings.right_prompt = "{rbubble}"
        if final then
            settings.right_prompt = apply_time_format(settings.right_prompt)
        end
    end
end

local function display_preview(settings, command, show_cursor, callout)
    local preview = copy_table(settings)
    translate_bubbles(preview)

    if preview.left_prompt then
        preview.left_prompt = replace_modules(preview.left_prompt)
    end
    if preview.right_prompt then
        preview.right_prompt = replace_modules(preview.right_prompt)
    end

    local left, right, col, anchors = flexprompt.render_wizard(preview, callout and true or nil)

    if callout and anchors then
        local x
        if type(callout[2]) == "table" then
            x = anchors[callout[2][1]] + callout[2][2]
        else
            x = anchors[callout[2]]
        end
        display_callout(callout[1], x, callout[3])
    end

    clink.print(left .. normal .. (command or "") .. ((show_cursor ~= false) and static_cursor or ""), NONL)
    if right then
        clink.print("\x1b[" .. col .. "G" .. right .. normal)
    else
        clink.print()
    end
end

local function display_yes(choices, extra)
    clink.print("(y)  Yes.  " .. (extra or "") .. "\n")
    return choices .. "y"
end

local function display_no(choices, extra)
    clink.print("(n)  No.  " .. (extra or "") .. "\n")
    return choices .. "n"
end

local function display_restart(choices)
    clink.print("(r)  Restart from the beginning.")
    return choices .. "r"
end

local function display_quit(choices)
    clink.print("(q)  Quit and do nothing.\n")
    return choices .. "q"
end

local function friendly_case(text)
    if text == "ascii" then return "ASCII" end
    return text:sub(1, 1):upper() .. text:sub(2)
end

local function choose_setting(settings, title, choices_name, setting_name, subset, callout) -- luacheck: no unused
    local choices = ""

    refresh_width(settings)

    clear_screen()
    display_title(title)
    clink.print()

    for index,name in ipairs(subset) do
        if index > 5 then
            break
        end

        choices = choices .. tostring(index)

        clink.print("(" .. index .. ")  " .. friendly_case(name) .. ".\n")

        local preview = copy_table(settings)
        preview[setting_name] = name

        display_preview(preview, nil, nil, callout)
        callout = nil

        clink.print()
    end

    choices = display_restart(choices)
    choices = display_quit(choices)

    local s = readchoice(choices)
    if not s then return end

    if s == "r" then -- luacheck: ignore 542
    elseif s == "q" then -- luacheck: ignore 542
    else
        settings[setting_name] = subset[tonumber(s)]
    end
    return s
end

local function choose_sides(settings, title)
    local choices = "" -- luacheck: ignore 311
    local prompts = flexprompt.choices.prompts[settings.style]
    local withbreaks = flexprompt.choices.prompts["breaks"]
    local preview

    refresh_width(settings)

    clear_screen()
    display_title(title)
    clink.print()

    choices = (settings.style == "rainbow") and "1234" or "12"

    clink.print("(1)  Left.\n")
    preview = copy_table(settings)
    preview.left_prompt = prompts.left[1]
    preview.right_prompt = prompts.left[2]
    display_preview(preview)
    clink.print()

    clink.print("(2)  Both.\n")
    preview = copy_table(settings)
    preview.left_prompt = prompts.both[1]
    preview.right_prompt = prompts.both[2]
    display_preview(preview)
    clink.print()

    if settings.style == "rainbow" then
        clink.print("(3)  Left with breaks between groups of related segments.\n")
        preview = copy_table(settings)
        preview.wizard.exit = 1
        preview.wizard.git = { status={ staged={ modify=3 } } }
        preview.left_prompt = withbreaks.left[1]
        preview.right_prompt = withbreaks.left[2]
        display_preview(preview)
        clink.print()

        clink.print("(4)  Both with breaks between groups of related segments.\n")
        preview = copy_table(settings)
        preview.wizard.exit = 1
        preview.wizard.git = { status={ staged={ modify=3 } } }
        preview.left_prompt = withbreaks.both[1]
        preview.right_prompt = withbreaks.both[2]
        display_preview(preview)
        clink.print()
    end

    choices = display_restart(choices)
    choices = display_quit(choices)

    local s = readchoice(choices)
    if not s then return end

    if s == "r" then -- luacheck: ignore 542
    elseif s == "q" then -- luacheck: ignore 542
    else
        if s == "1" then
            settings.left_prompt = apply_time_format(prompts.left[1])
            settings.right_prompt = apply_time_format(prompts.left[2])
        elseif s == "2" then
            settings.left_prompt = apply_time_format(prompts.both[1])
            settings.right_prompt = apply_time_format(prompts.both[2])
        elseif s == "3" then
            settings.left_prompt = apply_time_format(withbreaks.left[1])
            settings.right_prompt = apply_time_format(withbreaks.left[2])
        elseif s == "4" then
            settings.left_prompt = apply_time_format(withbreaks.both[1])
            settings.right_prompt = apply_time_format(withbreaks.both[2])
        end
        _timeformat = nil
    end
    return s
end

local function choose_time(settings, title)
    local choices = "" -- luacheck: ignore 311
    local preview

    refresh_width(settings)

    clear_screen()
    display_title(title)
    clink.print()

    choices = "12345"

    clink.print("(1)  No.\n")
    preview = copy_table(settings)
    _timeformat = "1"
    display_preview(preview)
    clink.print()

    clink.print("(2)  24-hour format.\n")
    preview = copy_table(settings)
    _timeformat = "2"
    display_preview(preview)
    clink.print()

    clink.print("(3)  24-hour format with day.\n")
    preview = copy_table(settings)
    _timeformat = "3"
    display_preview(preview)
    clink.print()

    clink.print("(4)  12-hour format.\n")
    preview = copy_table(settings)
    _timeformat = "4"
    display_preview(preview)
    clink.print()

    clink.print("(5)  12-hour format with day.\n")
    preview = copy_table(settings)
    _timeformat = "5"
    display_preview(preview)
    clink.print()

    choices = display_restart(choices)
    choices = display_quit(choices)

    local s = readchoice(choices)
    if not s then return end

    if s == "r" then -- luacheck: ignore 542
    elseif s == "q" then -- luacheck: ignore 542
    else
        _timeformat = s
    end
    return s
end

local function choose_frames(settings, title)
    local choices = "" -- luacheck: ignore 311
    local preview

    refresh_width(settings)

    clear_screen()
    display_title(title)
    clink.print()

    choices = "1234"

    clink.print("(1)  No frame.\n")
    preview = copy_table(settings)
    preview.left_frame = "none"
    preview.right_frame = "none"
    display_preview(preview)
    clink.print()

    clink.print("(2)  Left.\n")
    preview = copy_table(settings)
    preview.left_frame = "round"
    preview.right_frame = "none"
    display_preview(preview)
    clink.print()

    clink.print("(3)  Right.\n")
    preview = copy_table(settings)
    preview.left_frame = "none"
    preview.right_frame = "round"
    display_preview(preview)
    clink.print()

    clink.print("(4)  Full.\n")
    preview = copy_table(settings)
    preview.left_frame = "round"
    preview.right_frame = "round"
    display_preview(preview)
    clink.print()

    choices = display_restart(choices)
    choices = display_quit(choices)

    local s = readchoice(choices)
    if not s then return end

    if s == "r" then -- luacheck: ignore 542
    elseif s == "q" then -- luacheck: ignore 542
    else
        settings.left_frame = (s == "1" or s == "3") and "none" or "round"
        settings.right_frame = (s == "1" or s == "2") and "none" or "round"
    end
    return s
end

local function choose_spacing(settings, title)
    local choices = "" -- luacheck: ignore 311

    refresh_width(settings)

    clear_screen()
    display_title(title)
    clink.print()

    choices = "123"

    clink.print("(1)  Normal.\n")
    clink.print("     Normally the prompt doesn't remove or add blank lines.")
    clink.print("     Whatever blank lines already exist are kept.\n")

    clink.print("(2)  Compact.\n")
    clink.print("     Removes any blank lines from the end of the previous")
    clink.print("     command's output.\n")
    display_preview(settings, nil, false)
    display_preview(settings)
    clink.print()

    clink.print("(3)  Sparse.\n")
    clink.print("     Removes any blank lines from the end of the previous")
    clink.print("     command's output, and then inserts one blank line.\n")
    display_preview(settings, nil, false)
    clink.print()
    display_preview(settings)
    clink.print()

    choices = display_restart(choices)
    choices = display_quit(choices)

    local s = readchoice(choices)
    if not s then return end

    if s == "r" then -- luacheck: ignore 542
    elseif s == "q" then -- luacheck: ignore 542
    else
        if s == "2" then
            settings.spacing = "compact"
        elseif s == "3" then
            settings.spacing = "sparse"
        else
            settings.spacing = "normal"
        end
    end
    return s
end

local function choose_icons(settings, title)
    local choices = "" -- luacheck: ignore 311
    local preview

    refresh_width(settings)

    clear_screen()
    display_title(title)
    clink.print()

    choices = "12"

    local few_no = (settings.style == "lean") and "No" or "Few"

    clink.print("(1)  " .. few_no .. " icons.\n")
    preview = copy_table(settings)
    preview.use_icons = nil
    display_preview(preview)
    clink.print()

    clink.print("(2)  Many icons.\n")
    preview = copy_table(settings)
    preview.use_icons = true
    display_preview(preview)
    clink.print()

    if clink.getansihost and clink.getansihost() == "winterminal" then
        choices = choices .. "3"
        clink.print("(3)  Many icons, and use color emoji in Windows Terminal.\n")
        preview = copy_table(settings)
        preview.use_icons = true
        preview.use_color_emoji = true
        display_preview(preview)
        clink.print()
    end

    choices = display_restart(choices)
    choices = display_quit(choices)

    local s = readchoice(choices)
    if not s then return end

    if s == "r" then -- luacheck: ignore 542
    elseif s == "q" then -- luacheck: ignore 542
    else
        settings.use_icons = nil
        if s == "2" then
            settings.use_icons = true
        elseif s == "3" then
            settings.use_icons = true
            settings.use_color_emoji = true
        end
    end
    return s
end

local function choose_transient(settings, title)
    local choices = "" -- luacheck: ignore 311

    refresh_width(settings)

    clear_screen()
    display_title(title)
    clink.print()

    choices = "yn"

    clink.print("(y)  Yes.\n")
    clink.print("     Past prompts are compacted, if the current directory")
    clink.print("     hasn't changed.\n")

    -- This initializes the settings.wizard.prefix needed below.
    flexprompt.render_wizard(settings)

    clink.print(settings.wizard.prefix .. flexprompt.render_transient_wizard(settings.wizard) .. "git pull")
    clink.print(settings.wizard.prefix .. flexprompt.render_transient_wizard(settings.wizard) .. "git branch x")
    if settings.spacing == "sparse" then clink.print() end
    display_preview(settings, "git checkout x")
    clink.print()

    clink.print("(n)  No.\n")
    display_preview(settings, "git pull", false)
    if settings.spacing == "sparse" then clink.print() end
    display_preview(settings, "git branch x", false)
    if settings.spacing == "sparse" then clink.print() end
    display_preview(settings, "git checkout x")
    clink.print()

    choices = display_restart(choices)
    choices = display_quit(choices)

    local s = readchoice(choices)
    if not s then return end

    if s == "r" then -- luacheck: ignore 542
    elseif s == "q" then -- luacheck: ignore 542
    else
        if s == "y" then
            _transient = "same_dir"
        else
            _transient = "off"
        end
    end
    return s
end

local function make_8bit_color_test()
    local s = ""
    for index = 0, 11, 1 do
        local color = 234 + index
        s = s .. "\x1b[48;5;"..color..";38;5;"..(color + 4 + math.floor(index*2/3)).."m" .. string.char(65 + index)
    end
    return s .. "\x1b[m"
end

local function wizard_can_use_extended_colors(settings)
    local can
    local old_settings = flexprompt.settings
    flexprompt.settings = settings
    can = flexprompt.can_use_extended_colors(true)
    flexprompt.settings = old_settings
    return can
end

local function make_icon_list(icons)
    local out = "X"
    local colors = { --[["\x1b[31m", "\x1b[33m",]] "\x1b[32m", --[["\x1b[34m", "\x1b[35m", "\x1b[36m"]] }
    for i = 1, #icons, 1 do
        out = out .. colors[((i - 1) % #colors) + 1] .. icons[i] .. normal .. "X"
    end
    return out
end

local function config_wizard()
    local s
    local settings_filename, delete_filename = get_settings_filename()
    local errors

    local hasicons
    local eight_bit_color_test = make_8bit_color_test()
    local four_bit_color
    local style_choices
    local callout
    local choices
    local wrote
    local nerdfonts_version
    local nerdfonts_width

    print(string.rep("\n", console.getheight()))

    clear_screen()

    repeat
        local preview =
        {
            wizard =
            {
                cwd = "c:\\directory",
                type = "git",
                branch = "main",
                duration = 5,
                exit = 0,
                battery = {},
            },
            lines = "two",
            left_prompt = "{cwd}{git}",
            right_prompt = "{duration}{time}",
        }

        _transient = nil
        _striptime = true
        _timeformat = nil

        hasicons = nil
        nerdfonts_version = nil
        nerdfonts_width = nil
        four_bit_color = false

        -- Find out about the font being used.

        refresh_width(preview)

        clear_screen()
        display_title("Welcome to the configuration wizard for flexprompt.")
        display_centered("This will ask a few questions and configure your prompt.")
        clink.print()
        display_centered("Does this look like a "..brightgreen.."diamond"..normal.." (rotated square)?")
        clink.print("\n")
        display_centered("-->  "..brightgreen..""..normal.."  <--")
        clink.print("\n")
        choices = ""
        choices = display_yes(choices)
        choices = display_no(choices)
        clink.print("     Visit "..brightgreen.."https://nerdfonts.com"..normal.." to find fonts that support the")
        clink.print("     powerline symbols flexprompt uses for its fancy text-mode graphics.")
        clink.print("\n     Some excellent fonts to consider are Meslo NF, Fira Code NF,")
        clink.print("     or Cascadia Code PL (and many other suitable fonts exist).\n\n")
        choices = display_quit(choices)
        s = readchoice(choices)
        if not s or s == "q" then break end
        if s == "y" then
            preview.charset = "unicode"
            preview.powerline_font = true
        end

        if not preview.charset then
            refresh_width(preview)
            clink.print("\x1b[4H\x1b[J", NONL)
            display_centered("Does this look like a "..brightgreen.."rectangle"..normal.."?")
            clink.print()
            display_centered(brightgreen..flexprompt.choices.left_frames["square"][1]..flexprompt.choices.right_frames["square"][1]..normal)
            display_centered("-->  "..brightgreen.."│  │"..normal.."  <--")
            display_centered(brightgreen..flexprompt.choices.left_frames["square"][2]..flexprompt.choices.right_frames["square"][2]..normal)
            clink.print()
            choices = ""
            choices = display_yes(choices)
            choices = display_no(choices)
            choices = display_restart(choices)
            choices = display_quit(choices)
            s = readchoice(choices)
            if not s or s == "q" then break end
            if s == "r" then goto continue end
            if s == "y" then
                preview.charset = "unicode"
            else
                preview.charset = "ascii"
                if clink.getansihost then
                    local term = clink.getansihost()
                    if term ~= "clink" and term ~= "winterminal" then
                        preview.symbols = preview.symbols or {}
                        preview.symbols.prompt = { ">", winterminal="❯" }
                    end
                end
            end
        end

        if preview.charset ~= "ascii" then
            refresh_width(preview)
            clink.print("\x1b[4H\x1b[J", NONL)
            display_centered("Which of these looks like an icon of a "..brightgreen.."wrist watch"..normal.."?")
            clink.print("\n")
            clink.print("(1)  "..brightgreen..""..normal.."\n")
            clink.print("(2)  "..brightgreen..""..normal.."\n")
            clink.print("(3)  Neither.\n")
            choices = "123"
            choices = display_restart(choices)
            choices = display_quit(choices)
            s = readchoice(choices)
            if not s or s == "q" then break end
            if s == "r" then goto continue end
            if s == "1" then
                nerdfonts_version = 3
            elseif s == "2" then
                nerdfonts_version = 2
            end
            hasicons = nerdfonts_version and true or false
        end

        if hasicons then
            refresh_width(preview)
            clink.print("\x1b[4H\x1b[J", NONL)
            display_centered("Which of these fit better between the crosses without being cut off?")
            clink.print("\n")
            clink.print("(1)  Mono width icons.  These should fit tightly, without being cut off.\n")
            clink.print("     -->  " .. make_icon_list({"","","",""}) .. "  <--\n")
            clink.print("(2)  Double-width icons.  These should fit loosely, without being cut off.\n")
            clink.print("     -->  " .. make_icon_list({" "," "," "," "}) .. "  <--\n")
            clink.print("(3)  Neither of them look right.\n")
            choices = "123"
            choices = display_restart(choices)
            choices = display_quit(choices)
            s = readchoice(choices)
            if not s or s == "q" then break end
            if s == "r" then goto continue end
            if s == "3" then
                hasicons = false
                nerdfonts_version = nil
                nerdfonts_width = nil
            elseif s == "2" then
                nerdfonts_width = 2
            else
                nerdfonts_width = 1
            end
        end

        preview.nerdfonts_version = nerdfonts_version
        preview.nerdfonts_width = nerdfonts_width

        if preview.charset == "ascii" then
            callout = { 4, {1,1}, "\x1b[1;33m/\x1b[A\x1b[Dseparator\x1b[m" }
            preview.left_frame = "none"
            preview.right_frame = "none"
        else
            callout = { 4, 1, "\x1b[1;33m↓\x1b[A\x1b[2Dseparator\x1b[m" }
            preview.heads = preview.powerline_font and "pointed" or nil
            preview.left_frame = "round"
            preview.right_frame = "round"

            refresh_width(preview)
            clink.print("\x1b[4H\x1b[J", NONL)
            display_centered("Does this look like "..brightgreen.."><"..normal.." but taller and fatter?")
            clink.print("\n")
            display_centered("-->  "..brightgreen.."❯❮"..normal.."  <--")
            clink.print("\n")
            choices = ""
            choices = display_yes(choices)
            choices = display_no(choices)
            choices = display_restart(choices)
            choices = display_quit(choices)
            s = readchoice(choices)
            if not s or s == "q" then break end
            if s == "r" then goto continue end

            preview.symbols = preview.symbols or {}
            preview.symbols.prompt = { ">", winterminal="❯" }
            if os.getenv("WT_SESSION") then
                if s == "n" then
                    preview.symbols.prompt = ">"
                end
            else
                if s == "y" then
                    preview.symbols.prompt = "❯"
                end
            end
        end

        if wizard_can_use_extended_colors(preview) then
            refresh_width(preview)
            clink.print("\x1b[4H\x1b[J", NONL)
            display_centered("Are the letters "..brightgreen.."A"..normal.." to "..brightgreen.."L"..normal.." readable, in a smooth gradient?")
            clink.print("\n")
            display_centered("-->  "..eight_bit_color_test.."  <--")
            clink.print("\n")
            choices = ""
            choices = display_yes(choices)
            choices = display_no(choices)
            choices = display_restart(choices)
            choices = display_quit(choices)
            s = readchoice(choices)
            if not s or s == "q" then break end
            if s == "r" then goto continue end
            preview.use_8bit_color = (s == "y") and true or false
        end

        if not wizard_can_use_extended_colors(preview) then
            four_bit_color = true
            preview.frame_color = { "brightblack", "brightblack", "darkwhite", "darkblack" }
        end

        -- Configuration.

        style_choices = { "lean", "classic", "rainbow" }
        if preview.use_8bit_color then
            table.insert(style_choices, "bubbles")
        end
        s = choose_setting(preview, "Prompt Style", "styles", "style", style_choices)
        if not s or s == "q" then break end
        if s == "r" then goto continue end

        if preview.charset == nil then
            s = choose_setting(preview, "Character Set", "charsets", "charset", { "unicode", "ascii" })
            if not s or s == "q" then break end
            if s == "r" then goto continue end
        end

        if preview.charset == "ascii" then
            preview.heads = nil
            preview.left_frame = "none"
            preview.right_frame = "none"
        end

        -- Since the prompt (frame) color is so prominent in classic style, ask
        -- about it very early.
        if preview.style == "classic" and not four_bit_color then
            s = choose_setting(preview, "Prompt Color", "frame_colors", "frame_color", { "lightest", "light", "dark", "darkest" })
            if not s or s == "q" then break end
            if s == "r" then goto continue end
        end

        -- Since separators are subtle in lean style, ask about separators
        -- before asking about time so that there are two separators visible.
        if preview.style == "lean" then
            if preview.charset == "unicode" then
                -- Callout needs to be shifted right 1, because lean doesn't
                -- include segment padding.
                callout[2] = { callout[2], 1}
            end
            s = choose_setting(preview, "Prompt Separators", "separators", "lean_separators", { "space", "spaces", "dot", "vertical" }, callout)
            if not s or s == "q" then break end
            if s == "r" then goto continue end
        end

        _striptime = nil
        s = choose_time(preview, "Show current time?")
        if not s or s == "q" then break end
        if s == "r" then goto continue end

        if preview.style ~= "lean" and preview.style ~= "bubbles" then
            local seps
            if preview.style == "rainbow" then
                if preview.powerline_font then
                    seps = { "pointed", "vertical", "slant", "round", "blurred" }
                elseif preview.charset ~= "ascii" then
                    seps = { "vertical", "blurred" }
                end
            else
                if preview.powerline_font then
                    seps = { "pointed", "vertical", "slant", "round", "none" }
                else
                    seps = { "bar", "slash", "space", "none" }
                end
            end
            if seps then
                s = choose_setting(preview, "Prompt Separators", "separators", "separators", seps, callout)
                if not s or s == "q" then break end
                if s == "r" then goto continue end
            end
        end

        if preview.charset ~= "ascii" and preview.style ~= "lean" and preview.style ~= "bubbles" then
            local caps = preview.powerline_font and { "pointed", "flat", "slant", "round", "blurred" } or { "flat", "blurred" }

            callout = { 4, 2, "\x1b[1;33m↓\x1b[A\x1b[2Dhead\x1b[m" }
            s = choose_setting(preview, "Prompt Heads", "caps", "heads", caps, callout)
            if not s or s == "q" then break end
            if s == "r" then goto continue end

            callout = { 4, 3, "\x1b[1;33m↓\x1b[A\x1b[2Dtail\x1b[m" }
            s = choose_setting(preview, "Prompt Tails", "caps", "tails", caps, callout)
            if not s or s == "q" then break end
            if s == "r" then goto continue end
        end

        -- Choose sides after choosing tails, so there's a good anchor for
        -- the tails callout.
        if preview.style ~= "bubbles" then
            s = choose_sides(preview, "Prompt Sides")
            if not s or s == "q" then break end
            if s == "r" then goto continue end
        end

        s = choose_setting(preview, "Prompt Height", "lines", "lines", { "one", "two" })
        if not s or s == "q" then break end
        if s == "r" then goto continue end

        if preview.lines == "two" then
            local conns = (preview.charset == "unicode") and { "disconnected", "dotted", "solid" } or { "disconnected", "dashed" }
            s = choose_setting(preview, "Prompt Connection", "connections", "connection", conns)
            if not s or s == "q" then break end
            if s == "r" then goto continue end

            if preview.left_frame ~= "none" or preview.right_frame ~= "none" then
                s = choose_frames(preview, "Prompt Frame")
                if not s or s == "q" then break end
                if s == "r" then goto continue end
            end

            if not preview.frame_color and not four_bit_color and
                    (preview.left_frame ~= "none" or preview.right_frame ~= "none" or preview.connection ~= "disconnected") then
                s = choose_setting(preview, "Prompt Frame Color", "frame_colors", "frame_color", { "lightest", "light", "dark", "darkest" })
                if not s or s == "q" then break end
                if s == "r" then goto continue end
            end
        end

        s = choose_spacing(preview, "Prompt Spacing")
        if not s or s == "q" then break end
        if s == "r" then goto continue end

        if hasicons and preview.charset == "unicode" and preview.style ~= "bubbles" then
            s = choose_icons(preview, "Icons")
            if not s or s == "q" then break end
            if s == "r" then goto continue end
        end

        if preview.style ~= "bubbles" then
            s = choose_setting(preview, "Prompt Flow", "flows", "flow", { "concise", "fluent" })
            if not s or s == "q" then break end
            if s == "r" then goto continue end
        end

        if clink.version_encoded >= 10020029 then
            s = choose_transient(preview, "Transient Prompt")
            if not s or s == "q" then break end
            if s == "r" then goto continue end
        end

        translate_bubbles(preview, true)

        do
            local old_settings = flexprompt.settings
            flexprompt.settings = preview

            local left_frame, right_frame = flexprompt.get_frame() -- luacheck: no unused
            local style = flexprompt.get_style()
            if left_frame and style ~= "lean" then
                if preview.left_prompt and preview.left_prompt:match("{exit}") then
                    preview.left_prompt = preview.left_prompt .. "{overtype}"
                elseif preview.right_prompt then
                    preview.right_prompt = preview.right_prompt:gsub("{exit}", "{overtype}{exit}")
                end
            end

            flexprompt.settings = old_settings
        end

        -- Done.

        if delete_filename or os.isfile(settings_filename) then
            clear_screen()
            display_title("Flexprompt autoconfig file already exists.")
            if os.isfile(settings_filename) then
                display_centered("Overwrite "..brightgreen..settings_filename..normal.."?")
            else
                display_centered("Write new "..brightgreen..settings_filename..normal.." file?")
            end
            clink.print()
            choices = ""
            choices = display_yes(choices)
            choices = display_restart(choices)
            choices = display_quit(choices)
            s = readchoice(choices)
            if not s or s == "q" then break end
            if s == "r" then goto continue end
        end

        errors = write_settings(preview)
        wrote = true
        break

        ::continue::
    until false

    clear_screen()
    console.scroll("end", 1)

    if wrote then
        if clink.reload then
            clink.reload()
        else
            clink.print("\x1b[1mThe new flexprompt configuration will take effect when Clink is reloaded.\x1b[m")
        end

        clink.print()
        clink.print("For information on how to configure the prompt further and how to include\nmore modules, see https://github.com/chrisant996/clink-flex-prompt#readme.")

        if errors then
            clink.print()
            for _,msg in ipairs(errors) do
                clink.print(brightyellow .. msg .. normal .. "\n")
            end
        end
    end
end

local function run_demo()
    local wizard =
    {
        cwd = "~\\src",
        root = "~\\src",
        type = "git",
        branch = "main",
        duration = 5,
        exit = 0,
        width = math.min(console.getwidth(), 80),
        screenwidth = math.min(console.getwidth(), 80),
        battery = {},
    }

    local preview =
    {
        wizard = wizard,
        left_prompt = "{cwd}{git}",
        unicode = true,
        symbols = {
            prompt = { ">", winterminal="❯" },
        },
        nerdfonts_version = flexprompt.settings.nerdfonts_version,
        nerdfonts_width = flexprompt.settings.nerdfonts_width,
    }

    local remember
    local function override(settings, fields)
        if fields then
            assert(not remember)
            remember = {}
            remember.fields = fields
            for k, v in pairs(fields) do
                remember[k] = settings[k]
                settings[k] = v
            end
        else
            for k, _ in pairs(remember.fields) do
                settings[k] = remember[k]
            end
            remember = nil
        end
    end

    print()
    display_centered("\x1b[1mLean Style\x1b[m ")
    preview.style = "lean"

    print()
    preview.right_prompt = "{duration}"
    display_preview(preview)

    print()
    preview.right_prompt = "{duration}{time}"
    override(preview, {
        lines = "two",
        flow = "fluent",
        use_icons = true,
        use_color_emoji = true,
        powerline_font = true,
    })
    display_preview(preview)
    override(preview)

    print()
    display_centered("\x1b[1mClassic Style\x1b[m")
    preview.style = "classic"
    preview.frame_color = "dark"

    print()
    preview.right_prompt = "{duration}"
    override(preview, {
        flow = "fluent",
        heads = "pointed",
    })
    display_preview(preview)
    override(preview)

    print()
    preview.right_prompt = "{duration}{time}"
    override(preview, {
        lines = "two",
        heads = "blurred",
        tails = "blurred",
        separators = "slant",
        left_frame = "round",
        right_frame = "round",
        connection = "dotted",
        use_icons = true,
        powerline_font = true,
    })
    display_preview(preview)
    override(preview)

    print()
    display_centered("\x1b[1mRainbow Style\x1b[m")
    preview.style = "rainbow"

    print()
    preview.left_prompt = "{battery}{break}{cwd}{git}"
    preview.right_prompt = "{duration}"
    preview.heads = "pointed"
    override(preview, {
        heads = "pointed",
        use_icons = true,
    })
    display_preview(preview)
    override(preview)

    print()
    preview.left_prompt = "{cwd}{git}"
    preview.right_prompt = "{duration}{time}"
    override(preview, {
        lines = "two",
        heads = "slant",
        tails = "slant",
        left_frame = "none",
        right_frame = "round",
        connection = "solid",
        use_icons = true,
        use_color_emoji = true,
        powerline_font = true,
    })
    display_preview(preview)
    override(preview)

    print()
    display_centered("\x1b[1mBubbles Style\x1b[m ")
    preview.style = "lean"
    wizard.battery = nil

    print()
    wizard.type = nil
    wizard.branch = nil
    wizard.cwd = "D:\\data"
    wizard.duration = nil
    override(preview, {
        lines = "two",
        left_prompt = "{lbubble}",
        right_prompt = "{rbubble}",
        use_icons = true,
        powerline_font = true,
    })
    display_preview(preview)
    override(preview)

    print()
    wizard.type = "git"
    wizard.branch = "main"
    wizard.cwd = "~\\src"
    wizard.duration = 5
    override(preview, {
        lines = "two",
        left_prompt = "{lbubble}",
        right_prompt = "{rbubble}",
        use_icons = true,
        powerline_font = true,
    })
    display_preview(preview)
    override(preview)

    print()
end

local function onfilterinput(text)
    text = " " .. text .. " "
    text = text:gsub("%s+", " ")
    if text == " flexprompt configure " then
        config_wizard()
        return "", false
    elseif text == " flexprompt demo " then
        run_demo()
        return "", false
    elseif text:match("^ flexprompt ") then
        clink.print("Clink flex prompt (https://github.com/chrisant996/clink-flex-prompt)")
        clink.print('Run "flexprompt configure" to configure the prompt.')
        return "", false
    end
end

if clink.onfilterinput then
    clink.onfilterinput(onfilterinput)
else
    clink.onendedit(onfilterinput)
end

clink.argmatcher("flexprompt"):addarg("configure")
