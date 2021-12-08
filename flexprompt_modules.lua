--------------------------------------------------------------------------------
-- Built in modules for flexprompt.

if ((clink and clink.version_encoded) or 0) < 10020010 then
    return
end

--------------------------------------------------------------------------------
-- Internals.

-- Is reset to {} at each onbeginedit.
local _cached_state = {}

local mod_brightcyan = { fg="96", bg="96", extfg="38;5;44", extbg="48;5;44" }
local mod_cyan = { fg="36", bg="46", extfg="38;5;6", extbg="48;5;6", lean=mod_brightcyan, classic=mod_brightcyan }
flexprompt.add_color("mod_cyan", mod_cyan)

--------------------------------------------------------------------------------
-- BATTERY MODULE:  {battery:show=show_level:breakleft:breakright}
--  - show_level shows the battery module unless the battery level is greater
--    than show_level.
--  - 'breakleft' adds an empty segment to left of battery in rainbow style.
--  - 'breakright' adds an empty segment to right of battery in rainbow style.
--
-- The 'breakleft' and 'breakright' options may look better than having battery
-- segment colors adjacent to other similarly colored segments in rainbow style.

local rainbow_battery_colors =
{
    {
        fg = "38;2;239;65;54",
        bg = "48;2;239;65;54"
    },
    {
        fg = "38;2;252;176;64",
        bg = "48;2;252;176;64"
    },
    {
        fg = "38;2;248;237;50",
        bg = "48;2;248;237;50"
    },
    {
        fg = "38;2;142;198;64",
        bg = "48;2;142;198;64"
    },
    {
        fg = "38;2;1;148;68",
        bg = "48;2;1;148;68"
    }
}

local function get_battery_status()
    local level, acpower, charging
    local batt_symbol = flexprompt.get_symbol("battery")

    local status = os.getbatterystatus()
    level = status.level
    acpower = status.acpower
    charging = status.charging

    if not level or level < 0 or (acpower and not charging) then
        return "", 0
    end
    if charging then
        batt_symbol = flexprompt.get_symbol("charging")
    end

    return level..batt_symbol, level
end

local function get_battery_status_color(level)
    if flexprompt.can_use_extended_colors() then
        local index = ((((level > 0) and level or 1) - 1) / 20) + 1
        index = math.modf(index)
        return rainbow_battery_colors[index], index == 1
    elseif level > 50 then
        return "green"
    elseif level > 30 then
        return "yellow"
    end
    return "red", true
end

local prev_battery_status, prev_battery_level
local function update_battery_prompt()
    while true do
        local status,level = get_battery_status()
        if prev_battery_level ~= status or prev_battery_level ~= level then
            clink.refilterprompt()
        end
        coroutine.yield()
    end
end

