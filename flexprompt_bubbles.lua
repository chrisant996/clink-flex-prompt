-- luacheck: globals flexprompt flexprompt_git flexprompt_bubbles
if not flexprompt or not flexprompt.add_module then
    log.info("flexprompt_bubbles requires flexprompt.")
    return
end

local function sgr(code)
    if not code then
        return "\x1b[m"
    elseif string.byte(code) == 0x1b then
        return code
    else
        return "\x1b["..code.."m"
    end
end

--------------------------------------------------------------------------------

local sep_shape = "round"   -- FUTURE: Maybe allow a way to override the shape?

--------------------------------------------------------------------------------
-- luacheck: push no unused

flexprompt.settings.symbols.detached = { nerdfonts2={"ﰖ", " "}, nerdfonts3={"󰜘", " "} }

local default_bg_as_fg = "30" -- REVIEW: Is this really needed?

local bg_default = sgr("49")
local bg_softblue = sgr("48;2;60;90;180")
local bg_softmagenta = sgr("48;2;100;60;160")
local bg_softgreen = sgr("48;2;60;120;90")
local bg_red = sgr("48;5;88")
local bg_gray1 = sgr("48;5;240")
local bg_gray2 = sgr("48;5;238")
local bg_gray3 = sgr("48;5;236")
local bg_darkgray1 = sgr("48;5;238")
local bg_darkgray2 = sgr("48;5;236")
local bg_darkgray3 = sgr("48;5;234")

local bg_git_default = sgr("48;2;0;120;240")
local bg_nongit_default = sgr("48;2;125;95;225")

local fg_default = sgr("39")
local fg_black = sgr("30")
local fg_red = sgr("38;5;202")
local fg_orange = sgr("38;5;208")
local fg_yellow = sgr("38;5;220")
local fg_green = sgr("38;5;40")
local fg_cyan = sgr("38;5;45")
local fg_magenta = sgr("38;5;171")
local fg_lavender = sgr("38;5;99")
local fg_white = sgr("38;5;255")

local fg_green_prompt_char = sgr("92")
local fg_red_prompt_char = sgr("91")
local fg_vpn = sgr("38;5;117")
local fg_muted = sgr("38;5;248")
local fg_fluent = fg_black

local fg_histlabel = "38;5;169"
local bg_blendmute = "48;2;0;0;0"

flexprompt_bubbles = flexprompt_bubbles or {}
flexprompt_bubbles.vpn_colors = flexprompt_bubbles.vpn_colors or {}

-- luacheck: pop
--------------------------------------------------------------------------------

local blend_color = flexprompt.blend_color

local function extract_bg(color, as_fg)
    if string.byte(color) ~= 0x1b then
        color = sgr(color)
    end
    local default_bg = as_fg and (default_bg_as_fg or "30") or "49"

    local code = ""
    for c in string.gmatch(color, "\x1b%[([^\x1b]*)m") do
        local params = string.explode(c, ";")
        local i = 1
        while i <= #params do
            local p = params[i]
            if p == "" or p == "0" then
                code = ""
            elseif p:find("^4[012345678]$") then
                code = as_fg and "3"..p:sub(2) or p
            elseif p == "49" then
                code = default_bg
            end
            i = i + 1

            if p == "38" or p == "48" then
                if params[i] == "2" then
                    code = string.format("%s;%s;%s;%s;%s", code, params[i], params[i+1], params[i+2], params[i+3])
                    i = i + 4
                elseif params[i] == "5" then
                    code = string.format("%s;%s;%s", code, params[i], params[i+1])
                    i = i + 2
                end
            end
        end
    end
    if code == "" then
        code = default_bg
    end
    return code
end

local function transition_bg(symbol, from, to)
    local as_fg = true
    local fg = extract_bg(from, as_fg)
    local bg = extract_bg(to, not as_fg)
    local text = sgr(fg..";"..bg)..symbol
    return text
end

local function make_fluent_text(text, restore_color, fluent_color)
    fluent_color = fluent_color or fg_fluent
    return fluent_color..text..restore_color
end

local function resolve_fluent_colors(text, fluent, normal)
    return text:gsub("\001", fluent):gsub("\002", normal)
end

--------------------------------------------------------------------------------

