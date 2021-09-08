--------------------------------------------------------------------------------
-- Clink requirements.
--
-- Notes:
--  - Transient prompt support requires Clink v1.2.29 or higher.
--  - Right prompt support requires Clink v1.2.24 or higher.
--  - Exit code support requires Clink v1.2.14 or higher.
--  - Async prompt filtering requires Clink v1.2.10 or higher.

if ((clink and clink.version_encoded) or 0) < 10020010 then
    print("clink-flex-prompt requires Clink v1.2.10 or higher.")
    return
end

--------------------------------------------------------------------------------
-- Internals.

flexprompt = flexprompt or {}
flexprompt.settings = flexprompt.settings or {}
flexprompt.settings.symbols = flexprompt.settings.symbols or {}
local modules

--------------------------------------------------------------------------------
-- Color codes.

flexprompt.colors =
{
    bold            = { fg="1"                  },
    default         = { fg="39",    bg="49"     },
    -- Normal low intensity colors.  Some styles brighten the normal low
    -- intensity colors; the "dark" versions are never brightened.
    black           = { fg="30",    bg="40",    lean="brightblack",     classic="brightblack",      },
    red             = { fg="31",    bg="41",    lean="brightred",       classic="brightred",        },
    green           = { fg="32",    bg="42",    lean="brightgreen",     classic="brightgreen",      },
    yellow          = { fg="33",    bg="43",    lean="brightyellow",    classic="brightyellow",     },
    blue            = { fg="34",    bg="44",    lean="brightblue",      classic="brightblue",       },
    magenta         = { fg="35",    bg="45",    lean="brightmagenta",   classic="brightmagenta",    },
    cyan            = { fg="36",    bg="46",    lean="brightcyan",      classic="brightcyan",       },
    white           = { fg="37",    bg="47",    lean="brightwhite",     classic="brightwhite",      },
    -- High intensity colors.
    brightblack     = { fg="90",    bg="100",   },
    brightred       = { fg="91",    bg="101",   },
    brightgreen     = { fg="92",    bg="102",   },
    brightyellow    = { fg="93",    bg="103",   },
    brightblue      = { fg="94",    bg="104",   },
    brightmagenta   = { fg="95",    bg="105",   },
    brightcyan      = { fg="96",    bg="106",   },
    brightwhite     = { fg="97",    bg="107",   },
    -- Low intensity colors.  Some styles brighten the normal low intensity
    -- colors; the "dark" versions are never brightened.
    darkblack       = { fg="30",    bg="40",    },
    darkred         = { fg="31",    bg="41",    },
    darkgreen       = { fg="32",    bg="42",    },
    darkyellow      = { fg="33",    bg="43",    },
    darkblue        = { fg="34",    bg="44",    },
    darkmagenta     = { fg="35",    bg="45",    },
    darkcyan        = { fg="36",    bg="46",    },
    darkwhite       = { fg="37",    bg="47",    },
}

--------------------------------------------------------------------------------
-- Configuration.

flexprompt.choices = {}

flexprompt.choices.charsets =
{
    ascii       = "ascii",
    unicode     = "unicode",
}

flexprompt.choices.styles =
{
    lean        = "lean",
    classic     = "classic",
    rainbow     = "rainbow",
}

flexprompt.choices.sides =
{
    left        = "left",
    both        = "both",
}

-- Default prompt strings based on styles and sides.
flexprompt.choices.prompts =
{
    lean        = { left = { "{battery}{cwd}{git}{duration}{time}" }, both = { "{battery}{cwd}{git}", "{exit}{duration}{time}" } },
    classic     = { left = { "{battery}{cwd}{git}{exit}{duration}{time}" }, both = { "{battery}{cwd}{git}", "{exit}{duration}{time}" } },
    rainbow     = { left = { "{battery:breakright}{cwd}{git}{exit}{duration}{time:color=brightblack,white}" }, both = { "{battery:breakright}{cwd}{git}", "{exit}{duration}{time}" } },
}

-- Only if style != lean.
flexprompt.choices.ascii_caps =
{
                --  Open    Close
    flat        = { "",     "",     separators="vertical" },
}

-- Only if style != lean.
flexprompt.choices.caps =
{
                --  Open    Close
    flat        = { "",     "",     separators="vertical" },
    pointed     = { "",    ""     },
    slant       = { "",    ""     },
    backslant   = { "",    ""     },
    round       = { "",    ""     },
    blurred     = { "░▒▓",  "▓▒░",  separators="vertical" },
}

-- Only if style == classic.
flexprompt.choices.ascii_separators =
{               --  Left    Right
    none        = { "",     ""      },
    vertical    = { "|",    "|"     },
    slant       = { "/",    "/"     },
    backslant   = { "\\",   "\\"    },
}

-- Only if style == classic.
flexprompt.choices.separators =
{               --  Left    Right
    none        = { "",     ""      },
    vertical    = { "│",    "│"     },
    pointed     = { "",    ""     },
    slant       = { "",    ""     },
    backslant   = { "",    ""     },
    round       = { "",    ""     },
    dot         = { "·",    "·"     },
    updiagonal  = { "╱",    "╱"     },
    downdiagonal= { "╲",    "╲"     },
}

flexprompt.choices.lines =
{
    one         = 1,
    two         = 2,
}

-- Only if lines > 1 and right_prompt is not nil.
flexprompt.choices.connections =
{
    disconnected= " ",
    dotted      = "·",
    solid       = "─",
}

-- Only if lines > 1.
flexprompt.choices.left_frames =
{
    none        = {},
    square      = { "┌─",   "└─"    },
    round       = { "╭─",   "╰─"    },
}

-- Only if lines > 1 and right_prompt is not nil.
flexprompt.choices.right_frames =
{
    none        = {},
    square      = { "─┐",   "─┘"    },
    round       = { "─╮",   "─╯"    },
}

-- Only if separators or connectors or frames.
local fc_frame = 1
local fc_back = 2
local fc_fore = 3
local fc_sep = 4
flexprompt.choices.frame_colors =
{               --  Frame       Back        Fore        Separator (optional; falls back to Frame)
    lightest    = { "38;5;244", "38;5;240", "38;5;248"  },
    light       = { "38;5;242", "38;5;238", "38;5;246"  },
    dark        = { "38;5;240", "38;5;236", "38;5;244"  },
    darkest     = { "38;5;238", "38;5;234", "38;5;242"  },
}

flexprompt.choices.spacing =
{
    compact     = "compact",
    normal      = "normal",
    sparse      = "sparse",
}

flexprompt.choices.flows =
{
    concise     = "concise",
    fluent      = "fluent",
}

flexprompt.choices.transient =
{
    "off",
    "same dir",
    "always",
}

-- Only if lines > 1 and left frame none, or if lines == 1 and style == lean, or if transient.
flexprompt.choices.prompt_symbols =
{
    angle       = { ">" }, -- unicode="❯" looks very good in some fonts, and is missing in some fonts.
    dollar      = { "$" },
    percent     = { "%" },
}

local symbols =
{
    branch          = {         unicode="" },
    conflict        = { "!" },
    addcount        = { "+" },
    modifycount     = { "*" },
    deletecount     = { "-" },
    renamecount     = { "" },   -- Empty string counts renames as modified.
    summarycount    = { "*",    unicode="±" },
    untrackedcount  = { "?" },
    aheadbehind     = { "" },    -- Optional symbol preceding ahead/behind counts.
    aheadcount      = { ">>",   unicode="↓" },
    behindcount     = { "<<",   unicode="↑" },
    staged          = { "#",    unicode="↗" },
    battery         = { "%" },
    charging        = { "++",   unicode="⚡" },
    prompt          = "angle",
    exit_zero       = nil,
    exit_nonzero    = nil,
}

