local normal = "\x1b[m"
local bold = "\x1b[1m"
local brightgreen = "\x1b[92m"
local static_cursor = "\x1b[7m " .. normal

local _transient
local _striptime

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
    local info = debug.getinfo(get_settings_filename, 'S')
    if not info.source or info.source:sub(1, 1) ~= "@" then
        error("Unable to write settings; file location unknown.")
    end

    local name = path.join(path.toparent(info.source:sub(2)), "flexprompt_autoconfig.lua")
    return name
end

local function write_var(file, name, value, indent)
    local t = type(value)
    if not indent then indent = "" end

    if t == "table" then
        file:write(indent .. name .. " =\n")
        file:write(indent .. "{\n")
        for n,v in pairs(value) do
            write_var(file, n, v, indent .. "    ")
        end
        file:write(indent .. "}" .. ((#indent > 0) and "," or "") .. "\n")
        return
    end

    if t == "string" then
        value = string.format("%q", value)
    elseif t == "boolean" then
        value = value and "true" or "false"
    elseif t == "number" then
        value = tostring(value)
    else
        log.info("flexprompt couldn't write '" .. name .. "'; unknown type '" .. t .. "'.")
    end

    file:write(indent .. name .. " = " .. value .. "\n")
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

    for n,v in pairs(settings) do
        if n ~= "wizard" then
            write_var(file, "flexprompt.settings."..n, v)
        end
    end

    file:close()

    if _transient then
        local command = os.getalias("clink"):gsub("%$%*", " set prompt.transient " .. _transient)
        os.execute(command)
    end
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

local function strip_modules(s)
    s = s:gsub("{battery[^}]*}", "")
    if _striptime then
        s = s:gsub("{time[^}]*}", "")
    end
    return s
end

local function display_preview(settings, command, show_cursor, callout)
    local preview = copy_table(settings)
    if preview.left_prompt then
        preview.left_prompt = strip_modules(preview.left_prompt)
    end
    if preview.right_prompt then
        preview.right_prompt = strip_modules(preview.right_prompt)
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

local function display_yes(choices)
    clink.print("(y)  Yes.\n")
    return choices .. "y"
end

local function display_no(choices)
    clink.print("(n)  No.\n")
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
            settings.left_prompt = prompts.left[1]
            settings.right_prompt = prompts.left[2]
        else
            settings.left_prompt = prompts.both[1]
            settings.right_prompt = prompts.both[2]
        end
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

    local function gsub_time(settings, choice)
        if choice == "2" then
            settings.left_prompt = settings.left_prompt:gsub("{time}", "{time:format=%%H:%%M:%%S}")
            settings.right_prompt = settings.right_prompt and settings.right_prompt:gsub("{time}", "{time:format=%%H:%%M:%%S}")
        elseif choice == "3" then
            settings.left_prompt = settings.left_prompt:gsub("{time}", "{time:format=%%a %%H:%%M}")
            settings.right_prompt = settings.right_prompt and settings.right_prompt:gsub("{time}", "{time:format=%%a %%H:%%M}")
        elseif choice == "4" then
            settings.left_prompt = settings.left_prompt:gsub("{time}", "{time:format=%%I:%%M:%%S %%p}")
            settings.right_prompt = settings.right_prompt and settings.right_prompt:gsub("{time}", "{time:format=%%I:%%M:%%S %%p}")
        elseif choice == "5" then
            settings.left_prompt = settings.left_prompt:gsub("{time}", "{time:format=%%a %%I:%%M %%p}")
            settings.right_prompt = settings.right_prompt and settings.right_prompt:gsub("{time}", "{time:format=%%a %%I:%%M %%p}")
        else
            settings.left_prompt = settings.left_prompt:gsub("{time}", "")
            settings.right_prompt = settings.right_prompt and settings.right_prompt:gsub("{time}", "") or nil
        end
    end

    clink.print("(1)  No.\n")
    preview = copy_table(settings)
    gsub_time(preview, "1")
    display_preview(preview)
    clink.print()

    clink.print("(2)  24-hour format.\n")
    preview = copy_table(settings)
    gsub_time(preview, "2")
    display_preview(preview)
    clink.print()

    clink.print("(3)  24-hour format with day.\n")
    preview = copy_table(settings)
    gsub_time(preview, "3")
    display_preview(preview)
    clink.print()

    clink.print("(4)  12-hour format.\n")
    preview = copy_table(settings)
    gsub_time(preview, "4")
    display_preview(preview)
    clink.print()

    clink.print("(5)  12-hour format with day.\n")
    preview = copy_table(settings)
    gsub_time(preview, "5")
    display_preview(preview)
    clink.print()

    choices = display_restart(choices)
    choices = display_quit(choices)

    local s = readchoice(choices)
    if not s then return end

    if s == "r" then
    elseif s == "q" then
    else
        gsub_time(settings, s)
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

local function config_wizard()
    local s
    local settings_filename = get_settings_filename()
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
                duration = 2,
                exit = 0,
            },
            lines = "two",
            left_prompt = "{cwd}{git}",
            right_prompt = "{duration}{time}",
            symbols = {
                branch=""
            },
        }

        _transient = nil
        _striptime = true

        four_bit_color = false

        -- Find out about the font being used.

        clear_screen()
        display_centered(bold.."Welcome to the configuration wizard for flexprompt."..normal)
        display_centered("This will ask a few questions and configure your prompt.")
        clink.print()
        display_centered("Does this look like a "..brightgreen.."diamond"..normal.." (rotated square)?")
        clink.print()
        display_centered("-->  "..brightgreen..""..normal.."  <--")
        clink.print()
        choices = ""
        choices = display_yes(choices)
        choices = display_no(choices)
        clink.print("     Visit "..bold.."https://nerdfonts.com"..normal.." to find fonts that support the")
        clink.print("     powerline symbols flexprompt uses for its fancy text-mode graphics.")
        clink.print("\n     Some excellent fonts to consider are Meslo NF, Fira Code NF,")
        clink.print("     or Cascadia Code PL (and many other suitable fonts exist).\n\n")
        choices = display_quit(choices)
        s = readchoice(choices)
        if not s or s == "q" then break end
        if s == "y" then preview.charset = "unicode" end
        if s == "n" then preview.charset = "ascii" end

        if preview.charset == "ascii" then
            preview.left_frame = "none"
            preview.right_frame = "none"
        else
            preview.heads = "pointed"
            preview.left_frame = "round"
            preview.right_frame = "round"
        end

        --[[
        -- THIS IS INCONCLUSIVE BECAUSE WINDOWS TERMINAL SEEMS TO ALWAYS SHOW
        -- THE THICK ANGLE BRACKET, USING THE SAME FONT AS THE DEFAULT TERMINAL.
        clink.print("\x1b[4H\x1b[J", NONL)
        display_centered("Does this look like a "..brightgreen.."angle bracket"..normal.." (greater than sign)?")
        clink.print()
        display_centered("-->  "..brightgreen.."❯"..normal.."  <--")
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
            preview.symbols.prompt = "❯"
        end
        --]]

        if wizard_can_use_extended_colors(preview) then
            clink.print("\x1b[4H\x1b[J", NONL)
            display_centered("Are the letters "..brightgreen.."A"..normal.." to "..brightgreen.."L"..normal.." readable, in a smooth gradient?")
            clink.print()
            display_centered("-->  "..eight_bit_color_test.."  <--")
            clink.print()
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

        preview.symbols.branch = nil

        if preview.charset == "unicode" then
            s = choose_setting(preview, "Character Set", "charsets", "charset", { "unicode", "ascii" })
            if not s or s == "q" then break end
            if s == "r" then goto continue end
        end

        if preview.charset == "ascii" then
            preview.heads = nil
            preview.left_frame = "none"
            preview.right_frame = "none"
        end

        if preview.style == "lean" then
            s = choose_sides(preview, "Prompt Sides")
            if not s or s == "q" then break end
            if s == "r" then goto continue end
        end

        if preview.style == "classic" and not four_bit_color then
            s = choose_setting(preview, "Prompt Color", "frame_colors", "frame_color", { "lightest", "light", "dark", "darkest" })
            if not s or s == "q" then break end
            if s == "r" then goto continue end
        end

        _striptime = nil
        s = choose_time(preview, "Show current time?")
        if not s or s == "q" then break end
        if s == "r" then goto continue end

        if preview.style ~= "lean" then
            if preview.charset == "ascii" then
                callout = { 4, {1,1}, "\x1b[1;33m/\x1b[A\x1b[Dseparator\x1b[m" }
                s = choose_setting(preview, "Prompt Separators", "ascii_separators", "separators", { "vertical", "slant", "none" }, callout)
            else
                callout = { 4, 1, "\x1b[1;33m↓\x1b[A\x1b[2Dseparator\x1b[m" }
                s = choose_setting(preview, "Prompt Separators", "separators", "separators", { "pointed", "vertical", "slant", "round", "none" }, callout)
            end
            if not s or s == "q" then break end
            if s == "r" then goto continue end

            if preview.charset ~= "ascii" then
                callout = { 4, 2, "\x1b[1;33m↓\x1b[A\x1b[2Dhead\x1b[m" }
                s = choose_setting(preview, "Prompt Heads", "caps", "heads", { "pointed", "blurred", "slant", "round", "flat" }, callout)
                if not s or s == "q" then break end
                if s == "r" then goto continue end

                callout = { 4, 3, "\x1b[1;33m↓\x1b[A\x1b[2Dtail\x1b[m" }
                s = choose_setting(preview, "Prompt Tails", "caps", "tails", { "pointed", "blurred", "slant", "round", "flat" }, callout)
                if not s or s == "q" then break end
                if s == "r" then goto continue end
            end

            -- Choose sides after choosing tails, so there's a good anchor for
            -- the tails callout.
            s = choose_sides(preview, "Prompt Sides")
            if not s or s == "q" then break end
            if s == "r" then goto continue end
        end

        s = choose_setting(preview, "Prompt Height", "lines", "lines", { "one", "two" })
        if not s or s == "q" then break end
        if s == "r" then goto continue end

        if preview.lines == "two" then
            s = choose_setting(preview, "Prompt Connection", "connections", "connection", { "disconnected", "dotted", "solid" })
            if not s or s == "q" then break end
            if s == "r" then goto continue end

            if preview.left_frame ~= "none" or preview.right_frame ~= "none" then
                s = choose_frames(preview, "Prompt Frame")
                if not s or s == "q" then break end
                if s == "r" then goto continue end
            end

            if preview.style ~= "classic" and not four_bit_color and
                    (preview.left_frame ~= "none" or preview.right_frame ~= "none" or preview.connection ~= "disconnected") then
                s = choose_setting(preview, "Prompt Color", "frame_colors", "frame_color", { "lightest", "light", "dark", "darkest" })
                if not s or s == "q" then break end
                if s == "r" then goto continue end
            end
        end

        s = choose_spacing(preview, "Prompt Spacing")
        if not s or s == "q" then break end
        if s == "r" then goto continue end

        if preview.charset == "unicode" then
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

        write_settings(preview)
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
    end
end

local function onfilterinput(text)
    text = " " .. text .. " "
    text = text:gsub("%s+", " ")
    if text == " flexprompt configure " then
        config_wizard()
        return "", false
    end
end

if clink.onfilterinput then
    clink.onfilterinput(onfilterinput)
else
    clink.onendedit(onfilterinput)
end

local argmatcher = clink.argmatcher("flexprompt"):addarg("configure")
