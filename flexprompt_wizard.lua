local normal = "\x1b[m"
local bold = "\x1b[1m"
local brightgreen = "\x1b[92m"
local brightyellow = "\x1b[93m"
local static_cursor = "\x1b[7m " .. normal

local _transient
local _striptime
local _timeformat

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

        if #s == 1 and string.find(choices, s) then
            return s
        end
    until false
end

local function clear_screen()
    clink.print("\x1b[H\x1b[J", NONL)
end

local function get_settings_filename()
    local name
    local info = debug.getinfo(1, 'S')
    if info.source and info.source:sub(1, 1) == "@" then
        name = path.join(path.toparent(info.source:sub(2)), "flexprompt_autoconfig.lua")
        if not os.isfile(name) then
            name = nil
        end
    end
    if not name then
        local dir = os.getenv("=clink.profile")
        if not os.isdir(dir) then
            error("Unable to write settings; file location unknown.")
        end
        name = path.join(dir, "flexprompt_autoconfig.lua")
    end
    return name
end

local function inc_line(line)
    line[1] = line[1] + 1
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

        for n,v in pairs(value) do
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
    local name = get_settings_filename()
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
    for n,v in pairs(settings) do
        if n ~= "wizard" then
            local msg = write_var(file, line, "flexprompt.settings."..n, v)
            if msg then
                errors = errors or {}
                table.insert(errors, msg)
            end
        end
    end

    file:close()

    if _transient then
        local command = os.getalias("clink"):gsub("%$%*", " set prompt.transient " .. _transient)
        os.execute(command)
    end

    return errors
end

local function copy_table(settings)
    local copy = {}
    for n,v in pairs(settings) do
        copy[n] = v
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

local function apply_time_format(s)
    if not s then return end

    if _striptime then
        s = s:gsub("{time[^}]*}", "")
    elseif _timeformat then
        if _timeformat == "2" then
            s = s:gsub("{time:dim}", "{time:dim:format=%%H:%%M:%%S}")
            s = s:gsub("{time}", "{time:format=%%H:%%M:%%S}")
        elseif _timeformat == "3" then
            s = s:gsub("{time:dim}", "{time:dim:format=%%a %%H:%%M}")
            s = s:gsub("{time}", "{time:format=%%a %%H:%%M}")
        elseif _timeformat == "4" then
            s = s:gsub("{time:dim}", "{time:dim:format=%%I:%%M:%%S %%p}")
            s = s:gsub("{time}", "{time:format=%%I:%%M:%%S %%p}")
        elseif _timeformat == "5" then
            s = s:gsub("{time:dim}", "{time:dim:format=%%a %%I:%%M %%p}")
            s = s:gsub("{time}", "{time:format=%%a %%I:%%M %%p}")
        else
            s = s:gsub("{time:dim}", "")
            s = s:gsub("{time}", "")
        end
    end
    return s
end

local function replace_modules(s)
    if not s then return end

    s = s:gsub("{battery[^}]*}", "")
    s = apply_time_format(s)
    return s
end

local function display_preview(settings, command, show_cursor, callout)
    local preview = copy_table(settings)
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

local function choose_setting(settings, title, choices_name, setting_name, subset, callout)
    local index
    local choices = ""

    clear_screen()
    display_centered(title)
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

    if s == "r" then
    elseif s == "q" then
    else
        settings[setting_name] = subset[tonumber(s)]
    end
    return s
end

local function choose_sides(settings, title)
    local choices = ""
    local prompts = flexprompt.choices.prompts[settings.style]
    local preview

    clear_screen()
    display_centered(title)
    clink.print()

    choices = "12"

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

    choices = display_restart(choices)
    choices = display_quit(choices)

    local s = readchoice(choices)
    if not s then return end

    if s == "r" then
    elseif s == "q" then
    else
        if s == "1" then
            settings.left_prompt = apply_time_format(prompts.left[1])
            settings.right_prompt = apply_time_format(prompts.left[2])
        else
            settings.left_prompt = apply_time_format(prompts.both[1])
            settings.right_prompt = apply_time_format(prompts.both[2])
        end
        _timeformat = nil
    end
    return s
end

