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

local function config_wizard()
    clink.print("Configuration wizard goes here... ", NONL)
    local s = readinput()
    clink.print(string.format("%q", s))
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
