local normal = "\x1b[m"
local bold = "\x1b[1m"
local brightgreen = "\x1b[92m"

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
    if not info.short_src then
        error("Unable to write settings; file location unknown.")
    end

    local name = path.join(path.toparent(info.short_src), "flexprompt_autoconfig.lua")
    return name
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
            file:write("flexprompt.settings." .. n .. " = " .. string.format("%q", v) .. "\n")
        end
    end

    file:close()
end

local function copy_table(settings)
    local copy = {}
    for n,v in pairs(settings) do
        copy[n] = v
    end
    return copy
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

local function display_preview(settings)
    local left, right, col = flexprompt.render_wizard(settings)

    clink.print(left .. normal, NONL)
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

local function choose_setting(settings, title, choices_name, setting_name, subset)
    local index
    local choices = ""

    clear_screen()
    display_centered(title)

    for index,name in ipairs(subset) do
        if index > 5 then
            break
        end

        choices = choices .. tostring(index)

        clink.print("(" .. index .. ")  " .. name:sub(1, 1):upper() .. name:sub(2) .. ".\n")

        local preview = copy_table(settings)
        preview[setting_name] = name

        display_preview(preview)

        clink.print()
    end

    choices = display_restart(choices)
    choices = display_quit(choices)

    repeat
        local s = readchoice(choices)
        if not s then return end

        if #s == 1 and string.find(choices, s) then
            if s == "r" then
            elseif s == "q" then
            else
                settings[setting_name] = subset[tonumber(s)]
            end
            return s
        end
    until false
end

local function config_wizard()
    local s
    local settings_filename = get_settings_filename()
    local wrote

    print(string.rep("\n", console.getheight()))

    clear_screen()

    repeat
        local preview =
        {
            wizard =
            {
                cwd = "c:\\cwd",
                duration = 2,
                exit = 0,
            },
            lines = "two",
            left_prompt = "{cwd}",
            right_prompt = "{duration}{time}",
        }

        clear_screen()
        display_centered("Welcome to the configuration wizard for flexprompt.")
        display_centered("This will ask a few questions and configure your prompt.")
        clink.print()
        display_centered("Does this look like a "..brightgreen.."diamond"..normal.." (rotated square)?")
        clink.print()
        display_centered("-->  "..brightgreen..""..normal.."  <--")
        clink.print()
        choices = ""
        choices = display_yes(choices)
        choices = display_no(choices)
        choices = display_quit(choices)
        s = readchoice(choices)
        if not s or s == "q" then break end
        if s == "n" then preview.charset = "ascii" end

        if preview.charset ~= "ascii" then
            preview.heads = "pointed"
        end

        s = choose_setting(preview, "Prompt Style", "styles", "style", { "lean", "classic", "rainbow" })
        if not s or s == "q" then break end
        if s == "r" then goto continue end

        if preview.style == "classic" then
            s = choose_setting(preview, "Prompt Color", "frame_colors", "frame_color", { "lightest", "light", "dark", "darkest" })
            if not s or s == "q" then break end
            if s == "r" then goto continue end
        end

        if os.isfile(settings_filename) then
            clear_screen()
            display_centered("Flexprompt autoconfig file already exists.")
            display_centered(bold.."Overwrite "..brightgreen..settings_filename..normal..bold.."?")
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
            clink.print("The new flexprompt configuration will take effect when Clink is reloaded.")
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

clink.onfilterinput(onfilterinput)

local argmatcher = clink.argmatcher("flexprompt"):addarg("configure")