local function choose_time(settings, title)
    local choices = ""
    local preview

    clear_screen()
    display_centered(title)
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

    if s == "r" then
    elseif s == "q" then
    else
        _timeformat = s
    end
    return s
end

local function choose_frames(settings, title)
    local choices = ""
    local preview

    clear_screen()
    display_centered(title)
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

    if s == "r" then
    elseif s == "q" then
    else
        settings.left_frame = (s == "1" or s == "3") and "none" or "round"
        settings.right_frame = (s == "1" or s == "2") and "none" or "round"
    end
    return s
end

local function choose_spacing(settings, title)
    local choices = ""
    local preview

    clear_screen()
    display_centered(title)
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

    if s == "r" then
    elseif s == "q" then
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
    local choices = ""
    local preview

    clear_screen()
    display_centered(title)
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

    choices = display_restart(choices)
    choices = display_quit(choices)

    local s = readchoice(choices)
    if not s then return end

    if s == "r" then
    elseif s == "q" then
    else
        settings.use_icons = (s == "2") and true or nil
    end
    return s
end

local function choose_transient(settings, title)
    local choices = ""
    local preview

    clear_screen()
    display_centered(title)
    clink.print()

    choices = "yn"

    clink.print("(y)  Yes.\n")
    clink.print("     Past prompts are compacted, if the current directory")
    clink.print("     hasn't changed.\n")
    clink.print(settings.wizard.prefix .. flexprompt.render_transient_wizard() .. "git pull")
    clink.print(settings.wizard.prefix .. flexprompt.render_transient_wizard() .. "git branch x")
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

    if s == "r" then
    elseif s == "q" then
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
    local colors = { "\x1b[31m", "\x1b[32m", "\x1b[33m", "\x1b[34m", "\x1b[35m", "\x1b[36m" }
    for i = 1, #icons, 1 do
        out = out .. colors[((i - 1) % #colors) + 1] .. icons[i] .. normal .. "X"
    end
    return out
end

local function config_wizard()
    local s
    local settings_filename = get_settings_filename()
    local errors

    local hasicons
    local eight_bit_color_test = make_8bit_color_test()
    local four_bit_color
    local callout
    local wrote

    print(string.rep("\n", console.getheight()))

    clear_screen()

    repeat
        local preview =
        {
            wizard =
            {
                width = console.getwidth() - 10, -- Align with "(1)  <-Here".
                cwd = "c:\\directory",
                duration = 5,
                exit = 0,
            },
            lines = "two",
            left_prompt = "{cwd}{git}",
            right_prompt = "{duration}{time}",
        }

        _transient = nil
        _striptime = true
        _timeformat = nil

        hasicons = nil
        four_bit_color = false

        -- Find out about the font being used.

        clear_screen()
        display_centered(bold.."Welcome to the configuration wizard for flexprompt."..normal)
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
                        preview.symbols.prompt = { ">", winterminal="❯" }
                    end
                end
            end
        end

        if preview.charset ~= "ascii" then
            clink.print("\x1b[4H\x1b[J", NONL)
            display_centered("Are these icons and do they fit between the crosses?")
            clink.print("\n")
            display_centered("-->  " .. make_icon_list({"","","","","","","","",""}) .. "  <--")
            clink.print("\n")
            choices = ""
            choices = display_yes(choices, "They are icons and they fit closely, but with no overlap.")
            choices = display_no(choices, "They are not icons, or some overlap neighboring crosses.")
            choices = display_restart(choices)
            choices = display_quit(choices)
            s = readchoice(choices)
            if not s or s == "q" then break end
            if s == "r" then goto continue end
            hasicons = (s == "y") and true or false
        end

        if preview.charset == "ascii" then
            callout = { 4, {1,1}, "\x1b[1;33m/\x1b[A\x1b[Dseparator\x1b[m" }
            preview.left_frame = "none"
            preview.right_frame = "none"
        else
            callout = { 4, 1, "\x1b[1;33m↓\x1b[A\x1b[2Dseparator\x1b[m" }
            preview.heads = preview.powerline_font and "pointed" or nil
            preview.left_frame = "round"
            preview.right_frame = "round"

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

        s = choose_setting(preview, "Prompt Style", "styles", "style", { "lean", "classic", "rainbow" })
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
            s = choose_setting(preview, "Prompt Separators", "separators", "lean_separators", { "space", "spaces" }, callout)
            if not s or s == "q" then break end
            if s == "r" then goto continue end
        end

        _striptime = nil
        s = choose_time(preview, "Show current time?")
        if not s or s == "q" then break end
        if s == "r" then goto continue end

        if preview.style ~= "lean" then
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

        if preview.charset ~= "ascii" and preview.style ~= "lean" then
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
        s = choose_sides(preview, "Prompt Sides")
        if not s or s == "q" then break end
        if s == "r" then goto continue end

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

        if hasicons and preview.charset == "unicode" then
            s = choose_icons(preview, "Icons")
            if not s or s == "q" then break end
            if s == "r" then goto continue end
        end

        s = choose_setting(preview, "Prompt Flow", "flows", "flow", { "concise", "fluent" })
        if not s or s == "q" then break end
        if s == "r" then goto continue end

        if clink.version_encoded >= 10020029 then
            s = choose_transient(preview, "Transient Prompt")
            if not s or s == "q" then break end
            if s == "r" then goto continue end
        end

        if true then
            local old_settings = flexprompt.settings
            flexprompt.settings = preview

            local left_frame, right_frame = flexprompt.get_frame()
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

        if os.isfile(settings_filename) then
            clear_screen()
            display_centered("Flexprompt autoconfig file already exists.")
            display_centered(bold.."Overwrite "..brightgreen..settings_filename..normal..bold.."?"..normal)
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
        duration = 5,
        exit = 0,
        width = console.getwidth(),
    }

    local preview =
    {
        wizard = wizard,
        left_prompt = "{cwd}{git}",
        unicode = true,
        symbols = {
            prompt = { ">", winterminal="❯" },
        },
    }

    print()
    display_centered("\x1b[1mLean Style\x1b[m ")
    preview.style = "lean"
    preview.connection = nil
    preview.heads = nil
    preview.tails = nil
    preview.separators = nil

    print()
    preview.lines = nil
    preview.right_prompt = "{duration}"
    preview.flow = nil
    preview.use_icons = false
    preview.powerline_font = false
    display_preview(preview)

    print()
    preview.lines = "two"
    preview.right_prompt = "{duration}{time}"
    preview.flow = "fluent"
    preview.use_icons = true
    preview.powerline_font = true
    display_preview(preview)

    print()
    display_centered("\x1b[1mClassic Style\x1b[m")
    preview.style = "classic"
    preview.frame_color = "dark"
    preview.connection = nil
    preview.heads = nil
    preview.tails = nil
    preview.separators = nil

    print()
    preview.lines = nil
    preview.right_prompt = "{duration}"
    preview.flow = nil
    preview.use_icons = false
    preview.powerline_font = false
    preview.heads = "pointed"
    display_preview(preview)

    print()
    preview.lines = "two"
    preview.right_prompt = "{duration}{time}"
    preview.flow = "fluent"
    preview.use_icons = true
    preview.powerline_font = true
    preview.heads = "blurred"
    preview.tails = "blurred"
    preview.separators = "slant"
    preview.left_frame = "round"
    preview.right_frame = "round"
    preview.connection = "dotted"
    display_preview(preview)

    print()
    display_centered("\x1b[1mRainbow Style\x1b[m")
    preview.style = "rainbow"
    preview.connection = nil
    preview.heads = nil
    preview.tails = nil
    preview.separators = nil

    print()
    preview.lines = nil
    preview.right_prompt = "{duration}"
    preview.flow = nil
    preview.use_icons = false
    preview.powerline_font = false
    preview.heads = "pointed"
    display_preview(preview)

    print()
    preview.lines = "two"
    preview.right_prompt = "{duration}{time}"
    preview.flow = "fluent"
    preview.use_icons = true
    preview.powerline_font = true
    preview.heads = "slant"
    preview.tails = "slant"
    preview.separators = nil
    preview.left_frame = "none"
    preview.right_frame = "round"
    preview.connection = "solid"
    display_preview(preview)

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

local argmatcher = clink.argmatcher("flexprompt"):addarg("configure")