local function render_battery(args)
    if not os.getbatterystatus then return end

    local show = tonumber(flexprompt.parse_arg_token(args, "s", "show") or "100")
    local batteryStatus,level = get_battery_status()
    prev_battery_status = batteryStatus
    prev_battery_level = level

    if clink.addcoroutine and flexprompt.settings.battery_idle_refresh ~= false and not _cached_state.battery_coroutine then
        local t = coroutine.create(update_battery_prompt)
        _cached_state.battery_coroutine = t
        clink.addcoroutine(t, flexprompt.settings.battery_refresh_interval or 15)
    end

    -- Hide when on AC power and fully charged, or when level is less than or
    -- equal to the specified 'show=level' ({battery:show=75} means "show at 75
    -- or lower").
    if not batteryStatus or batteryStatus == "" or level > (show or 80) then
        return
    end

    local style = flexprompt.get_style()

    -- The 'breakleft' and 'breakright' args add blank segments to force a color
    -- break between rainbow segments, in case adjacent colors are too similar.
    local bl, br
    if style == "rainbow" then
        bl = flexprompt.parse_arg_keyword(args, "bl", "breakleft")
        br = flexprompt.parse_arg_keyword(args, "br", "breakright")
    end

    local color, warning = get_battery_status_color(level)

    if warning and style == "classic" then
        -- batteryStatus = flexprompt.make_fluent_text(sgr(color.bg .. ";30") .. batteryStatus)
        -- The "22;" defeats the color parsing that would normally generate
        -- corresponding fg and bg colors even though only an explicit bg color
        -- was provided (versus a usual {fg=x,bg=y} color table).
        color = "22;" .. color.bg .. ";30"
    end

    local segments = {}
    if bl then table.insert(segments, { "", "realblack" }) end
    table.insert(segments, { batteryStatus, color, "realblack" })
    if br then table.insert(segments, { "", "realblack" }) end

    return segments
end

--------------------------------------------------------------------------------
-- CWD MODULE:  {cwd:color=color_name,alt_color_name:rootcolor=rootcolor_name:type=type_name}
--  - color_name is a name like "green", or an sgr code like "38;5;60".
--  - alt_color_name is optional; it is the text color in rainbow style.
--  - rootcolor_name overrides the repo parent color when using "rootsmart".
--  - type_name is the format to use:
--      - "full" is the full path.
--      - "folder" is just the folder name.
--      - "smart" is the git repo\subdir, or the full path.
--      - "rootsmart" is the full path, with parent of git repo not colored.
--
-- The default type is "rootsmart" if not specified.

-- Returns the folder name of the specified directory.
--  - For c:\foo\bar it yields bar
--  - For c:\ it yields c:\
--  - For \\server\share\subdir it yields subdir
--  - For \\server\share it yields \\server\share
local function get_folder_name(dir)
    local parent,child = path.toparent(dir)
    dir = child
    if #dir == 0 then
        dir = parent
    end
    return dir
end

local function render_cwd(args)
    local colors = flexprompt.parse_arg_token(args, "c", "color")
    local color, altcolor
    local style = flexprompt.get_style()
    if style == "rainbow" then
        color = flexprompt.use_best_color("blue", "38;5;19")
    elseif style == "classic" then
        color = flexprompt.use_best_color("cyan", "38;5;39")
    else
        color = flexprompt.use_best_color("blue", "38;5;33")
    end
    color, altcolor = flexprompt.parse_colors(colors, color, altcolor)

    local wizard = flexprompt.get_wizard_state()
    local cwd = wizard and wizard.cwd or os.getcwd()
    local git_dir

    local sym
    local type = flexprompt.parse_arg_token(args, "t", "type") or "rootsmart"
    if wizard then
        -- Disable cwd/git integration in the configuration wizard.
    elseif type == "folder" then
        cwd = get_folder_name(cwd)
    else
        repeat
            if flexprompt.settings.use_home_tilde then
                local home = os.getenv("HOME")
                if home and string.find(string.lower(cwd), string.lower(home)) == 1 then
                    git_dir = flexprompt.get_git_dir(cwd) or false
                    if not git_dir then
                        cwd = "~" .. string.sub(cwd, #home + 1)
                        break
                    end
                end
            end

            if type == "smart" or type == "rootsmart" then
                if git_dir == nil then -- Don't double-hunt for it!
                    git_dir = flexprompt.get_git_dir()
                end
                if git_dir then
                    -- Get the root git folder name and reappend any part of the
                    -- directory that comes after.
                    -- Ex: C:\Users\username\some-repo\innerdir -> some-repo\innerdir
                    local git_root_dir = path.toparent(git_dir) -- Don't use get_parent() here!
                    local appended_dir = string.sub(cwd, string.len(git_root_dir) + 1)
                    local smart_dir = get_folder_name(git_root_dir) .. appended_dir
                    if type == "rootsmart" then
                        local rootcolor = flexprompt.parse_arg_token(args, "rc", "rootcolor")
                        local parent = cwd:sub(1, #cwd - #smart_dir)
                        cwd = flexprompt.make_fluent_text(parent, rootcolor or true) .. smart_dir
                    else
                        cwd = smart_dir
                    end
                    local tmp = flexprompt.get_icon("cwd_git_symbol")
                    sym = (tmp ~= "") and tmp or nil
                end
            end
        until true
    end

    cwd = flexprompt.append_text(flexprompt.get_dir_stack_depth(), cwd)
    cwd = flexprompt.append_text(sym or flexprompt.get_module_symbol(), cwd)

    return cwd, color, altcolor
end

--------------------------------------------------------------------------------
-- DURATION MODULE:  {duration:format=format_name:color=color_name,alt_color_name}
--  - format_name is the format to use:
--      - "colons" is "H:M:S" format.
--      - "letters" is "Hh Mm Ss" format (the default).
--  - color_name is a name like "green", or an sgr code like "38;5;60".
--  - alt_color_name is optional; it is the text color in rainbow style.

local endedit_time
local last_duration

-- Clink v1.2.30 has a fix for Lua's os.clock() implementation failing after the
-- program has been running more than 24 days.  Without that fix, os.time() must
-- be used instead, but the resulting duration can be off by up to +/- 1 second.
local duration_clock = ((clink.version_encoded or 0) >= 10020030) and os.clock or os.time

local function duration_onbeginedit()
    last_duration = nil
    if endedit_time then
        local beginedit_time = duration_clock()
        local elapsed = beginedit_time - endedit_time
        if elapsed >= 0 then
            last_duration = math.floor(elapsed)
        end
    end
end

local function duration_onendedit()
    endedit_time = duration_clock()
end

local function render_duration(args)
    local wizard = flexprompt.get_wizard_state()
    local duration = wizard and wizard.duration or last_duration
    if (duration or 0) < (flexprompt.settings.duration_threshold or 3) then return end

    local colors = flexprompt.parse_arg_token(args, "c", "color")
    local color, altcolor
    if flexprompt.get_style() == "rainbow" then
        color = flexprompt.use_best_color("yellow", "38;5;136")
        altcolor = "realblack"
    else
        color = flexprompt.use_best_color("darkyellow", "38;5;214")
    end
    color, altcolor = flexprompt.parse_colors(colors, color, altcolor)

    local h, m, s
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
    local format = flexprompt.parse_arg_token(args, "f", "format")
    if format and format == "colons" then
        if h then
            text = string.format("%u:%02u:%02u", h, m, s)
        else
            text = string.format("%u:%02u", (m or 0), s)
        end
    else
        text = s .. "s"
        if m then
            text = flexprompt.append_text(m .. "m", text)
            if h then
                text = flexprompt.append_text(h .. "h", text)
            end
        end
    end

    if flexprompt.get_flow() == "fluent" then
        text = flexprompt.append_text(flexprompt.make_fluent_text("took"), text)
    end
    text = flexprompt.append_text(text, flexprompt.get_module_symbol())

    return text, color, altcolor
end

--------------------------------------------------------------------------------
-- EXIT MODULE:  {exit:always:color=color_name,alt_color_name:hex}
--  - 'always' always shows the exit code even when 0.
--  - color_name is used when the exit code is 0, and is a name like "green", or
--    an sgr code like "38;5;60".
--  - alt_color_name is optional; it is the text color in rainbow style when the
--    exit code is 0.
--  - 'hex' forces hex display for values > 255 or < -255.  Otherwise hex
--    display is used for values > 32767 or < -32767.

local function render_exit(args)
    if not os.geterrorlevel then return end

    local text
    local value = flexprompt.get_errorlevel()

    local always = flexprompt.parse_arg_keyword(args, "a", "always")
    if not always and value == 0 then return end

    local hex = flexprompt.parse_arg_keyword(args, "h", "hex")

    if math.abs(value) > (hex and 255 or 32767) then
        local lo = bit32.band(value, 0xffff)
        local hi = bit32.rshift(value, 16)
        if hi > 0 then
            hex = string.format("%x", hi) .. string.format("%04.4x", lo)
        else
            hex = string.format("%x", lo)
        end
        text = "0x" .. hex
    else
        text = value
    end

    local style = flexprompt.get_style()
    local colors = flexprompt.parse_arg_token(args, "c", "color")
    local color, altcolor
    color = value ~= 0 and "exit_nonzero" or "exit_zero"
    color, altcolor = flexprompt.parse_colors(colors, color, altcolor)

    local sym = flexprompt.get_module_symbol()
    if sym == "" then
        sym = flexprompt.get_icon(value ~= 0 and "exit_nonzero" or "exit_zero")
    end
    text = flexprompt.append_text(sym, text)

    if flexprompt.get_flow() == "fluent" then
        text = flexprompt.append_text(flexprompt.make_fluent_text("exit"), text)
    end

    return text, color, altcolor
end

--------------------------------------------------------------------------------
-- GIT MODULE:  {git:nostaged:noaheadbehind:color_options}
--  - 'nostaged' omits the staged details.
--  - 'noaheadbehind' omits the ahead/behind details.
--  - 'showremote' shows the branch and its remote.
--  - color_options override status colors as follows:
--      - clean=color_name,alt_color_name           When status is clean.
--      - conflict=color_name,alt_color_name        When a conflict exists.
--      - dirty=color_name,alt_color_name           When status is dirty.
--      - remote=color_name,alt_color_name          For ahead/behind details.
--      - staged=color_name,alt_color_name          For staged details.
--      - unknown=color_name,alt_color_name         When status is unknown.
--      - unpublished=color_name,alt_color_name     When status is clean but branch is not published.

local git = {}
local cached_info = {}
local fetched_repos = {}

-- Add status details to the segment text.  Depending on git.status_details this
-- may show verbose counts for operations, or a concise overall count.
--
-- Synchronous call.
local function add_details(text, details)
    if git.status_details then
        if details.add > 0 then
            text = flexprompt.append_text(text, flexprompt.get_symbol("addcount") .. details.add)
        end
        if details.modify > 0 then
            text = flexprompt.append_text(text, flexprompt.get_symbol("modifycount") .. details.modify)
        end
        if details.delete > 0 then
            text = flexprompt.append_text(text, flexprompt.get_symbol("deletecount") .. details.delete)
        end
        if (details.rename or 0) > 0 then
            text = flexprompt.append_text(text, flexprompt.get_symbol("renamecount") .. details.rename)
        end
    else
        text = flexprompt.append_text(text, flexprompt.get_symbol("summarycount") .. (details.add + details.modify + details.delete + (details.rename or 0)))
    end
    if (details.untracked or 0) > 0 then
        text = flexprompt.append_text(text, flexprompt.get_symbol("untrackedcount") .. details.untracked)
    end
    return text
end

-- Collects git status info.
--
-- Uses async coroutine calls.
local function collect_git_info()
    if flexprompt.settings.git_fetch_interval then
        local git_dir = flexprompt.get_git_dir():lower()
        local when = fetched_repos[git_dir]
        if not when or os.clock() - when > flexprompt.settings.git_fetch_interval * 60 then
            local file = flexprompt.popenyield("git fetch 2>nul")
            if file then file:close() end

            fetched_repos[git_dir] = os.clock()
        end
    end

    local status = flexprompt.get_git_status()
    local conflict = flexprompt.get_git_conflict()
    local ahead, behind = flexprompt.get_git_ahead_behind()
    return { status=status, conflict=conflict, ahead=ahead, behind=behind, finished=true }
end

-- Expects the colors arg to follow this scheme:
-- All elements are by index:
--  1 = token
--  2 = alttoken
--  3 = color
--  4 = altcolor
--  5 = extended color
--  6 = extended altcolor
local function parse_color_token(args, colors)
    local parsed_colors = flexprompt.parse_arg_token(args, colors[1], colors[2])
    local color = flexprompt.use_best_color(colors[3], colors[5] or colors[3])
    local altcolor = flexprompt.use_best_color(colors[4], colors[6] or colors[4])
    color, altcolor = flexprompt.parse_colors(parsed_colors, color, altcolor)
    return color, altcolor
end

local git_colors =
{
    clean       = { "c",   "clean",        "vcs_clean",         },
    conflict    = { "!",   "conflict",     "vcs_conflict",      },
    dirty       = { "d",   "dirty",        "vcs_dirty",         },
    remote      = { "r",   "remote",       "vcs_remote",        },
    staged      = { "s",   "staged",       "vcs_staged",        },
    unknown     = { "u",   "unknown",      "vcs_unknown",       },
    unpublished = { "up",  "unpublished",  "vcs_unpublished",   },
}

local function render_git(args)
    local git_dir
    local branch, detached
    local info
    local wizard = flexprompt.get_wizard_state()

    if wizard then
        git_dir = true
        branch = wizard.branch or "main"
        info = { finished=true }
    else
        git_dir = flexprompt.get_git_dir()
        if not git_dir then return end

        branch, detached = flexprompt.get_git_branch(git_dir)
        if not branch then return end

        -- Discard cached info if from a different repo or branch.
        if (cached_info.git_dir ~= git_dir) or (cached_info.git_branch ~= branch) then
            cached_info = {}
            cached_info.git_dir = git_dir
            cached_info.git_branch = branch
        end

        -- Use coroutine to collect status info asynchronously.
        info = flexprompt.promptcoroutine(collect_git_info)

        -- Use cached info until coroutine is finished.
        if not info then
            info = cached_info.git_info or {}
        else
            cached_info.git_info = info
        end

        -- Add remote to branch name if requested.
        if flexprompt.parse_arg_keyword(args, "sr", "showremote") then
            local remote = flexprompt.get_git_remote(git_dir)
            if remote then
                branch = branch .. flexprompt.make_fluent_text("->") .. remote
            end
        end
    end

    -- Segments.
    local segments = {}

    -- Local status.
    local style = flexprompt.get_style()
    local flow = flexprompt.get_flow()
    local gitStatus = info.status
    local gitConflict = info.conflict
    local gitUnknown = not info.finished
    local gitUnpublished = not detached and gitStatus and gitStatus.unpublished
    local colors = git_colors.clean
    local color, altcolor
    local icon_name = "branch"
    if gitUnpublished then
        icon_name = "unpublished"
        colors = git_colors.unpublished
    end
    text = flexprompt.format_branch_name(branch, icon_name)
    if gitConflict then
        colors = git_colors.conflict
        text = flexprompt.append_text(text, flexprompt.get_symbol("conflict"))
    elseif gitStatus and gitStatus.working then
        colors = git_colors.dirty
        text = add_details(text, gitStatus.working)
    elseif gitUnknown then
        colors = git_colors.unknown
    end

    color, altcolor = parse_color_token(args, colors)
    table.insert(segments, { text, color, altcolor })

    -- Staged status.
    local noStaged = flexprompt.parse_arg_keyword(args, "ns", "nostaged")
    if not noStaged and gitStatus and gitStatus.staged then
        text = flexprompt.append_text("", flexprompt.get_symbol("staged"))
        colors = git_colors.staged
        text = add_details(text, gitStatus.staged)
        color, altcolor = parse_color_token(args, colors)
        table.insert(segments, { text, color, altcolor })
    end

    -- Remote status (ahead/behind).
    local noAheadBehind = flexprompt.parse_arg_keyword(args, "nab", "noaheadbehind")
    if not noAheadBehind then
        local ahead = info.ahead or "0"
        local behind = info.behind or "0"
        if ahead ~= "0" or behind ~= "0" then
            text = flexprompt.append_text("", flexprompt.get_symbol("aheadbehind"))
            colors = git_colors.remote
            if ahead ~= "0" then
                text = flexprompt.append_text(text, flexprompt.get_symbol("aheadcount") .. ahead)
            end
            if behind ~= "0" then
                text = flexprompt.append_text(text, flexprompt.get_symbol("behindcount") .. behind)
            end
            color, altcolor = parse_color_token(args, colors)
            table.insert(segments, { text, color, altcolor })
        end
    end

    return segments
end

--------------------------------------------------------------------------------
-- HG MODULE:  {hg:color_options}
--  - color_options override status colors as follows:
--      - clean=color_name,alt_color_name       When status is clean.
--      - dirty=color_name,alt_color_name       When status is dirty (modified files).

local hg_colors =
{
    clean       = { "c",  "clean",  "vcs_clean" },
    dirty       = { "d",  "dirty",  "vcs_conflict" },
}

local function get_hg_dir(dir)
    return flexprompt.scan_upwards(dir, function (dir)
        -- Return if it's a hg (Mercurial) dir.
        return flexprompt.has_dir(dir, ".hg")
    end)
end

local function render_hg(args)
    local hg_dir = get_hg_dir()
    if not hg_dir then return end

    -- We're inside of hg repo, read branch and status.
    local pipe = io.popen("hg branch 2>&1")
    local output = pipe:read('*all')
    local rc = { pipe:close() }

    -- Strip the trailing newline from the branch name.
    local n = #output
    while n > 0 and output:find("^%s", n) do n = n - 1 end
    local branch = output:sub(1, n)
    if not branch then return end
    if string.sub(branch,1,7) == "abort: " then return end
    if string.find(branch, "is not recognized") then return end

    local flow = flexprompt.get_flow()
    local text = flexprompt.format_branch_name(branch)

    local colors
    local pipe = io.popen("hg status -amrd 2>&1")
    local output = pipe:read('*all')
    local rc = { pipe:close() }
    if (output or "") ~= "" then
        text = flexprompt.append_text(text, flexprompt.get_symbol("modifycount"))
        colors = hg_colors.dirty
    else
        colors = hg_colors.clean
    end

    local color, altcolor = parse_color_token(args, colors)
    return text, color, altcolor
end

--------------------------------------------------------------------------------
-- MAVEN MODULE:  {maven:color=color_name,alt_color_name}
--  - color_name is a name like "green", or an sgr code like "38;5;60".
--  - alt_color_name is optional; it is the text color in rainbow style.

local function get_pom_xml_dir(dir)
    return flexprompt.scan_upwards(dir, function (dir)
        local pom_file = path.join(dir, "pom.xml")
        -- More efficient than opening the file.
        if os.isfile(pom_file) then return true end
    end)
end

local function render_maven(args)
    if get_pom_xml_dir() then
        local handle = io.popen('xmllint --xpath "//*[local-name()=\'project\']/*[local-name()=\'groupId\']/text()" pom.xml 2>NUL')
        local package_group = handle:read("*a")
        handle:close()
        if package_group == nil or package_group == "" then
            local parent_handle = io.popen('xmllint --xpath "//*[local-name()=\'project\']/*[local-name()=\'parent\']/*[local-name()=\'groupId\']/text()" pom.xml 2>NUL')
            package_group = parent_handle:read("*a")
            parent_handle:close()
            if not package_group then package_group = "" end
        end

        handle = io.popen('xmllint --xpath "//*[local-name()=\'project\']/*[local-name()=\'artifactId\']/text()" pom.xml 2>NUL')
        local package_artifact = handle:read("*a")
        handle:close()
        if not package_artifact then package_artifact = "" end

        handle = io.popen('xmllint --xpath "//*[local-name()=\'project\']/*[local-name()=\'version\']/text()" pom.xml 2>NUL')
        local package_version = handle:read("*a")
        handle:close()
        if package_version == nil or package_version == "" then
            local parent_handle = io.popen('xmllint --xpath "//*[local-name()=\'project\']/*[local-name()=\'parent\']/*[local-name()=\'version\']/text()" pom.xml 2>NUL')
            package_version = parent_handle:read("*a")
            parent_handle:close()
            if not package_version then package_version = "" end
        end

        local text = package_group .. ":" .. package_artifact .. ":" .. package_version
        text = flexprompt.append_text(flexprompt.get_module_symbol(), text)

        local color, altcolor = parse_color_token(args, { "c", "color", "mod_cyan" })
        return text, color, altcolor
    end
end

--------------------------------------------------------------------------------
-- MODMARK MODULE:  {modmark:color=color_name,alt_color_name:text=modmark_text}
--  - modmark_text provides a string to show when the current line is modified.
--      - The default is '*'.
--  - color_name is a name like "green", or an sgr code like "38;5;60".
--  - alt_color_name is optional; it is the text color in rainbow style.
--
-- Requires Clink v1.2.51 or higher.

local _modmark
local _modifiedline

local function modmark_onbeginedit()
    _modmark = nil
    _modifiedline = nil

    if rl.ismodifiedline then
        local left_prompt = flexprompt.settings.left_prompt or ""
        local right_prompt = flexprompt.settings.right_prompt or ""
        if left_prompt:match("{modmark[:}]") or right_prompt:match("{modmark[:}]") then
            _modmark = rl.isvariabletrue("mark-modified-lines")
            _modifiedline = rl.ismodifiedline()
            rl.setvariable("mark-modified-lines", "off")
        end
    end
end

if clink.onaftercommand and rl.ismodifiedline then
    local function modmark_aftercommand()
        if not _modmark then return end

        if rl.ismodifiedline() ~= _modifiedline then
            _modifiedline = rl.ismodifiedline()
            flexprompt.refilter_module("modmark")
            clink.refilterprompt()
        end
    end

    clink.onaftercommand(modmark_aftercommand)
end

local function render_modmark(args)
    local modmark
    local wizard = flexprompt.get_wizard_state()
    if wizard then
        modmark = wizard.modmark
    else
        modmark = rl.ismodifiedline()
    end

    if not modmark then
        return
    end

    local text = flexprompt.parse_arg_token(args, "t", "text") or "*"
    if not text or text == "" then
        return
    end

    local color, altcolor = parse_color_token(args, { "c", "color", "mod_cyan" })
    return text, color, altcolor
end

--------------------------------------------------------------------------------
-- NPM MODULE:  {npm:color=color_name,alt_color_name}
--  - color_name is a name like "green", or an sgr code like "38;5;60".
--  - alt_color_name is optional; it is the text color in rainbow style.

local function get_package_json_file(dir)
    return flexprompt.scan_upwards(dir, function (dir)
        local file = io.open(path.join(dir, "package.json"))
        if file then return file end
    end)
end

local function render_npm(args)
    local file = get_package_json_file()
    if not file then return end

    local package_info = file:read('*a')
    file:close()

    local package_name = string.match(package_info, '"name"%s*:%s*"(%g-)"') or ""
    local package_version = string.match(package_info, '"version"%s*:%s*"(.-)"') or ""

    local text = package_name .. "@" .. package_version
    text = flexprompt.append_text(flexprompt.get_module_symbol(), text)

    local color, altcolor = parse_color_token(args, { "c", "color", "mod_cyan" })
    return text, color, altcolor
end

--------------------------------------------------------------------------------
-- OVERTYPE MODULE:  {overtype:text=overtype_name,insert_name:color=c,a:overtypecolor=c,a:insertcolor=c,a}
--  - text provides strings to show in the is the format to use:
--      - "overtype_name" is shown when overtype mode is on.
--      - "insert_name" is shown when insert mode is on.
--      - An empty text makes the module not show up in the corresponding mode.
--  - color specifies the colors for both overtype and insert mode.
--      - c is a name like "green", or an sgr code like "38;5;60".
--      - a is optional; it is the text color in rainbow style.
--  - overtypecolor specifies the colors for overtype mode.
--      - c is a name like "green", or an sgr code like "38;5;60".
--      - a is optional; it is the text color in rainbow style.
--  - insertcolor specifies the colors for overtype mode.
--      - c is a name like "green", or an sgr code like "38;5;60".
--      - a is optional; it is the text color in rainbow style.
--
-- Requires Clink v1.2.50 or higher.

local function render_overtype(args)
    local overtype
    local wizard = flexprompt.get_wizard_state()
    if wizard then
        overtype = wizard.overtype
    else
        overtype = not rl.insertmode()
    end

    local text
    local name = flexprompt.parse_arg_token(args, "t", "text") or "OVERTYPE"
    local names = name:explode(",")
    text = names[(not overtype) and 2 or 1]
    if not text or text == "" then
        return
    end

    local colors
    if overtype then
        colors = flexprompt.parse_arg_token(args, "o", "overtypecolor")
    else
        colors = flexprompt.parse_arg_token(args, "i", "insertcolor")
    end
    colors = colors or flexprompt.parse_arg_token(args, "c", "color")

    local color, altcolor
    if flexprompt.get_style() == "rainbow" then
        color = flexprompt.use_best_color("yellow", "38;5;214")
        altcolor = "realblack"
    else
        color = flexprompt.use_best_color("darkyellow", "38;5;172")
    end
    color, altcolor = flexprompt.parse_colors(colors, color, altcolor)

    return text, color, altcolor
end

--------------------------------------------------------------------------------
-- PYTHON MODULE:  {python:always:color=color_name,alt_color_name}
--  - 'always' shows the python module even if there are no python files.
--  - color_name is a name like "green", or an sgr code like "38;5;60".
--  - alt_color_name is optional; it is the text color in rainbow style.

local function get_virtual_env(env_var)
    local venv_path = false

    -- Return the folder name of the current virtual env, or false.
    local function get_virtual_env_var(var)
        env_path = clink.get_env(var)
        return env_path and string.match(env_path, "[^\\/:]+$") or false
    end

    local venv = (env_var and get_virtual_env_var(env_var)) or
        get_virtual_env_var("VIRTUAL_ENV") or
        get_virtual_env_var("CONDA_DEFAULT_ENV") or false
    return venv
end

local function has_py_files(dir)
    return flexprompt.scan_upwards(dir, function (dir)
        for _ in pairs(os.globfiles(path.join(dir, "*.py"))) do
            return true
        end
    end)
end

local function render_python(args)
    -- flexprompt.python_virtual_env_variable can be nil.
    local venv = get_virtual_env(flexprompt.python_virtual_env_variable)
    if not venv then return end

    local always = flexprompt.parse_arg_keyword(args, "a", "always")
    if not always and not has_py_files() then return end

    local text = "[" .. venv .. "]"
    text = flexprompt.append_text(flexprompt.get_module_symbol(), text)

    local color, altcolor = parse_color_token(args, { "c", "color", "mod_cyan" })
    return text, color, altcolor
end

--------------------------------------------------------------------------------
-- SVN MODULE:  {hg:color_options}
--  - color_options override status colors as follows:
--      - clean=color_name,alt_color_name       When status is clean.
--      - dirty=color_name,alt_color_name       When status is dirty (modified files).

local svn_colors =
{
    clean       = { "c",  "clean",  "vcs_clean" },
    dirty       = { "d",  "dirty",  "vcs_conflict" },
}

local function get_svn_dir(dir)
    return flexprompt.scan_upwards(dir, function (dir)
        -- Return if it's a svn (Subversion) dir.
        local has = flexprompt.has_dir(dir, ".svn")
        if has then return has end
    end)
end

local function get_svn_branch()
    local file = io.popen("svn info 2>nul")
    for line in file:lines() do
        local m = line:match("^Relative URL:")
        if m then
            file:close()
            return line:sub(line:find("/")+1,line:len())
        end
    end
    file:close()
end

local function get_svn_status()
    local file = io.popen("svn status -q")
    for line in file:lines() do
        file:close()
        return true
    end
    file:close()
end

local function render_svn(args)
    local svn_dir = get_svn_dir()
    if not svn_dir then return end

    local branch = get_svn_branch()
    if not branch then return end

    local flow = flexprompt.get_flow()
    local text = flexprompt.format_branch_name(branch)

    local colors = svn_colors.clean
    if get_svn_status() then
        colors = svn_colors.dirty
        text = flexprompt.append_text(text, flexprompt.get_symbol("modifycount"))
    end

    local color, altcolor = parse_color_token(args, colors)
    return text, color, altcolor
end

--------------------------------------------------------------------------------
-- TIME MODULE:  {time:dim:color=color_name,alt_color_name:format=format_string}
--  - 'dim' uses dimmer default colors for rainbow style.
--  - color_name is a name like "green", or an sgr code like "38;5;60".
--  - alt_color_name is optional; it is the text color in rainbow style.
--  - format_string uses the rest of the text as a format string for os.date().
--
-- If present, the 'format=' option must be last (otherwise it could never
-- include colons).

local last_time

local function time_onbeginedit()
    last_time = nil
end

local function render_time(args)
    local wizard = flexprompt.get_wizard_state()
    if not wizard and last_time then
        return last_time[1], last_time[2], last_time[3]
    end

    local dim = flexprompt.parse_arg_keyword(args, "d", "dim")
    local colors = flexprompt.parse_arg_token(args, "c", "color")
    local color, altcolor
    if flexprompt.get_style() == "rainbow" then
        color = dim and "realbrightblack" or "realwhite"
        altcolor = dim and "realwhite" or "realblack"
    else
        color = { fg="36", bg="46", extfg="38;5;6", extbg="48;5;6" }
    end
    color, altcolor = flexprompt.parse_colors(colors, color, altcolor)

    local format = flexprompt.parse_arg_token(args, "f", "format", true)
    if not format then
        format = "%a %H:%M"
    end

    local text = os.date(format)

    if flexprompt.get_flow() == "fluent" then
        text = flexprompt.append_text(flexprompt.make_fluent_text("at"), text)
    end

    text = flexprompt.append_text(text, flexprompt.get_module_symbol())

    last_time = { text, color, altcolor }

    return text, color, altcolor
end

--------------------------------------------------------------------------------
-- USER MODULE:  {user:type=type_name:color=color_name,alt_color_name}
--  - type_name is any of 'computer', 'user', or 'both' (the default).
--  - color_name is a name like "green", or an sgr code like "38;5;60".
--  - alt_color_name is optional; it is the text color in rainbow style.

local function render_user(args)
    local colors = flexprompt.parse_arg_token(args, "c", "color")
    local color, altcolor
    local style = flexprompt.get_style()
    if style == "rainbow" then
        color = flexprompt.use_best_color("magenta", "38;5;90")
    elseif style == "classic" then
        color = flexprompt.use_best_color("magenta", "38;5;171")
    else
        color = flexprompt.use_best_color("magenta", "38;5;135")
    end
    color, altcolor = flexprompt.parse_colors(colors, color, altcolor)

    local type = flexprompt.parse_arg_token(args, "t", "type") or "both"
    local user = (type ~= "computer") and os.getenv("username") or ""
    local computer = (type ~= "user") and os.getenv("computername") or ""
    if #computer > 0 then
        local prefix = "@"
        -- if #user == 0 then prefix = "\\\\" end
        computer = prefix .. computer
    end

    local text = user..computer
    return text, color, altcolor
end

--------------------------------------------------------------------------------
-- VPN MODULE:  {color=color_name,alt_color_name}
--  - color_name is a name like "green", or an sgr code like "38;5;60".
--  - alt_color_name is optional; it is the text color in rainbow style.

local vpn_cached_info = {}

-- Collects connection info.
--
-- Uses async coroutine calls.
local function collect_vpn_info()
    local file = flexprompt.popenyield("rasdial 2>nul")
    local line
    local conns = {}

    -- Skip first line, which is always a header line.
    line = file:read("*l")
    if not line or line == "" then
        file:close()
        return {}
    end

    -- Read the rest of the lines.
    while true do
        line = file:read("*l")
        if not line then
            break
        end
        table.insert(conns, line)
    end

    -- If the spawned process returned a non-zero exit code, it failed.
    local ok,what,stat = file:close()
    if not ok then
        return {}
    end

    -- Discard the last line, which says the command completed successfully.
    table.remove(conns)
    if #conns == 0 then
        return {}
    end

    -- Concatenate the connection(s) into a string.
    line = ""
    for _,c in ipairs(conns) do
        if #line > 0 then line = line .. "," end
        line = line .. c
    end

    return { connection=line }
end

local function render_vpn(args)
    local info
    local wizard = flexprompt.get_wizard_state()

    if wizard then
        info = { connection="WORKVPN", finished=true }
    else
        -- Get connection status.
        info = flexprompt.promptcoroutine(collect_vpn_info)

        -- Use cached info until coroutine is finished.
        if not info then
            info = vpn_cached_info or {}
        else
            vpn_cached_info = info
        end
    end

    if not info or not info.connection then
        return
    end

    local colors = flexprompt.parse_arg_token(args, "c", "color")
    local color, altcolor
    local style = flexprompt.get_style()
    if style == "rainbow" then
        color = flexprompt.use_best_color("cyan", "38;5;67")
    elseif style == "classic" then
        color = flexprompt.use_best_color("cyan", "38;5;117")
    else
        color = flexprompt.use_best_color("cyan", "38;5;110")
    end
    color, altcolor = flexprompt.parse_colors(colors, color, altcolor)

    local text = info.connection
    if flexprompt.get_flow() == "fluent" then
        text = flexprompt.append_text(flexprompt.make_fluent_text("over"), text)
    end
    text = flexprompt.append_text(flexprompt.get_module_symbol(), text)

    return text, color, altcolor
end

--------------------------------------------------------------------------------
-- Event handlers.  Since this file contains multiple modules, let them all
-- share one event handler per event type, rather than adding separate handlers
-- for separate modules.

local function builtin_modules_onbeginedit()
    _cached_state = {}
    duration_onbeginedit()
    modmark_onbeginedit()
    time_onbeginedit()
end

local function builtin_modules_onendedit()
    duration_onendedit()
end

clink.onbeginedit(builtin_modules_onbeginedit)
clink.onendedit(builtin_modules_onendedit)

--------------------------------------------------------------------------------
-- Initialize the built-in modules.

flexprompt.add_module( "battery",   render_battery                      )
flexprompt.add_module( "cwd",       render_cwd,         { unicode="" } )
flexprompt.add_module( "duration",  render_duration,    { unicode="" } )
flexprompt.add_module( "exit",      render_exit                         )
flexprompt.add_module( "git",       render_git,         { unicode="" } )
flexprompt.add_module( "hg",        render_hg                           )
flexprompt.add_module( "maven",     render_maven                        )
flexprompt.add_module( "npm",       render_npm                          )
flexprompt.add_module( "python",    render_python,      { unicode="" } )
flexprompt.add_module( "svn",       render_svn                          )
flexprompt.add_module( "time",      render_time,        { unicode="" } )
flexprompt.add_module( "user",      render_user,        { unicode="" } )
flexprompt.add_module( "vpn",       render_vpn,         { unicode="" } )

if rl.insertmode then
flexprompt.add_module( "overtype",  render_overtype                     )
end

if rl.ismodifiedline then
flexprompt.add_module( "modmark",   render_modmark                      )
end
