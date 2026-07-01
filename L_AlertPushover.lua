-- L_AlertPushover.lua -- Send Vera system alerts via Pushover
-- Copyright (C) 2026, Patrick H. Rigney; published under MIT License
-- See: https://github.com/toggledbits/Vera-AlertPushover

module("L_AlertPushover", package.seeall)

local _,json = pcall( require, "dkjson" )

-- Globals --
local MYSID = "urn:toggledbits-com:serviceId:AlertPushover1"
local ALERTSFILE = "/etc/cmh/alerts.json"
local POLLING_RATE = 60
local log = luup.log
local toString = tostring

-- Flags --
local DEBUG_MODE = false

-- Utility --
local function debug(text) if DEBUG_MODE then log(text) end end

-- Initialize a variable if it does not already exist.
local function initVar( name, dflt, dev, sid )
    local currVal = luup.variable_get( sid or MYSID, name, dev )
    if currVal == nil then
        luup.variable_set( sid or MYSID, name, tostring(dflt), dev )
        return tostring(dflt)
    end
    return currVal
end

-- Get variable with possible default
local function getVar( name, dflt, dev, sid )
    local s,t = luup.variable_get( sid or MYSID, name, dev )
    if s == nil or s == "" then return dflt,0 end
    return s,t
end

-- Get numeric variable, or return default value if not set or blank
local function getVarNumeric( name, dflt, dev, sid )
    local s = getVar( name, dflt, dev, sid )
    return type(s)=="number" and s or tonumber(s) or dflt
end

local function getVarBool( name, dflt, dev, sid ) return getVarNumeric( name, dflt and 1 or 0, dev, sid ) ~= 0 end

local function init( device )

    initVar( "Enabled", 1, device )
    initVar( "DebugMode", 0, device )
    initVar( "PollingRate", 60, device )
    initVar( "PushoverToken", "SET ME!", device )
    initVar( "PushoverUser", "SET ME!", device )
    initVar( "PushoverTitle", "Alert from Vera", device )
    initVar( "PushoverSound", "", device )
    initVar( "PushoverDevice", "", device )
    initVar( "PushoverPriority", "0", device )
    initVar( "SeverityMap", "", device )
    initVar( "DeviceMap", "", device )

    DEBUG_MODE = getVarBool( "DebugMode", 1, device )
    log("AlertPushover Plugin: debug "..(DEBUG_MODE and "enabled" or "disabled"))

    local p = getVarNumeric( "PollingRate", 60, device )
    if p > 10 then
        POLLING_RATE = p
    end
    debug("AlertPushover Plugin: POLLING_RATE=" .. POLLING_RATE)
end

local function split( str, sep )
    sep = sep or ","
    local arr = {}
    if str == nil or #str == 0 then return arr, 0 end
    local rest = string.gsub( str or "", "([^" .. sep .. "]*)" .. sep, function( m ) table.insert( arr, m ) return "" end )
    table.insert( arr, rest )
    return arr, #arr
end

local function SQ( str )
    return '"' .. (str:gsub('[$`\\"]', '\\%1')) .. '"'
end

local function sendAlert( device, title, msg, data )
    local ptoken = getVar( "PushoverToken", "SET ME!", device )
    local puser = getVar( "PushoverUser", "SET ME!", device )
    if ptoken == "" or puser == "" then
        error "Pushover token or user not set"
    else
        local psound = getVar( "PushoverSound", "", device )
        local priority = getVarNumeric( "PushoverSeverity", 0, device )
        local pmap = getVar("SeverityMap", "", device )
        if pmap ~= "" and data.Severity ~= nil then
            pmap = split(pmap, ",")
            for _,x in ipairs( pmap ) do
                local vp,p = x:match( "^([^=]+)=(.*)" )
                if data.Severity == tonumber(vp) then
                    debug("AlertPushover: mapping Vera priority "..tostring(data.Severity).." to Pushover "..tostring(priority))
                    if "X" == p then return end  -- Don't send alert
                    priority = tonumber(p) or 0
                    break
                end
            end
        end
        local pdevice = getVar( "PushoverDevice", "", device )
        pmap = getVar("DeviceMap", "", device )
        if pmap ~= "" then
            local u = data.Users or ""
            pmap = split(pmap, ",")
            for _,x in ipairs( pmap ) do
                local vp,p = x:match( "^([^=]+)=(.*)" )
                if u == vp then
                    debug("AlertPushover: mapping Vera user "..tostring(data.Users).." to Pushover "..tostring(pdevice))
                    if "X" == p then return end  -- Don't send alert
                    pdevice = p
                    break
                end
            end
        end
        local baseurl = getVar( "PushoverURL", "https://api.pushover.net/1/messages.json", device )
        local cmd = 'curl -s -m 15 -X POST -o /tmp/alertpushover-resp.txt'
        cmd = cmd .. string.format(" --form-string token=%s", SQ(ptoken))
        cmd = cmd .. string.format(" --form-string user=%s", SQ(puser))
        cmd = cmd .. string.format(" --form-string message=%s", SQ(msg))
        cmd = cmd .. string.format(" --form-string priority=%s", SQ(tostring(priority)))
        if data.LocalTimestamp ~= nil then
            cmd = cmd .. string.format(" --form-string timestamp=%d", data.LocalTimestamp)
        end
        if ( title or "" ) ~= "" then
            cmd = cmd .. string.format(" --form-string title=%s", SQ(title))
        end
        if pdevice ~= "" then
            cmd = cmd .. string.format(" --form-string device=%s", SQ(pdevice))
        end
        if ( psound or "" ) ~= "" then
            cmd = cmd .. string.format(" --form-string sound=%s", SQ(psound))
        end
        cmd = cmd .. " '" .. baseurl .. "'"
        debug("AlertPushover exec: "..tostring(cmd))
        local st = os.execute( cmd ) -- N.B. return value cannot be relied upon under Luup
        if st ~= 0 then
            debug("AlertPushover: "..cmd.." returned "..st)
        end
    end