local function first_letter(s)
    if unicode.iter then
        -- This handles combining marks, but does not yet handle ZWJ (0x200d)
        -- such as in emoji sequences.
        local letter = ""
        for codepoint, value, combining in unicode.iter(s) do
            if value == 0x200d then
                break
            elseif not combining and #letter > 0 then
                break
            end
            letter = letter .. codepoint
        end
        return letter
    else
        return s:sub(1, 1)
    end
end

local function abbrev_child(parent, child)
    local letter = first_letter(child)
    if not letter or letter == "" then
        return child, false
    end

    local any = false
    local lcd = 0
    local dirs = os.globdirs(path.join(parent, letter .. "*"))
    for _, x in ipairs(dirs) do
        local m = string.matchlen(child, x)
        if lcd < m then
            lcd = m
        end
        any = true
    end
    lcd = (lcd >= 0) and lcd or 0

    if not any then
        return child, false
    end

    local abbr = child:sub(1, lcd) .. first_letter(child:sub(lcd + 1))
    return abbr, abbr ~= child
end

local function abbrev_path(dir, fluent, all, relative, notrim)
    -- Removeable drives could be floppy disks or CD-ROMs, which are slow.
    -- Network drives are slow.  Invalid drives are unknown.  If the drive
    -- type might be slow then don't abbreviate.
    local tilde, tilde_len = dir:find("^~[/\\]+")
    local s, parent

    local drivetype, parse
    if relative then
        relative = os.getfullpathname(relative)
        drivetype = os.getdrivetype(path.getdrive(relative))
        s = ""
        parent = relative
        parse = dir
    else
        local drive = path.getdrive(dir) or ""
        if tilde then
            parent = os.getenv("HOME")
            drive = path.getdrive(parent) or ""
            drivetype = os.getdrivetype(drive)
            s = "~"
            parse = dir:sub(tilde_len + 1)
        elseif drive ~= "" then
            local seps
            parent = drive
            drivetype = os.getdrivetype(drive)
            seps, parse = dir:match("^([/\\]*)(.*)$", #drive + 1)
            s = drive
            if #seps > 0 then
                parent = parent .. "\\"
                s = s .. "\\"
            end
        else
            parent = os.getcwd()
            drive = path.getdrive(parent) or ""
            drivetype = os.getdrivetype(drive)
            s = ""
            parse = dir
        end
    end

    if drivetype ~= "fixed" and drivetype ~= "ramdisk" then
        return dir
    end

    local components = {}
    while true do
        local up, child = path.toparent(parse)
        if #child > 0 then
            table.insert(components, child .. "\\")
        else
            if #up > 0 then
                table.insert(components, up)
            end
            break
        end
        parse = up
    end

    local first = #components
    for i = first, 1, -1 do
        local child = components[i]
        local this_dir = path.join(parent, child)
        local special = not all and (i == 1 or i == #components or flexprompt.is_git_dir(this_dir))
        if special then
            s = path.join(s, child)
        else
            local text, abbreviated = abbrev_child(parent, child)
            if abbreviated and fluent then
                s = path.join(s, make_fluent_text(text, fluent))
            else
                s = path.join(s, text)
            end
        end
        parent = this_dir
    end

    dir = notrim and s or s:gsub("[/\\]+$", "")
    return dir
end

--------------------------------------------------------------------------------

local space_before = "space_before"
local space_after = "space_after"
local function addtext(segments, new_fg, text, padding)
    if text and text ~= "" then
        if padding == space_before then
            text = " "..text
        elseif padding == space_after then
            text = text.." "
        end
        table.insert(segments, (segments.bg or bg_default)..new_fg..text)
    end
end

local function can_use_powerline()
    return flexprompt.settings.powerline_font and not flexprompt.settings.no_graphics
end

local function addosep(segments, sep, new_bg)
    if not can_use_powerline() then
        table.insert(segments, new_bg.." ")
    elseif new_bg == segments.bg then
        table.insert(segments, segments.bg..fg_black..sep.sep[2]..fg_default)
    else
        table.insert(segments, transition_bg(sep.cap[1], new_bg, segments.bg or bg_default))
    end
    segments.bg = new_bg
end

local function addcsep(segments, sep, new_bg)
    if not can_use_powerline() then
        table.insert(segments, " "..new_bg)
    elseif new_bg == segments.bg then
        table.insert(segments, segments.bg..fg_black..sep.sep[1]..fg_default)
    else
        table.insert(segments, transition_bg(sep.cap[2], segments.bg or bg_default, new_bg))
    end
    segments.bg = new_bg
end

--local ellipsis_char = "…"
local ellipsis_char = ".."
local ellipsis_char_width = console.cellcount(ellipsis_char)

local function ellipsify(text, limit, fluent_restore_color)
    if console.cellcount(text) <= limit then
        return text
    end
    local s = ""
    local truncate = 0
    local total = 0
    local strings = console.explodeansi and console.explodeansi(text) or { text }
    for _,t in ipairs(strings) do
        if t:byte() == 27 then
            s = s .. t
        else
            for i in unicode.iter(t) do
                if total + ellipsis_char_width <= limit then
                    truncate = #s
                end
                total = total + console.cellcount(i)
                if total > limit then
                    s = s:sub(1, truncate)
                    if fluent_restore_color then
                        s = s..make_fluent_text(ellipsis_char, fluent_restore_color)
                    else
                        s = s..ellipsis_char
                    end
                    break
                end
                s = s..i
            end
        end
    end
    return s
end

local function collect_info()
    local info = {}
    local scm_info = flexprompt.get_scm_info()
    info.cwd = os.getcwd()
    if scm_info then
        for key, value in pairs(scm_info) do
            info[key] = value
        end
    end
    info.vpn = flexprompt.get_vpn_info()
    if info.status then
        info.working = info.status.working
        info.staged = info.status.staged
    end
    return info
end

--------------------------------------------------------------------------------

local prev_battery_level
local prev_battery_acpower
local battery_coroutine
local update_battery_prompt

local battery_ui = {
    charging_series = {
        nerdfonts2 = { "","","","","","","" },
        nerdfonts3 = { "󰢟","󰢜","󰂆","󰂇","󰂈","󰢝","󰂉","󰢞","󰂊","󰂋","󰂅" },
    },
    discharging_series = {
        nerdfonts2 = { "","","","","","","","","","","" },
        nerdfonts3 = { "󰂎","󰁺","󰁻","󰁼","󰁽","󰁾","󰁿","󰂀","󰂁","󰂂","󰁹" },
    },
    rainbow_colors =
    {
        { fg=sgr("38;2;239;65;54"),  bg=sgr("48;2;239;65;54")  },
        { fg=sgr("38;2;252;176;64"), bg=sgr("48;2;252;176;64") },
        { fg=sgr("38;2;248;237;50"), bg=sgr("48;2;248;237;50") },
        { fg=sgr("38;2;142;198;64"), bg=sgr("48;2;142;198;64") },
        { fg=sgr("38;2;1;148;68"),   bg=sgr("48;2;1;148;68")   },
    },
}

local function get_battery_color()
    local status = os.getbatterystatus()
    local level = status and status.level
    if not level then
        return ""
    end

    local index = ((((level > 0) and level or 1) - 1) / 20) + 1
    index = math.modf(index)
    return battery_ui.rainbow_colors[index], index == 1
end

local function get_battery_status()
    local wizard = flexprompt.get_wizard_state()

    local status = wizard and wizard.battery or os.getbatterystatus()
    local level = status.level
    local acpower = status.acpower
    local charging = status.charging

    -- Check for battery status failure.
    if not level or level < 0 or (acpower and not charging) then
        return (level or -1), "", "", acpower
    end

    if clink.addcoroutine and not battery_coroutine then
        prev_battery_level = level
        prev_battery_acpower = acpower
        battery_coroutine = coroutine.create(function()
            update_battery_prompt()
        end)
        clink.addcoroutine(battery_coroutine, 15)
    end

    local batt_symbol, level_symbol
    do
        local series = charging and battery_ui.charging_series or battery_ui.discharging_series
        if series then
            series = series[flexprompt.get_nerdfonts_version()]
            if series then
                level_symbol = series[math.floor(level * (#series - 1) / 100)]
                if flexprompt.get_nerdfonts_width() == 2 then
                    level_symbol = level_symbol .. " "
                end
            end
        end
        batt_symbol = flexprompt.get_symbol(charging and "charging" or "battery")
        level_symbol = level_symbol or ""
    end

    return level, batt_symbol, level_symbol, acpower
end

update_battery_prompt = function()
    while true do
        local level, _, _, acpower = get_battery_status()
        if prev_battery_level ~= level or prev_battery_acpower ~= acpower then
            clink.refilterprompt()
        end
        coroutine.yield()
    end
end

--------------------------------------------------------------------------------

local function get_exit_code(include_icons, hex)
    local value = flexprompt.get_errorlevel()
    if value then
        if math.abs(value) > (hex and 255 or 32767) then
            local lo = bit32.band(value, 0xffff)
            local hi = bit32.rshift(value, 16)
            if hi > 0 then
                hex = string.format("%x", hi) .. string.format("%04.4x", lo)
            else
                hex = string.format("%x", lo)
            end
            value = "0x"..hex
        end
        local text = tostring(value)
        if text ~= "0" then
            if include_icons then
                local icon = flexprompt.get_icon(text ~= "0" and "exit_nonzero" or "exit_zero")
                text = flexprompt.append_text(text, icon)
            end
            return text
        end
    end
end

local function get_duration(include_icons, duration_colon)
    local duration = flexprompt.get_duration()
    if not duration then
        return
    elseif not flexprompt.settings.force_duration and duration < (flexprompt.settings.duration_threshold or 3) then
        return
    end

    local h, m, s
    local t = math.floor(duration * 10) % 10
    duration = math.floor(duration)
    s = (duration % 60)
    duration = math.floor(duration / 60)
    if duration > 0 then
        m = (duration % 60)
        duration = math.floor(duration / 60)
        if duration > 0 then
            h = duration
        end
    end

    local text
    if duration_colon then
        if h then
            text = string.format("%u:%02u:%02u", h, m, s)
        else
            text = string.format("%u:%02u", (m or 0), s)
        end
        if flexprompt.settings.duration_invert_tenths then
            text = text.."."..t
        end
    else
        if flexprompt.settings.duration_invert_tenths then
            s = s.."."..t
        end
        text = s.."s"
        if m then
            text = flexprompt.append_text(m.."m", text)
            if h then
                text = flexprompt.append_text(h.."h", text)
            end
        end
    end

    if include_icons then
        text = flexprompt.append_text(text, flexprompt.get_icon("duration_module"))
    end
    return text
end

local function get_time(format, include_icons)
    local text = os.date(format, flexprompt.get_time())
    if include_icons then
        text = flexprompt.append_text(text, flexprompt.get_icon("time_module"))
    end
    return text
end

--------------------------------------------------------------------------------

local cached = {}

local sep = {
    cap=flexprompt.choices.caps[sep_shape or "round"] or { "", "" },
    sep=flexprompt.choices.separators[sep_shape or "round"] or { "", "" },
}

local function which_icon(info)
    if info.detached then
        return "detached"
    elseif info.unpublished then
        return "unpublished"
    elseif info.submodule then
        return "submodule"
    else
        return "branch"
    end
end

local function get_grays(darker)
    local gray1 = darker and bg_darkgray1 or bg_gray1
    local gray2 = darker and bg_darkgray2 or bg_gray2
    local gray3 = darker and bg_darkgray3 or bg_gray3
    return gray1, gray2, gray3
end

local function get_info()
    local wizard = flexprompt.get_wizard_state()
    if wizard then
        return {
            cwd = wizard.cwd,
            root = wizard.cwd,
            type = wizard.type,
            repo = wizard.cwd,
            branch = wizard.branch,
            ready = true,
        }
    end

    local info = flexprompt.promptcoroutine(collect_info)
    if info then
        info.refreshing = nil
        info.ready = true
        cached = info
    else
        cached.refreshing = true
    end
    return cached
end

local function render_tbubble(args) -- luacheck: no unused
    local wizard = flexprompt.get_wizard_state()
    if wizard then
        return
    end

    local text = os.getenv("CLINK_HISTORY_LABEL") or ""
    text = text:gsub("^ +", ""):gsub(" +$", "")
    if text == "" then
        return
    end

    local symbol = flexprompt.get_symbol("histlabel_module")
    if symbol and #symbol > 0 then
        text = flexprompt.append_text(symbol, text)
    elseif flexprompt.get_flow() == "fluent" then
        local pro = make_fluent_text("[History: ", fg_histlabel, fg_muted)
        local epi = make_fluent_text("]", fg_histlabel, fg_muted)
        text = pro .. text .. epi
    else
        text = "[History: " .. text .. "]"
    end
    return text, fg_histlabel, "black"
end

local function render_lbubble(args, shorten) -- luacheck: no unused
    local darker = flexprompt.parse_arg_keyword(args, "d", "darker") or flexprompt_bubbles.darker
    local include_icons = flexprompt.parse_arg_keyword(args, "i", "icons")
    local use_battery_level_icon = flexprompt.parse_arg_keyword(args, "li", "levelicon")
    local gray1, gray2, gray3 = get_grays(darker) -- luacheck: no unused

    local info = get_info()

    local segments = {}
    segments.bg = bg_default

    local scm_icon
    if info.type then
        scm_icon = flexprompt.get_symbol(string.lower(info.type.."_module"))
        if not scm_icon or scm_icon == "" then
            scm_icon = info.type
        end
    end

    local cwd_color = flexprompt.get_cwd_color(info.cwd)
    if not cwd_color and info.type then
        cwd_color = flexprompt.get_scm_color(info.type)
        if not cwd_color then
            cwd_color = (info.type == "git") and bg_git_default or bg_nongit_default
        end
    end
    cwd_color = cwd_color or bg_softblue

    local depth = flexprompt.get_dir_stack_depth()
    if #depth > 0 then
        local bg_depth = blend_color(cwd_color, bg_blendmute, 0.66) or gray3
        addosep(segments, sep, bg_depth)
        addtext(segments, fg_white, depth, space_after)
    end

    local cwd = flexprompt.maybe_apply_tilde(info.cwd)
    addosep(segments, sep, cwd_color)
    do
        local force_parent
        local full_cwd = flexprompt.parse_arg_keyword(args, "f", "fullcwd")
        local no_smart = flexprompt.is_no_smart_cwd and flexprompt.is_no_smart_cwd(info.cwd)
        if type(no_smart) == "string" then
            force_parent = no_smart
            no_smart = false
        end
        if not no_smart and info.type then
            local root, r_tilde = flexprompt.maybe_apply_tilde(force_parent or info.root)
            local parent, p_tilde = flexprompt.maybe_apply_tilde(path.toparent(force_parent or info.root))
            local can_smart = (root ~= parent and r_tilde == p_tilde)
            local smart = can_smart and cwd:sub(#parent + 1) or cwd
            smart = smart:gsub("^[\\/]+", ""):gsub("[\\/]+$", "")
            if shorten then
                smart = abbrev_path(smart, fg_white, nil, parent)
                if full_cwd then
                    parent = abbrev_path(parent, nil, true, nil, true)
                end
            end
            local drive = path.getdrive(info.cwd)
            if full_cwd then
                smart = make_fluent_text(path.join(parent, ""), fg_white)..smart
            elseif drive and drive:upper() ~= "C:" then
                smart = make_fluent_text(drive, fg_white).." "..smart
            else
                smart = fg_white..smart
            end
            addtext(segments, fg_black, flexprompt.append_text(scm_icon, smart))
        else
            local text = cwd
            if shorten then
                text = abbrev_path(text, fg_white)
            end
            if include_icons then
                local icon = flexprompt.get_icon("cwd_module")
                text = flexprompt.append_text(icon, text)
            end
            addtext(segments, fg_white, text)
        end
    end

    local fg_status
    if not info.ready then
        fg_status = fg_muted
    elseif info.working then
        fg_status = fg_yellow
    elseif info.unpublished then
        fg_status = fg_lavender
    else
        fg_status = fg_green
    end

    -- addcsep(segments, sep, gray1)

    if info._error then
        addcsep(segments, sep, bg_red)
        addtext(segments, fg_white, "error", space_before)
        addcsep(segments, sep, gray3)
    else
        addcsep(segments, sep, gray2)
        if info.type or info.branch or info.working or info.detached then
            local which = which_icon(info)
            local icon = flexprompt.get_symbol(which)
            if which == "detached" and (icon == "" or flexprompt.get_flow() == "fluent") then
                icon = make_fluent_text("detached", fg_status, fg_muted)
            end
            if info.refreshing and icon then
                local refresh = flexprompt.get_icon("refresh")
                if refresh and console.cellcount(refresh) == console.cellcount(icon) then
                    icon = refresh
                end
            end

            local branch
            if info.detached then
                branch = info.commit:sub(1, 8)
            else
                branch = info.branch
                if info.type == "git" and flexprompt_git and type(flexprompt_git.postprocess_branch) == "function" then
                    local modified = flexprompt_git.postprocess_branch(branch)
                    if modified then
                        branch = resolve_fluent_colors(modified, fg_fluent, fg_status)
                    end
                end
                if shorten then
                    local target = math.max(console.getwidth() / 4, 20)
                    if console.cellcount(branch) > target then
                        branch = ellipsify(branch, target - 4, fg_status) .. branch:sub(-4)
                    end
                end
            end

            local text = icon or ""
            text = flexprompt.append_text(text, branch)
            if not info.detached and info.remote and flexprompt.parse_arg_keyword(args, "sr", "showremote") then
                text = text..make_fluent_text("->", fg_status, fg_muted)..ellipsify(info.remote, 10)
            end
            addtext(segments, fg_status, text, space_before)
        end

        addcsep(segments, sep, info.conflict and bg_red or gray3)
        local ahead = info.ahead or "0"
        local behind = info.behind or "0"
        if info.working or info.staged or info.conflict or ahead ~= "0" or behind ~= "0" then
            if info.working or info.conflict then
                local text = ""
                if info.working and info.working.conflict > 0 then
                    text = fg_white.."!"..info.working.conflict
                elseif info.conflict then
                    text = fg_white.."!!"
                else
                    local count = info.working.add + info.working.modify + info.working.delete
                    if count > 0 then
                        local icon = flexprompt.get_symbol("summarycount")
                        text = flexprompt.append_text(text, icon..count)
                    end
                    if info.working.untracked > 0 then
                        local icon = flexprompt.get_symbol("untrackedcount")
                        text = flexprompt.append_text(text, icon..info.working.untracked)
                    end
                end
                addtext(segments, fg_status, text, space_before)
            end
            if info.staged or ahead ~= "0" or behind ~= "0" then
                local text = ""
                local fg
                if info.staged then
                    local count = info.staged.add + info.staged.modify + info.staged.delete + info.staged.rename
                    if count > 0 then
                        fg = fg_magenta
                        text = flexprompt.append_text(text, fg_magenta..flexprompt.get_symbol("staged")..count)
                    end
                end
                if ahead ~= "0" or behind ~= "0" then
                    local ab = ""
                    if ahead ~= "0" then
                        ab = flexprompt.append_text(ab, flexprompt.get_symbol("aheadcount")..ahead)
                    end
                    if behind ~= "0" then
                        ab = flexprompt.append_text(ab, flexprompt.get_symbol("behindcount")..behind)
                    end
                    if fg then
                        ab = fg_cyan..ab
                    else
                        fg = fg_cyan
                    end
                    text = flexprompt.append_text(text, ab)
                end
                if info.conflict then
                    addcsep(segments, sep, gray3)
                end
                addtext(segments, fg, text, space_before)
            end
        end
    end

    addcsep(segments, sep, bg_default)
    addtext(segments, "", fg_default)

    local prompt = table.concat(segments)

    local level, bsym, lsym, acpower = get_battery_status()
    if level >= 0 and (level < 100 or not acpower) then
        local color, critical = get_battery_color()
        if use_battery_level_icon and not critical and lsym and lsym ~= "" then
            level = lsym
        else
            level = tostring(level)..bsym
        end
        if critical then
            level = color.bg.."\x1b[1;97m "..level.." "
        else
            level = color.fg..level
        end
        prompt = level.."\x1b[m "..prompt
    end

    local ret = { text=prompt, color="black", altcolor="black" }
    if not shorten then
        ret.condense_callback = function()
            return render_lbubble(args, true)
        end
    end
    return ret
end

local function render_rbubble(args)
    local darker = flexprompt.parse_arg_keyword(args, "d", "darker") or flexprompt_bubbles.darker
    local include_icons = flexprompt.parse_arg_keyword(args, "i", "icons")
    local duration_colon = flexprompt.parse_arg_keyword(args, "c", "colons")
    local hex = flexprompt.parse_arg_keyword(args, "h", "hex")
    local format = flexprompt.parse_arg_token(args, "f", "format", true)
    if not format then
        format = "%a %H:%M"
    end

    local gray1, gray2, gray3 = get_grays(darker) -- luacheck: no unused
    local info = get_info()

    local segments = {}
    segments.bg = bg_default

    if info.vpn then
        local text = ""
        local num = 0
        for _, v in ipairs(info.vpn) do
            num = num + 1
            if num > 2 then
                text = text..fg_muted..","..fg_red.."+More"
                break
            end
            if text ~= "" then
                text = text..fg_muted..","
            end
            local vpn_color = sgr(flexprompt_bubbles.vpn_colors[v.type] or fg_vpn)
            text = text..vpn_color..v.name
        end
        if include_icons then
            text = flexprompt.append_text(text, flexprompt.get_icon("vpn_module"))
        end
        if text ~= "" then
            text = text.."\x1b[m"
        end
        addtext(segments, "", text, space_after)
    end

    addosep(segments, sep, gray3)
    addtext(segments, fg_red, get_exit_code(include_icons, hex), space_after)

    addosep(segments, sep, gray2)
    addtext(segments, fg_orange, get_duration(include_icons, duration_colon), space_after)

    -- addosep(segments, sep, gray1)

    addosep(segments, sep, bg_softgreen)
    addtext(segments, fg_white, get_time(format, include_icons))

    addcsep(segments, sep, bg_default)

    local prompt = table.concat(segments)
    return prompt, "black", "black"
end

local show_color_contrast = os.getenv("flexprompt_bubbles_color_contrast")

clink.onbeginedit(function()
    local cwd = os.getcwd()
    local detect = flexprompt.detect_scm() or {}
    if (cwd ~= cached.cwd or
            detect.root ~= cached.root or
            detect.type ~= cached.type or
            (detect.branch and detect.branch ~= cached.branch) or
            detect.detached ~= cached.detached or
            detect.commit ~= cached.commit) then
        cached = {
            cwd=cwd,
            root=detect.root,
            type=detect.type,
            branch=detect.branch,
            detached=detect.detached,
            commit=detect.commit
        }
    end

    battery_coroutine = nil

    if show_color_contrast then
        show_color_contrast = nil

        local bgs = { bg_softblue, bg_softgreen, bg_softmagenta, bg_git_default, bg_nongit_default, bg_red }
        if type(flexprompt.settings.cwd_colors) == "table" then
            for _, bg in ipairs(flexprompt.settings.cwd_colors) do
                table.insert(bgs, sgr(bg.color))
            end
        end
        if type(flexprompt.settings.scm_colors) == "table" then
            for _, color in pairs(flexprompt.settings.scm_colors) do
                table.insert(bgs, sgr(color))
            end
        end

        for _, bg in ipairs(bgs) do
            clink.print(bg.." "..fg_white.."hello/"..fg_fluent.."xyz"..fg_white.."/world "..sgr())
        end

        local grays = { bg_gray1, bg_gray2, bg_gray3 }
        local fgs = { fg_red, fg_orange, fg_yellow, fg_green, fg_cyan, fg_magenta, fg_lavender }
        for i, bg in ipairs(grays) do
            local s = ""
            for j = 0, 1 do
                if j > 0 then
                    s = s.." "
                end
                if j > 0 then
                    local dark_grays = { get_grays(true) }
                    bg = dark_grays[i]
                end
                local additional = " "
                for k, f in ipairs(fgs) do
                    additional = additional..f..tostring(k)..string.char(96 + k).." "
                end
                s = s..bg.." "..fg_white.."abc "..fg_muted.."mno"..fg_white.." xyz "..additional..sgr()
            end
            clink.print(s)
        end

        clink.print(sgr()..bg_default..fg_vpn.." vpn connection "..sgr())
        if flexprompt_bubbles.vpn_colors then
            for vpn, fg in pairs(flexprompt_bubbles.vpn_colors) do
                clink.print(sgr()..bg_default..sgr(fg).." "..vpn.." connection "..sgr())
            end
        end
    end
end)

--------------------------------------------------------------------------------

local swap_graphics_settings

local function swap_field(name, a, b)
    local tmp = a[name]
    a[name] = b[name]
    b[name] = tmp
end

-- luacheck: globals toggle_flexprompt_graphics
function toggle_flexprompt_graphics(rl_buffer) -- luacheck: no unused
    if not swap_graphics_settings then
        swap_graphics_settings = {}
        swap_graphics_settings.no_graphics = true
    end

    swap_field("no_graphics", flexprompt.settings, swap_graphics_settings)

    flexprompt.reset_render_state()
    clink.refilterprompt()
end
if rl.describemacro then
    rl.describemacro(
        "luafunc:toggle_flexprompt_graphics",
        "Toggle flexprompt graphics (e.g. to share copy/paste from terminal)")
end
if rl.getbinding and not rl.getbinding([["\e[27;8;90~"]]) then
    rl.setbinding([["\e[27;8;90~"]], [["luafunc:toggle_flexprompt_graphics"]])
end

--------------------------------------------------------------------------------

flexprompt.add_module("tbubble", render_tbubble)
flexprompt.add_module("lbubble", render_lbubble)
flexprompt.add_module("rbubble", render_rbubble)