--flexprompt.settings.battery_idle_refresh
--flexprompt.settings.use_home_tilde
--flexprompt.settings.prompt_symbol
--flexprompt.settings.prompt_symbol_color
--flexprompt.settings.exit_zero_color
--flexprompt.settings.exit_nonzero_color
--flexprompt.settings.exit_nonzero_color
--flexprompt.settings.symbols.cwd_git_symbol
--flexprompt.settings.symbols.{name}_module

--------------------------------------------------------------------------------
-- Wizard state.

local _in_wizard
local _screen_width
local _wizard_prefix = ""
local _cwd
local _duration
local _exit
local _git

local function get_errorlevel()
    return _exit or os.geterrorlevel()
end

--------------------------------------------------------------------------------
-- Configuration helpers.

local pad_right_edge = " "

local function csi(args, code)
    return "\x1b["..tostring(args)..code
end

local function sgr(args)
    if args then
        return "\x1b["..tostring(args).."m"
    else
        return "\x1b[m"
    end
end

local _can_use_extended_colors = nil
local function can_use_extended_colors(force)
    if _can_use_extended_colors == nil or force then
        _can_use_extended_colors = flexprompt.settings.use_8bit_color
        if _can_use_extended_colors == nil then
            _can_use_extended_colors = false
            if clink.getansihost then
                local host = clink.getansihost()
                if host == "winconsolev2" or host == "winterminal" then
                    _can_use_extended_colors = true
                end
            end
        end
    end
    return _can_use_extended_colors
end

local function get_style()
    -- Indexing into the styles table validates that the style name is
    -- recognized.
    return flexprompt.choices.styles[flexprompt.settings.style or "lean"] or "lean"
end

local function get_style_ground()
    return (get_style() == "rainbow") and "bg" or "fg"
end

local _charset
local function get_charset()
    if not _charset then
        -- Indexing into the charsets table validates that the charset name is
        -- recognized.
        _charset = flexprompt.choices.charsets[flexprompt.settings.charset or "unicode"] or "unicode"
    end
    return _charset
end

local function get_lines()
    return flexprompt.choices.lines[flexprompt.settings.lines or "one"] or 1
end

local function get_spacing()
    -- Indexing into the spacing table validates that the spacing name is
    -- recognized.
    return flexprompt.choices.spacing[flexprompt.settings.spacing or "normal"] or "normal"
end

local function get_connector()
    return flexprompt.choices.connections[flexprompt.settings.connection or "disconnected"] or " "
end

local function lookup_color(args, verbatim)
    if not args or type(args) == "table" then
        return args
    end

    if args and not args:match("^[0-9]") then
        local color = flexprompt.colors[args]
        if color then
            local redirect = color[get_style()]
            if redirect then
                color = flexprompt.colors[redirect]
            end
        end
        return color
    end

    local mode = args:sub(1,3)
    if mode == "38;" or mode == "48;" then
        args = args:sub(4)
        return { fg = "38;"..args, bg = "48;"..args }
    end

    -- Use the color even though it's not understood.  But not in rainbow style,
    -- because that can garble segment transitions.
    if get_style() ~= "rainbow" then
        return { fg = args, bg = args }
    end
end

local function get_frame()
    if not _charset then get_charset() end
    if _charset == "ascii" then return end

    local l = flexprompt.choices.left_frames[flexprompt.settings.left_frame or "none"]
    local r = flexprompt.choices.right_frames[flexprompt.settings.right_frame or "none"]
    if l and #l == 0 then
        l = nil
    end
    if r and #r == 0 then
        r = nil
    end
    return l, r
end

local function get_frame_color()
    local frame_color = flexprompt.settings.frame_color or "light"
    if type(frame_color) ~= table then
        frame_color = flexprompt.choices.frame_colors[frame_color] or frame_color
    end

    if type(frame_color) ~= "table" then
        frame_color = { frame_color, frame_color, frame_color }
    end

    frame_color =
    {
        lookup_color(frame_color[fc_frame]),
        lookup_color(frame_color[fc_back]),
        lookup_color(frame_color[fc_fore]),
        lookup_color(frame_color[fc_sep] or frame_color[fc_frame]),
    }

    return frame_color
end

local function get_symbol(name)
    local symbol = flexprompt.settings.symbols[name] or symbols[name] or ""
    if type(symbol) == "table" then
        if not _charset then get_charset() end
        symbol = symbol[_charset] or symbol[1] or ""
    end
    return symbol
end

local function get_icon(name)
    if not flexprompt.settings.use_icons then return "" end
    if type(flexprompt.settings.use_icons) == "table" and not flexprompt.settings.use_icons[name] then return "" end

    return get_symbol(name) or ""
end

local function get_prompt_symbol_color()
    local color
    if flexprompt.settings.prompt_symbol_color then
        color = flexprompt.settings.prompt_symbol_color
    elseif os.geterrorlevel then
        color = (get_errorlevel() == 0) and
                (flexprompt.settings.exit_zero_color or "brightgreen") or
                (flexprompt.settings.exit_nonzero_color or "brightred")
    else
        color = "brightwhite"
    end
    color = lookup_color(color)
    return sgr(color.fg)
end

local function get_prompt_symbol()
    local p = flexprompt.settings.symbols.prompt
    local symbol = flexprompt.choices.prompt_symbols[p or symbols.prompt] or p
    if type(symbol) == "table" then
        if not _charset then get_charset() end
        symbol = symbol[_charset] or symbol[1] or "?!"
    end
    return symbol
end

local function get_flow()
    -- Indexing into the flows table validates that the flow name is recognized.
    return flexprompt.choices.flows[flexprompt.settings.flow or "concise"] or "concise"
end

local function make_fluent_text(text, force)
    if not force and get_style() == "rainbow" then
        return text
    else
        return "\001" .. text .. "\002"
    end
end

local function get_screen_width()
    return _screen_width or console.getwidth()
end

local function connect(lhs, rhs, frame, sgr_frame_color)
    local lhs_len = console.cellcount(lhs)
    local rhs_len = console.cellcount(rhs)
    local frame_len = console.cellcount(frame)
    local width = get_screen_width() - #pad_right_edge
    local gap = width - (lhs_len + rhs_len + frame_len)
    if gap < 0 then
        gap = gap + rhs_len
        rhs_len = 0
        rhs = ""
        if gap < 0 then
            frame = ""
        end
    end
    if gap > 0 then
        if not sgr_frame_color then
            sgr_frame_color = sgr(flexprompt.colors.red.fg)
        end
        lhs = lhs .. sgr_frame_color .. string.rep(get_connector(), gap)
    end
    return lhs..rhs..frame
end

local function reset_cached_state()
    _can_use_extended_colors = nil
    _charset = nil

    _in_wizard = nil
    _screen_width = nil
    _wizard_prefix = ""
    _cwd = nil
    _duration = nil
    _exit = nil
    _git = nil
end

--------------------------------------------------------------------------------
-- Other helpers.

local function get_folder_name(dir)
    local parent,child = path.toparent(dir)
    dir = child
    if #dir == 0 then
        dir = parent
    end
    return dir
end

local function get_parent(dir)
    local parent = path.toparent(dir)
    if parent and parent ~= "" and parent ~= dir then
        return parent
    end
end