end

-- -------------- "PUBLIC" FUNCTIONS -----------------

function checkAlerts(device)
    -- This is a delay callback, so we have to convert string argument
    device  = tonumber(device, 10) or error("invalid device number")
    local delay = POLLING_RATE
    local ptoken = getVar( "PushoverToken", "", device )
    local puser = getVar( "PushoverUser", "", device )

    local fd = io.open( ALERTSFILE, "r" )
    if not fd then
        log("AlertPushover: alerts file "..ALERTSFILE.." not found")
    elseif ptoken == "SET ME!" or ptoken == "" or puser == "SET ME!" or puser == "" then
        log("AlertPushover: Pushover API token and user must be set for operation; see https://pushover.net/api")
        fd:close()
    else
        local l = fd:read("*a")
        local data,pos,err = json.decode(l)
        fd:close()
        if data == nil then
            log("AlertPushover: can't decode "..ALERTSFILE.." at "..pos..": "..err)
        elseif data.alerts ~= nil and #data.alerts > 0 then
            debug("AlertPushover: "..tostring(#data.alerts).." pending")
            local alert = table.remove( data.alerts, 1 )
            debug("AlertPushover: handling "..json.encode(alert))

            fd = io.open( ALERTSFILE, "w" )
            if not fd then
                log("AlertPushover: can't write "..ALERTSFILE)
            else
                fd:write(json.encode(data))
                fd:close()

                -- Attempt to avoid duplicates, which appears to be an issue
                local dkey = tostring(alert.PK_Alert)
                    .. ":" .. tostring(alert.SourceType)
                    .. ":" .. tostring(alert.EventType)
                    .. ":" .. tostring(alert.PK_Device)
                    .. ":" .. tostring(alert.Severity)
                    .. ":" .. tostring(alert.NewValue)
                    .. ":" .. tostring(alert.Users)
                if dkey == getVar( "LastAlert", "", device ) then
                    debug("AlertPushover: ignoring duplicate alert "..dkey)
                    delay = 1
                else
                    local title = getVar( "PushoverTitle", "Alert from Vera", device )
                    local msg = "[" ..tostring(alert.Severity).. "] "
                    if ( alert.SourceType == 3 or alert.SourceType == 4 ) and alert.NewValue ~= "0" then
                        -- Seems to be Armed Sensor Tripped
                        msg = msg .. tostring(alert.DeviceName or alert.Description) .. ": armed sensor TRIPPED"
                    elseif ( alert.SourceType == 3 or alert.SourceType == 4 ) and alert.NewValue == "0" then
                        msg = msg .. tostring(alert.DeviceName or alert.Description) .. ": armed sensor RESTORED"
                    else
                        msg = msg .. tostring(alert.Code)
                            .. " " .. tostring(alert.DeviceName or alert.Description)
                        if tostring(alert.DeviceName) ~= tostring(alert.Description) then
                            msg = msg .. " " .. tostring(alert.Description)
                        end
                    end
                    msg = msg .. "\n\nID: " .. dkey

                    debug("AlertPushover: sending alert "..dkey)
                    local _,err = pcall( sendAlert, device, title, msg, alert )
                    if err ~= nil then
                        error("AlertPushover: failed to send alert: "..tostring(err))
                    else
                        luup.variable_set( MYSID, "LastAlert", dkey, device )
                    end

                    delay = math.max( 5, getVarNumeric( "Delay", math.ceil( POLLING_RATE / 2 ), device ) )
                end
            end
        end
    end

    if getVarNumeric( "Enabled", 1, device ) == 0 then
        log("AlertPushover: disabled by configuration; stopping.")
        return
    end
    luup.call_delay("checkAlerts", delay, tostring(device))
end

function AlertPushoverInit(lul_device)
    if getVarNumeric( "Enabled", 1, lul_device ) == 0 then
        log("AlertPushover Plugin DISABLED by configuration")
        return false, "Plugin disabled", "AlertPushover Plugin"
    end

    init(lul_device)
    checkAlerts(lul_device)
    log( "AlertPushover Plugin started, version 26180-toggledbits" )
    return true, "Startup successful.", "AlertPushover Plugin"
end