local function has_dir(dir, subdir)
    local test = path.join(dir, subdir)
    return os.isdir(test) and test or nil
end

local function has_file(dir, file)
    local test = path.join(dir, file)
    return os.isfile(test) and test or nil
end

local function append_text(lhs, rhs)
    if not lhs then return tostring(rhs) end
    if not rhs then return tostring(lhs) end

    lhs = tostring(lhs)
    rhs = tostring(rhs)

    if #lhs > 0 and #rhs > 0 then
        return lhs .. " " .. rhs
    else
        return lhs .. rhs
    end
end

--------------------------------------------------------------------------------
-- Segments.

local segmenter = nil

local function init_segmenter(side, frame_color)
    local charset = get_charset()
    local open_caps, close_caps, separators

    if side == 0 then
        open_caps = flexprompt.settings.tails or "flat"
        close_caps = flexprompt.settings.heads or "flat"
    else
        open_caps = flexprompt.settings.heads or "flat"
        close_caps = flexprompt.settings.tails or "flat"
    end
    if type(open_caps) ~= "table" then
        if charset == "ascii" then
            open_caps = flexprompt.choices.caps["flat"]
        else
            open_caps = flexprompt.choices.caps[open_caps]
        end
    end
    if type(close_caps) ~= "table" then
        if charset == "ascii" then
            close_caps = flexprompt.choices.caps["flat"]
        else
            close_caps = flexprompt.choices.caps[close_caps]
        end
    end

    segmenter = {}
    segmenter.side = side
    segmenter.style = get_style()
    segmenter.frame_color = frame_color
    segmenter.back_color = flexprompt.colors.default
    segmenter.open_cap = open_caps[1]
    segmenter.close_cap = close_caps[2]

    if segmenter.style == "lean" then
        segmenter.separator = " "
        segmenter.open_cap = ""
        segmenter.close_cap = ""
    else
        local available_caps = (charset == "ascii") and flexprompt.choices.ascii_caps or flexprompt.choices.caps
        local available_separators = (charset == "ascii") and flexprompt.choices.ascii_separators or flexprompt.choices.separators
        separators = flexprompt.settings.separators or flexprompt.settings.heads or "flat"
        if available_caps[separators] then
            local redirect = available_caps[separators].separators
            if redirect then
                separators = redirect
            end
        end
        if segmenter.style == "classic" then
            if type(separators) ~= "table" then
                separators = available_separators[separators] or available_separators["vertical"]
            else
                local custom = available_separators[separators[side + 1]]
                if custom then
                    separators = { custom[side + 1], custom[side] }
                end
            end
            segmenter.separator = separators[side + 1]
        elseif segmenter.style == "rainbow" then
            if type(separators) ~= "table" then
                local altseparators = available_separators[separators]
                if altseparators then
                    segmenter.altseparator = altseparators[side + 1]
                end
                separators = available_caps[separators] or available_caps["flat"]
            else
                local custom = available_caps[separators[side + 1]]
                if custom then
                    separators = { custom[side + 1], custom[side] }
                end
            end
            segmenter.separator = separators[2 - side]
        end
    end
end

local function color_segment_transition(color, symbol, close)
    if not symbol or symbol == "" then
        return ""
    end

    local swap
    if segmenter.style == "classic" then
        swap = close
    elseif segmenter.style == "rainbow" then
        swap = not close
        if not segmenter.open_cap and not close and segmenter.side == 0 then
            swap = false
        end
    end

    local fg = swap and "bg" or "fg"
    local bg = swap and "fg" or "bg"
    if segmenter.style == "rainbow" then
        if segmenter.back_color.bg == color.bg then
            return sgr(segmenter.frame_color[fc_sep].fg) .. segmenter.altseparator
        else
            return sgr(segmenter.back_color[fg] .. ";" .. color[bg]) .. symbol
        end
    else
        return sgr(segmenter.back_color[bg] .. ";" .. color[fg]) .. symbol
    end
end

local function apply_fluent_colors(text, base_color)
    local fluent_color = sgr((get_flow() == "lean") and nil or segmenter.frame_color[fc_fore].fg)
    return string.gsub(text, "\001", fluent_color):gsub("\002", base_color)
end

local function next_segment(text, color, rainbow_text_color)
    local out = ""

    if not color then
        color = flexprompt.colors.brightred
    end
    rainbow_text_color = lookup_color(rainbow_text_color or "white")
    if not rainbow_text_color then rainbow_text_color = flexprompt.colors.brightred end

    local sep
    local transition_color = color
    local back, fore
    local classic = segmenter.style == "classic"
    local rainbow = segmenter.style == "rainbow"

    if segmenter.open_cap then
        sep = segmenter.open_cap
        if classic then
            transition_color = segmenter.frame_color[fc_back]
            back = segmenter.frame_color[fc_back].bg
            fore = segmenter.frame_color[fc_fore].fg
        end
    else
        sep = segmenter.separator
        if classic then
            transition_color = segmenter.frame_color[fc_sep]
        end
    end

    local pad = (segmenter.style == "lean" -- Lean has no padding.
                 or text == "") -- Segment with empty string has no padding.
                 and "" or " "

    if not text then
        if segmenter.style ~= "lean" and not segmenter.open_cap then
            out = out .. color_segment_transition(color, segmenter.close_cap, true)
        end
        return out
    end

    out = out .. color_segment_transition(transition_color, sep)
    if fore then
        out = out .. sgr(back .. ";" .. fore)
    end

    -- A module with an empty string is a segment break.  When there's no
    -- separator, force a break by showing one connector character using the
    -- frame color.
    if text == "" and sep == "" and (rainbow or classic) then
        text = make_fluent_text(sgr(flexprompt.colors.default.bg) .. get_connector())
    end

    -- Applying 'color' goes last so that the module can override other colors
    -- if it really wants to.  E.g. by returning "41;30" as the color a module
    -- can force the segment color to be black on red, even in classic or lean
    -- styles.  But doing that in the rainbow style will garble segment
    -- transition colors.
    local base_color
    if rainbow then
        base_color = sgr(rainbow_text_color.fg .. ";" .. color.bg)
    elseif classic then
        base_color = sgr(segmenter.frame_color[fc_back].bg .. ";" .. color.fg)
    else
        base_color = sgr("49;" .. color.fg )
    end

    out = out .. base_color
    if pad ~= "" and not (classic and (sep == "" or sep == " ") and not segmenter.open_cap) then
        out = out .. pad
    end
    out = out .. apply_fluent_colors(text, base_color) .. pad

    if rainbow then
        segmenter.back_color = color
    elseif classic then
        segmenter.back_color = segmenter.frame_color[fc_back]
    end

    segmenter.open_cap = nil

    return out
end

--------------------------------------------------------------------------------
-- Coroutines.

local coroutines = {}

local function coroutines_onbeginedit()
    coroutines = {}
    _promptcoroutine = nil
end

local function promptcoroutine_manager()
    for _,entry in pairs(coroutines) do
        entry.func(true--[[async]])
    end
end

local function promptcoroutine(func)
    if not segmenter._current_module then return end

    local entry = coroutines[segmenter._current_module]
    if entry == nil then
        entry = { done=false, result=nil }
        coroutines[segmenter._current_module] = entry

        -- Wrap func to track completion and result.
        entry.func = function (async)
            local o = func(async)
            entry.done = true
            entry.result = o
        end

        local async = settings.get("prompt.async")
        if async then
            -- Create the prompt coroutine manager if needed.
            if not _promptcoroutine then
                _promptcoroutine = clink.promptcoroutine(promptcoroutine_manager)
            end
        else
            -- Create coroutine for running func synchronously.  We must
            -- maintain func's expectation that it is run as a coroutine, even
            -- when it's not being run asynchronously.
            local c = coroutine.create(function (async)
                entry.func(async)
            end)

            -- Run the coroutine synchronously.
            local max_iter = 25
            for iteration = 1, max_iter + 1, 1 do
                -- Pass false to let it know it is not async.
                local result, _ = coroutine.resume(c, false--[[async]])
                if result then
                    if coroutine.status(c) == "dead" then
                        break
                    end
                else
                    if _ and type(_) == "string" then
                        _error_handler(_)
                    end
                    break
                end
                -- Cap iterations when running synchronously, in case it's
                -- poorly behaved.
                if iteration >= max_iter then
                    -- Ideally this could print an error message about
                    -- abandoning a misbehaving coroutine, but that would mess
                    -- up the prompt and input line display.
                    break
                end
            end

            -- Update the entry indicating completion, even if the loop ended
            -- before func ever returned.
            entry.done = true
        end
    end

    return entry.result
end

--------------------------------------------------------------------------------
-- Module parsing and rendering.

local function render_module(name, args)
    local func = modules[string.lower(name)]
    if func then
        return func(args)
    end
end

local function render_modules(prompt, side, frame_color, anchors)
    local out = ""
    local init = 1

    init_segmenter(side, frame_color)

    while true do
        local s,e,cap = string.find(prompt, "{([^}]*)}", init)
        if not s then
            break
        end

        init = e + 1

        local args = nil
        local name = string.match(cap, "(%w+):")
        if name then
            args = string.sub(cap, #name + 2)
        else
            name = cap
        end

        segmenter._current_module = name

        if name and #name > 0 then
            local text,color,rainbow_text_color = render_module(name, args)
            if text then
                if anchors then
                    -- Add 1 because the separator isn't added yet.
                    anchors[1] = console.cellcount(out) + 1
                end

                local segments
                if type(text) ~= "table" then
                    -- No table provided.
                    segments = { { text, color, rainbow_text_color } }
                elseif type(text[1]) ~= "table" then
                    -- Table of non-tables provided.
                    segments = { text }
                else
                    -- Table of tables provided.
                    segments = text
                end
                for _,segment in pairs(segments) do
                    if segment then
                        out = out .. next_segment(segment[1], lookup_color(segment[2]), segment[3])
                    end
                end
            end
        end

        segmenter._current_module = nil
    end

    out = out .. next_segment(nil, flexprompt.colors.default)

    if anchors then
        anchors[2] = console.cellcount(out)
    end

    return out
end

local function render_prompts(settings, need_anchors)
    reset_cached_state()

    local old_settings = flexprompt.settings
    if settings then
        flexprompt.settings = settings
        if settings.wizard then
            local width = console.getwidth()
            reset_cached_state()
            _in_wizard = true
            _screen_width = settings.wizard.width or (width - 8)
            _wizard_prefix = ""
            if _screen_width < width then
                _wizard_prefix = string.rep(" ", (width - _screen_width) / 2)
            end
            _cwd = settings.wizard.cwd
            _duration = settings.wizard.duration
            _exit = settings.wizard.exit
            _git = settings.wizard.git

            -- Let the wizard know the width and prefix.
            settings.wizard.width = _screen_width
            settings.wizard.prefix = _wizard_prefix
        end
    end

    local style = get_style()
    local lines = get_lines()

    local left_prompt = flexprompt.settings.left_prompt
    local right_prompt = flexprompt.settings.right_prompt
    if not left_prompt and not right_prompt then
        local prompts = flexprompt.choices.prompts[style]["both"]
        left_prompt = prompts[1]
        right_prompt = prompts[2]
    end

    local left1 = ""
    local right1
    local rightframe1
    local left2 = nil
    local right2 = nil

    local anchors = need_anchors and {} or nil
    local left_frame, right_frame
    if lines > 1 then
        left_frame, right_frame = get_frame()
    end
    local frame_color = get_frame_color()
    local sgr_frame_color = sgr("0;" .. frame_color[fc_frame].fg) or nil

    -- Padding around left/right segments for lean style.
    local pad_frame = (style == "lean") and " " or ""

    -- Line 1 ----------------------------------------------------------------

    if true then
        left1 = render_modules(left_prompt or "", 0, frame_color, anchors)

        if left_frame then
            if left1 ~= "" then
                left1 = pad_frame .. left1
            end
            left1 = sgr_frame_color .. left_frame[1] .. left1
        end

        if lines == 1 then
            left1 = left1 .. sgr() .. " "
            if style == "lean" then
                left1 = left1 .. get_prompt_symbol_color() .. get_prompt_symbol() .. sgr() .. " "
            end
        end

        if right_prompt then
            right1 = render_modules(right_prompt, 1, frame_color)
        end

        if right_frame then
            rightframe1 = sgr_frame_color
            if right1 and right1 ~= "" then
                rightframe1 = rightframe1 .. pad_frame
            end
            rightframe1 = rightframe1 .. right_frame[1]
        end
    end

    -- Line 2 ----------------------------------------------------------------

    if lines > 1 then
        left2 = ""
        right2 = ""

        if left_frame then
            left2 = left2 .. sgr_frame_color .. left_frame[2]
        end
        if not left_frame or style == "lean" then
            left2 = left2 .. get_prompt_symbol_color() .. get_prompt_symbol()
        end

        left2 = left2 .. sgr() .. " "

        if right_frame then
            right2 = right2 .. sgr_frame_color .. right_frame[2]
        end
    end

    -- Combine segments ------------------------------------------------------

    local prompt = left1
    local rprompt

    if lines == 1 then
        prompt = _wizard_prefix .. prompt
        rprompt = right1
    else
        rprompt = right2
        if right1 or right_frame then
            if style == "lean" then
                -- Padding around left/right segments for lean style.
                if left1 and #left1 > 0 then left1 = left1 .. " " end
                if right1 and #right1 > 0 then right1 = " " .. right1 end
            end
            prompt = connect(left1 or "", right1 or "", rightframe1 or "", sgr_frame_color)
        end
        prompt = _wizard_prefix .. prompt .. sgr() .. "\r\n" .. _wizard_prefix .. left2
    end

    if rprompt and #rprompt > 0 then
        rprompt = rprompt .. sgr() .. pad_right_edge
    end

    if get_spacing() == "sparse" and not _in_wizard then
        prompt = sgr() .. "\r\n" .. prompt
    end

    if settings then flexprompt.settings = old_settings end

    if need_anchors then
        local left_frame_len = left_frame and console.cellcount(left_frame[1]) or 0
        if anchors[1] then
            anchors[1] = #_wizard_prefix + left_frame_len + anchors[1]
        end
        if anchors[2] then
            anchors[2] = #_wizard_prefix + left_frame_len + anchors[2]
        end
        if rightframe1 then
            anchors[3] = #_wizard_prefix + _screen_width + - #pad_right_edge - console.cellcount(rightframe1)
        end
    end

    return prompt, rprompt, anchors
end

local function render_transient_prompt()
    return get_prompt_symbol_color() .. get_prompt_symbol() .. sgr() .. " "
end

function flexprompt.render_wizard(settings, need_anchors)
    local left, right, anchors = render_prompts(settings, need_anchors)
    local col
    if not right or right == "" then
        right = nil
    else
        col = #_wizard_prefix + (_screen_width - console.cellcount(right)) + 1
    end
    return left, right, col, anchors
end

flexprompt.render_transient_wizard = render_transient_prompt

--------------------------------------------------------------------------------
-- Build prompt.

local pf = clink.promptfilter(5)
local continue_filtering = nil

if CMDER_SESSION then
    -- Halt further prompt filtering when used with Cmder.  This ensures our
    -- prompt replaces the Cmder default prompt.
    continue_filtering = false

    -- Disable the Cmder prompt's version control status, since it's expensive
    -- and we supersede it with our own prompt text.  It should be unreachable
    -- because of setting continue_filtering = false, but is still included for
    -- extra thoroughness.
    prompt_includeVersionControl = false
end

local right

function pf:filter(prompt)
    prompt, right = render_prompts()
    return prompt
end

function pf:rightfilter(prompt)
    return right or "", continue_filtering
end

function pf:transientfilter(prompt)
    return render_transient_prompt()
end

function pf:transientrightfilter(prompt)
    return "", continue_filtering
end

-- Capture the $+ dir stack depth if present at the beginning of PROMPT.
local dirStackDepth
local plus_capture = clink.promptfilter(1)
function plus_capture:filter(prompt)
    dirStackDepth = ""
    local plusBegin, plusEnd = prompt:find("^[+]+")
    if plusBegin == nil then
        plusBegin, plusEnd = prompt:find("[\n][+]+")
        if plusBegin then
            plusBegin = plusBegin + 1
        end
    end
    if plusBegin ~= nil then
        dirStackDepth = prompt:sub(plusBegin, plusEnd).." "
    end
end

-- Consume blank lines before the prompt.  Powerlevel10k doesn't consume blank
-- lines, but CMD causes blank lines more often than zsh does, so to achieve a
-- similar effect it's necessary to consume blank lines.
local function spacing_onbeginedit()
    if get_spacing() ~= "normal" then
        local text
        local line = console.getnumlines() - 1
        local up = 0
        while line > 0 do
            text = console.getlinetext(line)
            if not text or #text ~= 0 then
                break
            end
            up = up + 1
            line = line - 1
        end
        if up > 0 then
            clink.print("\x1b[" .. up .. "A\x1b[J", NONL)
        end
    end
end

--------------------------------------------------------------------------------
-- Public API.

-- Add a module.
-- E.g. flexprompt.add_module("xyz", xyz_render) calls the xyz_render function
-- when "{xyz}" or "{xyz:args}" is encountered in a prompt string.  The function
-- receives "args" as its only argument.
function flexprompt.add_module(name, func)
    modules[string.lower(name)] = func
end

-- Add a named color.
-- Named colors must be a table { fg=_sgr_code_, bg=_sgr_code_ }.
-- The fg and bg are needed for the rainbow style to properly color transitions
-- between segments.
function flexprompt.add_color(name, fore, back)
    flexprompt.colors[name] = { fg=fore, bg=back }
end

-- Function to get the prompt style.
flexprompt.get_style = get_style

-- Function to get the prompt flow.
flexprompt.get_flow = get_flow

-- Get an SGR string to apply the named color as either a foreground or
-- background color, depending on the style (rainbow style applies colors as
-- background colors).
function flexprompt.get_styled_sgr(name)
    local color = lookup_color(name)
    if color then
        return sgr(color[get_style_ground()])
    end
    return ""
end

-- Parse arg "abc:def=mno:xyz" for token "def" returns value "xyz".
function flexprompt.parse_arg_token(args, name, altname, include_colon)
    if not args then
        return
    end

    args = ":" .. args .. (include_colon and "" or ":")

    local value
    if name then
        local pat = include_colon and "=(.*)" or "=([^:]*):"
        value = string.match(args, ":" .. name .. pat)
        if not value and altname then
            value = string.match(args, ":" .. altname .. pat)
        end
    end

    return value
end

-- Parsing arg "abc:def=mno:xyz" for a keyword like "abc" or "xyz" returns true.
function flexprompt.parse_arg_keyword(args, name, altname)
    if not args then
        return
    end

    args = ":" .. args .. ":"

    local value
    if name then
        value = string.match(args, ":" .. name .. ":")
        if not value and altname then
            value = string.match(args, ":" .. altname .. ":")
        end
    end

    return value
end

-- Parsing text "white,cyan" returns "white", "cyan".
function flexprompt.parse_colors(text, default, altdefault)
    local color, altcolor = default, altdefault
    if text then
        if string.find(text, ",") then
            color, altcolor = string.match(text, "([^,]+),([^,]+)")
        else
            color = text
        end
    end
    return color, altcolor
end

-- Function that takes (text) and surrounds it with control codes to apply
-- fluent coloring to the text.
flexprompt.make_fluent_text = make_fluent_text

-- Function that takes (lhs, rhs) and appends them together with a space in
-- between.  If either string is empty or nil, the other string is returned
-- (without appending them).
flexprompt.append_text = append_text

-- Function to check whether extended colors are available (256 color and 24 bit
-- color codes).
flexprompt.can_use_extended_colors = can_use_extended_colors

-- Function that takes (name) and retrieves the named icon (same as get_symbol,
-- but only gets the symbol if flexprompt.settings.use_icons is true).
flexprompt.get_icon = get_icon

-- Function that takes (name) and retrieves the named symbol.
flexprompt.get_symbol = get_symbol

-- Function to get customizable symbol for current module (only gets the symbol
-- if flexprompt.settings.use_icons is true).
function flexprompt.get_module_symbol()
    local s = ""
    if segmenter and segmenter._current_module then
        local name = segmenter._current_module .. "_module"
        s = flexprompt.get_icon(name)
    end
    return s
end

-- Function that takes (dir, subdir) and returns "dir\subdir" if the subdir
-- exists, otherwise it returns nil.
flexprompt.has_dir = has_dir

-- Function that takes (dir, file) and returns "dir\file" if the file exists,
-- otherwise it returns nil.
flexprompt.has_file = has_file

-- Function that walks up from dir, looking for scan_for in each directory.
-- Starting with dir (or cwd if dir is nil), this invokes scan_func(dir), which
-- can check for a subdir or a file or whatever it wants to check.
-- NOTE:  scan_func(dir) must return nil to keep scanning upwards; any other
-- value (including false) is returned to the caller.
function flexprompt.scan_upwards(dir, scan_func)
    -- Set default path to current directory.
    if not dir or dir == '.' then dir = os.getcwd() end

    repeat
        -- Call the supplied function.
        local result = scan_func(dir)
        if result ~= nil then return result end

        -- Walk up to parent path.
        local parent = get_parent(dir)
        dir = parent
    until not dir
end

-- Function to register a module's prompt coroutine.
-- IMPORTANT:  Use this instead of clink.promptcoroutine()!
flexprompt.promptcoroutine = promptcoroutine

--------------------------------------------------------------------------------
-- Internal helpers.

local function load_ini(fileName)
    -- This function is based on https://github.com/Dynodzzo/Lua_INI_Parser/blob/master/LIP.lua
    local file = io.open(fileName, 'r')
    if not file then return nil end

    local data = {};
    local section;
    for line in file:lines() do
        local tempSection = line:match('^%[([^%[%]]+)%]$');
        if tempSection then
            section = tonumber(tempSection) and tonumber(tempSection) or tempSection;
            data[section] = data[section] or {}
        end

        local param, value = line:match('^%s-([%w|_]+)%s-=%s+(.+)$')
        if param and value ~= nil then
            if tonumber(value) then
                value = tonumber(value);
            elseif value == 'true' then
                value = true;
            elseif value == 'false' then
                value = false;
            end
            if tonumber(param) then
                param = tonumber(param);
            end
            data[section][param] = value
        end
    end
    file:close();
    return data;
end

local git_config = {}
function git_config.load(git_dir)
    git_config.config = git_dir and load_ini(path.join(git_dir, 'config')) or nil
    return git_config.config
end
function git_config.get(section, param)
    if not git_config.config then return end
    if (not param) or (not section) then return end
    return git_config.config[section] and git_config.config[section][param] or nil
end

--------------------------------------------------------------------------------
-- Public API; git functions.

-- Test whether dir is part of a git repo.
-- @return  nil for not in a git repo, or the name of a git dir or file.
--
-- Synchronous call.
function flexprompt.get_git_dir(dir)
    local function has_git_file(dir)
        local dotgit = path.join(dir, '.git')
        local gitfile
        if os.isfile(dotgit) then
            gitfile = io.open(dotgit)
        end
        if not gitfile then return end

        local git_dir = gitfile:read():match('gitdir: (.*)')
        gitfile:close()

        -- gitdir can (apparently) be absolute or relative:
        local file_when_absolute = git_dir and os.isdir(git_dir) and git_dir
        if file_when_absolute then
            -- Don't waste time calling os.isdir on a potentially relative path
            -- if we already know it's an absolute path.
            return file_when_absolute
        end
        local rel_dir = path.join(dir, git_dir)
        local file_when_relative = git_dir and os.isdir(rel_dir) and rel_dir
        if file_when_relative then
            return file_when_relative
        end
    end

    return flexprompt.scan_upwards(dir, function (dir)
        -- Return if it's a git dir.
        return has_dir(dir, ".git") or has_git_file(dir)
    end)
end

-- Get the name of the current branch.
-- @return  branch name.
--
-- Synchronous call.
function flexprompt.get_git_branch(git_dir)
    git_dir = git_dir or flexprompt.get_git_dir()

    -- If git directory not found then we're probably outside of repo or
    -- something went wrong.  The same is when head_file is nil.
    local head_file = git_dir and io.open(path.join(git_dir, 'HEAD'))
    if not head_file then return end

    local HEAD = head_file:read()
    head_file:close()

    -- If HEAD matches branch expression, then we're on named branch otherwise
    -- it is a detached commit.
    local branch_name = HEAD:match('ref: refs/heads/(.+)')

    return branch_name or 'HEAD detached at '..HEAD:sub(1, 7)
end

-- Get the status of working dir.
-- @return  nil for clean, or a table with dirty counts.
--
-- Uses async coroutine call.
function flexprompt.get_git_status()
    local file = io.popenyield("git --no-optional-locks status --porcelain 2>nul")
    local w_add, w_mod, w_del, w_unt = 0, 0, 0, 0
    local s_add, s_mod, s_del, s_ren = 0, 0, 0, 0

    for line in file:lines() do
        local kindStaged, kind = string.match(line, "(.)(.) ")

        if kind == "A" then
            w_add = w_add + 1
        elseif kind == "M" then
            w_mod = w_mod + 1
        elseif kind == "D" then
            w_del = w_del + 1
        elseif kind == "?" then
            w_unt = w_unt + 1
        end

        if kindStaged == "A" then
            s_add = s_add + 1
        elseif kindStaged == "M" then
            s_mod = s_mod + 1
        elseif kindStaged == "D" then
            s_del = s_del + 1
        elseif kindStaged == "R" then
            s_ren = s_ren + 1
        end
    end
    file:close()

    if flexprompt.get_symbol("renamecount") == "" then
        s_mod = s_mod + s_ren
        s_ren = 0
    end

    local working
    local staged

    if w_add + w_mod + w_del + w_unt > 0 then
        working = {}
        working.add = w_add
        working.modify = w_mod
        working.delete = w_del
        working.untracked = w_unt
    end

    if s_add + s_mod + s_del + s_ren > 0 then
        staged = {}
        staged.add = s_add
        staged.modify = s_mod
        staged.delete = s_del
        staged.rename = s_ren
    end

    local status
    if working or staged then
        status = {}
        status.working = working
        status.staged = staged
    end
    return status
end

-- Gets the number of commits ahead/behind from upstream.
-- @return  ahead, behind.
--
-- Uses async coroutine call.
function flexprompt.get_git_ahead_behind()
    local file = io.popenyield("git rev-list --count --left-right @{upstream}...HEAD 2>nul")
    local ahead, behind = "0", "0"

    for line in file:lines() do
        ahead, behind = string.match(line, "(%d+)[^%d]+(%d+)")
    end
    file:close()

    return ahead, behind
end

-- Gets the conflict status.
-- @return  true for conflict, or false for no conflicts.
--
-- Uses async coroutine call.
function flexprompt.get_git_conflict()
    local file = io.popenyield("git diff --name-only --diff-filter=U 2>nul")

    for line in file:lines() do
        file:close()
        return true;
    end
    file:close()

    return false
end

-- Gets remote for current branch.
-- @return  remote name, or nil if not found.
--
-- Synchronous call.
function flexprompt.get_git_remote(git_dir)
    if not git_dir then return end

    local branch = flexprompt.get_git_branch(git_dir)
    if not branch then return end

    -- Load git config info.
    if not git_config.load(git_dir) then return end

    -- For remote and ref resolution algorithm see https://git-scm.com/docs/git-push.
    local remote_to_push = git_config.get('branch "' .. branch .. '"', 'remote') or ''
    local remote_ref = git_config.get('remote "' .. remote_to_push .. '"', 'push') or git_config.get('push', 'default')

    local remote = remote_to_push
    if remote_ref then remote = remote .. '/' .. remote_ref end

    if remote ~= '' then
        return remote
    end
end

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

local cached_battery_coroutine
local function render_battery(args)
    if not os.getbatterystatus then return end

    local show = tonumber(flexprompt.parse_arg_token(args, "s", "show") or "100")
    local batteryStatus,level = get_battery_status()
    prev_battery_status = batteryStatus
    prev_battery_level = level

    if flexprompt.settings.battery_idle_refresh ~= false and not cached_battery_coroutine then
        local t = coroutine.create(update_battery_prompt)
        cached_battery_coroutine = t
        clink.addcoroutine(t, flexprompt.settings.battery_refresh_interval or 15)
    end

    -- Hide when on AC power and fully charged, or when level is less than or
    -- equal to the specified 'show=level' ({battery:show=75} means "show at 75
    -- or lower").
    if not batteryStatus or batteryStatus == "" or level > (show or 80) then
        return
    end

    local style = get_style()

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
    if bl then table.insert(segments, { "", "black" }) end
    table.insert(segments, { batteryStatus, color, "black" })
    if br then table.insert(segments, { "", "black" }) end

    return segments
end

--------------------------------------------------------------------------------
-- CWD MODULE:  {cwd:color=color_name,alt_color_name:type=type_name}
--  - color_name is a name like "green", or an sgr code like "38;5;60".
--  - alt_color_name is optional; it is the text color in rainbow style.
--  - type_name is the format to use:
--      - "full" is the full path.
--      - "folder" is just the folder name.
--      - "smart" is the git repo\subdir, or the full path.
--      - "rootsmart" is the full path, with parent of git repo not colored.
--
-- The default type is "rootsmart" if not specified.

local function render_cwd(args)
    local colors = flexprompt.parse_arg_token(args, "c", "color")
    local color, altcolor
    local style = flexprompt.get_style()
    if style == "rainbow" then
        color = "blue"
        altcolor = "white"
    elseif style == "classic" then
        color = flexprompt.can_use_extended_colors() and "38;5;39" or "cyan"
    else
        color = flexprompt.can_use_extended_colors() and "38;5;33" or "blue"
    end
    color, altcolor = flexprompt.parse_colors(colors, color, altcolor)

    local cwd = _cwd or os.getcwd()
    local git_dir

    local sym
    local type = flexprompt.parse_arg_token(args, "t", "type") or "rootsmart"
    if _cwd then
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
                        cwd = flexprompt.make_fluent_text(cwd:sub(1, #cwd - #smart_dir), true) .. smart_dir
                    else
                        cwd = smart_dir
                    end
                    sym = flexprompt.get_icon("cwd_git_symbol")
                end
            end
        until true
    end

    cwd = append_text(sym or flexprompt.get_module_symbol(), cwd)

    return dirStackDepth .. cwd, color, "white"
end

--------------------------------------------------------------------------------
-- DURATION MODULE:  {duration:color=color_name,alt_color_name}
--  - color_name is a name like "green", or an sgr code like "38;5;60".
--  - alt_color_name is optional; it is the text color in rainbow style.

local endedit_time
local last_duration

local function duration_onbeginedit()
    if endedit_time then
        local beginedit_time = os.time()
        local elapsed = beginedit_time - endedit_time
        if elapsed >= 0 then
            last_duration = math.floor(elapsed)
        end
    end
end

local function duration_onendedit()
    endedit_time = os.time()
end

local function render_duration(args)
    local duration = _duration or last_duration
    if (duration or 0) <= 0 then return end

    local colors = flexprompt.parse_arg_token(args, "c", "color")
    local color, altcolor
    if flexprompt.get_style() == "rainbow" then
        color = "yellow"
        altcolor = "black"
    else
        if not flexprompt.can_use_extended_colors() then
            color = "darkyellow"
        else
            color = "38;5;214"
        end
    end
    color, altcolor = flexprompt.parse_colors(colors, color, altcolor)

    local text
    text = (duration % 60) .. "s"
    duration = math.floor(duration / 60)
    if duration > 0 then
        text = append_text((duration % 60) .. "m", text)
        duration = math.floor(duration / 60)
        if duration > 0 then
            text = append_text(duration .. "h", text)
        end
    end

    if flexprompt.get_flow() == "fluent" then
        text = append_text(flexprompt.make_fluent_text("took"), text)
    end
    text = append_text(text, flexprompt.get_module_symbol())

    return text, color, altcolor
end

--------------------------------------------------------------------------------
-- EXIT MODULE:  {exit:always:color=color_name,alt_color_name:hex}
--  - 'always' always shows the exit code even when 0.
--  - color_name is used when the exit code is 0, and is a name like "green", or
--    an sgr code like "38;5;60".
--  - alt_color_name is optional; it is the text color in rainbow style when the
--    exit code is 0.
--  - 'hex' shows the exit code in hex when > 255 or < -255.

local function render_exit(args)
    if not os.geterrorlevel then return end

    local text
    local value = get_errorlevel()

    local always = flexprompt.parse_arg_keyword(args, "a", "always")
    if not always and value == 0 then return end

    local hex = flexprompt.parse_arg_keyword(args, "h", "hex")

    if hex and math.abs(value) > 255 then
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
    text = append_text(flexprompt.get_module_symbol(), text)

    local colors = flexprompt.parse_arg_token(args, "c", "color")
    local color, altcolor
    if flexprompt.get_style() == "rainbow" then
        color = "black"
        altcolor = "red"
    else
        color = "red"
    end
    color, altcolor = flexprompt.parse_colors(colors, color, altcolor)

    if value ~= 0 then
        color = "red"
        altcolor = "brightyellow"
    end

    if flexprompt.get_flow() == "fluent" then
        text = append_text(flexprompt.make_fluent_text("exit"), text)
    else
        local sym = flexprompt.get_module_symbol()
        if not sym then
            sym = flexprompt.get_icon(value ~= 0 and "exit_nonzero" or "exit_zero")
        end
        text = append_text(text, sym)
    end

    return text, color, altcolor
end

--------------------------------------------------------------------------------
-- GIT MODULE:  {git:nostaged:noaheadbehind:color_options}
--  - 'nostaged' omits the staged details.
--  - 'noaheadbehind' omits the ahead/behind details.
--  - 'showremote' shows the branch and its remote.
--  - color_options override status colors as follows:
--      - clean=color_name,alt_color_name       When status is clean.
--      - conflict=color_name,alt_color_name    When a conflict exists.
--      - dirty=color_name,alt_color_name       When status is dirty.
--      - remote=color_name,alt_color_name      For ahead/behind details.
--      - staged=color_name,alt_color_name      For staged details.
--      - unknown=color_name,alt_color_name     When status is unknown.

local git = {}
local cached_info = {}

-- Add status details to the segment text.  Depending on git.status_details this
-- may show verbose counts for operations, or a concise overall count.
--
-- Synchronous call.
local function add_details(text, details)
    if git.status_details then
        if details.add > 0 then
            text = append_text(text, flexprompt.get_symbol("addcount") .. details.add)
        end
        if details.modify > 0 then
            text = append_text(text, flexprompt.get_symbol("modifycount") .. details.modify)
        end
        if details.delete > 0 then
            text = append_text(text, flexprompt.get_symbol("deletecount") .. details.delete)
        end
        if (details.rename or 0) > 0 then
            text = append_text(text, flexprompt.get_symbol("renamecount") .. details.rename)
        end
    else
        text = append_text(text, flexprompt.get_symbol("summarycount") .. (details.add + details.modify + details.delete + (details.rename or 0)))
    end
    if (details.untracked or 0) > 0 then
        text = append_text(text, flexprompt.get_symbol("untrackedcount") .. details.untracked)
    end
    return text
end

-- Collects git status info.
--
-- Uses async coroutine calls.
local function collect_git_info()
    local status = flexprompt.get_git_status()
    local conflict = flexprompt.get_git_conflict()
    local ahead, behind = flexprompt.get_git_ahead_behind()
    return { status=status, conflict=conflict, ahead=ahead, behind=behind, finished=true }
end

local function parse_color_token(args, colors)
    local parsed_colors = flexprompt.parse_arg_token(args, colors.token, colors.alttoken)
    local color, altcolor = flexprompt.parse_colors(parsed_colors, colors.name, colors.altname)
    return color, altcolor
end

local git_colors =
{
    clean       = { token="c",  alttoken="clean",       name="green",   altname="black" },
    conflict    = { token="!",  alttoken="conflict",    name="red",     altname="brightwhite" },
    dirty       = { token="d",  alttoken="dirty",       name="yellow",  altname="black" },
    remote      = { token="r",  alttoken="remote",      name="cyan",    altname="black" },
    staged      = { token="s",  alttoken="staged",      name="magenta", altname="black" },
    unknown     = { token="u",  alttoken="unknown",     name="white",   altname="black" },
}

local function render_git(args)
    if _in_wizard then
        local color, altcolor = parse_color_token(args, git_colors.clean)
        return "master", color, altcolor
    end

    local git_dir = flexprompt.get_git_dir()
    if not git_dir then
        return
    end

    local branch = flexprompt.get_git_branch(git_dir)
    if not branch then
        return
    end

    -- Discard cached info if from a different repo or branch.
    if (cached_info.git_dir ~= git_dir) or (cached_info.git_branch ~= branch) then
        cached_info = {}
        cached_info.git_dir = git_dir
        cached_info.git_branch = branch
    end

    -- Use coroutine to collect status info asynchronously.
    local info = flexprompt.promptcoroutine(collect_git_info)

    -- Use cached info until coroutine is finished.
    if not info then
        info = cached_info.git_info or {}
    else
        cached_info.git_info = info
    end

    -- Segments.
    local segments = {}

    -- Local status.
    local style = flexprompt.get_style()
    local flow = flexprompt.get_flow()
    local gitStatus = info.status
    local gitConflict = info.conflict
    local gitUnknown = not info.finished
    local colors = git_colors.clean
    local showRemote = flexprompt.parse_arg_keyword(args, "sr", "showremote")
    local text = append_text(flexprompt.get_module_symbol(), branch)
    if showRemote then
        local remote = flexprompt.get_git_remote(git_dir)
        if remote then
            text = text .. flexprompt.make_fluent_text("->") .. remote
        end
    end
    if flow == "fluent" then
        text = append_text(flexprompt.make_fluent_text("on"), text)
    elseif style ~= "lean" then
        text = append_text(flexprompt.get_symbol("branch"), text)
    end
    if gitConflict then
        colors = git_colors.conflict
        text = append_text(text, flexprompt.get_symbol("conflict"))
    elseif gitStatus and gitStatus.working then
        colors = git_colors.dirty
        text = add_details(text, gitStatus.working)
    elseif gitUnknown then
        colors = git_colors.unknown
    end

    local color, altcolor = parse_color_token(args, colors)
    table.insert(segments, { text, color, altcolor })

    -- Staged status.
    local noStaged = flexprompt.parse_arg_keyword(args, "ns", "nostaged")
    if not noStaged and gitStatus and gitStatus.staged then
        text = append_text("", flexprompt.get_symbol("staged"))
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
            text = append_text("", flexprompt.get_symbol("aheadbehind"))
            colors = git_colors.remote
            if ahead ~= "0" then
                text = append_text(text, flexprompt.get_symbol("aheadcount") .. ahead)
            end
            if behind ~= "0" then
                text = append_text(text, flexprompt.get_symbol("behindcount") .. behind)
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
    clean       = { "c", "clean", "green", "black" },
    dirty       = { "d", "dirty", "red", "white" },
}

local function get_hg_dir(dir)
    return flexprompt.scan_upwards(dir, function (dir)
        -- Return if it's a hg (Mercurial) dir.
        return has_dir(dir, ".hg")
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
    local text = append_text(flexprompt.get_symbol("branch"), branch)
    text = append_text(flexprompt.get_module_symbol(), text)
    if flow == "fluent" then
        text = append_text(flexprompt.make_fluent_text("on"), text)
    end

    local colors
    local pipe = io.popen("hg status -amrd 2>&1")
    local output = pipe:read('*all')
    local rc = { pipe:close() }
    if (output or "") ~= "" then
        text = append_text(text, get_symbol("modifycount"))
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
        text = append_text(flexprompt.get_module_symbol(), text)

        local color, altcolor = parse_color_token(args, { "c", "color", "cyan", "white" })
        return text, color, altcolor
    end
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
    text = append_text(flexprompt.get_module_symbol(), text)

    local color, altcolor = parse_color_token(args, { "c", "color", "cyan", "white" })
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
    text = append_text(flexprompt.get_module_symbol(), text)

    local color, altcolor = parse_color_token(args, { "c", "color", "cyan", "white" })
    return text, color, altcolor
end

--------------------------------------------------------------------------------
-- SVN MODULE:  {hg:color_options}
--  - color_options override status colors as follows:
--      - clean=color_name,alt_color_name       When status is clean.
--      - dirty=color_name,alt_color_name       When status is dirty (modified files).

local svn_colors =
{
    clean       = { "c", "clean", "green", "black" },
    dirty       = { "d", "dirty", "red", "white" },
}

local function get_svn_dir(dir)
    return flexprompt.scan_upwards(dir, function (dir)
        -- Return if it's a svn (Subversion) dir.
        local has = has_dir(dir, ".svn")
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
    local text = branch
    local colors = svn_colors.clean

    if flow == "fluent" then
        text = append_text(flexprompt.make_fluent_text("on"), text)
    elseif style ~= "lean" then
        text = append_text(get_symbol("branch"), text)
    end
    text = append_text(flexprompt.get_module_symbol(), text)

    if get_svn_status() then
        colors = svn_colors.dirty
        text = append_text(text, flexprompt.get_symbol("modifycount"))
    end

    local color, altcolor = parse_color_token(args, colors)
    return text, color, altcolor
end

--------------------------------------------------------------------------------
-- TIME MODULE:  {time:color=color_name,alt_color_name:format=format_string}
--  - color_name is a name like "green", or an sgr code like "38;5;60".
--  - alt_color_name is optional; it is the text color in rainbow style.
--  - format_string uses the rest of the text as a format string for os.date().
--
-- If present, the 'format=' option must be last (otherwise it could never
-- include colons).

local function render_time(args)
    local colors = flexprompt.parse_arg_token(args, "c", "color")
    local color, altcolor
    if flexprompt.get_style() == "rainbow" then
        color = "white"
        altcolor = "black"
    else
        color = "darkcyan"
    end
    color, altcolor = flexprompt.parse_colors(colors, color, altcolor)

    local format = flexprompt.parse_arg_token(args, "f", "format", true)
    if not format then
        format = "%a %H:%M"
    end

    local text = os.date(format)

    if flexprompt.get_flow() == "fluent" then
        text = append_text(flexprompt.make_fluent_text("at"), text)
    end

    text = append_text(text, flexprompt.get_module_symbol())

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
    if not flexprompt.can_use_extended_colors() then
        color = "magenta"
    elseif style == "rainbow" then
        color = "38;5;90"
        altcolor = "white"
    elseif style == "classic" then
        color = "38;5;171"
    else
        color = "38;5;135"
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
-- Module table.
-- Initialized with the built-in modules.
-- Custom modules can be added with flexprompt.add_module().

--[[local]] modules =
{
    battery = render_battery,
    cwd = render_cwd,
    duration = render_duration,
    exit = render_exit,
    git = render_git,
    hg = render_hg,
    maven = render_maven,
    npm = render_npm,
    python = render_python,
    svn = render_svn,
    time = render_time,
    user = render_user,
}

--------------------------------------------------------------------------------
-- Shared event handlers.

local offered_wizard

local function onbeginedit()
    -- Fix our tables if a script deleted them accidentally.
    if not flexprompt.settings then flexprompt.settings = {} end
    if not flexprompt.settings.symbols then flexprompt.settings.symbols = {} end

    coroutines_onbeginedit()
    duration_onbeginedit()
    spacing_onbeginedit()

    if not offered_wizard then
        local empty = true
        for n,v in pairs(flexprompt.settings) do
            if n == "symbols" then
                for nn in pairs(v) do
                    empty = false
                    break
                end
            else
                empty = false
            end
            if not empty then
                break
            end
        end
        if empty then
            clink.print("\n" .. sgr(1) .. "Flexprompt has not yet been configured." .. sgr())
            clink.print('Run "flexprompt configure" to configure the prompt.\n')
        end
        offered_wizard = true
    end
end

local function onendedit()
    duration_onendedit()
end

clink.onbeginedit(onbeginedit)
clink.onendedit(onendedit)
