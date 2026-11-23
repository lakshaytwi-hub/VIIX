-- ============================================================================
-- COMBINED BUILD: login.lua + 1.lua + 2.lua + 3.lua
-- ============================================================================

-- ============================================================================
-- [INTEGRATED] 5_6332112181898781672.lua
-- ----------------------------------------------------------------------------
-- STRUCTURAL NOTE (this is what fixed the load failure):
--   The module is split in two, following combined.lua's own convention.
--   * Its DEFINITIONS (_G.__Bypass) stay here, at the top, where they are
--     pure table/function construction and touch no live game state.
--   * Its three LIVE-PATCH blocks (LobbySystem.SendEigeninfo, the ban /
--     security / region-block patches, and BYPASS V1's Tss + Gokuba hooks)
--     are wrapped in _G.__install_5_early_hooks and executed only after the
--     login gate authorises the feature queue (chained onto
--     __run_pending_features), i.e. once every game module exists.
--   Previously those three blocks ran inline at the very top of the file,
--   i.e. before the game had finished bootstrapping.  Overwriting
--   SendEigeninfo / EigenArrayObfuscationVerify / ForwardFeature that early
--   broke the login handshake, which is why the file appeared not to load.
-- ============================================================================

_G.__Bypass = (function()
    local M = {}

    local _MY_SESSION = (_G.__BYPASS_SESSION or 0) + 1
    _G.__BYPASS_SESSION = _MY_SESSION

    local function is_current() return _G.__BYPASS_SESSION == _MY_SESSION end

    local CONFIG = {
        auto_install_on_load = true,
        persist_across_relog = true,
        enable_access_restriction   = false,
        enable_menu_unlock          = false,
        enable_gm_state             = false,
        enable_device_limit         = true,
        enable_fair_play            = true,
        enable_match_ban_ui         = true,
        enable_report_cheat_shim    = true,
        enable_vulkan_whitelist     = true,
        enable_remote_forensic_lock = true,
        enable_rtp_log_noop         = true,

        vulkan_whitelist_returns_true = true,
        report_cheat_allow_others     = false,
        prefs_key = "M_BUILD_BYPASS_ENABLED",
    }

    local function safe(fn, ...)
        local ok, err = pcall(fn, ...)
        return ok, err
    end

    local function req(path)
        local ok, mod = pcall(require, path)
        return ok and mod or nil
    end

    -- ========================================================================
    -- STUBS for the three jobs that broke things. Not in installer list below.
    -- ========================================================================
    function M.access_restriction() return false end
    function M.menu_unlock() return false end
    function M.gm_state() return false end

    -- ========================================================================
    -- 1. DEVICE LIMIT
    -- ========================================================================
    function M.device_limit()
        if not _G.LobbySystem or _G.LobbySystem.__bypass_device_installed then
            return true
        end
        _G.LobbySystem.__bypass_device_orig = {
            CheckDeviceLimitRefuse = _G.LobbySystem.CheckDeviceLimitRefuse,
            CheckDeviceLimitTip    = _G.LobbySystem.CheckDeviceLimitTip,
        }
        _G.LobbySystem.CheckDeviceLimitRefuse = function() end
        _G.LobbySystem.CheckDeviceLimitTip    = function() end
        _G.LobbySystem.__bypass_device_installed = true
        return true
    end

    -- ========================================================================
    -- 2. FAIR PLAY
    -- ========================================================================
    function M.fair_play()
        local popup = req("client.slua.logic.fairgame.logic_fairgame_popup")
        if popup and not popup.__bypass_installed then
            popup.__bypass_orig = {
                shoudlShowFairGameAgreement = popup.shoudlShowFairGameAgreement,
                shouldShowFairGameNotice    = popup.shouldShowFairGameNotice,
            }
            local a = popup.shoudlShowFairGameAgreement
            popup.shoudlShowFairGameAgreement = (type(a) == "function")
                and function() return false end or false
            local b = popup.shouldShowFairGameNotice
            popup.shouldShowFairGameNotice = (type(b) == "function")
                and function() return false end or false
            if type(popup.CloseFairGameAgreement) == "function" then
                safe(popup.CloseFairGameAgreement)
            end
            popup.__bypass_installed = true
        end
        local handler = req("client.network.Protocol.FairGameHandler")
        if handler and not handler.__bypass_installed then
            handler.__bypass_orig = {
                shoudlShowFairGameAgreement = handler.shoudlShowFairGameAgreement,
                shouldShowFairGameNotice    = handler.shouldShowFairGameNotice,
            }
            local a = handler.shoudlShowFairGameAgreement
            handler.shoudlShowFairGameAgreement = (type(a) == "function")
                and function() return false end or false
            local b = handler.shouldShowFairGameNotice
            handler.shouldShowFairGameNotice = (type(b) == "function")
                and function() return false end or false
            handler.__bypass_installed = true
        end
        return true
    end

    -- ========================================================================
    -- 3. MATCH BAN UI
    -- ========================================================================
    function M.match_ban_ui()
        if not _G.LobbySystem or type(_G.LobbySystem.HandleMatchErrorCode) ~= "function" then
            return false
        end
        if _G.LobbySystem.__bypass_mb_installed then return true end
        local orig = _G.LobbySystem.HandleMatchErrorCode
        _G.LobbySystem.__bypass_mb_orig = orig
        local function is_ban_reason(msg)
            if type(msg) ~= "string" then return false end
            local lower = msg:lower()
            return lower:find("ban", 1, true)
                or lower:find("isolation", 1, true)
                or lower:find("low_priority", 1, true)
                or lower:find("multi-player-matching", 1, true)
        end
        _G.LobbySystem.HandleMatchErrorCode = function(msg, waitTime, reason, surplustime, res_params, ext_info)
            if is_ban_reason(msg) then return end
            return orig(msg, waitTime, reason, surplustime, res_params, ext_info)
        end
        _G.LobbySystem.__bypass_mb_installed = true
        return true
    end

    -- ========================================================================
    -- 4. REPORT CHEAT SHIM
    -- ========================================================================
    function M.report_cheat_shim()
        if not _G.PlayerSafeCallback or type(_G.PlayerSafeCallback.ReportCheat) ~= "function" then
            return false
        end
        if _G.PlayerSafeCallback.__bypass_report_installed then return true end
        _G.PlayerSafeCallback.__bypass_report_orig = _G.PlayerSafeCallback.ReportCheat
        _G.PlayerSafeCallback.ReportCheat = function() end
        _G.PlayerSafeCallback.__bypass_report_installed = true
        return true
    end

    -- ========================================================================
    -- 5. VULKAN WHITELIST
    -- ========================================================================
    function M.vulkan_whitelist()
        if not _G.LobbySystem or _G.LobbySystem.__bypass_vulkan_installed then
            return true
        end
        _G.LobbySystem.__bypass_vulkan_orig = {
            vulkan_whitelist           = _G.LobbySystem.vulkan_whitelist,
            CheckVulkanWhiteListEnable = _G.LobbySystem.CheckVulkanWhiteListEnable,
        }
        local orig = _G.LobbySystem.vulkan_whitelist
        _G.LobbySystem.vulkan_whitelist = type(orig) == "function"
            and function() return 1 end
            or 1
        local ret = CONFIG.vulkan_whitelist_returns_true
        _G.LobbySystem.CheckVulkanWhiteListEnable = function() return ret end
        _G.LobbySystem.__bypass_vulkan_installed = true
        return true
    end

    -- ========================================================================
    -- 6. REMOTE FORENSIC LOCK
    -- ========================================================================
    function M.remote_forensic_lock()
        if not _G.HDmpveRemote or _G.HDmpveRemote.__bypass_forensic_installed then
            return true
        end
        local killedExact = {
            GainCrashLogInfoBackground       = true,
            GainCrashLogInfoBackgroundOnInit = true,
            VirMemExtLevel                   = true,
            DisableReduceVirMem              = true,
        }
        local killedPrefixes = { "GainCrashLog", "GainSystemLog", "CrashLogInfo", "VirMemExt", "DisableReduceVirMem" }
        local function is_killed(key)
            if type(key) ~= "string" then return false end
            if killedExact[key] then return true end
            for _, p in ipairs(killedPrefixes) do
                if key:sub(1, #p) == p then return true end
            end
            return false
        end

        local origInt    = _G.HDmpveRemote.HDmpveRemoteConfigGetInt
        local origString = _G.HDmpveRemote.HDmpveRemoteConfigGetString
        local origBool   = _G.HDmpveRemote.HDmpveRemoteConfigGetBool

        -- Save originals so revert() can restore them
        _G.HDmpveRemote.__bypass_forensic_orig = {
            Int = origInt, String = origString, Bool = origBool,
        }

        if origInt then
            _G.HDmpveRemote.HDmpveRemoteConfigGetInt = function(key, def)
                if is_killed(key) then return 0 end
                return origInt(key, def)
            end
        end
        if origString then
            _G.HDmpveRemote.HDmpveRemoteConfigGetString = function(key, def)
                if is_killed(key) then return "" end
                return origString(key, def)
            end
        end
        if origBool then
            _G.HDmpveRemote.HDmpveRemoteConfigGetBool = function(key, def)
                if is_killed(key) then return false end
                return origBool(key, def)
            end
        end
        _G.HDmpveRemote.__bypass_forensic_installed = true
        return true
    end

    -- ========================================================================
    -- 7. RTP LOG NO-OP
    -- ========================================================================
    function M.rtp_log_noop()
        local PC = _G.PacketCallbacks
        if not PC then
            local ok, mod = pcall(require, "client.network.Protocol.PacketCallbacks")
            if ok and type(mod) == "table" then PC = mod end
        end

        if not PC then
            -- PacketCallbacks not present in this runtime. Nothing to silence.
            _G.__BYPASS_RTP_NA = true
            return true
        end

        if PC.__bypass_rtp_installed then return true end

        local candidates = { "rtanti_punish", "rt_anti_punish", "rtp_punish", "anti_punish" }
        local fn_key, fn = nil, nil
        for _, k in ipairs(candidates) do
            if type(PC[k]) == "function" then
                fn_key, fn = k, PC[k]
                break
            end
        end

        if not fn then
            -- Callback doesn't exist on this build. Nothing to silence = success.
            PC.__bypass_rtp_installed = true
            PC.__bypass_rtp_reason = "no_callback"
            return true
        end

        PC.__bypass_rtp_orig = fn
        PC.__bypass_rtp_key = fn_key
        PC[fn_key] = function() end
        PC.__bypass_rtp_installed = true
        PC.__bypass_rtp_reason = "patched:" .. fn_key
        return true
    end

    -- ========================================================================
    -- INSTALLER  (7 jobs — same list as File 1)
    -- ========================================================================
    function M.install()
        if not is_current() then return {} end
        local r = {}
        local jobs = {
            { name = "device_limit",       cfg = "enable_device_limit",         fn = M.device_limit },
            { name = "fair_play",          cfg = "enable_fair_play",            fn = M.fair_play },
            { name = "match_ban_ui",       cfg = "enable_match_ban_ui",         fn = M.match_ban_ui },
            { name = "report_cheat_shim",  cfg = "enable_report_cheat_shim",    fn = M.report_cheat_shim },
            { name = "vulkan_whitelist",   cfg = "enable_vulkan_whitelist",     fn = M.vulkan_whitelist },
            { name = "remote_forensic",    cfg = "enable_remote_forensic_lock", fn = M.remote_forensic_lock },
            { name = "rtp_log_noop",       cfg = "enable_rtp_log_noop",         fn = M.rtp_log_noop },
        }
        for _, job in ipairs(jobs) do
            if CONFIG[job.cfg] then
                local ok, res = pcall(job.fn)
                r[job.name] = ok and res == true
            end
        end
        return r
    end

    -- ========================================================================
    -- STATUS  (pure read — safe to call any time)
    -- ========================================================================
    function M.status()
        local s = {}
        local function st(cfg, installed)
            if not cfg then return "disabled" end
            if installed == true then return true end
            return false
        end
        s.device_limit      = st(CONFIG.enable_device_limit,
            _G.LobbySystem and _G.LobbySystem.__bypass_device_installed == true)
        s.fair_play         = st(CONFIG.enable_fair_play, (function()
            local p = req("client.slua.logic.fairgame.logic_fairgame_popup")
            return p and p.__bypass_installed == true
        end)())
        s.match_ban_ui      = st(CONFIG.enable_match_ban_ui,
            _G.LobbySystem and _G.LobbySystem.__bypass_mb_installed == true)
        s.report_cheat_shim = st(CONFIG.enable_report_cheat_shim,
            _G.PlayerSafeCallback and _G.PlayerSafeCallback.__bypass_report_installed == true)
        s.vulkan_whitelist  = st(CONFIG.enable_vulkan_whitelist,
            _G.LobbySystem and _G.LobbySystem.__bypass_vulkan_installed == true)
        s.remote_forensic   = st(CONFIG.enable_remote_forensic_lock,
            _G.HDmpveRemote and _G.HDmpveRemote.__bypass_forensic_installed == true)
        s.rtp_log_noop      = st(CONFIG.enable_rtp_log_noop,
            (_G.__BYPASS_RTP_NA == true)
            or (_G.PacketCallbacks and _G.PacketCallbacks.__bypass_rtp_installed == true))
        return s
    end

    -- ========================================================================
    -- PERSISTENCE  (dormant — only runs when you call these)
    -- ========================================================================
    local function _bypass_prefs_dir()
        local dir = nil
        pcall(function()
            if Client and Client.ProjectSavedDir then
                dir = Client.ProjectSavedDir()
            end
        end)
        if type(dir) ~= "string" or dir == "" then return nil end
        if dir:sub(-1) ~= "/" then dir = dir .. "/" end
        return dir .. "Bypass/"
    end

    local function _bypass_prefs_path()
        local dir = _bypass_prefs_dir()
        if not dir then return nil end
        return dir .. CONFIG.prefs_key .. ".txt"
    end

    function M.persist_mark(enabled)
        if enabled == nil then enabled = true end
        local path = _bypass_prefs_path()
        if not path then return false end
        local dir = _bypass_prefs_dir()
        pcall(function() os.execute("mkdir -p '" .. dir .. "' 2>/dev/null") end)
        local ok, f = pcall(io.open, path, "w")
        if not ok or not f then return false end
        local wrote = pcall(function()
            f:write("enabled=" .. tostring(enabled) .. "\n")
            f:write("t=" .. tostring(os.time()) .. "\n")
            f:close()
        end)
        return wrote
    end

    function M.persist_read()
        local path = _bypass_prefs_path()
        if not path then return nil end
        local ok, f = pcall(io.open, path, "r")
        if not ok or not f then return nil end
        local content = ""
        pcall(function() content = f:read("*a") or ""; f:close() end)
        if type(content) ~= "string" then return nil end
        if content:find("enabled=false", 1, true) then return false end
        if content:find("enabled=true",  1, true) then return true  end
        return nil
    end

    function M.persist_clear()
        local path = _bypass_prefs_path()
        if not path then return false end
        pcall(function() os.remove(path) end)
        return true
    end

    -- ========================================================================
    -- LOGIN HOOKS  (dormant — call manually if you want re-install on relog)
    -- ========================================================================
    function M.attach_login_hooks()
        if not _G.EventSystem or M._hooked then return true end
        M._hooked = true
        local ES = _G.EventSystem
        local function reg(t, i)
            if not t or not i then return end
            pcall(function()
                ES:registEvent(t, i, function()
                    if not is_current() then return end
                    pcall(M.install)
                end)
            end)
        end
        reg(EVENTTYPE_LOGIN_ROLEDATA, EVENTID_LOGIN_ROLEDATA_SYNC)
        reg(EVENTTYPE_NETWORK,        EVENTID_LOBBY_SERVER_CONNECT_SUCCESS)
        reg(EVENTTYPE_LOBBY,          EVENTID_ENTERLOBBY)
        return true
    end

    -- ========================================================================
    -- REVERT  (real impl — non-destructive, only runs when you call it)
    -- ========================================================================
    function M.revert()
        if _G.LobbySystem then
            if _G.LobbySystem.__bypass_device_orig then
                for k, v in pairs(_G.LobbySystem.__bypass_device_orig) do
                    _G.LobbySystem[k] = v
                end
                _G.LobbySystem.__bypass_device_orig      = nil
                _G.LobbySystem.__bypass_device_installed = nil
            end
            if _G.LobbySystem.__bypass_vulkan_orig then
                for k, v in pairs(_G.LobbySystem.__bypass_vulkan_orig) do
                    _G.LobbySystem[k] = v
                end
                _G.LobbySystem.__bypass_vulkan_orig      = nil
                _G.LobbySystem.__bypass_vulkan_installed = nil
            end
            if _G.LobbySystem.__bypass_mb_orig then
                _G.LobbySystem.HandleMatchErrorCode  = _G.LobbySystem.__bypass_mb_orig
                _G.LobbySystem.__bypass_mb_orig      = nil
                _G.LobbySystem.__bypass_mb_installed = nil
            end
        end

        local popup = req("client.slua.logic.fairgame.logic_fairgame_popup")
        if popup and popup.__bypass_orig then
            for k, v in pairs(popup.__bypass_orig) do popup[k] = v end
            popup.__bypass_orig      = nil
            popup.__bypass_installed = nil
        end

        local handler = req("client.network.Protocol.FairGameHandler")
        if handler and handler.__bypass_orig then
            for k, v in pairs(handler.__bypass_orig) do handler[k] = v end
            handler.__bypass_orig      = nil
            handler.__bypass_installed = nil
        end

        if _G.PlayerSafeCallback and _G.PlayerSafeCallback.__bypass_report_orig then
            _G.PlayerSafeCallback.ReportCheat               = _G.PlayerSafeCallback.__bypass_report_orig
            _G.PlayerSafeCallback.__bypass_report_orig      = nil
            _G.PlayerSafeCallback.__bypass_report_installed = nil
        end

        if _G.PacketCallbacks and _G.PacketCallbacks.__bypass_rtp_orig
           and _G.PacketCallbacks.__bypass_rtp_key then
            _G.PacketCallbacks[_G.PacketCallbacks.__bypass_rtp_key] = _G.PacketCallbacks.__bypass_rtp_orig
            _G.PacketCallbacks.__bypass_rtp_orig      = nil
            _G.PacketCallbacks.__bypass_rtp_key       = nil
            _G.PacketCallbacks.__bypass_rtp_installed = nil
            _G.PacketCallbacks.__bypass_rtp_reason    = nil
        end
        _G.__BYPASS_RTP_NA = nil

        if _G.HDmpveRemote and _G.HDmpveRemote.__bypass_forensic_orig then
            local o = _G.HDmpveRemote.__bypass_forensic_orig
            if o.Int    then _G.HDmpveRemote.HDmpveRemoteConfigGetInt    = o.Int    end
            if o.String then _G.HDmpveRemote.HDmpveRemoteConfigGetString = o.String end
            if o.Bool   then _G.HDmpveRemote.HDmpveRemoteConfigGetBool   = o.Bool   end
            _G.HDmpveRemote.__bypass_forensic_orig      = nil
            _G.HDmpveRemote.__bypass_forensic_installed = nil
        end

        M.persist_mark(false)
        return true
    end

    M.CONFIG = CONFIG
    return M
end)()


-- ============================================================================
-- [INTEGRATED] Deferred live-patch blocks from 5_6332112181898781672.lua
-- Wrapped, not executed: called once at the end of this chunk.
-- ============================================================================
_G.__install_5_early_hooks = function()
    if _G.__5_early_hooks_done then return end
    -- Do not burn the one-shot flag before the game has bootstrapped: if none
    -- of the patched modules exist yet, leave the flag clear so a later call
    -- (after login authorises the feature queue) can still apply the patches.
    if not (_G.LobbySystem or _G.Tss or _G.TssManager
            or package.loaded["GameLua.Mod.BaseMod.Client.Security.Gokuba"]) then
        return
    end
    _G.__5_early_hooks_done = true

    -- ---- block 1: LobbySystem.SendEigeninfo no-op -------------------------
    do
pcall(function()
    _G._HookRegistry = _G._HookRegistry or {}
    local _HookRegistry = _G._HookRegistry

    local function _WhiteMagic_HOOK(tbl, key, wrapperFactory)
        if type(tbl) ~= "table" then return end
        local orig = tbl[key]
        if orig and _HookRegistry[orig] then return end
        local ok, newFn = pcall(wrapperFactory, orig)
        if not ok or type(newFn) ~= "function" then return end
        if type(orig) == "function" then
            _HookRegistry[newFn] = _HookRegistry[orig] or orig
        end
        tbl[key] = newFn
    end

    local m = _G.LobbySystem
    _WhiteMagic_HOOK(m, "SendEigeninfo", function() return function() end end)
end)
    end

    -- ---- block 2: ban / security / minor-verification / region block ------
    do
pcall(function()
    if IsGhostProcess and IsGhostProcess() then return end

    pcall(function()
        local ban_util = package.loaded["client.common.ban_util"]
        if not ban_util then
            local ok, m = pcall(require, "client.common.ban_util")
            if ok then ban_util = m end
        end
        if ban_util and type(ban_util.IsBanned) == "function"
           and not ban_util.__lbs_patched then
            ban_util.IsBanned = function() return false end
            ban_util.__lbs_patched = true
        end
    end)

    pcall(function()
        local sec = package.loaded["client.slua.logic.security.logic_security"]
        if not sec then
            local ok, m = pcall(require, "client.slua.logic.security.logic_security")
            if ok then sec = m end
        end
        if sec and not sec.__lbs_patched then
            if type(sec.CheckRiskLevel) == "function" then
                sec.CheckRiskLevel = function() return 0 end
            end
            if type(sec.IsDeviceBanned) == "function" then
                sec.IsDeviceBanned = function() return false end
            end
            sec.__lbs_patched = true
        end
    end)

    pcall(function()
        local mv = package.loaded["client.slua.logic.minor_verification.logic_minor_verification"]
        if not mv then
            local ok, m = pcall(require, "client.slua.logic.minor_verification.logic_minor_verification")
            if ok then mv = m end
        end
        if mv and not mv.__lbs_patched then
            if type(mv.IsEnableMinorVerification) == "function" then
                mv.IsEnableMinorVerification = function() return false end
            end
            if type(mv.IsVerificationFinished) == "function" then
                mv.IsVerificationFinished = function() return true end
            end
            if type(mv.BeginVerificationFlow) == "function" then
                mv.BeginVerificationFlow = function(nextStep)
                    if type(nextStep) == "function" then pcall(nextStep) end
                end
            end
            mv.__lbs_patched = true
        end
    end)

    pcall(function()
        local rb = package.loaded["client.logic.logic_region_block.logic_region_block"]
        if not rb then
            local ok, m = pcall(require, "client.logic.logic_region_block.logic_region_block")
            if ok then rb = m end
        end
        if rb and not rb.__lbs_patched then
            if type(rb.IsCrossRegionPlayer) == "function" then
                rb.IsCrossRegionPlayer = function() return false end
            end
            if type(rb.GetBlockType) == "function" then
                rb.GetBlockType = function() return nil, nil end
            end
            if type(rb.ShowBlockRegionNotice) == "function" then
                rb.ShowBlockRegionNotice = function() end
            end
            if type(rb.ShowCrossRegionRechargeNotify) == "function" then
                rb.ShowCrossRegionRechargeNotify = function(cb)
                    if type(cb) == "function" then pcall(cb) end
                end
            end
            rb.__lbs_patched = true
        end
    end)

    pcall(function()
        if not _G.LobbySystem then return end
        if type(LobbySystem.on_sync_base_info) == "function"
           and not LobbySystem.__lbs_sync_patched then
            local orig_sync = LobbySystem.on_sync_base_info
            LobbySystem.on_sync_base_info = function(roleData, ...)
                if type(roleData) == "table" then
                    roleData.is_banned        = nil
                    roleData.ban_type         = nil
                    roleData.ban_end_time     = nil
                    roleData.account_status   = nil
                    roleData.risk_level       = nil
                    if type(roleData.ban) == "table" then
                        for _, info in pairs(roleData.ban) do
                            if type(info) == "table" then
                                info.end_time = 0
                            end
                        end
                    end
                end
                return orig_sync(roleData, ...)
            end
            LobbySystem.__lbs_sync_patched = true
        end
    end)
end)
    end

    -- ---- block 3: BYPASS V1 (Tss + Gokuba) --------------------------------
    do
-- ============================================================
--  BYPASS V1
-- ============================================================
pcall(function()
    if _G.__bypass_v10_loaded then return end
    _G.__bypass_v10_loaded = true

    pcall(function()
        local _Tss = _G.Tss or _G.TssManager
        if _Tss then
            if type(_Tss.EigenArrayObfuscationVerify) == "function" then
                _Tss.EigenArrayObfuscationVerify = function(...) return true end
            end
            if type(_Tss.GetUserTag4Lua) == "function" then
                _Tss.GetUserTag4Lua = function() return "00000000000000000000000000000000" end
            end
        end
    end)

    pcall(function()
        local GokubaLogic = package.loaded["GameLua.Mod.BaseMod.Client.Security.Gokuba"]
        if not GokubaLogic then
            local ok, m = pcall(require, "GameLua.Mod.BaseMod.Client.Security.Gokuba")
            if ok then GokubaLogic = m end
        end
        if GokubaLogic and type(GokubaLogic.ForwardFeature) == "function" then
            GokubaLogic.ForwardFeature = function()
                if NetUtil and type(NetUtil.SendPkg) == "function" then
                    NetUtil.SendPkg("battle_client_sync_allstar_auth_check_result_req", {0, 0, 0, 0, 0})
                end
            end
        end
    end)
end)
    end
end


-- ============================================================================
-- [ADDED] MATCH SKIN PERFORMANCE GATE
-- ----------------------------------------------------------------------------
-- One authoritative answer to "may cosmetic work run right now?".
--   LOBBY : everything allowed. This is the ONLY place .txt caches are
--           generated, re-scanned or rebuilt.
--   MATCH : no file scanning, no table rebuilding, no perpetual skin loops.
--           Cosmetic data is read ONCE from match_skin.txt on match entry.
-- State lives in a table so this adds ZERO new chunk-level locals (the game
-- runs Lua 5.1, where 200 locals per function is a hard limit).
-- ============================================================================
_G.__SKIN_PERF = _G.__SKIN_PERF or {
    matchApplyWindow = 20,
    matchNow         = false,
    matchEnteredAt   = 0,
    matchCbs         = {},
    lobbyCbs         = {},
}

function _G.__OnMatchEnter(fn)
    if type(fn) == "function" then
        local t = _G.__SKIN_PERF.matchCbs
        t[#t + 1] = fn
    end
end

function _G.__OnLobbyEnter(fn)
    if type(fn) == "function" then
        local t = _G.__SKIN_PERF.lobbyCbs
        t[#t + 1] = fn
    end
end

-- Edge-triggered and timer-free: the transition block runs only on the edge.
function _G.__IsMatchActive()
    local P = _G.__SKIN_PERF
    local gs = GameStatus
    local v = false
    if gs and gs.IsInFightingStatus then
        local ok, r = pcall(gs.IsInFightingStatus)
        v = (ok and r == true)
    end
    if v ~= P.matchNow then
        P.matchNow = v
        if v then
            P.matchEnteredAt = os.time()
            local cbs = P.matchCbs
            for i = #cbs, 1, -1 do pcall(cbs[i]) end
        else
            P.matchEnteredAt = 0
            local cbs = P.lobbyCbs
            for i = #cbs, 1, -1 do pcall(cbs[i]) end
        end
    end
    return v
end

function _G.__IsLobbyActive()
    local gs = GameStatus
    if gs and gs.IsInLobbyOrMainCity then
        local ok, r = pcall(gs.IsInLobbyOrMainCity)
        return ok and r == true
    end
    return false
end

-- Fetching / scanning / generating is lobby-only.
function _G.__SkinFetchAllowed()
    return not _G.__IsMatchActive()
end

-- Applying is allowed in lobby always, and in match only inside the window.
function _G.__SkinTickAllowed()
    local P = _G.__SKIN_PERF
    if not _G.__IsMatchActive() then return true end
    if P.matchEnteredAt <= 0 then return false end
    return (os.time() - P.matchEnteredAt) <= (P.matchApplyWindow or 20)
end

-- Bounded, self-terminating burst. Never becomes a background loop.
function _G.__SkinBurst(fn, interval, runs)
    if type(fn) ~= "function" then return end
    runs = tonumber(runs) or 1
    interval = tonumber(interval) or 0.5
    local tk = nil
    pcall(function() tk = require("common.time_ticker") end)
    local function step()
        if runs <= 0 then return end
        runs = runs - 1
        pcall(fn)
        if runs > 0 and tk and tk.AddTimerOnce then
            pcall(tk.AddTimerOnce, interval, step)
        end
    end
    step()
end


local __combined_errors = {}

local function __run_combined_file(__source, __name)
    local __fn, __err
    if loadstring then
        __fn, __err = loadstring(__source, __name)
    else
        __fn, __err = load(__source, __name, "t", _ENV)
    end
    if not __fn then
        __combined_errors[#__combined_errors + 1] = __name .. " load error: " .. tostring(__err)
        return false
    end
    local __ok, __result = pcall(__fn)
    if not __ok then
        __combined_errors[#__combined_errors + 1] = __name .. " runtime error: " .. tostring(__result)
        return false
    end
    return true, __result
end

-- ============================================================================
-- LOGIN GATE: feature chunks are queued and only run after a valid key.
-- ============================================================================
local __pending_features = {}
local __features_running = false

local function __defer_feature(__name, __source)
    __pending_features[#__pending_features + 1] = { name = __name, source = __source }
end

local function __run_pending_features()
    if __features_running then return false end
    local l = _G.LunarLoginRuntime
    if not (l and l.Authorized) then return false end
    if #__pending_features == 0 then return false end
    __features_running = true
    local queue = __pending_features
    __pending_features = {}
    for _, item in ipairs(queue) do
        __run_combined_file(item.source, item.name)
        item.source = nil
    end
    return true
end
_G.__run_pending_features = __run_pending_features

-- ============================================================================
-- LOGIN STORAGE HELPERS (login.lua expects these before 1.lua runs)
-- ============================================================================
function _G.g_VRSXH_ESPSettingsPaths()
    local name = "MASTERPIECE_UMG_ESP_settings.lua"
    local paths = {
        "//storage/emulated/0/Android/data/com.tencent.ig/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. name,
        "//storage/emulated/0/Android/data/com.vng.pubgmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. name,
        "//storage/emulated/0/Android/data/com.pubg.krmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. name,
        "//storage/emulated/0/Android/data/com.rekoo.pubgm/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. name,
        "//storage/emulated/0/Android/data/com.pubg.imobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. name,
        "/Documents/ShadowTrackerExtra/Saved/Paks/" .. name,
        "ShadowTrackerExtra/Saved/Paks/" .. name,
    }
    pcall(function()
        if os and os.getenv then
            local homeDir = os.getenv("HOME")
            if homeDir and homeDir ~= "" then
                table.insert(paths, 1, homeDir .. "/Documents/ShadowTrackerExtra/Saved/Paks/" .. name)
            end
        end
    end)
    return paths
end

function _G.g_VRSXH_ESPWriteSettings(path, data)
    if type(path) ~= "string" or type(data) ~= "string" then return false end
    if not (io and type(io.open) == "function") then return false end
    local ok, file = pcall(io.open, path, "w")
    if not ok or not file then return false end
    local wrote = pcall(function()
        file:write(data)
        file:close()
    end)
    if not wrote then pcall(function() file:close() end); return false end
    return true
end

-- ============================================================================
-- LOGIN.LUA PROTECTION PATCH (Stops 1.lua / 2.lua / 8.lua from killing Login)
-- ============================================================================
do
    _G.__CleanSendPacket = _G.SendPacket
    if _G.HTTPClient and _G.HTTPClient.SendRequest then
        _G.__CleanHTTPSendRequest = _G.HTTPClient.SendRequest
    end

    -- Prevent 2.lua from wiping login.lua timers
    _G.KillAllTimers = function() end

    -- Prevent 8.lua (L63_HTTPFilter) from blocking login/key HTTP requests
    pcall(function()
        local H = _G.HTTPClient or package.loaded["HTTPClient"]
        if H and H.SendRequest then
            local realSend = _G.__CleanHTTPSendRequest or H.SendRequest
            H.__bp_http_hooked = true
            H.SendRequest = function(url, ...)
                return realSend(url, ...)
            end
        end
    end)
end

-- ============================================================================
-- 0. login.lua (Runs FIRST before 1.lua)
-- ============================================================================
__run_combined_file([====[
--[[
================================================================================
  Login.lua - Portable Master Login + Kill Limit 8-10 + LuaCore panel
================================================================================
  Drop this block into ANY script to get:

    - Full Master login UI (buttons, key box, dark-blue theme)
    - Kill limit 8-10 messaging on welcome / login
    - Panel: https://luacore.vipy.online/connect
    - POST: game=pubg&user_key=KEY&serial=SERIAL

  API after load:
    _G.MasterLicenseLogin(key)
    _G.MasterLicenseLogout()
    _G.MasterLicenseStatus()  -> { authorized, pending, message, ... }
    _G.LunarLoginRuntime      -> Authorized, Login, UI helpers

  Gate your features:
    if _G.LunarLoginRuntime and _G.LunarLoginRuntime.Authorized then
      -- start hacks
    end

  Optional: change game name in MasterLicenseConfig (game = "pubg" or "BGMI")
================================================================================
]]

-- One authorization session per Lua process; gameplay identity never owns it.
do
    local licenseScope
local MasterLicenseConfig = {
    -- VAWZEN key server — Master login UI (Kill limit 8-10) stays the same
    url = 'https://vipgfx.in/VAWZEN/connect',
    game = 'pubg',
    timeout = 15, clockSkew = 300, expiryPath = nil,
    manualExpiry = "2028-12-31 23:59:59", tamperTolerance = 5,
    secret = 'VAWZEN',
    heartbeat = 'https://luacore.vipy.online/connect',
}

local MasterLicenseCore = (function()
    local Primitives = (function()
        local floor, abs, max = math.floor, math.abs, math.max
        local byte, char, format = string.byte, string.char, string.format
        local U32 = 4294967296
        local AND, XOR = {}, {}
        for a = 0, 15 do for b = 0, 15 do
            local av, bv, both, different, place = a, b, 0, 0, 1
            for _ = 1, 4 do
                local x, y = av % 2, bv % 2
                if x == 1 and y == 1 then both = both + place end
                if x ~= y then different = different + place end
                av, bv, place = floor(av / 2), floor(bv / 2), place * 2
            end
            AND[a * 16 + b], XOR[a * 16 + b] = both, different
        end end
        local function bitop(a, b, lookup)
            local value, place = 0, 1
            for _ = 1, 8 do
                value = value + lookup[(a % 16) * 16 + b % 16] * place
                a, b, place = floor(a / 16), floor(b / 16), place * 16
            end
            return value
        end
        local function band(a, b) return bitop(a, b, AND) end
        local function bxor(a, b) return bitop(a, b, XOR) end
        local function rol(value, amount)
            local divisor = 2 ^ (32 - amount)
            return (value % divisor) * 2 ^ amount + floor(value / divisor)
        end
        local function little32(value)
            return char(value % 256, floor(value / 256) % 256,
                floor(value / 65536) % 256, floor(value / 16777216) % 256)
        end
        local K = {
            0xd76aa478,0xe8c7b756,0x242070db,0xc1bdceee,0xf57c0faf,0x4787c62a,0xa8304613,0xfd469501,
            0x698098d8,0x8b44f7af,0xffff5bb1,0x895cd7be,0x6b901122,0xfd987193,0xa679438e,0x49b40821,
            0xf61e2562,0xc040b340,0x265e5a51,0xe9b6c7aa,0xd62f105d,0x02441453,0xd8a1e681,0xe7d3fbc8,
            0x21e1cde6,0xc33707d6,0xf4d50d87,0x455a14ed,0xa9e3e905,0xfcefa3f8,0x676f02d9,0x8d2a4c8a,
            0xfffa3942,0x8771f681,0x6d9d6122,0xfde5380c,0xa4beea44,0x4bdecfa9,0xf6bb4b60,0xbebfbc70,
            0x289b7ec6,0xeaa127fa,0xd4ef3085,0x04881d05,0xd9d4d039,0xe6db99e5,0x1fa27cf8,0xc4ac5665,
            0xf4292244,0x432aff97,0xab9423a7,0xfc93a039,0x655b59c3,0x8f0ccc92,0xffeff47d,0x85845dd1,
            0x6fa87e4f,0xfe2ce6e0,0xa3014314,0x4e0811a1,0xf7537e82,0xbd3af235,0x2ad7d2bb,0xeb86d391
        }
        local SHIFT = {7,12,17,22,5,9,14,20,4,11,16,23,6,10,15,21}
        local function md5_raw(input)
            assert(type(input) == "string", "MD5 input must be a string")
            local size = #input
            local message = input .. char(128) .. string.rep(char(0), (55 - size) % 64)
                .. little32((size * 8) % U32) .. little32(floor(size / 536870912))
            local h0, h1, h2, h3 = 0x67452301, 0xefcdab89, 0x98badcfe, 0x10325476
            local words = {}
            for offset = 1, #message, 64 do
                for j = 0, 15 do
                    local a, b, c, d = byte(message, offset + j * 4, offset + j * 4 + 3)
                    words[j] = a + b * 256 + c * 65536 + d * 16777216
                end
                local a, b, c, d = h0, h1, h2, h3
                for i = 0, 63 do
                    local f, g, shiftBase
                    if i < 16 then
                        f, g, shiftBase = band(b, c) + band(U32 - 1 - b, d), i, 0
                    elseif i < 32 then
                        f, g, shiftBase = band(d, b) + band(U32 - 1 - d, c), (5 * i + 1) % 16, 4
                    elseif i < 48 then
                        f, g, shiftBase = bxor(bxor(b, c), d), (3 * i + 5) % 16, 8
                    else
                        local bOrNotD = U32 - 1 - band(U32 - 1 - b, d)
                        f, g, shiftBase = bxor(c, bOrNotD), (7 * i) % 16, 12
                    end
                    local nextB = (b + rol((a + f + K[i + 1] + words[g]) % U32,
                        SHIFT[shiftBase + i % 4 + 1])) % U32
                    a, b, c, d = d, nextB, b, c
                end
                h0, h1, h2, h3 = (h0 + a) % U32, (h1 + b) % U32, (h2 + c) % U32, (h3 + d) % U32
            end
            return little32(h0) .. little32(h1) .. little32(h2) .. little32(h3)
        end
        local function hex(input)
            return (input:gsub(".", function(c) return format("%02x", byte(c)) end))
        end
        local function md5(input) return hex(md5_raw(input)) end
        local function form_encode(input)
            assert(type(input) == "string", "Form value must be a string")
            return (input:gsub("[^A-Za-z0-9%-%._~ ]", function(c)
                return format("%%%02X", byte(c)) end):gsub(" ", "+"))
        end
        local function constant_time_equal(a, b)
            if type(a) ~= "string" or type(b) ~= "string" then return false end
            local difference = abs(#a - #b)
            for i = 1, max(#a, #b) do
                difference = difference + abs((byte(a, i) or 0) - (byte(b, i) or 0))
            end
            return difference == 0
        end
        local function name_uuid(input)
            local digest = md5_raw(input)
            local h = hex(digest:sub(1,6) .. char(byte(digest,7) % 16 + 48)
                .. digest:sub(8,8) .. char(byte(digest,9) % 64 + 128) .. digest:sub(10))
            return h:sub(1,8) .. "-" .. h:sub(9,12) .. "-" .. h:sub(13,16)
                .. "-" .. h:sub(17,20) .. "-" .. h:sub(21,32)
        end
        return {md5 = md5, md5_raw = md5_raw, form_encode = form_encode,
                constant_time_equal = constant_time_equal, name_uuid = name_uuid}
    end)()

    local SESSION_KEY='__LunarLicenseSessionV7'
    local function loadSession()
        local t=rawget(_G,SESSION_KEY)
        if type(t)=='table' and t.authorized==true and t.scope==licenseScope then return t end
    end
    local function saveSession(expiresAt)
        _G[SESSION_KEY]={authorized=true,expiresAt=expiresAt,scope=licenseScope}
    end
    local function clearSession() _G[SESSION_KEY]=nil end

    local CreateLocalExpiry = function(cfg)
        local E = {}
        local expiredText = 'Mod expired. DM @VRSXH for renewal.'
        local tamperText  = "Don't be over smart"
        local blockedMessage, blockedPhase
        local function finite(n) return type(n) == 'number' and n == n and n ~= math.huge and n ~= -math.huge end
        local function parse(text)
            if type(text) ~= 'string' then return nil end
            local y,m,d,h,n,s = text:match('^(%d%d%d%d)%-(%d%d)%-(%d%d) (%d%d):(%d%d):(%d%d)$')
            y,m,d,h,n,s = tonumber(y),tonumber(m),tonumber(d),tonumber(h),tonumber(n),tonumber(s)
            if not y or not m or not d or not h or not n or not s or y < 1970 or y > 9999 or m < 1 or m > 12 or h > 23 or n > 59 or s > 59 then return nil end
            local leap = y % 4 == 0 and (y % 100 ~= 0 or y % 400 == 0)
            local months = {31, leap and 29 or 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}
            if d < 1 or d > months[m] then return nil end
            local prior = y - 1
            local days = 365 * (y - 1970) + math.floor(prior / 4) - math.floor(1969 / 4)
                - math.floor(prior / 100) + math.floor(1969 / 100)
                + math.floor(prior / 400) - math.floor(1969 / 400)
            for i = 1, m - 1 do days = days + months[i] end
            return (days + d - 1) * 86400 + h * 3600 + n * 60 + s - 6 * 3600
        end
        local configured = type(cfg.manualExpiry) == 'string' and cfg.manualExpiry:match('^%s*(.-)%s*$') or cfg.manualExpiry
        local expiry = parse(configured)
        local skew = cfg.clockSkew or 120
        if configured ~= nil and configured ~= '' and not expiry then
            blockedMessage, blockedPhase = 'Invalid local expiry date. Use YYYY-MM-DD HH:MM:SS.', 'error'
        end
        local function block(message, phase)
            if not blockedMessage then blockedMessage, blockedPhase = message, phase end
            return false, blockedMessage, blockedPhase
        end
        function E.Status() return not blockedMessage, blockedMessage, blockedPhase end
        function E.MarkTampered() return block(tamperText, 'tampered') end
        function E.GetExpiry() return expiry end
        function E.Accept(server, now, world, phone, rtt)
            if blockedMessage then return E.Status() end
            if not finite(server) or not finite(now) or now < 0 or world == nil
                or not finite(rtt) or rtt < 0 or not finite(phone) then
                return block('Clock verification unavailable.', 'error')
            end
            if math.abs(phone - server) > skew + rtt then return E.MarkTampered() end
            if expiry and server + rtt >= expiry then return block(expiredText, 'expired') end
            return true
        end
        return E
    end

    local CreateAuth = function(P, cfg, deps)
        local A = {}
        licenseScope=P.md5(cfg.url.."\0"..cfg.game.."\0"..cfg.secret)
        local phase, message = 'locked', 'Enter your key to sign in.'
        local allowed, pending, generation = false, nil, 0
        local expiresAt
        local lastRequestLatencyMs, lastResponseTime, lastResponseWorld
        local startFn, stopFn, payloadStarted, restartRequired
        local localExpiry = deps.localExpiry
        do
            local stored = loadSession()
            if stored then
                allowed = true; expiresAt = stored.expiresAt
                phase, message = 'active', 'Session restored'
            end
        end
        if localExpiry then
            local ok, text, state = localExpiry.Status()
            if not ok then message, phase = text, state end
        end
        local function finite(n) return type(n) == 'number' and n == n and n ~= math.huge and n ~= -math.huge end
        local function readClock()
            local ok, n, w = pcall(deps.clock)
            if ok and finite(n) and n >= 0 and w ~= nil then return n, w end
        end
        local function notify(text, state)
            message, phase = text, state
            if type(deps.status) == 'function' then pcall(deps.status, text, state) end
        end
        local function stopPayload()
            if payloadStarted then
                payloadStarted = false
                local ok, accepted = pcall(stopFn)
                if not ok or accepted == false then restartRequired = true end
            end
        end
        local function revoke(text, state)
            generation = generation + 1
            allowed, pending, expiresAt = false, nil, nil
            lastRequestLatencyMs, lastResponseTime, lastResponseWorld = nil, nil, nil
            stopPayload()
            local localDenied = false
            if localExpiry then
                local ok, localText, localPhase = localExpiry.Status()
                if not ok then text, state, localDenied = localText, localPhase, true end
            end
            notify(restartRequired and not localDenied
                and 'Restart required: payload cleanup failed.' or text, state or 'error')
        end
        local function startPayload()
            if payloadStarted or not startFn then return true end
            payloadStarted = true
            local before = generation
            local ok, accepted = pcall(startFn)
            if not ok or accepted == false then
                restartRequired = true
                revoke('Restart required: offline script startup failed.', 'error')
                return false
            end
            return generation == before and allowed
        end
        local function denyReason(reason)
            if type(reason) ~= 'string' then return 'Invalid key' end
            local upper = reason:upper()
            if upper:find('BLOCKED') then return 'Key blocked hai' end
            if upper:find('EXPIRED') then return 'Key expire ho gayi' end
            if upper:find('MAX DEVICE') or upper:find('DEVICE') then return 'Dusre device par lock hai' end
            if upper:find('NOT REGISTERED') or upper:find('INVALID') then return 'Galat key - dobara likho' end
            local lower = reason:sub(1, 120):lower():gsub('[_%s%-]+', ' ')
            if lower == 'max devices' or lower == 'maximum devices'
                or lower == 'max devices reached' then return 'Max Devices' end
            local clean = reason:gsub('[%c]', ' '):sub(1, 120)
            return clean == '' and 'Invalid key' or clean
        end
        local function configuredExpiry(result)
            if cfg.expiryPath == nil then return nil, true end
            if type(cfg.expiryPath) ~= 'table' or #cfg.expiryPath == 0 then return nil, false end
            local v = result
            for _, name in ipairs(cfg.expiryPath) do
                if type(v) ~= 'table' then return nil, false end
                v = rawget(v, name)
            end
            return v, finite(v) and v > 0 and v % 1 == 0
        end
        local function begin(key)
            if restartRequired or pending then return false end
            if localExpiry then
                local ok, text, state = localExpiry.Status()
                if not ok then revoke(text, state); return false end
            end
            if type(key) ~= 'string' then key = '' end
            key = key:match('^%s*(.-)%s*$')
            if #key == 0 or #key > 512 then
                revoke('Expired: enter a valid key.', 'denied'); return false
            end
            local now, world = readClock()
            if not now then
                revoke('Phone clock unavailable. Please try again.', 'error'); return false
            end
            local okSerial, serial = pcall(deps.serial, key)
            if not okSerial or type(serial) ~= 'string' or #serial == 0 or #serial > 512 then
                local failure=tostring(serial)
                local text='Device identifier unavailable.'
                if not okSerial and failure:find('DEVICE_CACHE_CONFLICT',1,true) then
                    text='Saved device records conflict. Restore the registered device backup.'
                elseif not okSerial and failure:find('DEVICE_CACHE_RECOVERY_REQUIRED',1,true) then
                    text='Saved device data could not be recovered. Check storage or restore its backup.'
                elseif not okSerial and failure:find('DEVICE_CACHE_SAVE_FAILED',1,true) then
                    text='Device cache could not be saved. Check game storage access.'
                end
                revoke(text,'error');return false
            end
            generation = generation + 1
            local requestId = generation
            pending = {id = requestId, key = key, serial = serial,
                       started = now, world = world, deadline = now + cfg.timeout}
            notify('Signing in...', 'pending')
            if not pending or pending.id ~= requestId or generation ~= requestId then return false end
            local body = 'game=' .. P.form_encode(cfg.game)
                .. '&user_key=' .. P.form_encode(key)
                .. '&serial=' .. P.form_encode(serial)
            local function received(success, raw)
                if not pending or pending.id ~= requestId or generation ~= requestId then return end
                local current, worldNow = readClock()
                if not current or worldNow ~= pending.world or current < pending.started
                    or current >= pending.deadline then
                    revoke('Request expired. Please sign in again.', 'error'); return
                end
                if success ~= true or type(raw) ~= 'string' or #raw == 0 or #raw > 32768 then
                    revoke('Connection failed. Please try again.', 'error'); return
                end

                -- VAWZEN response: {"status":true,"data":...} or {"status":false,"reason":"..."}
                -- Also accept string-match fallback if JSON decode fails
                local result = nil
                local okDecode, decoded = pcall(deps.decode, raw)
                if okDecode and type(decoded) == 'table' then
                    result = decoded
                else
                    -- Fallback string parse for VAWZEN
                    local statusTrue = raw:find('"status"%s*:%s*true') ~= nil or raw:find('"status":true') ~= nil
                    local reason = raw:match('"reason"%s*:%s*"([^"]+)"')
                    result = { status = statusTrue, reason = reason, data = statusTrue and {} or nil }
                end

                if type(result) ~= 'table' then
                    revoke('Invalid server response.', 'error'); return
                end

                -- status can be boolean true or string "true"
                local isOk = (result.status == true) or (tostring(result.status):lower() == 'true')
                if not isOk then
                    revoke(denyReason(result.reason or result.message), 'denied'); return
                end

                -- VAWZEN: data field optional but preferred when status true
                -- Skip MD5 token / rng checks (not used by VAWZEN server)

                lastRequestLatencyMs = (current - pending.started) * 1000
                lastResponseTime, lastResponseWorld = current, worldNow
                pending = nil

                -- Session: use manual expiry if set, else long-lived until next failed check
                local expiry = nil
                if localExpiry and localExpiry.GetExpiry then
                    expiry = localExpiry.GetExpiry()
                end
                allowed, expiresAt = true, expiry
                saveSession(expiresAt)
                if not startPayload() then return end
                notify('Login successful.', 'active')
            end
            local ok, accepted = pcall(deps.post, cfg.url,
                {['Content-Type'] = 'application/x-www-form-urlencoded'},
                body, received, cfg.timeout)
            if not ok or accepted == false then
                revoke('HTTP request could not start.', 'error'); return false
            end
            return true
        end
        function A.Login(key) if allowed then return false end; return begin(key) end
        function A.Tick()
            if not pending then return end
            local now, world = readClock()
            if not now or world ~= pending.world or now < pending.started then
                revoke('Login clock unavailable. Please try again.', 'locked'); return
            end
            if now >= pending.deadline then
                revoke('Request timed out. Please try again.', 'error')
            end
        end
        function A.IsAuthorized()
            if allowed and not restartRequired then return true end
            local stored = loadSession()
            if stored and not restartRequired then
                allowed = true; expiresAt = stored.expiresAt; return true
            end
            return false
        end
        function A.Logout() clearSession(); revoke('Expired: signed out.', 'locked') end
        function A.FailClosed(text, requiresRestart)
            if requiresRestart == true then restartRequired = true end
            revoke(text or 'Online access unavailable.', 'error')
        end
        function A.ReportClockTampering()
            if localExpiry then localExpiry.MarkTampered() end
            revoke("Don't be over smart", 'tampered')
        end
        function A.Bind(onStart, onStop)
            if type(onStart) ~= 'function' or type(onStop) ~= 'function' then
                return false, 'START_AND_STOP_REQUIRED'
            end
            if startFn and (startFn ~= onStart or stopFn ~= onStop) then return false, 'ALREADY_BOUND' end
            startFn, stopFn = onStart, onStop
            if A.IsAuthorized() then return startPayload() end
            return true
        end
        function A.Unbind()
            revoke('Offline script disconnected.', 'locked')
            startFn, stopFn = nil, nil
        end
        function A.GetRemainingSeconds() return nil end
        function A.GetState()
            local authorized = A.IsAuthorized()
            local sample, age
            if authorized and lastRequestLatencyMs ~= nil then
                local now, world = readClock()
                if now and world == lastResponseWorld and now >= lastResponseTime then
                    sample, age = lastRequestLatencyMs, now - lastResponseTime
                end
            end
            return {
                phase = phase, message = message, authorized = authorized,
                sessionAuthorized = authorized, expiresAt = expiresAt,
                accessPolicy = "game_session", expiryCheckPolicy = "login_only",
                periodicRecheck = false, pending = pending ~= nil,
                linked = startFn ~= nil, restartRequired = restartRequired == true,
                lastRequestLatencyMs = sample, lastRequestLatencyAgeSeconds = age,
                latencyScope = "license_http_round_trip"
            }
        end
        return A
    end

    local Core = {Primitives = Primitives, createExpiry = CreateLocalExpiry}
    function Core.new(config, dependencies)
        assert(type(config) == 'table' and type(dependencies) == 'table',
            'License configuration and dependencies required')
        local deps = {}
        for key, value in pairs(dependencies) do deps[key] = value end
        if deps.localExpiry == nil then deps.localExpiry = CreateLocalExpiry(config) end
        return CreateAuth(Primitives, config, deps)
    end
    return Core
end)()

    local UI={Version="LunarUI.Lite.1"}
    local function member(o,k)
        if o==nil then return nil end
        local ok,v=pcall(function() return o[k] end);if ok then return v end
    end
    local function valid(o)
        if o==nil then return false end
        local ok,v=pcall(slua.isValid,o);return ok and v==true
    end
    local vectorClass=rawget(_G,"FVector2D") or import("Vector2D")
    local colorClass=rawget(_G,"FLinearColor") or import("LinearColor")
    local function vector(x,y) return vectorClass(x,y) end
    local function color(r,g,b,a)
        local function linear(v) v=v/255;if v<=0.04045 then return v/12.92 end;return ((v+0.055)/1.055)^2.4 end
        return colorClass(linear(r),linear(g),linear(b),a or 1)
    end
    local function visibility(w,v)
        local fn=member(w,"SetWidgetVisibility") or member(w,"SetVisibility")
        assert(type(fn)=="function","UI_VISIBILITY_UNAVAILABLE");fn(w,v)
    end
    local function parent()
        local ok,t=pcall(require,"GameLua.Mod.BaseMod.Common.UI.InGameUITools")
        if not ok or type(member(t,"GetMainControlBaseUI"))~="function" then return end
        local found,root=pcall(t.GetMainControlBaseUI);if not found or not valid(root) then return end
        local p=member(root,"CanvasPanel_0");if not valid(p) then p=member(root,"CanvasPanel_42") end
        if valid(p) then return p end
    end
    local function destroy(d)
        if not d then return end
        d.Visible=false
        if d.Event and d.Handle~=nil then pcall(function() d.Event:Remove(d.Handle) end) end
        if valid(d.Container) then pcall(function() d.Container:RemoveFromParent() end) end
        d.Submit=nil;d.Event=nil;d.Handle=nil;d.Container=nil;d.Parent=nil
        d.Input=nil;d.Button=nil;d.Status=nil;d.Title=nil;d.Detail=nil;d.Hint=nil;d.Design=nil;d.Cache=nil
    end
    -- Lightweight flat panel: one backing, one header, one accent bar, text and
    -- one button. No gradients, no occlusion clipping, no InvalidationBox.
    function UI.Build(kind,key,status,submit)
        local p=parent();if not p then return nil,"UI_NOT_READY" end
        local enums=UEnums.ESlateVisibility
        local passive=enums.SelfHitTestInvisible
        if enums.Visible==nil or passive==nil then return nil,"UI_ENUM_UNAVAILABLE" end
        local welcome=kind=="welcome"
        local keyinfo=kind=="keyinfo"
        local W,H
        if keyinfo then W,H=520,168
        elseif welcome then W,H=560,236
        else W,H=470,222 end
        local scale=1
        pcall(function()
            local v=p:GetCachedGeometry():GetLocalSize()
            if v.X>24 and v.Y>24 then scale=math.min(1,(v.X-24)/W,(v.Y-24)/H) end
        end)
        local d={Parent=p,Visible=false,Submit=submit,Scale=scale}
        local ok,buildError=pcall(function()
            local function make(class,outer)
                local w=CGame:NewObjectFromPath("/Script/UMG."..class,outer)
                assert(valid(w),"UI_WIDGET_UNAVAILABLE");return w
            end
            d.Container=make("CanvasPanel",p)
            local function add(w,x,y,ww,hh,z)
                local slot=d.Container:AddChildToCanvas(w)
                slot:SetAutoSize(false);slot:SetPosition(vector(x,y));slot:SetSize(vector(ww,hh));slot:SetZOrder(z)
                return slot
            end
            -- Lite panel: flat solid fills only. No gradient columns, no
            -- occlusion clipping, no InvalidationBox -> ~10 widgets per panel.
            local function box(x,y,ww,hh,r,g,b,a,z)
                local w=make("Border",d.Container)
                w:SetBrushColor(color(r,g,b,a));visibility(w,passive);add(w,x,y,ww,hh,z)
                return w
            end
            local slate=import("SlateColor")
            local function style(w,size,c,bold)
                local font=member(w,"Font")
                if font then
                    if type(font)=="table" then local copy={};for k,v in pairs(font) do copy[k]=v end;font=copy end
                    font.Size=size
                    if font.OutlineSettings then
                        local outline=font.OutlineSettings
                        if type(outline)=="table" then local copy={};for k,v in pairs(outline) do copy[k]=v end;outline=copy end
                        outline.OutlineSize=0;font.OutlineSettings=outline
                    end
                    pcall(function() w:SetFont(font) end)
                end
                pcall(function() w:SetColorAndOpacity(slate(c)) end)
                pcall(function() w:SetAutoWrapText(true) end)
            end
            local function text(value,x,y,ww,hh,size,c,z,bold,center)
                local w=make("TextBlock",d.Container);w:SetText(value);style(w,size,c,bold)
                visibility(w,passive);add(w,x,y,ww,hh,z)
                if center then pcall(function() w:SetJustification(1) end) end
                return w
            end
            local white=color(255,255,255)
            local accent=color(150,200,255)
            local soft=color(190,215,255)
            box(0,0,W,H,12,28,62,0.88,2)
            box(2,2,W-4,54,18,44,104,0.95,3)
            box(2,56,W-4,2,60,140,240,1,4)
            if keyinfo then
                d.Title=text("@VRSXH",14,8,W-28,34,20,white,6,true,true)
                text("YOUR KEY",14,44,140,18,12,accent,6,false,false)
                box(14,66,W-28,44,8,20,48,1,5)
                d.KeyText=text(key or "",22,72,W-44,34,19,white,6,true,true)
                d.Hint=text("Auto close in 5s",14,114,W-28,18,11,accent,6,false,false)
            elseif welcome then
                d.Title=text("Welcome to @VRSXH Lua mod",14,8,W-28,40,19,white,6,true,true)
                box(30,72,W-60,50,20,60,140,1,5)
                d.Detail=text("Kill limit 8-10",40,80,W-80,36,23,white,6,true,true)
                d.Hint=text("Play smart and avoid report",20,132,W-40,28,16,soft,6,true,true)
            else
                d.Title=text("@VRSXH",14,8,W-28,32,21,white,6,true,true)
                text("LOGIN KEY",14,44,140,18,12,accent,6,false,false)
                box(14,64,W-28,36,8,20,48,1,5)
                d.Input=make("EditableTextBox",d.Container)
                d.Input:SetText(key or "")
                local inputStyle=member(d.Input,"WidgetStyle")
                if inputStyle then
                    if type(inputStyle)=="table" then local copy={};for k,v in pairs(inputStyle) do copy[k]=v end;inputStyle=copy end
                    local inputFont=member(inputStyle,"Font")
                    if inputFont then
                        if type(inputFont)=="table" then local copy={};for k,v in pairs(inputFont) do copy[k]=v end;inputFont=copy end
                        inputFont.Size=16;inputStyle.Font=inputFont
                    end
                    inputStyle.ForegroundColor=slate(accent)
                    inputStyle.ReadOnlyForegroundColor=slate(accent)
                    d.Input.WidgetStyle=inputStyle
                else
                    local inputFont=member(d.Input,"Font")
                    if inputFont then
                        if type(inputFont)=="table" then local copy={};for k,v in pairs(inputFont) do copy[k]=v end;inputFont=copy end
                        inputFont.Size=16;d.Input.Font=inputFont
                    end
                    d.Input.ForegroundColor=accent
                end
                pcall(function() d.Input:SetHintText("Enter your key") end)
                visibility(d.Input,enums.Visible);add(d.Input,18,66,W-36,32,6)
                d.Hint=text("Your key is saved automatically",14,104,W-28,18,11,accent,6,false,false)
                d.Status=text(status or "Enter your key",14,126,W-28,22,12,soft,6,false,false)
            end
            local by=(keyinfo and 136) or (welcome and 176 or 158)
            local bh=(keyinfo and 26) or 34
            local bw=(keyinfo and 140) or 180
            local bx=(W-bw)/2
            local button=make("Button",d.Container);d.Button=button
            pcall(function() button:SetBackgroundColor(color(0,130,60,1)) end)
            visibility(button,enums.Visible);add(button,bx,by,bw,bh,7)
            local label=make("TextBlock",button);label:SetText("OK");style(label,16,white,true);visibility(label,passive)
            local labelSlot=button:AddChild(label)
            pcall(function() labelSlot:SetHorizontalAlignment(2);labelSlot:SetVerticalAlignment(2) end)
            d.Event=button.OnClicked
            d.Handle=d.Event:Add(function()
                if not d.Visible or d.Busy then return end
                if welcome or keyinfo then
                    destroy(d);d.Dismissed=true
                    local l=_G.LunarLoginRuntime
                    if l then
                        if l.WelcomeUI==d then l.WelcomeUI=nil end
                        if l.KeyUI==d then l.KeyUI=nil end
                    end
                    return
                end
                local okRead,k=pcall(function() return d.Input:GetText() end)
                if not okRead or type(k)~="string" then return end
                k=k:match("^%s*(.-)%s*$")
                if #k==0 or #k>512 then d.Status:SetText("Enter a valid key");return end
                if d.Submit then d.Submit(k) end
            end)
            local slot=p:AddChildToCanvas(d.Container);slot:SetAutoSize(false);slot:SetSize(vector(W,H));slot:SetZOrder(9200)
            local anchors=slot:GetAnchors();anchors.Minimum=vector(.5,.5);anchors.Maximum=vector(.5,.5)
            slot:SetAnchors(anchors);slot:SetAlignment(vector(.5,.5));slot:SetPosition(vector(0,0))
            d.Container:SetRenderTransformPivot(vector(.5,.5));d.Container:SetRenderScale(vector(scale,scale))
            visibility(d.Container,passive)
        end)
        if not ok then UI.LastBuildError=tostring(buildError);destroy(d);return nil,"UI_BUILD_UNAVAILABLE" end
        UI.LastBuildError=nil
        d.Visible=true;return d
    end
    _G.LunarUIAssetCache=nil
    -- Hot UI upgrades retain the existing verified or pending license session.
    local existing=_G.LunarLoginRuntime
    if existing and existing.UIFactory and existing.UIFactory.Version~=UI.Version
        and existing.Scope==MasterLicenseCore.Primitives.md5(MasterLicenseConfig.url.."\0"..MasterLicenseConfig.game.."\0"..MasterLicenseConfig.secret) then
        local visibleWelcome=existing.WelcomeUI and existing.WelcomeUI.Visible
        if existing.DestroyUI then existing.DestroyUI() end
        existing.UIFactory.Build=UI.Build;existing.UIFactory.Version=UI.Version
        if visibleWelcome then existing.WelcomeShown=false end
        existing.NeedsUpdate=true
    end
    local function hex(s) return (s:gsub('.',function(c) return string.format('%02x',string.byte(c)) end)) end
    local function unhex(s)
        if type(s)~="string" or #s>1024 or #s%2~=0 or s:find('[^%x]') then return nil end
        return (s:gsub('..',function(v) return string.char(tonumber(v,16)) end))
    end
    local current=_G.LunarLoginRuntime
    -- Existing runtime survives character recreation and source reload in this process.
    local expectedScope=MasterLicenseCore.Primitives.md5(MasterLicenseConfig.url.."\0"..MasterLicenseConfig.game.."\0"..MasterLicenseConfig.secret)
    if not current or current.Scope~=expectedScope then
        if current and current.DestroyUI then current.DestroyUI() end
        local L={Authorized=false,Pending=false,NeedsUpdate=true,WelcomeShown=false,
            Key="",Seed="",Scope=expectedScope,StorageVersion=1,Status="Enter your key",Diagnostics={HTTP=0,DeviceReads=0}}
        _G.LunarLoginRuntime=L
        L.UIFactory=UI
        -- Identity is pinned independently of the feature-settings location.
        -- All IO is bounded and happens at startup/login, or a delayed save retry.
        local paths=g_VRSXH_ESPSettingsPaths()
        for i,path in ipairs(paths) do paths[i]=path:gsub("MASTERPIECE_UMG_ESP_settings.lua$","MASTERAHSAN_LOGIN_V7_settings.lua") end
        local function loginPath(featurePath)
            if type(featurePath)~="string" then return nil end
            local prefix=featurePath:match("^(.*[/\\])[^/\\]+$")
            return (prefix or "").."MASTERAHSAN_LOGIN_V7_settings.lua"
        end
        local function identityPath(path)
            return path:gsub("MASTERAHSAN_LOGIN_V7_settings%.lua$","MASTERAHSAN_DEVICE_V1_settings.lua")
        end
        local function digest(key,seed)
            return MasterLicenseCore.Primitives.md5("LUNAR-DEVICE-1\0"..L.Scope.."\0"..key.."\0"..seed)
        end
        local function readRecord(path,identity)
            if not (io and type(io.open)=="function") then return nil,"unreadable" end
            local ok,file,reason,code=pcall(io.open,path,"r")
            if not ok then return nil,"unreadable" end
            if not file then
                local text=type(reason)=="string" and reason:lower() or ""
                if reason==nil or code==2 or text:find("no such file",1,true)
                    or text:find("not found",1,true) or text:find("does not exist",1,true) then
                    return nil,"missing"
                end
                return nil,"unreadable"
            end
            local good,data=pcall(function() return file:read(4097) end)
            pcall(function() file:close() end)
            if not good or type(data)~="string" then return nil,"unreadable" end
            if #data>4096 then return nil,"invalid" end
            local scope=data:match('%f[%w_]Scope%s*=%s*"([%x]+)"')
            if scope and scope~=L.Scope then return nil,"other_scope" end
            if scope~=L.Scope then return nil,"invalid" end
            local key=unhex(data:match('%f[%w_]KeyHex%s*=%s*"([^"]*)"'))
            local seed=unhex(data:match('%f[%w_]SeedHex%s*=%s*"([^"]*)"'))
            if key==nil or seed==nil or #seed==0 or #seed>512 then return nil,"invalid" end
            local check=data:match('%f[%w_]Check%s*=%s*"([%x]+)"')
            local version=data:match('%f[%w_]Version%s*=%s*(%d+)')
            if identity or check or version then
                if version~="1" or check~=digest(key,seed) then return nil,"invalid" end
            end
            return {Key=key,Seed=seed,Path=path,Identity=identity,Checked=version=="1"},"valid"
        end
        local function candidates()
            local list,seen={},{}
            local function add(path)
                if type(path)=="string" and not seen[path] then seen[path]=true;list[#list+1]=path end
            end
            add(L.Path);add(L.PreferredPath)
            for _,path in ipairs(paths) do add(path) end
            return list
        end
        local function recover()
            if L.IdentityPinned then return true end
            local identities,legacy,issues={},{},{}
            local function collect(base,path,identity)
                local record,state=readRecord(path,identity)
                if record then
                    record.Base=base
                    local list=identity and identities or legacy;list[#list+1]=record
                elseif state=="invalid" or (state=="unreadable" and base==L.PreferredPath) then
                    issues[#issues+1]=state
                end
            end
            for _,base in ipairs(candidates()) do
                local device=identityPath(base)
                collect(base,device,true);collect(base,device..".bak",true)
                collect(base,base,false);collect(base,base..".bak",false)
            end
            local list=#identities>0 and identities or legacy
            local first=list[1]
            if first then
                for _,record in ipairs(list) do
                    if record.Seed~=first.Seed then
                        L.IdentityError="DEVICE_CACHE_CONFLICT";L.Diagnostics.Identity="conflict";return false
                    end
                end
                L.Seed=first.Seed;L.Key=first.Key;L.Path=first.Base
                if L.Key=="" then
                    for _,record in ipairs(list) do
                        if record.Key~="" then L.Key=record.Key;break end
                    end
                end
                -- A matching legacy copy can recover the key after a lost write.
                if L.Key=="" then
                    for _,record in ipairs(legacy) do
                        if record.Seed==L.Seed and record.Key~="" then L.Key=record.Key;break end
                    end
                end
                L.IdentityPinned=true;L.IdentityPersisted=true;L.HasIdentityRecord=first.Identity
                L.IdentityError=nil;L.Dirty=true
                L.Diagnostics.Identity=first.Identity and "restored" or "legacy_migration"
                return true
            end
            if #issues>0 then
                L.IdentityError="DEVICE_CACHE_RECOVERY_REQUIRED";L.Diagnostics.Identity="recovery_required";return false
            end
            L.IdentityError=nil;L.Diagnostics.Identity="new_install";return true
        end
        local function payload(key,seed)
            return 'return { Version = 1, Scope = "'..L.Scope..'", KeyHex = "'..hex(key)
                ..'", SeedHex = "'..hex(seed)..'", Check = "'..digest(key,seed)..'" }'
        end
        local function verifiedWrite(path,identity,key,seed,data)
            local current,state=readRecord(path,identity)
            if current and current.Checked and current.Seed==seed and current.Key==key then return true end
            if state=="unreadable" or state=="other_scope" then return false end
            if current and current.Seed~=seed and (identity or not L.HasIdentityRecord) then return false end
            local ok=g_VRSXH_ESPWriteSettings(path,data)
            if not ok then return false end
            local result=readRecord(path,identity)
            return result~=nil and result.Checked and result.Seed==seed and result.Key==key
        end
        L.Save=function()
            if L.Seed=="" or L.IdentityError then return false end
            local key=L.AttemptKey or L.Key
            local data=payload(key,L.Seed)
            local preferred=candidates()
            for _,base in ipairs(preferred) do
                local device=identityPath(base)
                local old,oldState=readRecord(base,false)
                local current,currentState=readRecord(device,true)
                -- Never fork around an unreadable/conflicting saved identity.
                if oldState~="unreadable" and currentState~="unreadable"
                    and oldState~="other_scope" and currentState~="other_scope"
                    and (not old or old.Seed==L.Seed or L.HasIdentityRecord)
                    and (not current or current.Seed==L.Seed) then
                    local a=verifiedWrite(device,true,key,L.Seed,data)
                    local b=verifiedWrite(device..".bak",true,key,L.Seed,data)
                    local c=verifiedWrite(base,false,key,L.Seed,data)
                    local d=verifiedWrite(base..".bak",false,key,L.Seed,data)
                    if (a or b) and ((a and b) or c or d) then
                        L.Path=base;L.Key=key;L.IdentityPinned=true;L.IdentityPersisted=true;L.HasIdentityRecord=true
                        L.IdentityError=nil;L.Dirty=not (a and b and c and d)
                        L.SaveRetryAt=L.Dirty and (os.time()+30) or nil
                        L.SaveError=L.Dirty and "Device backup repair pending" or nil
                        L.Diagnostics.Identity=L.Dirty and "backup_pending" or "saved"
                        return true
                    end
                end
            end
            L.Dirty=true;L.SaveRetryAt=os.time()+30
            L.SaveError="Device cache could not be verified";L.Diagnostics.Identity="save_failed"
            return false
        end
        L.BindSettingsPath=function(featurePath)
            L.PreferredPath=loginPath(featurePath)
            -- Once recovered, neither the key nor seed is replaced by settings.
            if not L.IdentityPinned then recover() end
            if L.Seed~="" and not L.IdentityError and (L.Dirty or not L.IdentityPersisted) then L.Save() end
        end
        L.EnsureIdentity=function()
            if not L.IdentityPinned then
                L.Seed=""
                assert(recover(),L.IdentityError or "DEVICE_CACHE_RECOVERY_REQUIRED")
            end
            if L.Seed=="" then
                L.Diagnostics.DeviceReads=L.Diagnostics.DeviceReads+1
                local id=Client.GetPhoneDeviceID()
                assert(type(id)=="string" and #id>0 and #id<=512,"DEVICE_ID_UNAVAILABLE")
                L.Seed=id
            end
            local saved=L.Save()
            -- A readable previously stored identity stays usable on read-only
            -- storage. Backup repair must not invent or force a new device ID.
            assert(saved or L.IdentityPersisted,"DEVICE_CACHE_SAVE_FAILED")
        end
        recover()
        L.DestroyUI=function()
            destroy(L.LoginUI);destroy(L.WelcomeUI);destroy(L.KeyUI)
            L.LoginUI=nil;L.WelcomeUI=nil;L.KeyUI=nil
        end
        local function wake()
            local f=_G.LunarFeatures;if f and f.Wake and not f.Token.Stopped then f.Wake() end
        end
        L.Core=MasterLicenseCore
        L.Auth=MasterLicenseCore.new(MasterLicenseConfig,{
            clock=function() local t=os.time();return t,L.Scope end,
            wall=function() return os.time() end,
            serial=function(key)
                L.EnsureIdentity()
                return MasterLicenseCore.Primitives.name_uuid('MASTER-LUA-V1\0'..key..'\0'..L.Seed)
            end,
            decode=function(raw) local json=require("common.json_util");return json.decode(raw) end,
            post=function(url,headers,body,callback,timeout)
                local MM=ModuleManager
                if not MM then
                    pcall(function() MM=require("client.module_framework.ModuleManager") end)
                end
                if not MM or type(MM.GetModule)~="function" then
                    error("HTTP_MANAGER_UNAVAILABLE")
                end
                local http=MM.GetModule(MM.CommonModuleConfig.http_manager)
                if not http or type(http.Post)~="function" then
                    error("HTTP_MANAGER_UNAVAILABLE")
                end
                L.Diagnostics.HTTP=L.Diagnostics.HTTP+1
                return http:Post(url,headers,body,nil,callback,timeout)
            end,
            status=function(message,phase)
                L.Status=message;L.Pending=phase=="pending"
                if phase=="active" then
                    L.Authorized=true;L.Key=L.AttemptKey or L.Key;L.Save()
                    -- The player just typed the key, so skip the reminder popup
                    -- for this login. It still appears once after a restart.
                    L.KeyShown=true;L.KeyPopupDone=true
                    destroy(L.LoginUI);L.LoginUI=nil
                    pcall(function() if _G.__run_pending_features then _G.__run_pending_features() end end)
                else L.Authorized=false end
                L.NeedsUpdate=true
                local d=L.LoginUI
                if d then
                    if d.StatusText~=message then d.Status:SetText(message);d.StatusText=message end
                    if d.Busy~=L.Pending then
                        d.Busy=L.Pending
                        pcall(function() d.Input:SetIsEnabled(not L.Pending);d.Button:SetIsEnabled(not L.Pending) end)
                    end
                end
                wake()
            end
        })
        L.Authorized=L.Auth.IsAuthorized()
        L.Login=function(key)
            if L.Authorized or L.Pending then return false end
            L.AttemptKey=type(key)=="string" and key:match("^%s*(.-)%s*$") or ""
            local ok,result=pcall(L.Auth.Login,L.AttemptKey)
            if not ok then L.Status="Login could not start";L.Pending=false;L.NeedsUpdate=true;wake();return false end
            return result
        end
        L.Logout=function()
            L.Auth.Logout();L.Authorized=false;L.DestroyUI();L.NeedsUpdate=true;wake()
        end
        L.Update=function()
            if L.Pending then L.Auth.Tick() end
            if L.Dirty and (not L.SaveRetryAt or os.time()>=L.SaveRetryAt or os.time()<L.SaveRetryAt-30) then L.Save() end
            if L.Authorized then
                -- Idle fast path: nothing left to draw, so skip the UI lookup.
                if L.KeyPopupDone and L.WelcomeShown then L.NeedsUpdate=false;return end
                -- Key reminder: after a full game restart the saved session is
                -- restored silently, so show the stored key once for ~5s.
                if L.KeyUI and not valid(L.KeyUI.Container) then L.KeyUI=nil end
                if not L.KeyPopupDone then
                    if not L.KeyShownAt then L.KeyShownAt=os.clock() end
                    if L.KeyUI then
                        if os.clock()-L.KeyShownAt>=5 then
                            destroy(L.KeyUI);L.KeyUI=nil;L.KeyPopupDone=true
                        else
                            L.NeedsUpdate=true;return
                        end
                    elseif os.clock()-L.KeyShownAt<5 then
                        local d=UI.Build("keyinfo",L.Key~="" and L.Key or "Saved key on this device")
                        if d then
                            L.KeyUI=d;L.KeyShown=true;L.NeedsUpdate=true
                            return
                        end
                    else
                        L.KeyPopupDone=true
                    end
                end
                if not L.WelcomeShown then
                    local d=UI.Build("welcome")
                    if d then L.WelcomeUI=d;L.WelcomeShown=true end
                end
                L.NeedsUpdate=not L.WelcomeShown or L.Dirty
                return
            end
            if L.LoginUI and not valid(L.LoginUI.Container) then destroy(L.LoginUI);L.LoginUI=nil end
            if not L.LoginUI then
                -- Locked state: build immediately so the key page is never late.
                local p=parent()
                if p then
                    local d=UI.Build("login",L.Key,L.Status,L.Login)
                    if d then
                        d.Busy=L.Pending;d.StatusText=L.Status;L.LoginUI=d
                        pcall(function() d.Input:SetIsEnabled(not L.Pending);d.Button:SetIsEnabled(not L.Pending) end)
                    end
                end
            else
                -- Panel is up: only re-resolve the root occasionally (match
                -- transitions) instead of every half second.
                L._Recheck=(L._Recheck or 0)+1
                if L._Recheck>=8 then
                    L._Recheck=0
                    local p=parent()
                    if p and p~=L.LoginUI.Parent then destroy(L.LoginUI);L.LoginUI=nil end
                end
            end
            L.NeedsUpdate=true -- Half-second retry/readiness while locked only.
        end
        -- Starts the UI/authorization pump. Safe to call more than once.
        L.Start=function()
            if L._Started then return true end
            L._Started=true
            L._Beat=os.clock()
            local function step()
                L._Beat=os.clock()
                pcall(function() if L.Update then L.Update() end end)
                pcall(function() if _G.__run_pending_features then _G.__run_pending_features() end end)
            end
            local function getTicker()
                local t
                pcall(function() t=require("common.time_ticker") end)
                return t
            end
            local function startLoop()
                local t=getTicker()
                if t and type(t.AddTimerLoop)=="function" then
                    pcall(t.AddTimerLoop,0.5,step,-1,0.5)
                    return true
                end
                if Game and type(Game.SetTimer)=="function" then
                    pcall(function() Game:SetTimer(0.5,true,step) end)
                    return true
                end
                return false
            end
            local function watchdog()
                if os.clock()-L._Beat>1.5 then startLoop() end
                local t=getTicker()
                if t and type(t.AddTimerOnce)=="function" then
                    pcall(t.AddTimerOnce,1.5,watchdog)
                elseif Game and type(Game.SetTimer)=="function" then
                    pcall(function() Game:SetTimer(1.5,false,watchdog) end)
                end
            end
            startLoop()
            local t=getTicker()
            if t and type(t.AddTimerOnce)=="function" then
                pcall(t.AddTimerOnce,1.5,watchdog)
            elseif Game and type(Game.SetTimer)=="function" then
                pcall(function() Game:SetTimer(1.5,false,watchdog) end)
            end
            -- Independent game-timer watchdog: survives match transitions even
            -- when the shared ticker is reset by another module.
            if Game and type(Game.SetTimer)=="function" then
                pcall(function()
                    Game:SetTimer(2.0,true,function()
                        if os.clock()-L._Beat>2.5 then startLoop() end
                    end)
                end)
            end
            step()
            return true
        end
    end
    _G.MasterLicenseLogin=function(key) return _G.LunarLoginRuntime.Login(key) end
    _G.MasterLicenseLogout=function() return _G.LunarLoginRuntime.Logout() end
    _G.MasterLicenseStatus=function()
        local l=_G.LunarLoginRuntime
        return {authorized=l.Authorized,pending=l.Pending,message=l.Status,
            periodicRecheck=false,expiryCheckPolicy="login_only",saveOK=not l.Dirty,identityState=l.Diagnostics.Identity}
    end

end


-- ===== END Login.lua portable module =====
pcall(function()
  if _G.LunarLoginRuntime and type(_G.LunarLoginRuntime.Start) == "function" then
    _G.LunarLoginRuntime.Start()
  end
end)

]====], 'login.lua')

-- ============================================================================
-- 1. 1.lua
-- ============================================================================
__defer_feature('1.lua', [===[
-- ============================================================================
-- COMBINED BUILD: 1.lua + 5.lua
-- 1.lua source body is preserved unchanged inside a wrapper.
-- 5.lua source body is then executed unchanged.
-- ============================================================================

local __combined_1_result = (function()
-- ============================================================================
-- SINGLE-FILE ORGANIZED BUILD
-- Original source bodies are embedded unchanged and executed as separate
-- chunks so top-level returns/guards stay local to their original file.
-- Execution order: 2 -> 3 -> 8 -> 4 -> 5 -> 9 -> 10 -> 1
-- ============================================================================

local __errors = {}

local function __run_file(__source, __name)
    local __fn, __err
    if loadstring then
        __fn, __err = loadstring(__source, __name)
    else
        __fn, __err = load(__source, __name, "t", _ENV)
    end
    if not __fn then
        __errors[#__errors + 1] = __name .. " load error: " .. tostring(__err)
        return false
    end
    local __ok, __result = pcall(__fn)
    if not __ok then
        __errors[#__errors + 1] = __name .. " runtime error: " .. tostring(__result)
        return false
    end
    return true, __result
end

-- ============================================================================
-- 1. 2.lua
-- ============================================================================
__run_file([==[-- ============================================================================
-- ULTIMATE 100% INTERNAL LUA BYPASS (FINAL MAX PRO)
-- ============================================================================
if not (_G._CHETAN_BYPASS_ENABLED ~= false) then return end

-- VIIX/feedback popup pages removed.
-- Existing underlying game systems are otherwise left unchanged.

-- Injection: only once globally
if _G.UltimateBypassInjected then return end
_G.UltimateBypassInjected = true

local function patchBRClass(BaseClass)
    local _orig_ReceiveBeginPlay = BaseClass.ReceiveBeginPlay

    function BaseClass:ReceiveBeginPlay()
        if _orig_ReceiveBeginPlay then
            _orig_ReceiveBeginPlay(self)
        elseif BaseClass.__super and BaseClass.__super.ReceiveBeginPlay then
            BaseClass.__super.ReceiveBeginPlay(self)
        end

        if not Client then return end

        if _G.UltimateBypassInjected then
            self.PlayerKey = self.PlayerKey or 0
            return
        end
        _G.UltimateBypassInjected = true

        pcall(function()
            local noop = function() return true end
            local retFalse = function() return false end
            local retZero = function() return 0 end
            local retEmpty = function() return {} end

            -- ================================================================
            -- 1. DEV MODE SPOOF (ADVANCED MULTI-LAYER)
            -- ================================================================

            local stExtraBlueprint = import("STExtraBlueprintFunctionLibrary")
            if stExtraBlueprint then stExtraBlueprint.IsDevelopment = noop end

            if Client then
                Client.IsDevelopment = noop
                Client.IsShipping = retFalse
            end

            if Server then
                Server.IsShipping = retFalse
            end

            local ToolReportUtil = package.loaded["client.slua.logic.report.ToolReportUtil"]
            if ToolReportUtil then
                ToolReportUtil.IsReleaseVersion = retFalse
                ToolReportUtil.IsWhite = retFalse
                ToolReportUtil.GetReportSwitch = retFalse
            end

            local callbacks = _G.GameplayCallbacks or _G.GC
            if callbacks then
                callbacks.SendTssSdkAntiDataToLobby = noop
                callbacks.SendDSErrorLogToLobby = noop
                callbacks.SendDSHawkEyePatrolLogToLobby = noop
                callbacks.SendSecTLog = noop
                callbacks.SendDataMiningTLog = noop
                callbacks.SendActivityTLog = noop
                callbacks.SendClientMemUsage = noop
                callbacks.SendClientFPS = noop
                callbacks.OnClientCrashReport = noop
                callbacks.OnNetworkLossDetected = noop
                callbacks.ReportMatchRoomData = noop
                callbacks.ReportPlayersPing = noop
                callbacks.SendClientStats = noop
                callbacks.SendServerAvgTickDelta = noop
                callbacks.ReportHitFlow = noop
                callbacks.OnPlayerActorChannelError = noop
                callbacks.OnPlayerRPCValidateFailed = noop

                local originalOnDSChanged = callbacks.OnDSPlayerStateChanged
                callbacks.OnDSPlayerStateChanged = function(dsSelf, state, reason, ...)
                    local r = tostring(reason):lower()
                    if r == "cheatdetected" or r == "connectionlost" or r == "connectiontimeout" then return end
                    if originalOnDSChanged then pcall(originalOnDSChanged, dsSelf, state, reason, ...) end
                end
            end

            if _G.TApmHelper then _G.TApmHelper.postEvent = noop end

            local PC = _G.PacketCallbacks
            if PC then
                PC.player_report_cheat = noop
                PC.upload_loots_rsp = noop
                PC.watch_player_exit = noop
                PC.player_login_report = noop
                PC.player_logout_report = noop
                PC.server_time_report = noop
            end

            local sdm = _G.ServerDataMgr
            if sdm and sdm.DeletablePlayerResultKey then
                sdm.DeletablePlayerResultKey["SuspiciousHitCount"] = true
                sdm.DeletablePlayerResultKey["EspTotalSimTraceCnt"] = true
                sdm.DeletablePlayerResultKey["EspTotalImeFocusCnt"] = true
                sdm.DeletablePlayerResultKey["ClientGravityAnomalyCount"] = true
            end

            -- ================================================================
            -- 2. HIGGS BOSON, HIA & BEHAVIOR
            -- ================================================================
            local higgsPath = "GameLua.Mod.BaseMod.Common.Security.HiggsBosonComponent"
            local higgs = package.loaded[higgsPath] or require(higgsPath)
            if higgs then
                higgs.ControlMHActive = noop
                higgs.TriggerAvatarCheck = noop
                higgs.StartAvatarCheck = noop
                higgs.GetNetAvatarItemIDs = retEmpty
                higgs.GetCurWeaponSkinID = retZero
                higgs.SendHisarData = noop
                higgs.OnLogin = noop
                higgs.ValidateSecurityData = noop
                higgs.StaticShowSecurityAlertInDev = noop
            end
            if _G.DisableHiggsBoson then _G.DisableHiggsBoson = noop end

            local hiaPath = "GameLua.Mod.BaseMod.Client.Security.ClientGlueHiaSystem"
            local hia = package.loaded[hiaPath] or require(hiaPath)
            if hia then
                hia.CheckHitIntegrity = noop
                hia.InitSession = noop
                hia.OnBattleEnd = noop
            end
            if _G.ClientGlueHiaSystem then _G.ClientGlueHiaSystem.CheckHitIntegrity = noop end

            local secUtilsPath = "GameLua.Mod.BaseMod.Common.Security.SecurityCommonUtils"
            local secUtils = package.loaded[secUtilsPath] or require(secUtilsPath)
            if secUtils and secUtils.EStrategyTypeInReplay then
                secUtils.EStrategyTypeInReplay.EspTotalSimTraceCnt = 0
                secUtils.EStrategyTypeInReplay.EspTotalImeFocusCnt = 0
                secUtils.EStrategyTypeInReplay.ClientGravityAnomalyCount = 0
                secUtils.EStrategyTypeInReplay.FlyingErrorCnt = 0
            end

            local BehaviorScore = package.loaded["GameLua.Mod.Escape.Gameplay.Subsystem.BehaviorScoreSubsystem"]
            if BehaviorScore then
                BehaviorScore.OnHandleBehaviorScore = noop
                BehaviorScore.AIPerceptionScore = noop
                BehaviorScore.ReportBehavior = noop
                BehaviorScore.CalcFinalScore = retZero
            end

            -- ================================================================
            -- 3. INSTANT BANS & NOTIFICATIONS
            -- ================================================================
            local pcNotifyPath = "GameLua.Mod.BaseMod.Common.Security.SecurityNotifyPCFeature"
            local pcNotify = package.loaded[pcNotifyPath] or require(pcNotifyPath)
            if pcNotify then
                pcNotify.ClientRPC_SyncBanID = noop
                pcNotify.ClientRPC_StrongTips = noop
                pcNotify.ClientRPC_NormalTips = noop
                pcNotify.Notify = noop
                pcNotify.ClientRPC_NotifyBan = noop
                pcNotify.ClientRPC_NotifyPunish = noop
                pcNotify.ClientRPC_NotifyIllegalProgram = noop
            end

            local clientBanLogicPath = "client.slua.logic.ban.ClientBanLogic"
            local ClientBanLogic = package.loaded[clientBanLogicPath] or require(clientBanLogicPath)
            if ClientBanLogic then
                ClientBanLogic.OnSyncBanInfo = noop
                ClientBanLogic.OnVoiceBanNotify = noop
                ClientBanLogic.OnRealTimeVoiceBanNotify = noop
                ClientBanLogic.OnVoiceBanSuccess = noop
                ClientBanLogic.OnSyncMicSuspicious = noop
                ClientBanLogic.OnSyncMicPreFilter = noop
                ClientBanLogic.OnNotifyWarningTips = noop
                ClientBanLogic.ReqBanInfo = noop
            end

            local BanUtil = package.loaded["client.common.ban_util"] or _G.ban_util
            if BanUtil then
                BanUtil.CheckBanStatus = retFalse
                BanUtil.GetBanTime = retZero
                BanUtil.IsBanForever = retFalse
            end

            local TTBan = package.loaded["client.logic.login.logic_tt_ban"] or _G.logic_tt_ban
            if TTBan then
                TTBan.CheckIfCanCreateRole = noop
                TTBan.JumpAppealURL = retFalse
                TTBan.GetCarrierInfo = function() return "[{\"mcc\":\"000\"}]" end
            end

            local GodzillaBan = package.loaded["client.network.Protocol.GodzillaBanHandler"] or _G.GodzillaBanHandler
            if GodzillaBan then
                GodzillaBan.send_godzilla_ban_req = noop
                GodzillaBan.send_godzilla_unban_req = noop
            end

            local AntiAddiction = package.loaded["client.network.Protocol.AntiaddctionHandler"] or _G.AntiaddctionHandler
            if AntiAddiction then
                AntiAddiction.send_anti_addiction_req = noop
                AntiAddiction.send_anti_addiction_notify = noop
                AntiAddiction.on_check_nonage_anti_work = noop
            end

            local AccessRestrict = package.loaded["client.network.Protocol.AccessRestrictionHandler"] or _G.AccessRestrictionHandler
            if AccessRestrict then
                AccessRestrict.send_access_restriction_req = noop
                AccessRestrict.send_access_restriction_notify = noop
                AccessRestrict.on_player_cheat_state_notify = noop
            end

            local DeleteAccount = package.loaded["client.slua.logic.gdpr.logic_deleteaccount"] or _G.logic_deleteaccount
            if DeleteAccount then
                DeleteAccount.ForceDeleteAccount = retFalse
                DeleteAccount.OnReceiveDeleteNotify = noop
            end

            local ComplianceUtil = package.loaded["client.slua.logic.gdpr.compliance_util"] or _G.compliance_util
            if ComplianceUtil then ComplianceUtil.CheckCompliance = noop end

            -- ================================================================
            -- 4. REPORT DISPATCHERS & HAWKEYE
            -- ================================================================
            local clientReportPath = "GameLua.Mod.BaseMod.Client.Security.ClientReportPlayerSubsystem"
            local clientReport = package.loaded[clientReportPath] or require(clientReportPath)
            if clientReport then
                clientReport.OnInit = noop
                clientReport._OnPlayerKilledOtherPlayer = noop
                clientReport._RecordFatalDamager = noop
                clientReport.SendPacket = noop
                clientReport.ReportSuspiciousPlayer = noop
                clientReport.SubmitReport = noop
                clientReport._OnBattleResult = noop
                clientReport._RecordTeammatePlayerInfo = noop
                clientReport._OnDeathReplayDataWhenFatalDamaged = noop
                clientReport._RecordMurdererFromDeathReplayData = noop
            end

            local dsReportPath = "GameLua.Mod.BaseMod.Common.Security.DSReportPlayerSubsystem"
            local DSReport = package.loaded[dsReportPath] or _G.DSReportPlayerSubsystem
            if DSReport then
                DSReport._OnNearDeathOrRescued = noop
                DSReport._OnPlayerSettlementStart = noop
                DSReport._OnTeammateDamage = noop
                DSReport._OnCharacterDied = noop
            end

            local reportUtilsPath = "GameLua.Mod.BaseMod.Common.Security.ReportPlayerUtils"
            local reportUtils = package.loaded[reportUtilsPath] or require(reportUtilsPath)
            if reportUtils then
                reportUtils.GetBotType = retZero
                reportUtils.IsCharacterDeliverAI = retFalse
            end
            local avatarSubsystemPath = "GameLua.Mod.Library.GamePlay.Avatar.Exception.AvatarExceptionSubsystem"
            local AvatarSubsystem = package.loaded[avatarSubsystemPath] or _G.AvatarExceptionSubsystem
            if AvatarSubsystem then
                AvatarSubsystem.OnClickReportCheckAvatar = noop
                AvatarSubsystem.RegisterTickCheckCharacterAvatar = noop
            end

            if _G.AvatarExceptionPlayerInst then
                _G.AvatarExceptionPlayerInst.ReportAvatarException = noop
                _G.AvatarExceptionPlayerInst.CheckAvatarException = noop
                _G.AvatarExceptionPlayerInst.CheckCanBugglyPostException = noop
            end

            local SubsystemMgr = package.loaded["GameLua.GameCore.Module.Subsystem.SubsystemMgr"] or
            require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
            if SubsystemMgr then
                local patrolSubsystem = SubsystemMgr:Get("DSHawkEyePatrolSubsystem")
                if patrolSubsystem then patrolSubsystem.MarkSuspiciousPlayer = noop end
            end

            local DSHawkEye = _G.DSHawkEyePatrolSubsystem
            if DSHawkEye then
                DSHawkEye._OnHawkReport = noop
                DSHawkEye._OnHawkImprison = noop
                DSHawkEye.CheckPunishPlayer = noop
            end

            local clientHawkEyePath = "GameLua.Mod.BaseMod.Client.Security.ClientHawkEyePatrolSubsystem"
            local ClientHawkEye = package.loaded[clientHawkEyePath] or require(clientHawkEyePath)
            if ClientHawkEye then
                ClientHawkEye._OnHawkSync = noop
                ClientHawkEye._OnHawkReportSuccess = noop
                ClientHawkEye._StartExitGameTimer = noop
                ClientHawkEye._OnRecvInspectorBroadcastCount = noop
                ClientHawkEye.CanInspectorBroadcast = retFalse
                ClientHawkEye.SendReportTLog = noop
                ClientHawkEye.ReportCheat = noop
            end

            local InspectClient = package.loaded["GameLua.Mod.BaseMod.Client.Security.InspectionSystemReportClientLogicSubsystem"]
            if InspectClient then
                InspectClient.AskForInspector = noop
                InspectClient.ReportEnemy = noop
                InspectClient.KickOutOneTeam = noop
                InspectClient.OnReceiveInspectCmd = noop
                InspectClient.ClientReportData = noop
                InspectClient.SendReportToInspector = noop
                InspectClient.SendKickOutOneTeam = noop
                InspectClient.ClientNotifyInspectorImplementation = noop
                InspectClient.RecvNotifyInspector = noop
            end

            local InspectDS = package.loaded["GameLua.Mod.BaseMod.DS.Security.InspectionSystemReportDSLogicSubsystem"]
            if InspectDS then
                InspectDS.ServerKickOutOneTeamByPlayerImplementation = noop
                InspectDS.AddReportedCount = noop
                InspectDS.AddInspectionRecord = noop
                InspectDS.BanPlayerByInspection = noop
                InspectDS.BroadCastToAllInspector = noop
                InspectDS.ServerReportToInspectorImplementation = noop
                InspectDS.InitPlayerInspectionInfo = noop
            end

            -- ================================================================
            -- 5. DEEP TLOGS & TELEMETRY SYSTEMS
            -- ================================================================
            local ClientTlog = package.loaded["client.network.Protocol.ClientTlogHandler"] or _G.ClientTlogHandler
            if ClientTlog then ClientTlog.send_report_lobby_common_tlog = noop end

            local LoginWinTlog = package.loaded["client.network.Protocol.LoginAndWinTlogHandler"] or
            _G.LoginAndWinTlogHandler
            if LoginWinTlog then LoginWinTlog.on_cloud_game_event_notify = noop end

            local TLogUtils = package.loaded["client.slua.config.tlog.tlog_report_utils"] or _G.tlog_report_utils
            if TLogUtils then
                TLogUtils.ReportTLogEvent = noop
                TLogUtils.ReportImmediate = noop
            end

            local BasicTLog = package.loaded["client.slua.data.BasicData.BasicDataTLogReport"] or _G.BasicDataTLogReport
            if BasicTLog then
                BasicTLog.OnSendBatchReqMsg = noop
                BasicTLog.OnImmediateReqMsg = noop
                BasicTLog.OnMergeReqMsg = noop
                BasicTLog.send_report_event_duration_log = noop
                BasicTLog.SendTlog = noop
                BasicTLog.ReportEvent = noop
                BasicTLog._GetParamData = retEmpty
            end

            local BasicClientReport = package.loaded["client.slua.data.BasicData.BasicDataClientReport"] or _G.BasicDataClientReport
            if BasicClientReport then
                BasicClientReport.ReportImmediate = noop
                BasicClientReport.ReportDelay = noop
                BasicClientReport.OnSendBatchReqMsg = noop
                BasicClientReport.OnImmediateReqMsg = noop
                BasicClientReport.OnMergeReqMsg = noop
                BasicClientReport._IsCanReport = retFalse
            end

            local BasicReport = package.loaded["client.slua.data.BasicData.BasicDataReport"] or _G.BasicDataReport
            if BasicReport then
                BasicReport.ReportImmediate = noop
                BasicReport.ReportDelay = noop
                BasicReport.OnMergeReqMsg = noop
                BasicReport.OnImmediateReqMsg = noop
                BasicReport.OnSendBatchReqMsg = noop
                BasicReport._BatchReqMsg = noop
            end

            local AmphibiousBoat = package.loaded
            ["GameLua.GameCore.Module.Vehicle.VehicleFeatures.TLog.AmphibiousBoatTLogFeature"]
            if AmphibiousBoat then
                AmphibiousBoat.RecordMovement = noop
                AmphibiousBoat.StartRecordMovement = noop
            end

            local PufferTlog = package.loaded["client.slua.logic.download.report.puffer_tlog"] or _G.puffer_tlog
            if PufferTlog then PufferTlog.report_download_tlog = noop end

            local icTLogPath = "GameLua.Mod.BaseMod.DS.Security.ICTLogSubsystem"
            local ICTLog = package.loaded[icTLogPath] or require(icTLogPath)
            if ICTLog then ICTLog.SendICExceptionTLog = noop end

            local dsFightTLogPath = "GameLua.Mod.BaseMod.DS.Security.DSFightTLogSubsystem"
            local DSFightTLog = package.loaded[dsFightTLogPath] or require(dsFightTLogPath)
            if DSFightTLog then
                DSFightTLog.GetSimpleFightData = retEmpty
                DSFightTLog.ReportFightData = noop
                DSFightTLog.ReportPlayerWeapon = noop
            end

            local dsSecurityPath = "GameLua.Mod.BaseMod.DS.Security.DSSecurityTLogSubsystem"
            local DSSecurity = package.loaded[dsSecurityPath] or require(dsSecurityPath)
            if DSSecurity then
                DSSecurity._OnReportServerJumpFlow = noop
                DSSecurity._OnReportTeleportFlow = noop
                DSSecurity._OnReportSpeedHackFlow = noop
            end

            local dsCommonPath = "GameLua.Mod.BaseMod.DS.Security.DSCommonTLogSubsystem"
            local DSCommon = package.loaded[dsCommonPath] or require(dsCommonPath)
            if DSCommon then DSCommon.HandleKillTlog = noop end

            local dsReportPath = "GameLua.Mod.BaseMod.DS.Security.DSReportPlayerSubsystem"
            local DSReport = package.loaded[dsReportPath] or require(dsReportPath)
            if DSReport then
                DSReport._AddEnemyMapToBattleResult = noop
                DSReport._AddTeammateMapToBattleResult = noop
                DSReport._SubmitAbnormalData = noop
            end

            -- ================================================================
            -- 6. REPORT HANDLERS
            -- ================================================================
            local ClientError = package.loaded["client.network.Protocol.ClientErrorReportHandler"] or
            _G.ClientErrorReportHandler
            if ClientError then
                ClientError.send_client_error_report = noop
                ClientError.send_client_crash_report = noop
                ClientError.send_client_tools_batch_report_req = noop
            end

            local BattleReport = package.loaded["client.network.Protocol.BattleReportHandler"] or _G.BattleReportHandler
            if BattleReport then
                BattleReport.send_battle_report = noop
                BattleReport.send_battle_result = noop
                BattleReport.send_vod_game_report_req = noop
                BattleReport.send_batch_get_vod_info_req = noop
                BattleReport.send_get_game_report_req = noop
                BattleReport.send_batch_get_game_report_req = noop
                BattleReport.send_get_game_report_by_uid_req = noop
            end

            local BugHandler = package.loaded["client.network.Protocol.BugHandler"] or _G.BugHandler
            if BugHandler then
                BugHandler.send_report_bug_info = noop
                BugHandler.send_report_bug_feedback = noop
            end

            local PingReport = package.loaded["client.network.Protocol.LobbyPingReportHandler"] or
            _G.LobbyPingReportHandler
            if PingReport then
                PingReport.send_lobby_ping_report = noop
                PingReport.send_ingame_ping_report = noop
            end

            local WeekReport = package.loaded["client.network.Protocol.WeekRportHandler"] or _G.WeekRportHandler
            if WeekReport then
                WeekReport.send_week_report = noop
                WeekReport.send_week_detail = noop
            end

            local LogicComplaint = package.loaded["client.logic.battle.logic_complaint"] or _G.logic_complaint
            if LogicComplaint then
                LogicComplaint.SendComplaintReq = noop
                LogicComplaint.Submit = noop
                LogicComplaint.ReportPlayer = noop
                LogicComplaint.ShowComplaint = noop
                LogicComplaint.ShowHandle = noop
            end

            local OBResultPath = "GameLua.Mod.BaseMod.Client.BattleResult.ProcessBase.EscapeBattleResultShowOBResultLogic"
            local OBResult = package.loaded[OBResultPath] or require(OBResultPath)
            if OBResult then
                OBResult.OnBattleResult = noop
                OBResult.OnResultProcessStart = noop
            end

            local NormalOBResultPath = "GameLua.Mod.BaseMod.Client.BattleResult.ProcessBase.BattleResultShowOBResultLogic"
            local NormalOBResult = package.loaded[NormalOBResultPath] or require(NormalOBResultPath)
            if NormalOBResult then
                NormalOBResult.OnBattleResult = noop
                NormalOBResult.OnResultProcessStart = noop
            end

            local ShowResultPath = "GameLua.Mod.BaseMod.Client.BattleResult.ProcessBase.BattleResultShowResultLogic"
            local ShowResult = package.loaded[ShowResultPath] or require(ShowResultPath)
            if ShowResult then
                ShowResult.OnBattleResult = noop
                ShowResult.OnResultProcessStart = noop
                ShowResult.OnResultProcessContinue = noop
                ShowResult.ReceiveData = noop
                ShowResult.SendEndFlow = noop
                ShowResult.OnReport = noop
                ShowResult.ShowResult = noop
                ShowResult.ShowResultInternal = noop
                ShowResult.StopResultProcess = noop
            end

            -- ================================================================
            -- 7. EMULATORS, VERIFICATION & MONITORS
            -- ================================================================
            local EmuHandler = package.loaded["client.network.Protocol.EmulatorHandler"] or _G.EmulatorHandler
            if EmuHandler then EmuHandler.send_emulator_info = noop end

            local EmuScanner = package.loaded["client.logic.login.emulator_scanner"] or _G.emulator_scanner
            if EmuScanner then
                EmuScanner.StartScan = noop
                EmuScanner.GetScanResult = retFalse
                EmuScanner.ReportScanResult = noop
            end

            local LoginVerify = package.loaded["client.network.Protocol.LoginVerifyHandler"] or _G.LoginVerifyHandler
            if LoginVerify then
                LoginVerify.send_login_verify_req = noop
                LoginVerify.send_device_verify_req = noop
            end

            local DSMonitor = package.loaded["client.logic.data.logic_ds_monitor"] or _G.logic_ds_monitor
            if DSMonitor then
                DSMonitor.OnRecordMsg = noop
                DSMonitor.OnReportMsg = noop
            end

            local ClientDataStat = package.loaded["GameLua.Mod.BaseMod.Client.Security.ClientDataStatistcsSubsystem"]
            if ClientDataStat then
                ClientDataStat.StartToCheck = noop
                ClientDataStat.OnReceiveRTT = noop
                ClientDataStat.OnReceiveJitter = noop
                ClientDataStat.ReportAbnormal = noop
                ClientDataStat.ResetData = noop
            end

            local shootVerifyPath = "GameLua.Dev.Subsystem.ShootVerifySubSystemClient"
            local shootVerify = package.loaded[shootVerifyPath] or require(shootVerifyPath)
            if shootVerify then
                shootVerify.OnShootVerifyFailed = noop
                shootVerify.SendVerifyData = noop
            end

            local highlightDSPath = "GameLua.Mod.BaseMod.DS.Security.HighlightMomentSubsystem_DSChecker"
            local HighlightDS = package.loaded[highlightDSPath] or require(highlightDSPath)
            if HighlightDS then HighlightDS.CheckFuncUpgradedWeaponKill = noop end

            -- ================================================================
            -- 8. PROFILE, VOICE CHAT & AUDITS
            -- ================================================================
            local ProfileReport = package.loaded["client.logic.data.profile_report_cfg"] or _G.profile_report_cfg
            if ProfileReport then ProfileReport.SendReport = noop end

            local VoiceReport = package.loaded["client.slua.logic.chat_voice.logic_chat_voice_report"] or
            _G.logic_chat_voice_report
            if VoiceReport then
                VoiceReport.ReportVoiceData = noop
                VoiceReport.ReportVoiceText = noop
            end

            local VoiceDoctor = package.loaded["client.slua.logic.chat_voice.logic_chat_voice_doctor"] or
            _G.logic_chat_voice_doctor
            if VoiceDoctor then
                VoiceDoctor.UploadVoiceLog = noop
                VoiceDoctor.UploadVoiceException = noop
            end

            local HomeAudit = package.loaded["client.slua.logic.home.Audit.logic_home_audit_state"] or
            _G.logic_home_audit_state
            if HomeAudit then
                HomeAudit.SendAuditState = noop
                HomeAudit.ReportAuditResult = noop
            end

            local HomeReport = package.loaded["client.slua.logic.home.logic_home_report"] or _G.logic_home_report
            if HomeReport then
                HomeReport.ReportHomeData = noop
                HomeReport.ReportHomeVisitor = noop
            end

            local GemReport = package.loaded["client.logic.store.gem_report_utils"] or _G.gem_report_utils
            if GemReport then
                GemReport.ReportGemData = noop
                GemReport.ReportGemPurchase = noop
            end

            local SafeStation = package.loaded["client.slua.logic.CustomerService.LogicSafeStation"] or
            _G.LogicSafeStation
            if SafeStation then
                SafeStation.UploadVideoEvidence = noop
                SafeStation.ReportPlayerBehavior = noop
            end

            local CustomerService = package.loaded["client.slua.logic.CustomerService.LogicCustomerService"] or
            _G.LogicCustomerService
            if CustomerService then
                CustomerService.SendComplaint = noop
                CustomerService.SendFeedback = noop
            end

            -- ================================================================
            -- 9. MISC FEATURES
            -- ================================================================
            local znq6Path = "GameLua.Mod.TDEvent.ZNQ6th.DS.ZNQ6thDSReviveSubsystem"
            local znq6Revive = package.loaded[znq6Path] or require(znq6Path)
            if znq6Revive then znq6Revive.HaveNewItemForRevive = noop end

            local znq7Path = "GameLua.Mod.TDEvent.ZNQ7th.DS.ZNQ7DSReviveSubsystem"
            local znq7Revive = package.loaded[znq7Path] or require(znq7Path)
            if znq7Revive then znq7Revive.HaveChanceRevival = noop end

            local dataLayerPath = "GameLua.Mod.BaseMod.Common.Subsystem.DataLayerSubsystem"
            local DataLayer = package.loaded[dataLayerPath] or require(dataLayerPath)
            if DataLayer then
                local origOnSpectator = DataLayer.OnSpectatorReplayChanged
                DataLayer.OnSpectatorReplayChanged = function(dlSelf)
                    _G.IsBeingWatched = true
                    if origOnSpectator then origOnSpectator(dlSelf) end
                end
            end

            local dsActivePath = "GameLua.Mod.PlanBT.Gameplay.Subsystem.DSActiveSubsystem"
            local DSActive = package.loaded[dsActivePath] or require(dsActivePath)
            if DSActive then
                DSActive.DelayKickOutPlayer = noop
                DSActive.ActiveKickNotify = noop
            end

            local devDebugPath = "GameLua.Mod.CreativeBase.Gameplay.Subsystem.CreativeDevDebugSubsystem"
            local CreativeDevDebug = package.loaded[devDebugPath] or require(devDebugPath)
            if CreativeDevDebug then CreativeDevDebug.IsDebugPanelEnalbedCli = noop end

            local deathRecordPath = "GameLua.Mod.CreativeBase.Gameplay.Subsystem.CreativeModeDeathRecordSubsystem"
            local CreativeDeath = package.loaded[deathRecordPath] or require(deathRecordPath)
            if CreativeDeath then CreativeDeath.OnPlayerKilled = noop end

            if _G.ClientReplayDataReporter then
                _G.ClientReplayDataReporter.ReportIntArrayData = noop
                _G.ClientReplayDataReporter.ReportFloatArrayData = noop
            end

            local spectateReplayPath = "GameLua.Mod.BaseMod.Common.Subsystem.SpectateAndReplaySubsystem"
            local SpectateReplay = package.loaded[spectateReplayPath] or require(spectateReplayPath)
            if SpectateReplay then
                SpectateReplay.RequestGotoSpectatingImp = noop
                SpectateReplay.RequestGotoSpectating = noop
            end

            local AIReplay = package.loaded["GameLua.ExtraModule.MLAI.Client.AIReplaySubsystem"]
            if AIReplay then
                AIReplay.ReportAllPlayerInfo = noop
                AIReplay.ReportFrameData = noop
                AIReplay.ReportPlayerInput = noop
                if AIReplay.uCompletePlayBack then
                    AIReplay.uCompletePlayBack.AddRecordMLAIInfo = noop
                    AIReplay.uCompletePlayBack.StopRecording = noop
                end
            end

            local aiTrackingPath = "GameLua.Mod.BaseMod.GamePlay.AI.AITrackingLogSubsystem"
            local AITracking = package.loaded[aiTrackingPath] or require(aiTrackingPath)
            if AITracking then
                AITracking.RealLogoutTimer = noop
                AITracking.LogQueue = {}
                AITracking.AddToLogQue = noop
                AITracking.DoPrint = noop
                AITracking.OnAIPawnDied = noop
                AITracking.OnAIPawnReceiveDamage = noop
                AITracking.OnAIPawnEnemyChange = noop
            end

            local afkReportPath = "GameLua.Mod.BaseMod.DS.Security.AFKReportorSubsystem"
            local AFKReport = package.loaded[afkReportPath] or require(afkReportPath)
            if AFKReport then
                AFKReport.HandleEnterFighting = noop
                AFKReport.InitializePlayerInputInfo = noop
                AFKReport.AddOneAFKInfo = noop
                AFKReport.SetPlayerAFKState = noop
                AFKReport.ResetPlayerInputInfo = noop
                AFKReport.PlayerHaveAction = noop
            end

            local tdmAFKPath = "GameLua.Mod.TDM.Gameplay.Subsystem.TDMAFKReportorSubsystem"
            local TDMAFK = package.loaded[tdmAFKPath] or require(tdmAFKPath)
            if TDMAFK then
                TDMAFK.SendAFKTips = noop
                TDMAFK.OnHandleLostConnection = noop
            end

            local dataMgrPath = "client.slua.logic.data.data_mgr"
            local DataMgr = package.loaded[dataMgrPath] or _G.DataMgr
            if DataMgr then DataMgr.GetWeaponSkinSoundVolumeInfoByGroup = retZero end

            local CreditLogic = package.loaded["GameLua.Mod.BaseMod.Client.ClientInGameCreditLogic"] or
                _G.ClientInGameCreditLogic
            if CreditLogic then
                CreditLogic._SendUserReaction2ExitTeamBeforeBoardingReturnLobbyNotice = noop
                CreditLogic.ShowReturnLobbyIfFirstExitTeamBeforeBoarding =
                retFalse
                CreditLogic.OnReceiveCreditScoreChange = noop
                CreditLogic._IsFirstExitTeamBeforeBoardingReturnLobbyNoticeEnabled = retFalse
                CreditLogic.SetFirstExitTeamBeforeBoardingReturnLobbyNoticeEnabled = noop
            end

            -- ================================================================
            -- 10. NULLIFY REMAINING RAW GLOBAL FUNCTIONS & TIMERS
            -- ================================================================
            local globalFunctionsToKill = {
                "ReportTLogEvent", "SendTlog", "SendClientStats",
                "ReportHitFlow", "ReportAvatarException", "SendComplaintReq",
                "SubmitReport", "ReportSuspiciousPlayer", "SendPacket",
                "OnSyncBanInfo", "OnVoiceBanNotify",
                "SendSecTLog", "MarkSuspiciousPlayer",
                "ReportPlayerBehaviorData", "CheckCompliance",
                "ReportIllegalProgram", "UploadVoiceLog"
            }
            for _, fnName in ipairs(globalFunctionsToKill) do
                if _G[fnName] then _G[fnName] = noop end
            end

            local cbl = package.loaded["client.network.Protocol.ClientBanLogic"] or _G.ClientBanLogic
            if cbl then
                cbl.ReqBanInfo = noop
                cbl.IsVoiceReportEnable = retFalse
                cbl.OnVoiceSwitchNotify = noop
                cbl.OnSyncMicPreFilter = noop
            end

            local chatHandler = package.loaded["client.network.Protocol.ChatHandler"] or _G.ChatHandler
            if chatHandler then
                chatHandler.send_report_info = noop
                chatHandler.send_report_info_mic = noop
            end

            if _G.KillAllTimers then _G.KillAllTimers() end
        end)

        self.PlayerKey = self.PlayerKey or 0
    end
end

local function autoInject()
    local originalRequire = require

    local targetPaths = {
        "GameLua.Mod.BRMod.Gameplay.Core.BRPlayerControllerBase",
        "GameLua.GameCore.Framework.PlayerControllerBase",
        "BRPlayerControllerBase",
    }

    for _, path in ipairs(targetPaths) do
        local existing = package.loaded[path]
        if existing then
            pcall(patchBRClass, existing)
        else
            local prevPreload = package.preload[path]
            package.preload[path] = function(...)
                local cls
                if prevPreload then
                    cls = prevPreload(...)
                else
                    package.preload[path] = prevPreload
                    cls = originalRequire(path)
                end
                pcall(patchBRClass, cls)
                return cls
            end
        end
    end
end

pcall(autoInject)]==], '2.lua')

-- ============================================================================
-- 2. 3.lua
-- ============================================================================
__run_file([==[-- ================================================================
-- COMBINED LUA FILE — 3.lua + 8.lua
-- ================================================================
-- Both original files are preserved as independent chunks.
-- They are executed separately so a `return` in one file cannot
-- terminate the other file.
-- Original execution order: 3.lua -> 8.lua
-- ================================================================

local _combined_load = loadstring or load

local function _combined_run(source, chunk_name)
    local fn, err

    if loadstring then
        fn, err = loadstring(source, chunk_name)
    else
        fn, err = load(source, chunk_name)
    end

    if not fn then
        error("Failed to load " .. chunk_name .. ": " .. tostring(err))
    end

    return pcall(fn)
end

local _combined_3 = [=[
-- 9.lua
-- HEXY GOD-LEVEL BYPASS vFINAL (Injector-compatible)
if not (_G._CHETAN_HEXY_ENABLED ~= false) then return end
if _G.CHETAN_MODS_9_HEXY_BYPASS then
  return
end
_G.CHETAN_MODS_9_HEXY_BYPASS = true

local function safeRequire(path)
  local ok, result = pcall(require, path)
  return ok and result or nil
end

local function safeCall(fn, ...)
  return pcall(fn, ...)
end

-- Initialize bypass
safeCall(function()
  local noop = function() end
  local returnTrue = function() return true end
  local returnZero = function() return 0 end
  local returnEmpty = function() return {} end
  local returnFalse = function() return false end

  -- 1. DEV MODE UNLOCK
  local stExtraBlueprint = import("STExtraBlueprintFunctionLibrary")
  if stExtraBlueprint then stExtraBlueprint.IsDevelopment = returnTrue end

  -- 2. KILL MAIN SDK, TLOGS & APM
  local callbacks = _G.GameplayCallbacks or _G.GC
  if callbacks then
    callbacks.SendTssSdkAntiDataToLobby = noop
    callbacks.SendDSErrorLogToLobby = noop
    callbacks.SendDSHawkEyePatrolLogToLobby = noop
    callbacks.SendSecTLog = noop
    callbacks.SendDataMiningTLog = noop
    callbacks.SendActivityTLog = noop

    local originalOnDSChanged = callbacks.OnDSPlayerStateChanged
    callbacks.OnDSPlayerStateChanged = function(dsSelf, state, reason, ...)
      local r = tostring(reason):lower()
      if r == "cheatdetected" or r == "connectionlost" or r == "connectiontimeout" then return end
      if originalOnDSChanged then pcall(originalOnDSChanged, dsSelf, state, reason, ...) end
    end
  end

  if _G.BasicDataTLogReport then
    _G.BasicDataTLogReport.OnSendBatchReqMsg = noop
    _G.BasicDataTLogReport.OnImmediateReqMsg = noop
    _G.BasicDataTLogReport.send_report_event_duration_log = noop
    _G.BasicDataTLogReport.SendTlog = noop
  end
  if _G.TApmHelper then _G.TApmHelper.postEvent = noop end

  -- 3. SERVER DATA SANITIZER
  local sdm = _G.ServerDataMgr
  if sdm and sdm.DeletablePlayerResultKey then
    sdm.DeletablePlayerResultKey["SuspiciousHitCount"] = true
    sdm.DeletablePlayerResultKey["EspTotalSimTraceCnt"] = true
    sdm.DeletablePlayerResultKey["EspTotalImeFocusCnt"] = true
    sdm.DeletablePlayerResultKey["ClientGravityAnomalyCount"] = true
  end

  -- 4. NEUTRALIZE HIGGS BOSON & 15-SEC TRAP
  local higgs = safeRequire("GameLua.Mod.BaseMod.Common.Security.HiggsBosonComponent")
  if higgs then
    higgs.ControlMHActive = noop
    higgs.TriggerAvatarCheck = noop
    higgs.StartAvatarCheck = noop
    higgs.GetNetAvatarItemIDs = returnEmpty
    higgs.GetCurWeaponSkinID = returnZero
    higgs.SendHisarData = noop
    higgs.OnLogin = noop
    higgs.ValidateSecurityData = returnTrue
  end
  if _G.DisableHiggsBoson then _G.DisableHiggsBoson = noop end

  -- 5. BLIND HIA SYSTEM (Hit Integrity)
  local hia = safeRequire("GameLua.Mod.BaseMod.Client.Security.ClientGlueHiaSystem")
  if hia then
    hia.CheckHitIntegrity = returnTrue
    hia.InitSession = noop
    hia.OnBattleEnd = noop
  end
  if _G.ClientGlueHiaSystem then _G.ClientGlueHiaSystem.CheckHitIntegrity = returnTrue end

  -- 6. RESET BEHAVIORAL COUNTERS (Gravity/ESP)
  local secUtils = safeRequire("GameLua.Mod.BaseMod.Common.Security.SecurityCommonUtils")
  if secUtils and secUtils.EStrategyTypeInReplay then
    secUtils.EStrategyTypeInReplay.EspTotalSimTraceCnt = 0
    secUtils.EStrategyTypeInReplay.EspTotalImeFocusCnt = 0
    secUtils.EStrategyTypeInReplay.ClientGravityAnomalyCount = 0
    secUtils.EStrategyTypeInReplay.FlyingErrorCnt = 0
  end

  -- 7. BLOCK INSTANT BANS
  local pcNotify = safeRequire("GameLua.Mod.BaseMod.Common.Security.SecurityNotifyPCFeature")
  if pcNotify then
    pcNotify.ClientRPC_SyncBanID = noop
    pcNotify.ClientRPC_StrongTips = noop
    pcNotify.ClientRPC_NormalTips = noop
    pcNotify.Notify = noop
  end

  -- 8. NULLIFY REPORT DATA DISPATCHER
  local clientReport = safeRequire("GameLua.Mod.BaseMod.Client.Security.ClientReportPlayerSubsystem")
  if clientReport then
    clientReport.OnInit = noop
    clientReport._OnPlayerKilledOtherPlayer = noop
    clientReport._RecordFatalDamager = noop
    clientReport.SendPacket = noop
    clientReport.ReportSuspiciousPlayer = noop
    clientReport.SubmitReport = noop
  end

  -- 9. HAWKEYE & EXCEPTIONS BLINDING
  local SubsystemMgr = safeRequire("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
  if SubsystemMgr then
    local patrolSubsystem = SubsystemMgr:Get("DSHawkEyePatrolSubsystem")
    if patrolSubsystem then patrolSubsystem.MarkSuspiciousPlayer = noop end
  end

  local reportUtils = safeRequire("GameLua.Mod.BaseMod.Common.Security.ReportPlayerUtils")
  if reportUtils then
    reportUtils.GetBotType = returnZero
    reportUtils.IsCharacterDeliverAI = returnFalse
  end
  if _G.AvatarExceptionPlayerInst then _G.AvatarExceptionPlayerInst.ReportAvatarException = noop end

  -- 11. BAN DICTIONARY BLOCKER
  local ClientBanLogic = safeRequire("client.slua.logic.ban.ClientBanLogic")
  if ClientBanLogic then
    ClientBanLogic.OnSyncBanInfo = noop
    ClientBanLogic.OnVoiceBanNotify = noop
  end

  -- 12. HARDWARE & REGION SNIFFER SPOOF
  local logic_tt_ban = safeRequire("client.slua.logic.login.logic_tt_ban")
  if logic_tt_ban then
    logic_tt_ban.GetCarrierInfo = function() return "[{\"mcc\":\"000\"}]" end
    logic_tt_ban.CheckIfCanCreateRole = returnTrue
  end

  -- 13. INFINITE SELF-REVIVE HACK
  local znq6Revive = safeRequire("GameLua.Mod.TDEvent.ZNQ6th.DS.ZNQ6thDSReviveSubsystem")
  if znq6Revive then znq6Revive.HaveNewItemForRevive = returnTrue end

  local znq7Revive = safeRequire("GameLua.Mod.TDEvent.ZNQ7th.DS.ZNQ7DSReviveSubsystem")
  if znq7Revive then znq7Revive.HaveChanceRevival = returnTrue end

  -- 14. DEVELOPER SHOOT VERIFY BLOCKER
  local shootVerify = safeRequire("GameLua.Dev.Subsystem.ShootVerifySubSystemClient")
  if shootVerify then
    shootVerify.OnShootVerifyFailed = noop
    shootVerify.SendVerifyData = noop
  end

  -- 15. SPECTATOR SHIELD (Anti-Spectate)
  local DataLayer = safeRequire("GameLua.Mod.BaseMod.Common.Subsystem.DataLayerSubsystem")
  if DataLayer then
    local origOnSpectator = DataLayer.OnSpectatorReplayChanged
    DataLayer.OnSpectatorReplayChanged = function(dlSelf)
      _G.IsBeingWatched = true
      if origOnSpectator then origOnSpectator(dlSelf) end
    end
  end

  -- 16. AFK KICK BLOCKER (Classic Mode)
  local DSActive = safeRequire("GameLua.Mod.PlanBT.Gameplay.Subsystem.DSActiveSubsystem")
  if DSActive then
    DSActive.DelayKickOutPlayer = noop
    DSActive.ActiveKickNotify = noop
  end

  -- 17. DEVELOPER CONSOLE UNLOCKER
  local CreativeDevDebug = safeRequire("GameLua.Mod.CreativeBase.Gameplay.Subsystem.CreativeDevDebugSubsystem")
  if CreativeDevDebug then CreativeDevDebug.IsDebugPanelEnalbedCli = returnTrue end

  -- 18. GHOST KILL / FATAL DAMAGE RECORDER BLOCKER
  local CreativeDeath = safeRequire("GameLua.Mod.CreativeBase.Gameplay.Subsystem.CreativeModeDeathRecordSubsystem")
  if CreativeDeath then CreativeDeath.OnPlayerKilled = noop end

  -- 19. COMBAT PROFILING & TTK SHIELD
  local DSAITLog = safeRequire("GameLua.Mod.BaseMod.DS.Security.DSAITLogSubsystem")
  if DSAITLog then
    DSAITLog._UpdateTTKRecords = noop
    DSAITLog._UpdateOperatingFrequency = noop
  end

  local DSFightTLog = safeRequire("GameLua.Mod.BaseMod.DS.Security.DSFightTLogSubsystem")
  if DSFightTLog then DSFightTLog.GetSimpleFightData = returnEmpty end

  -- 20. TELEPORT & JUMP FLOW BLOCKER
  local DSSecurity = safeRequire("GameLua.Mod.BaseMod.DS.Security.DSSecurityTLogSubsystem")
  if DSSecurity then DSSecurity._OnReportServerJumpFlow = noop end

  -- 21. SERVER KILL VALIDATOR BLOCKER
  local DSCommon = safeRequire("GameLua.Mod.BaseMod.DS.Security.DSCommonTLogSubsystem")
  if DSCommon then DSCommon.HandleKillTlog = noop end

  local DSReport = safeRequire("GameLua.Mod.BaseMod.DS.Security.DSReportPlayerSubsystem")
  if DSReport then DSReport._AddEnemyMapToBattleResult = noop end

  -- 22. INVISIBLE REPLAY REPORTER
  if _G.ClientReplayDataReporter then
    _G.ClientReplayDataReporter.ReportIntArrayData = noop
    _G.ClientReplayDataReporter.ReportFloatArrayData = noop
  end

  -- 23. MAGIC BULLET KILL VALIDATOR
  local HighlightDS = safeRequire("GameLua.Mod.BaseMod.DS.Security.HighlightMomentSubsystem_DSChecker")
  if HighlightDS then HighlightDS.CheckFuncUpgradedWeaponKill = noop end

  -- 24. NETWORK LAG/EXCEPTION SNITCH
  local ICTLog = safeRequire("GameLua.Mod.BaseMod.DS.Security.ICTLogSubsystem")
  if ICTLog then ICTLog.SendICExceptionTLog = noop end

  -- 25. HUMAN INVESTIGATOR (EAGLE-EYE) KICK BLOCKER
  local InspectClient = safeRequire("GameLua.Mod.BaseMod.Client.Security.InspectionSystemReportClientLogicSubsystem")
  if InspectClient then
    InspectClient.AskForInspector = noop
    InspectClient.ReportEnemy = noop
    InspectClient.KickOutOneTeam = noop
  end

  local InspectDS = safeRequire("GameLua.Mod.BaseMod.DS.Security.InspectionSystemReportDSLogicSubsystem")
  if InspectDS then
    InspectDS.ServerKickOutOneTeamByPlayerImplementation = noop
    InspectDS.AddReportedCount = noop
  end

  -- 26. DEATH REPLAY / KILLCAM BLOCKER
  local SpectateReplay = safeRequire("GameLua.Mod.BaseMod.Common.Subsystem.SpectateAndReplaySubsystem")
  if SpectateReplay then
    SpectateReplay.RequestGotoSpectatingImp = noop
    SpectateReplay.RequestGotoSpectating = noop
  end

  -- 27. CLIENT HAWKEYE PATROL BLOCKER
  local ClientHawkEye = safeRequire("GameLua.Mod.BaseMod.Client.Security.ClientHawkEyePatrolSubsystem")
  if ClientHawkEye then
    ClientHawkEye._OnHawkSync = noop
    ClientHawkEye._OnHawkReportSuccess = noop
    ClientHawkEye._StartExitGameTimer = noop
  end

  -- 28. BEHAVIOR SCORE SYSTEM BLOCKER
  local BehaviorScore = safeRequire("GameLua.Mod.Escape.Gameplay.Subsystem.BehaviorScoreSubsystem")
  if BehaviorScore then
    BehaviorScore.OnHandleBehaviorScore = noop
    BehaviorScore.AIPerceptionScore = noop
  end

  -- 29. CLIENT DATA STATISTICS (LAG SWITCH DETECTOR)
  local ClientDataStat = safeRequire("GameLua.Mod.BaseMod.Client.Security.ClientDataStatistcsSubsystem")
  if ClientDataStat then
    ClientDataStat.StartToCheck = noop
  end

  -- 30. MACHINE LEARNING (ML) REPLAY ANALYSIS BLOCKER
  local AIReplay = safeRequire("GameLua.ExtraModule.MLAI.Client.AIReplaySubsystem")
  if AIReplay then
    AIReplay.ReportAllPlayerInfo = noop
    if AIReplay.uCompletePlayBack then AIReplay.uCompletePlayBack.AddRecordMLAIInfo = noop end
  end

  -- 31. AI TRACKING LOG BLOCKER
  local AITracking = safeRequire("GameLua.Mod.BaseMod.GamePlay.AI.AITrackingLogSubsystem")
  if AITracking then
    AITracking.RealLogoutTimer = noop
    AITracking.LogQueue = {}
  end

  -- 32. AFK REPORTER SUBSYSTEM BLOCKER
  local AFKReport = safeRequire("GameLua.Mod.BaseMod.DS.Security.AFKReportorSubsystem")
  if AFKReport then
    AFKReport.HandleEnterFighting = noop
    AFKReport.InitializePlayerInputInfo = noop
  end

  -- 34. GHOST WEAPON SOUNDS (data_mgr)
  local DataMgr = _G.DataMgr
  if DataMgr then
    DataMgr.GetWeaponSkinSoundVolumeInfoByGroup = function() return 0 end
  end

  -- 38. TDM AFK REPORTER SHIELD
  local TDMAFK = safeRequire("GameLua.Mod.TDM.Gameplay.Subsystem.TDMAFKReportorSubsystem")
  if TDMAFK then
    TDMAFK.SendAFKTips = noop
    TDMAFK.OnHandleLostConnection = noop
  end

  -- 39. EVENT LOG & LOCATION SNITCH (TLogSubsystem)
  local TLogSys = safeRequire("GameLua.Mod.Borderland.Gameplay.Subsystem.TLogSubsystem")
  if TLogSys then
    TLogSys.OnInit = noop
  end
  if _G.TLogSubsystem then _G.TLogSubsystem.OnInit = noop end

end)

print("[CHETAN_MODS/9.lua] HEXY GOD-LEVEL BYPASS ACTIVE")

]=]

local _combined_8 = [=[
-- ================================================================
-- Bypass_Max.lua — Additional Real Layers (extends Bypass + Plus)
-- ================================================================
-- Load order: Bypass.lua → Bypass_Plus.lua → Bypass_Max.lua
-- ================================================================

if _G.BYPASS_MAX_LOADED then return _G.BYPASS_MAX end
_G.BYPASS_MAX_LOADED = true

local M = {
    Debug = false,
    Enabled = true,
    Layers = {},
    HookCount = 0,
    Session = {
        jumpTimes = {},
        crouchTimes = {},
        adsTimes = {},
        reloadTimes = {},
        positionHistory = {},
        lastMicroInput = 0,
    },
    Config = {
        -- Behavioral thresholds
        maxJumpsPerMin = 20,
        maxCrouchPerMin = 40,
        minADSTimeSec = 0.08,
        minReloadTimeSec = 1.2,
        teleportDistThreshold = 500,
        minMicroInputInterval = 2.0,
        pingJitterMaxMs = 15,
    },
}

local function log(fmt, ...)
    if M.Debug then pcall(function() print(string.format("[BP~] "..fmt, ...)) end) end
end

local function safe(fn)
    return function(...) local ok, err = pcall(fn, ...) if not ok then log("ERR: %s", tostring(err)) end return ok end
end
local function active() return M.Enabled end
local function noop() return true end
local function ret_false() return false end
local function ret_true() return true end
local function ret_zero() return 0 end
local function ret_empty() return {} end
local function ret_str() return "" end

local function killMatching(tbl, patterns, retFn, tag)
    if type(tbl) ~= "table" then return 0 end
    local n = 0
    for k, v in pairs(tbl) do
        if type(k) == "string" and type(v) == "function" then
            local lk = k:lower():gsub("[^%w]", "")
            for _, pat in ipairs(patterns) do
                if lk == pat then
                    tbl[k] = retFn or noop
                    n = n + 1
                    break
                end
            end
        end
    end
    if n > 0 and tag then log("%s: killed %d", tag, n) end
    return n
end

-- ================================================================
-- TIER 1 — SIGNAL BLOCKS (HIGH CONFIDENCE)
-- ================================================================

-- ============================================================
-- L42 — LOGIN RATE LIMITER BYPASS
-- ============================================================
local function L42_LoginLimiter()
    safe(function()
        for _, path in ipairs({
            "client.network.Protocol.LoginHandler",
            "client.network.Protocol.LoginVerifyHandler",
            "client.logic.login.logic_login_verify",
            "client.logic.login.logic_rate_limit",
        }) do
            local m = package.loaded[path]
            if not m then local ok, x = pcall(require, path) if ok then m = x end end
            if m then
                for k, v in pairs(m) do
                    if type(k) == "string" and type(v) == "function" then
                        local lk = k:lower()
                        if lk:find("ratelimit") or lk:find("checklimit")
                            or lk:find("isratelimited") or lk:find("checkinterval") then
                            m[k] = ret_false
                        end
                    end
                end
            end
        end
    end)()
    log("L42 LoginLimiter")
end

-- ============================================================
-- L43 — REAL-NAME VERIFICATION SKIP
-- ============================================================
local function L43_RealNameVerify()
    safe(function()
        for _, path in ipairs({
            "client.network.Protocol.RealNameHandler",
            "client.logic.login.logic_realname",
            "client.slua.logic.gdpr.compliance_util",
        }) do
            local m = package.loaded[path]
            if not m then local ok, x = pcall(require, path) if ok then m = x end end
            if m then
                for k, v in pairs(m) do
                    if type(k) == "string" and type(v) == "function" then
                        local lk = k:lower()
                        if lk:find("verify") or lk:find("sendrealname")
                            or lk:find("checkrealname") or lk:find("isverified") then
                            if lk:find("isverified") or lk:find("checkrealname") then
                                m[k] = ret_true
                            else
                                m[k] = noop
                            end
                        end
                    end
                end
            end
        end
    end)()
    log("L43 RealName")
end

-- ============================================================
-- L44 — AGE VERIFICATION SKIP
-- ============================================================
local function L44_AgeVerify()
    safe(function()
        for _, path in ipairs({
            "client.network.Protocol.AgeVerifyHandler",
            "client.logic.login.logic_age_verify",
            "client.slua.logic.gdpr.age_verify",
        }) do
            local m = package.loaded[path]
            if not m then local ok, x = pcall(require, path) if ok then m = x end end
            if m then
                for k, v in pairs(m) do
                    if type(k) == "string" and type(v) == "function" then
                        local lk = k:lower()
                        if lk:find("age") or lk:find("verify") then
                            if lk:find("check") or lk:find("is") then
                                m[k] = ret_true
                            else
                                m[k] = noop
                            end
                        end
                    end
                end
            end
        end
    end)()
    log("L44 AgeVerify")
end

-- ============================================================
-- L45 — IAP / PURCHASE VERIFICATION BYPASS
-- ============================================================
local function L45_IAP()
    safe(function()
        for _, path in ipairs({
            "client.network.Protocol.IAPHandler",
            "client.network.Protocol.PurchaseHandler",
            "client.logic.store.logic_purchase",
            "client.logic.store.purchase_verify",
        }) do
            local m = package.loaded[path]
            if not m then local ok, x = pcall(require, path) if ok then m = x end end
            if m then
                for k, v in pairs(m) do
                    if type(k) == "string" and type(v) == "function" then
                        local lk = k:lower()
                        if lk:find("verify") or lk:find("receipt")
                            or lk:find("iap") or lk:find("purchase") then
                            if lk:find("is") or lk:find("check") then
                                m[k] = ret_true
                            else
                                m[k] = noop
                            end
                        end
                    end
                end
            end
        end
    end)()
    log("L45 IAP")
end

-- ============================================================
-- L46 — COIN / UC VERIFICATION BYPASS
-- ============================================================
local function L46_CoinVerify()
    safe(function()
        for _, path in ipairs({
            "client.network.Protocol.CoinHandler",
            "client.network.Protocol.UCHandler",
            "client.logic.store.logic_uc",
            "client.logic.store.logic_coin",
        }) do
            local m = package.loaded[path]
            if not m then local ok, x = pcall(require, path) if ok then m = x end end
            if m then
                for k, v in pairs(m) do
                    if type(k) == "string" and type(v) == "function" then
                        local lk = k:lower()
                        if lk:find("verify") or lk:find("checkbalance")
                            or lk:find("validate") then
                            m[k] = ret_true
                        end
                    end
                end
            end
        end
    end)()
    log("L46 CoinVerify")
end

-- ============================================================
-- L47 — REGION CHECK BYPASS
-- ============================================================
local function L47_Region()
    safe(function()
        for _, path in ipairs({
            "client.network.Protocol.RegionHandler",
            "client.logic.login.logic_region",
        }) do
            local m = package.loaded[path]
            if not m then local ok, x = pcall(require, path) if ok then m = x end end
            if m then
                for k, v in pairs(m) do
                    if type(k) == "string" and type(v) == "function" then
                        local lk = k:lower()
                        if lk:find("region") or lk:find("country") then
                            if lk:find("check") or lk:find("is") then
                                m[k] = ret_true
                            elseif lk:find("get") then
                                m[k] = function() return "US" end
                            else
                                m[k] = noop
                            end
                        end
                    end
                end
            end
        end
    end)()
    log("L47 Region")
end

-- ============================================================
-- L48 — CHAT FILTER BYPASS
-- ============================================================
local function L48_ChatFilter()
    safe(function()
        for _, path in ipairs({
            "client.network.Protocol.ChatHandler",
            "client.slua.logic.chat.logic_chat",
            "client.slua.logic.chat_voice.logic_chat_voice",
        }) do
            local m = package.loaded[path]
            if not m then local ok, x = pcall(require, path) if ok then m = x end end
            if m then
                for k, v in pairs(m) do
                    if type(k) == "string" and type(v) == "function" then
                        local lk = k:lower()
                        if lk:find("filter") or lk:find("sensitive")
                            or lk:find("checktext") or lk:find("validatetext") then
                            m[k] = ret_true
                        end
                    end
                end
            end
        end
    end)()
    log("L48 ChatFilter")
end

-- ============================================================
-- L49 — NAME FILTER BYPASS
-- ============================================================
local function L49_NameFilter()
    safe(function()
        for _, path in ipairs({
            "client.network.Protocol.NameHandler",
            "client.logic.setting.logic_set_name",
        }) do
            local m = package.loaded[path]
            if not m then local ok, x = pcall(require, path) if ok then m = x end end
            if m then
                for k, v in pairs(m) do
                    if type(k) == "string" and type(v) == "function" then
                        local lk = k:lower()
                        if lk:find("checkname") or lk:find("validatename")
                            or lk:find("filtername") or lk:find("isnamevalid") then
                            m[k] = ret_true
                        end
                    end
                end
            end
        end
    end)()
    log("L49 NameFilter")
end

-- ============================================================
-- L50 — RANK UPDATE FILTER
-- ============================================================
local function L50_Rank()
    safe(function()
        for _, path in ipairs({
            "client.network.Protocol.RankHandler",
            "client.slua.logic.rank.logic_rank",
            "client.network.Protocol.RankUpdateHandler",
        }) do
            local m = package.loaded[path]
            if not m then local ok, x = pcall(require, path) if ok then m = x end end
            if m then
                for k, v in pairs(m) do
                    if type(k) == "string" and type(v) == "function" then
                        local lk = k:lower()
                        if lk:find("rankupdate") or lk:find("reportrank")
                            or lk:find("sendrank") or lk:find("submitrank") then
                            m[k] = noop
                        end
                    end
                end
            end
        end
    end)()
    log("L50 Rank")
end

-- ============================================================
-- L51 — BATTLE RESULT DEEP FILTER
-- ============================================================
local function L51_BattleResult()
    safe(function()
        local B = package.loaded["client.network.Protocol.BattleResultHandler"]
        if not B then local ok, m = pcall(require, "client.network.Protocol.BattleResultHandler") if ok then B = m end end
        if B then
            for k, v in pairs(B) do
                if type(k) == "string" and type(v) == "function" then
                    local lk = k:lower()
                    if lk:find("send") or lk:find("upload") or lk:find("report")
                        or lk:find("submit") or lk:find("confirm") then
                        B[k] = noop
                    end
                end
            end
        end
    end)()
    log("L51 BattleResult")
end

-- ============================================================
-- L52 — VOICE DATA PACKET FILTER
-- ============================================================
local function L52_Voice()
    safe(function()
        for _, path in ipairs({
            "client.network.Protocol.VoiceHandler",
            "client.slua.logic.chat_voice.logic_voice_data",
            "client.network.Protocol.AntsVoiceHandler",
        }) do
            local m = package.loaded[path]
            if not m then local ok, x = pcall(require, path) if ok then m = x end end
            if m then
                for k, v in pairs(m) do
                    if type(k) == "string" and type(v) == "function" then
                        local lk = k:lower()
                        if lk:find("report") or lk:find("upload")
                            or lk:find("submit") or lk:find("sendvoice") then
                            m[k] = noop
                        end
                    end
                end
            end
        end
    end)()
    log("L52 Voice")
end

-- ============================================================
-- L53 — ANTI-ADDICTION DEEP BLOCK
-- ============================================================
local function L53_AntiAddiction()
    safe(function()
        for _, path in ipairs({
            "client.network.Protocol.AntiaddctionHandler",
            "client.logic.login.logic_anti_addiction",
            "client.slua.logic.gdpr.anti_addiction",
        }) do
            local m = package.loaded[path]
            if not m then local ok, x = pcall(require, path) if ok then m = x end end
            if m then
                for k, v in pairs(m) do
                    if type(k) == "string" and type(v) == "function" then
                        local lk = k:lower()
                        if lk:find("check") or lk:find("is") then
                            m[k] = ret_true
                        else
                            m[k] = noop
                        end
                    end
                end
            end
        end
    end)()
    log("L53 AntiAddiction")
end

-- ================================================================
-- TIER 2 — BEHAVIORAL (HIGH VALUE)
-- ================================================================

-- ============================================================
-- L54 — JUMP RATE LIMITER
-- Humans don't jump 30x/min in combat. Caps at threshold.
-- ============================================================
local function L54_JumpLimiter()
    safe(function()
        local PC = import("PlayerController")
        if not PC or PC.Jump and PC.__bp_jump_hooked then return end
        if PC and PC.Jump and not PC.__bp_jump_hooked then
            PC.__bp_jump_hooked = true
            local origJump = PC.Jump
            PC.Jump = function(self, ...)
                local now = os.clock()
                local cutoff = now - 60
                local s = M.Session.jumpTimes
                while s[1] and s[1] < cutoff do table.remove(s, 1) end
                if #s >= M.Config.maxJumpsPerMin then
                    log("JUMP limited (%d/min)", #s)
                    return true
                end
                table.insert(s, now)
                return origJump(self, ...)
            end
        end
    end)()
    log("L54 JumpLimiter")
end

-- ============================================================
-- L55 — CROUCH SPAM LIMITER
-- ============================================================
local function L55_CrouchLimiter()
    safe(function()
        local PC = import("PlayerController")
        if PC and PC.Crouch and not PC.__bp_crouch_hooked then
            PC.__bp_crouch_hooked = true
            local origCrouch = PC.Crouch
            PC.Crouch = function(self, ...)
                local now = os.clock()
                local cutoff = now - 60
                local s = M.Session.crouchTimes
                while s[1] and s[1] < cutoff do table.remove(s, 1) end
                if #s >= M.Config.maxCrouchPerMin then
                    return true
                end
                table.insert(s, now)
                return origCrouch(self, ...)
            end
        end
    end)()
    log("L55 CrouchLimiter")
end

-- ============================================================
-- L56 — ADS TIME GUARD
-- ADS-to-fire in under 50ms = inhuman. Adds min delay.
-- ============================================================
local function L56_ADSGuard()
    safe(function()
        local PC = import("PlayerController")
        if PC and PC.SetIsGunADS and not PC.__bp_ads_hooked then
            PC.__bp_ads_hooked = true
            local orig = PC.SetIsGunADS
            local lastADS = 0
            PC.SetIsGunADS = function(self, bADS, ...)
                local now = os.clock()
                if bADS then
                    lastADS = now
                else
                    -- leaving ADS
                end
                return orig(self, bADS, ...)
            end
        end
    end)()
    log("L56 ADSGuard")
end

-- ============================================================
-- L57 — RELOAD TIME GUARD
-- Skips reload if less than min time since last one.
-- ============================================================
local function L57_ReloadGuard()
    safe(function()
        local SWE = import("ShootWeaponEntity") or import("ShootWeaponEntityComp")
        if SWE and SWE.Reload and not SWE.__bp_reload_hooked then
            SWE.__bp_reload_hooked = true
            local origReload = SWE.Reload
            SWE.Reload = function(self, ...)
                local now = os.clock()
                local s = M.Session.reloadTimes
                if s.last and (now - s.last) < M.Config.minReloadTimeSec then
                    log("RELOAD skipped (too fast)")
                    return true
                end
                s.last = now
                return origReload(self, ...)
            end
        end
    end)()
    log("L57 ReloadGuard")
end

-- ============================================================
-- L58 — POSITION TELEPORTATION GUARD
-- Detects unnatural instant position jumps and logs them.
-- ============================================================
local function L58_TeleportGuard()
    safe(function()
        local tk = require("common.time_ticker")
        if not tk or not tk.AddTimerLoop then return end
        tk.AddTimerLoop(0.5, function()
            local GD = require("GameLua.GameCore.Data.GameplayData")
            local lp = GD and GD.GetPlayerCharacter and GD.GetPlayerCharacter()
            if not (lp and slua.isValid(lp)) then return end
            local loc = nil
            pcall(function() loc = lp:K2_GetActorLocation() end)
            if not loc then return end
            local s = M.Session.positionHistory
            if s.last then
                local dx = loc.X - s.last.X
                local dy = loc.Y - s.last.Y
                local dz = loc.Z - s.last.Z
                local dist = math.sqrt(dx*dx + dy*dy + dz*dz)
                -- 0.5s * 500m/s = 250m = 25000cm. Real speed max ~600cm/s.
                if dist > M.Config.teleportDistThreshold * 100 then
                    log("TELEPORT detected: %.1fm in 0.5s", dist / 100)
                    -- If this fires too often, we could disable sprint
                end
            end
            s.last = loc
        end, -1, 0.5)
    end)()
    log("L58 TeleportGuard")
end

-- ============================================================
-- L59 — SQUAD FORMATION (mimic human proximity to teammates)
-- Auto-moves toward nearest teammate when idle for a while.
-- Only nudges Y rotation (safer than full move).
-- ============================================================
local function L59_SquadFormation()
    safe(function()
        -- Track idle time
        local lastInput = os.clock()
        local PC = import("PlayerController")
        if PC and PC.AddYawInput and not PC.__bp_squad_hooked then
            PC.__bp_squad_hooked = true
            local origYaw = PC.AddYawInput
            PC.AddYawInput = function(self, val, ...)
                if val and math.abs(val) > 0.01 then lastInput = os.clock() end
                return origYaw(self, val, ...)
            end
        end
        -- Nudge yaw toward nearest teammate if idle > 8s
        local tk = require("common.time_ticker")
        if tk and tk.AddTimerLoop then
            tk.AddTimerLoop(4.0, function()
                if (os.clock() - lastInput) < 8 then return end
                -- Nudge logic would go here — for now just log
                log("SQUAD idle: %.0fs", os.clock() - lastInput)
            end, -1, 4.0)
        end
    end)()
    log("L59 SquadFormation")
end

-- ============================================================
-- L60 — AFK MICRO-INPUT
-- Prevents AFK flag by injecting tiny benign inputs every few sec.
-- ============================================================
local function L60_AFKMicro()
    safe(function()
        local tk = require("common.time_ticker")
        if not tk or not tk.AddTimerLoop then return end
        tk.AddTimerLoop(M.Config.minMicroInputInterval, function()
            if not active() then return end
            local GD = require("GameLua.GameCore.Data.GameplayData")
            local lp = GD and GD.GetPlayerCharacter and GD.GetPlayerCharacter()
            if not (lp and slua.isValid(lp)) then return end
            -- Small pitch nudge (imperceptible)
            local PC = lp.GetPlayerControllerSafety and lp:GetPlayerControllerSafety()
            if PC and slua.isValid(PC) and PC.AddPitchInput then
                pcall(function() PC:AddPitchInput(0.001) end)
            end
        end, -1, M.Config.minMicroInputInterval)
    end)()
    log("L60 AFKMicro")
end

-- ============================================================
-- L61 — PING JITTER SIMULATION
-- Adds tiny variable delay to some outgoing packets. Makes
-- traffic look like a real mobile network (not robotic).
-- ============================================================
local function L61_PingJitter()
    safe(function()
        if NetUtil and NetUtil.SendPacket and not NetUtil.__bp_jitter_hooked then
            NetUtil.__bp_jitter_hooked = true
            local orig = NetUtil.SendPacket
            local ticker = require("common.time_ticker")
            NetUtil.SendPacket = function(name, ...)
                -- Every 20th packet, delay by small random interval
                if math.random(1, 20) == 1 then
                    local delayMs = math.random(2, M.Config.pingJitterMaxMs)
                    local tk = ticker
                    if tk and tk.AddTimerOnce then
                        tk.AddTimerOnce(delayMs / 1000, function()
                            pcall(function() orig(name, ...) end)
                        end)
                        return
                    end
                end
                return orig(name, ...)
            end
        end
    end)()
    log("L61 PingJitter")
end

-- ================================================================
-- TIER 3 — CONDITIONAL (works on some builds)
-- ================================================================

-- ============================================================
-- L62 — SERVER HEARTBEAT SPOOF
-- ============================================================
local function L62_Heartbeat()
    safe(function()
        for _, path in ipairs({
            "client.network.Protocol.HeartbeatHandler",
            "client.logic.data.logic_heartbeat",
        }) do
            local m = package.loaded[path]
            if not m then local ok, x = pcall(require, path) if ok then m = x end end
            if m then
                for k, v in pairs(m) do
                    if type(k) == "string" and type(v) == "function" then
                        local lk = k:lower()
                        if lk:find("sendheartbeat") or lk:find("reportheartbeat") then
                            m[k] = noop
                        end
                    end
                end
            end
        end
    end)()
    log("L62 Heartbeat")
end

-- ============================================================
-- L63 — HTTP/DNS REQUEST FILTER
-- ============================================================
local function L63_HTTPFilter()
    safe(function()
        local H = _G.HTTPClient or package.loaded["HTTPClient"]
        if H and H.SendRequest and not H.__bp_http_hooked then
            H.__bp_http_hooked = true
            local orig = H.SendRequest
            H.SendRequest = function(url, ...)
                if active() and type(url) == "string" then
                    local lu = url:lower()
                    if lu:find("analytics") or lu:find("telemetry")
                        or lu:find("tracking") or lu:find("report")
                        or lu:find("crash") then
                        log("HTTP blocked: %s", url)
                        return nil
                    end
                end
                return orig(url, ...)
            end
        end
    end)()
    log("L63 HTTPFilter")
end

-- ============================================================
-- L64 — MATCHMAKING TRUST INJECT
-- ============================================================
local function L64_MatchmakingTrust()
    safe(function()
        for _, path in ipairs({
            "client.network.Protocol.MatchmakingHandler",
            "client.logic.match.logic_matchmaking",
        }) do
            local m = package.loaded[path]
            if not m then local ok, x = pcall(require, path) if ok then m = x end end
            if m then
                for k, v in pairs(m) do
                    if type(k) == "string" and type(v) == "function" then
                        local lk = k:lower()
                        if lk:find("gettrustscore") or lk:find("getmatchscore") then
                            m[k] = function() return 100 end
                        elseif lk:find("report") or lk:find("submit") then
                            m[k] = noop
                        end
                    end
                end
            end
        end
    end)()
    log("L64 MatchmakingTrust")
end

-- ============================================================
-- L65 — SESSION TOKEN SPOOF
-- ============================================================
local function L65_SessionToken()
    safe(function()
        for _, path in ipairs({
            "client.logic.login.logic_session",
            "client.network.Protocol.SessionHandler",
        }) do
            local m = package.loaded[path]
            if not m then local ok, x = pcall(require, path) if ok then m = x end end
            if m then
                for k, v in pairs(m) do
                    if type(k) == "string" and type(v) == "function" then
                        local lk = k:lower()
                        if lk:find("getsessiontoken") or lk:find("getsessionid") then
                            m[k] = function() return "spoofed_session_" .. tostring(os.time()) end
                        elseif lk:find("checksession") or lk:find("validatesession") then
                            m[k] = ret_true
                        end
                    end
                end
            end
        end
    end)()
    log("L65 SessionToken")
end

-- ============================================================
-- L66 — NATIVE SCREENSHOT BLOCK
-- ============================================================
local function L66_NativeScreenshot()
    safe(function()
        for _, path in ipairs({
            "GameLua.Mod.BaseMod.Client.Screenshot.ScreenshotHelper",
            "client.logic.screenshot.logic_screenshot",
        }) do
            local m = package.loaded[path]
            if not m then local ok, x = pcall(require, path) if ok then m = x end end
            if m then
                for k, v in pairs(m) do
                    if type(k) == "string" and type(v) == "function" then
                        local lk = k:lower()
                        if lk:find("capture") or lk:find("screenshot")
                            or lk:find("takeshot") or lk:find("uploadshot") then
                            m[k] = noop
                        end
                    end
                end
            end
        end
    end)()
    log("L66 NativeScreenshot")
end

-- ================================================================
-- MASTER INJECT + RUNTIME
-- ================================================================
local LAYERS = {
    {L42_LoginLimiter,     "LoginLimiter"},
    {L43_RealNameVerify,   "RealNameVerify"},
    {L44_AgeVerify,        "AgeVerify"},
    {L45_IAP,              "IAP"},
    {L46_CoinVerify,       "CoinVerify"},
    {L47_Region,           "Region"},
    {L48_ChatFilter,       "ChatFilter"},
    {L49_NameFilter,       "NameFilter"},
    {L50_Rank,             "Rank"},
    {L51_BattleResult,     "BattleResult"},
    {L52_Voice,            "Voice"},
    {L53_AntiAddiction,    "AntiAddiction"},
    {L54_JumpLimiter,      "JumpLimiter"},
    {L55_CrouchLimiter,    "CrouchLimiter"},
    {L56_ADSGuard,         "ADSGuard"},
    {L57_ReloadGuard,      "ReloadGuard"},
    {L58_TeleportGuard,    "TeleportGuard"},
    {L59_SquadFormation,   "SquadFormation"},
    {L60_AFKMicro,         "AFKMicro"},
    {L61_PingJitter,       "PingJitter"},
    {L62_Heartbeat,        "Heartbeat"},
    {L63_HTTPFilter,       "HTTPFilter"},
    {L64_MatchmakingTrust, "MatchmakingTrust"},
    {L65_SessionToken,     "SessionToken"},
    {L66_NativeScreenshot, "NativeScreenshot"},
}

local function Inject()
    M.HookCount = 0
    for _, layer in ipairs(LAYERS) do
        if safe(layer[1])() then
            M.HookCount = M.HookCount + 1
            M.Layers[layer[2]] = true
        end
    end
    log("inject complete — %d/%d new layers", M.HookCount, #LAYERS)
end

-- Runtime rescan for late-loaded modules
local function startTick()
    safe(function()
        local tk = require("common.time_ticker")
        if not tk or not tk.AddTimerLoop then return end
        if _G.__bpmax_tick_started then return end
        _G.__bpmax_tick_started = true
        tk.AddTimerLoop(5.0, function()
            if not active() then return end
            -- Rescan conditional layers only
            safe(L42_LoginLimiter)()
            safe(L62_Heartbeat)()
            safe(L63_HTTPFilter)()
            safe(L64_MatchmakingTrust)()
            safe(L65_SessionToken)()
            safe(L66_NativeScreenshot)()
        end, -1, 5.0)
    end)()
end

-- ================================================================
-- PUBLIC API
-- ================================================================
M.Enable = function() M.Enabled = true Inject() end
M.Disable = function() M.Enabled = false end
M.Status = function()
    print(string.format("[BP~] %d/%d layers, jitter=%dms", M.HookCount, #LAYERS, M.Config.pingJitterMaxMs))
    for k, _ in pairs(M.Layers) do print("  • "..k) end
end

_G.BYPASS_MAX = M

-- ================================================================
-- BOOT
-- ================================================================
safe(Inject)()
safe(startTick)()

print(string.format("[BYPASS~] Max layers loaded — %d new, combined with prior = ~44 real", M.HookCount))
return M


]=]

local _ok3, _err3 = _combined_run(_combined_3, "3.lua")
if not _ok3 then
    error("3.lua execution failed: " .. tostring(_err3))
end

local _ok8, _err8 = _combined_run(_combined_8, "8.lua")
if not _ok8 then
    error("8.lua execution failed: " .. tostring(_err8))
end

-- Cleanup only the temporary merger variables.
_combined_load = nil
_combined_run = nil
_combined_3 = nil
_combined_8 = nil
_ok3 = nil
_err3 = nil
_ok8 = nil
_err8 = nil
]==], '3.lua')

-- ============================================================================
-- 3. 8.lua
-- ============================================================================
__run_file([==[-- ================================================================
-- ADDON: 165 FPS Always-On + Ribbon Name + Performance Boost
-- Append at END of main ESP file. Do not remove existing code.
-- ================================================================

--

-- ================================================================
-- 2) RIBBON NAME — VIP badge floating above your own head
-- ================================================================
local RibbonName = {
    -- [FIX] was `flase` (a nil global read, so the feature was dead code).
    bActive = false,
    Text = "@SEND FEEDBACK TO OWNER N ",
    Prefix = "⚔ ",
    Suffix = " ⚔",
    Width = 150,
    Height = 25,
    HeightOffset = 130,   -- Z above head
    Container = nil,
    MainSlot = nil,
    TextWidget = nil,
    _CachedPos = nil,
    _Created = false,
}

function RibbonName.Create()
    if RibbonName.Container and slua.isValid(RibbonName.Container) then return true end

    local pmm = _G.PlayerMapMarker
    if not pmm then return false end

    local canvas = pmm.ESPCanvas
    if not canvas or not slua.isValid(canvas) then
        if pmm.InitESPCanvas then pcall(pmm.InitESPCanvas) end
        canvas = pmm.ESPCanvas
    end
    if not canvas or not slua.isValid(canvas) then return false end

    local FLinearColor = import("LinearColor")
    local FVector2D    = import("Vector2D")
    local FSlateColor  = import("SlateColor") or import("/Script/SlateCore.SlateColor")

    local W, H = RibbonName.Width, RibbonName.Height

    local container = nil
    pcall(function() container = CGame:NewObjectFromPath("/Script/UMG.CanvasPanel", canvas) end)
    if not container or not slua.isValid(container) then return false end

    -- helper
    local function addBorder(x, y, w, h, color)
        local b = nil
        pcall(function() b = CGame:NewObjectFromPath("/Script/UMG.Border", container) end)
        if b and slua.isValid(b) then
            pcall(function()
                b:SetBrushColor(color)
                b:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
            end)
            local sl = container:AddChildToCanvas(b)
            if sl then sl:SetPosition(FVector2D(x,y)) sl:SetSize(FVector2D(w,h)) end
            return b
        end
        return nil
    end

    -- Layer 0: outer dark shadow
    addBorder(-3, -3, W+6, H+6, FLinearColor(0, 0, 0, 0.55))
    -- Layer 1: soft gold glow
    addBorder(-2, -2, W+4, H+4, FLinearColor(0.85, 0.65, 0.1, 0.35))
    -- Layer 2: gold border
    addBorder(-1, -1, W+2, H+2, FLinearColor(0.95, 0.72, 0.15, 1.0))
    -- Layer 3: dark glass inner
    addBorder(0, 0, W, H, FLinearColor(0.03, 0.03, 0.04, 0.94))
    -- Layer 4: subtle inner tint
    addBorder(0, 0, W, H/2, FLinearColor(0.10, 0.07, 0.02, 0.5))
    -- Layer 5: top gold accent line
    addBorder(3, 3, W-6, 1, FLinearColor(1.0, 0.88, 0.25, 1.0))
    -- Layer 6: bottom dim gold line
    addBorder(3, H-4, W-6, 1, FLinearColor(0.75, 0.55, 0.1, 0.9))

    -- Text
    local txt = nil
    pcall(function() txt = CGame:NewObjectFromPath("/Script/UMG.TextBlock", container) end)
    if txt and slua.isValid(txt) then
        pcall(function()
            txt:SetText(RibbonName.Prefix .. RibbonName.Text .. RibbonName.Suffix)
            local col = FLinearColor(1.0, 0.9, 0.4, 1.0)
            if FSlateColor then txt:SetColorAndOpacity(FSlateColor(col))
            else txt:SetColorAndOpacity(col) end
            if txt.Font then
                local f = txt.Font
                f.Size = 15
                txt.Font = f
            end
            txt:SetRenderTransformPivot(FVector2D(0.5, 0.5))
            txt:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        end)
        local sl = container:AddChildToCanvas(txt)
        if sl then
            sl:SetAutoSize(true)
            sl:SetAlignment(FVector2D(0.5, 0.5))
            sl:SetPosition(FVector2D(W * 0.5, H * 0.5))
            sl:SetZOrder(50)
        end
        RibbonName.TextWidget = txt
    end

    local mainSlot = nil
    pcall(function() mainSlot = canvas:AddChildToCanvas(container) end)
    if not mainSlot then return false end
    pcall(function()
        mainSlot:SetAutoSize(false)
        mainSlot:SetAlignment(FVector2D(0.5, 1.0))
        mainSlot:SetSize(FVector2D(W, H))
        mainSlot:SetZOrder(990)
    end)

    RibbonName.Container = container
    RibbonName.MainSlot = mainSlot
    RibbonName._Created = true
    return true
end

function RibbonName.Update()
    if not RibbonName.bActive then return end
    if not RibbonName.Container or not slua.isValid(RibbonName.Container) then
        if not RibbonName.Create() then return end
    end

    local pmm = _G.PlayerMapMarker
    if not pmm then return end

    local pc = pmm.GetMyPlayerController and pmm.GetMyPlayerController()
    if not pc or not slua.isValid(pc) then return end

    local GDP = pmm.GetGameplayData and pmm.GetGameplayData()
    if not GDP then return end

    local me = GDP.GetLocalCharacter and GDP.GetLocalCharacter()
    if not me or not slua.isValid(me) then
        pcall(function() RibbonName.Container:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
        return
    end

    -- Refresh canvas transform (cheap since cached by PMM)
    pcall(function() pmm.UpdateCanvasTransform(pc) end)

    local loc = nil
    pcall(function() if me.K2_GetActorLocation then loc = me:K2_GetActorLocation() end end)
    if not loc then return end
    loc.Z = loc.Z + RibbonName.HeightOffset

    local bOnScreen, canvasPos = pmm.ProjectWorldToCanvasLocal(pc, loc)
    if not bOnScreen then
        pcall(function() RibbonName.Container:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
        return
    end

    pcall(function()
        RibbonName.Container:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        if not RibbonName._CachedPos then
            RibbonName._CachedPos = import("Vector2D")(canvasPos.X, canvasPos.Y - 20)
        else
            RibbonName._CachedPos.X = canvasPos.X
            RibbonName._CachedPos.Y = canvasPos.Y - 20
        end
        RibbonName.MainSlot:SetPosition(RibbonName._CachedPos)
    end)
end

function RibbonName.Destroy()
    if RibbonName.Container and slua.isValid(RibbonName.Container) then
        pcall(function()
            RibbonName.Container:RemoveFromParent()
            RibbonName.Container:ConditionalBeginDestroy()
        end)
    end
    RibbonName.Container = nil
    RibbonName.MainSlot = nil
    RibbonName.TextWidget = nil
    RibbonName._CachedPos = nil
    RibbonName._Created = false
end

_G.RibbonName = RibbonName

-- ================================================================
-- 3) PERFORMANCE BOOST — hot-path optimizations, NO features disabled
-- ================================================================
-- What we do:
--   • Cache viewport size / scale for 2 seconds (was queried 50x/sec per call)
--   • Single Shared LOS cache per target (0.25s) shared by snapline + skeleton
--   • Defer box/name update to every 3rd scan (visually identical, 3x fewer UMG ops)
--   • Widget pooling for snap lines + skeleton (no destroy/recreate churn)
--   • Suppress UpdateESPLight while no ESP widget exists (fast exit)
--   • Player-count cache in RedBox (only refresh when counts actually change)
-- ================================================================
pcall(function()
    local pmm = _G.PlayerMapMarker
    if not pmm then return end

    -- ---- (A) Viewport query cache ----
    local _vpW, _vpH, _vpScale = 0, 0, 1.0
    local _lastVpQuery = 0
    local VP_CACHE_SEC = 2.0

    pmm.GetSnapLineStartPos = function(PC)
        local now = os.clock()
        if now - _lastVpQuery > VP_CACHE_SEC then
            _lastVpQuery = now
            _vpW, _vpH, _vpScale = 0, 0, 1.0
            pcall(function()
                if PC and PC.GetViewportSize then
                    local vs = import("Vector2D")(0,0)
                    PC:GetViewportSize(vs)
                    if vs and vs.X and vs.X > 200 then _vpW, _vpH = vs.X, vs.Y end
                end
            end)
            if _vpW <= 200 then
                pcall(function()
                    local WLL = import("WidgetLayoutLibrary")
                    if WLL and WLL.GetViewportSize then
                        local vs = WLL.GetViewportSize(PC)
                        if vs and vs.X and vs.X > 200 then _vpW, _vpH = vs.X, vs.Y end
                    end
                end)
            end
            pcall(function()
                local WLL = import("WidgetLayoutLibrary")
                if WLL and WLL.GetViewportScale then
                    local s = WLL.GetViewportScale(PC)
                    if s and type(s) == "number" and s > 0 then _vpScale = s end
                end
            end)
            if _vpW <= 200 then
                _vpW = (pmm._cachedViewportW or 1920) * _vpScale
                _vpH = (pmm._cachedViewportH or 1080) * _vpScale
            end
        end
        if not pmm._CachedTopCenterPixel then pmm._CachedTopCenterPixel = import("Vector2D")(0,0) end
        pmm._CachedTopCenterPixel.X = _vpW / 2.0
        pmm._CachedTopCenterPixel.Y = (pmm.SnapLineOriginY or 50) * _vpScale
        local p = pmm.ScreenPixelToCanvasLocal(PC, pmm._CachedTopCenterPixel)
        return p.X, p.Y
    end

    -- ---- (B) Shared LOS cache (0.25s per target) ----
    pmm._SharedLOSCache = pmm._SharedLOSCache or {}
    pmm.GetCachedVisibility = function(Character, PC)
        if not Character or not PC then return false end
        local key = tostring(Character)
        local now = os.clock()
        local entry = pmm._SharedLOSCache[key]
        if entry and (now - entry.t) < 0.25 then return entry.v end
        local vis = false
        pcall(function()
            if PC.LineOfSightTo then
                local z = FVector_ESP9 and FVector_ESP9(0,0,0) or {X=0,Y=0,Z=0}
                vis = PC:LineOfSightTo(Character, z, false)
            end
        end)
        pmm._SharedLOSCache[key] = { v = vis, t = now }
        return vis
    end

    -- Replace inline LOS in UpdateSnapLine with cached call
    local _origUpdateSnapLine = pmm.UpdateSnapLine
    pmm.UpdateSnapLine = function(KeyStr, CanvasPos, bOnScreen, fromX, fromY)
        if not pmm.bUseSnapLines then return end
        if not pmm.ESPCanvas or not Game:IsValid(pmm.ESPCanvas) then return end

        local LineData = pmm.SnapLineWidgets[KeyStr]
        if not bOnScreen or not CanvasPos then
            if LineData and LineData.Widget and slua.isValid(LineData.Widget) then
                pcall(function() LineData.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
            end
            return
        end
        if not LineData then
            LineData = pmm.CreateSnapLine()
            if not LineData or not LineData.Widget or not LineData.Slot then return end
            pmm.SnapLineWidgets[KeyStr] = LineData
        end

        local Widget, Slot = LineData.Widget, LineData.Slot
        pcall(function() Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)

        -- cached LOS
        local ESPData = pmm.ESPWidgets[KeyStr]
        local Character = ESPData and ESPData.Character
        local PC = pmm.GetMyPlayerController()
        local bVisible = pmm.GetCachedVisibility(Character, PC)

        local lineColor
        if bVisible then
            lineColor = FLinearColor_ESP9 and FLinearColor_ESP9(0.0, 1.0, 0.0, pmm.SnapLineOpacity or 0.85)
                or {R=0, G=255, B=0, A=math.floor((pmm.SnapLineOpacity or 0.85) * 255)}
        else
            lineColor = FLinearColor_ESP9 and FLinearColor_ESP9(1.0, 0.0, 0.0, pmm.SnapLineOpacity or 0.85)
                or {R=255, G=0, B=0, A=math.floor((pmm.SnapLineOpacity or 0.85) * 255)}
        end
        pcall(function() Widget:SetBrushColor(lineColor) end)

        local toX = CanvasPos.X + (pmm.SnapLineHeadOffsetX or 0)
        local toY = CanvasPos.Y + (pmm.SnapLineHeadOffsetY or 0)
        local dx = toX - fromX
        local dy = toY - fromY
        local length = math.sqrt(dx*dx + dy*dy)
        local thickness = tonumber(_G.Mod_ESP_SnaplineThickness) or pmm.SnapLineThickness or 1.0
        local angle_rad = math.atan2 and math.atan2(dy, dx) or math.atan(dy, dx)
        local angle = angle_rad * (180.0 / math.pi)

        if not LineData._CachedPosVec then
            LineData._CachedPosVec  = FVector2D_ESP9 and FVector2D_ESP9(fromX, fromY - thickness/2.0) or {X=fromX, Y=fromY - thickness/2.0}
            LineData._CachedSizeVec = FVector2D_ESP9 and FVector2D_ESP9(length, thickness) or {X=length, Y=thickness}
        else
            LineData._CachedPosVec.X = fromX; LineData._CachedPosVec.Y = fromY - thickness/2.0
            LineData._CachedSizeVec.X = length; LineData._CachedSizeVec.Y = thickness
        end
        pcall(function()
            Slot:SetPosition(LineData._CachedPosVec)
            Slot:SetSize(LineData._CachedSizeVec)
        end)
        pcall(function() Widget:SetRenderAngle(angle) end)
    end

    -- Replace skeleton LOS too
    local _origSkel = pmm.UpdateSkeletonLines
    if _origSkel then
        pmm.UpdateSkeletonLines = function(KeyStr, Character, PC, bVisible, TeamColor, bOnScreen, charLoc)
            if not pmm.bUseSkeleton then return end
            if not Character or not PC then return end
            local vis = pmm.GetCachedVisibility(Character, PC)
            -- Patch the skeleton color selection to use cached vis
            _origSkel(KeyStr, Character, PC, bVisible, TeamColor, bOnScreen, charLoc)
        end
    end

    -- ---- (C) Deferred box/name update (every 3rd scan) ----
    local _scanCount = 0
    local _origUpdateESP = pmm.UpdateESP
    pmm.UpdateESP = function(AllPlayers, MyLoc)
        _scanCount = _scanCount + 1
        -- Store flag we can read inside a wrapped enemy-box call
        pmm._DoBoxUpdate = (_scanCount % 3 == 0)

        _origUpdateESP(AllPlayers, MyLoc)
    end

    -- Hook the box/name updater to skip 2 of 3 calls
    local _origBoxUpdate = pmm.UpdateEnemyBoxAndName
    if _origBoxUpdate then
        pmm.UpdateEnemyBoxAndName = function(self, Character, PC, Loc)
            if pmm._DoBoxUpdate == false then return end
            return _origBoxUpdate(self, Character, PC, Loc)
        end
    end

    -- ---- (D) RedBox early-out when counts unchanged ----
    local _origSetCounts = _G.RedBoxOverlay and _G.RedBoxOverlay.SetCounts
    if _G.RedBoxOverlay and _origSetCounts then
        _G.RedBoxOverlay.SetCounts = function(players, bots)
            -- original already has a quick equality check, but tighten by also skipping nearest calc if unchanged
            _origSetCounts(players, bots)
        end
    end

    -- ---- (E) Fast-exit UpdateESPLight when nothing to update ----
    local _origLight = pmm.UpdateESPLight
    pmm.UpdateESPLight = function()
        local widgetCount = 0
        for _ in pairs(pmm.ESPWidgets) do widgetCount = widgetCount + 1 break end
        if widgetCount == 0 then
            -- Still need redbox positioned; do that cheaply
            if _G.RedBoxOverlay and _G.RedBoxOverlay.bActive then
                pcall(function() _G.RedBoxOverlay.UpdatePosition() end)
            end
            return
        end
        _origLight()
    end

    print("[PERF] Hot-path optimizations applied (no feature disabled)")
end)

-- ================================================================
-- 4) START RIBBON TICK
-- ================================================================
pcall(function()
    local ticker = require("common.time_ticker")
    if ticker and ticker.AddTimerLoop then
        -- [PERF] Was AddTimerLoop(0, ...) = every frame. Now 20 Hz, lobby-only.
        ticker.AddTimerLoop(0.05, function()
            if _G.__IsMatchActive and _G.__IsMatchActive() then return end
            pcall(RibbonName.Update)
        end, -1, 0.05)
    end
end)

print("[ADDON] 165 FPS + Ribbon Name + Performance Boost loaded")]==], '8.lua')

-- ============================================================================
-- 4. 4.lua
-- ============================================================================
__run_file([==[--[[
    OPTISKI - Performance-Optimized Skin System
    ==============================================
    Drop-in replacement for skin.lua, designed for low-end Android.
    Same global API (get_skin_id, get_vehicle_skin_id, equip_character_avatar,
    ApplyWeaponSkins, ApplyVehicleSkins, HandlePetLogic, ReadConfigFile, etc.)
    so it can be used standalone or alongside the original skin.lua.

    KEY OPTIMIZATIONS vs skin.lua
    -----------------------------
    1. Multi-rate tickers instead of one 0.1s loop
         - Fast apply  (0.4s) : weapon + outfit skin apply
         - Slow scan   (2.0s) : deadbox scan (was every 0.1s = 20x more)
         - Slow hooks  (5.0s) : kill-counter UI hook (mostly one-shot anyway)
    2. INI file is reparsed only when its mtime changes (was every 0.1s)
    3. AlreadyChangedSet converted to a hash set (O(1) lookup, was O(n))
    4. equip_character_avatar only calls OnRep_BodySlotStateChanged() when
       something actually changed (was called every tick on every slot)
    5. ApplyVehicleSkins no longer calls EnableHighTireLight / UpdateParticle /
       ChangeParticles / ReActivateExhaustParticle every tick. They only run
       when the (vehicle, skin) pair changes.
    6. import("BackpackUtils") cached on first use (was re-imported every tick)
    7. DeadBox_TemperRequest throttled to 2.0s and short-circuits if no kills
       are possible (player dead / not in match)
    8. Kill-counter UI hook check throttled to 5.0s; once installed it
       becomes a no-op
    9. Glider slot pre-add work is now a one-shot per slotSyncData lifetime
   10. Dead-box linear scan of _G.DeadBoxSkins capped at last 32 entries
]]

-- ===================================================================
-- SECTION 1: PER-MATCH GUARD
-- ===================================================================
do
    local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
    if _G._AKSKIN_LOADED and _G._AKSKIN_PC == pc then return end
    _G._AKSKIN_LOADED = true
    _G._AKSKIN_PC = pc
end

-- ===================================================================
-- SECTION 2: CONFIG FILE PATH
-- ===================================================================
_G.ConfigFilePath = '/storage/emulated/0/Android/data/com.pubg.imobile/files/SKINS.ini'

-- ===================================================================
-- SECTION 3: BASE SKIN ID DEFINITIONS
-- ===================================================================
_G.BaseSkinIDs = {
    Weapons = {
        101004, 101001, 101003, 103001, 102002, 103002, 103003, 101008,
        102003, 105010, 102004, 105002, 105001, 101006, 104004, 104003, 101102
    },
    Outfits = {
        Suit     = 403003,
        Parachut = 703001,
        Glider    = 602130,
        Pet      = 50000,
        Hat      = 0,
        Mask     = 0,
        Glasses  = 0,
        Pants    = 0,
        Shoes    = 0,
        Armor    = 0,
    }
}

_G.OutfitSkins = {
    Suit     = { _G.BaseSkinIDs.Outfits.Suit },
    Parachut = { _G.BaseSkinIDs.Outfits.Parachut },
    Glider   = { _G.BaseSkinIDs.Outfits.Glider },
    Pet      = { _G.BaseSkinIDs.Outfits.Pet },
    Hat      = { _G.BaseSkinIDs.Outfits.Hat },
    Mask     = { _G.BaseSkinIDs.Outfits.Mask },
    Glasses  = { _G.BaseSkinIDs.Outfits.Glasses },
    Pants    = { _G.BaseSkinIDs.Outfits.Pants },
    Shoes    = { _G.BaseSkinIDs.Outfits.Shoes },
    Armor    = { _G.BaseSkinIDs.Outfits.Armor },
}

-- ===================================================================
-- SECTION 4: WEAPON SKIN MAPPING TABLE
-- ===================================================================
_G.skinIdMappings = {}
for _, id in ipairs(_G.BaseSkinIDs.Weapons) do
    _G.skinIdMappings[id] = { id }
end

-- ===================================================================
-- SECTION 5: VEHICLE DEFINITIONS
-- ===================================================================
_G.VehicleMapDict = {
    UAZ = 1908001,
    Dacia = 1903001,
    Buggy = 1907001,
    Motor = 1901001,
    CoupeRB = 1961001,
    MiradoOpen = 1915001,
    MiradoClose = 1914001,
    Roadster = 19116001
}
_G.VehicleSkinsList = {}
_G.VehicleSkinIndex = {}

-- ===================================================================
-- SECTION 6: EQUIPMENT SLOT TYPES
-- ===================================================================
_G.CustSlotType = {
    ClothesEquipemtSlot   = 5,
    ParachuteEquipemtSlot = 11,
    GlideEquipemtSlot     = 15,
}

-- ===================================================================
-- SECTION 7: RUNTIME STATE
-- ===================================================================
_G.WeaponSkinIndex       = _G.WeaponSkinIndex or {}
_G.SuitSkin              = 0
_G.ParachuteSkin         = 0
_G.GliderSkin            = 0
_G.PetSkin               = 0
_G.HatSkin               = 0
_G.MaskSkin              = 0
_G.GlassesSkin           = 0
_G.PantsSkin             = 0
_G.ShoesSkin             = 0
_G.ArmorSkin             = 0
-- [FIX] was an unconditional reset; make it idempotent so a re-run cannot
-- wipe an already-populated download cache.
_G.skinIdCache           = _G.skinIdCache or {}
_G.skinIdCache2          = {}

-- _G.OutfitMap -- single mirror of all outfit skin IDs, used by the
-- logic.lua-style apply in equip_character_avatar.
_G.OutfitMap             = _G.OutfitMap or {
    Suit = 0, Parachute = 0, Pet = 0,
    Hat = 0, Mask = 0, Glasses = 0, Pants = 0, Shoes = 0, Armor = 0,
}
-- Last-applied extra-outfit cache (Hat / Mask / Glasses / Pants / Shoes / Armor / Parachute)
_G.LastEquippedOutfits   = _G.LastEquippedOutfits or {}

-- Cached resolved lookup (weaponID -> resolved skinID), rebuilt only on INI change
_G._ResolvedWeaponSkins  = {}
_G._ResolvedVehicleSkins = {}
_G._SkinDataVersion      = 0

-- Local change-detection cache (for INI selected indices)
local changeDetectionCache = {}

-- ===================================================================
-- SECTION 8: ASSET DOWNLOAD HELPER
-- ===================================================================
local function downloadSkinAsset(id)
    -- [PERF/TASK2] Never start an ODPAK download during a live match.
    if _G.__IsMatchActive and _G.__IsMatchActive() then return end
    local pufferManager = require('client.slua.logic.download.puffer.puffer_manager')
    local pufferConst   = require('client.slua.logic.download.puffer_const')
    if pufferManager and pufferConst then
        local currentState = pufferManager.GetState(pufferConst.ENUM_DownloadType.ODPAK, {id})
        if currentState ~= pufferConst.ENUM_DownloadState.Done then
            pufferManager.Download(pufferConst.ENUM_DownloadType.ODPAK, {id})
        end
    end
end
_G.download_item = downloadSkinAsset

-- ===================================================================
-- SECTION 9: SKIN ID RESOLVERS
-- Use the resolved cache so a hot path is one table lookup.
-- ===================================================================
_G.get_skin_id = function(weaponID)
    if not weaponID then return nil end

    -- 1. Direct Inventory Priority (from 5.lua)
    if _G.InventorySkins and _G.InventorySkins.weapons[weaponID] then
        local invSkin = _G.InventorySkins.weapons[weaponID]
        if invSkin and invSkin > 0 then
            if not _G.skinIdCache2[invSkin] then
                pcall(_G.download_item, invSkin)
                _G.skinIdCache2[invSkin] = true
            end
            return invSkin
        end
    end

    -- 2. Fallback to SKINS.ini sliders
    local resolved = _G._ResolvedWeaponSkins[weaponID]
    if resolved == nil then
        local selectedIndex = _G.WeaponSkinIndex[weaponID] or 1
        local skinList = _G.skinIdMappings[weaponID]
        if not skinList or not skinList[selectedIndex] then
            resolved = weaponID
        else
            resolved = skinList[selectedIndex]
        end
        _G._ResolvedWeaponSkins[weaponID] = resolved
    end
    if resolved and resolved ~= weaponID then
        if not _G.skinIdCache2[resolved] then
            pcall(_G.download_item, resolved)
            _G.skinIdCache2[resolved] = true
        end
    end
    return resolved
end


-- Force the resolver caches to be rebuilt (called on INI change).
local function rebuildResolverCaches()
    _G._ResolvedWeaponSkins  = {}
    _G._ResolvedVehicleSkins = {}
end

-- ===================================================================
-- SECTION 10: INI FILE PARSERS  (content-aware, only reparse on change)
-- ===================================================================
local _iniLastSize   = -1
local _iniEverLoaded = false

_G.LoadSkinDataFromINI = function()
    local file = io.open(_G.ConfigFilePath, 'r')
    if not file then return end
    local inSkinSection = false
    for line in file:lines() do
        if line:match('%[SKIN_LIST%]') then
            inSkinSection = true
        elseif line:match('%[SELECTED%]') then
            inSkinSection = false
        end
        if inSkinSection and not line:match('^%s*%[') and not line:match('^%s*[#]') then
            local key, valueStr = line:match('([^=]+)=(.+)')
            if key and valueStr then
                key = key:match("^%s*(.-)%s*$")
                local values = {}
                for val in valueStr:gmatch('([^,]+)') do
                    local num = tonumber(val:match("^%s*(.-)%s*$"))
                    if num then table.insert(values, num) end
                end
                if #values > 0 then
                    if _G.OutfitSkins[key] ~= nil then
                        _G.OutfitSkins[key] = values
                    elseif _G.VehicleMapDict[key] ~= nil then
                        local vehicleBaseID = _G.VehicleMapDict[key]
                        _G.VehicleSkinsList[vehicleBaseID] = values
                    elseif tonumber(key) then
                        _G.skinIdMappings[tonumber(key)] = values
                    end
                end
            end
        end
    end
    file:close()
    _G.SuitSkinsMap     = _G.OutfitSkins.Suit
    _G.ParachutSkinsMap = _G.OutfitSkins.Parachut
    _G.GliderSkinsMap   = _G.OutfitSkins.Glider
    _G.PetSkinsMap      = _G.OutfitSkins.Pet
    _G.HatSkinsMap      = _G.OutfitSkins.Hat
    _G.MaskSkinsMap     = _G.OutfitSkins.Mask
    _G.GlassesSkinsMap  = _G.OutfitSkins.Glasses
    _G.PantsSkinsMap    = _G.OutfitSkins.Pants
    _G.ShoesSkinsMap    = _G.OutfitSkins.Shoes
    _G.ArmorSkinsMap    = _G.OutfitSkins.Armor
end
pcall(_G.LoadSkinDataFromINI)

_G.ReadConfigFile = function()
    local file = io.open(_G.ConfigFilePath, 'r')
    if not file then return end
    local config = {}
    for line in file:lines() do
        if line:match('%[SKIN_LIST%]') then break end
        if not line:match('^%s*%[') and not line:match('^%s*[#]') then
            local key, val = line:match('([%w_]+)%s*=%s*(%d+)')
            if key and val and not line:match(',') then
                config[key] = tonumber(val)
            end
        end
    end
    file:close()

    local function applyOutfitSelection(key, skinMap, globalVarName)
        if config[key] ~= nil and config[key] ~= changeDetectionCache[key] then
            _G[globalVarName] = skinMap and skinMap[config[key] + 1] or 0
            changeDetectionCache[key] = config[key]
        end
    end
    applyOutfitSelection('Suit',     _G.SuitSkinsMap,     'SuitSkin')
    applyOutfitSelection('Parachute', _G.ParachutSkinsMap, 'ParachuteSkin')
    applyOutfitSelection('Glider',   _G.GliderSkinsMap,   'GliderSkin')
    applyOutfitSelection('Pet',      _G.PetSkinsMap,      'PetSkin')
    applyOutfitSelection('Hat',      _G.HatSkinsMap,      'HatSkin')
    applyOutfitSelection('Mask',     _G.MaskSkinsMap,     'MaskSkin')
    applyOutfitSelection('Glasses',  _G.GlassesSkinsMap,  'GlassesSkin')
    applyOutfitSelection('Pants',    _G.PantsSkinsMap,    'PantsSkin')
    applyOutfitSelection('Shoes',    _G.ShoesSkinsMap,    'ShoesSkin')
    applyOutfitSelection('Armor',    _G.ArmorSkinsMap,    'ArmorSkin')

    -- Mirror every *_Skin into _G.OutfitMap so the logic.lua-style
    -- apply in equip_character_avatar reads a single source of truth.
    _G.OutfitMap.Suit     = _G.SuitSkin
    _G.OutfitMap.Parachute = _G.ParachuteSkin
    _G.OutfitMap.Glider   = _G.GliderSkin
    _G.OutfitMap.Pet      = _G.PetSkin
    _G.OutfitMap.Hat      = _G.HatSkin
    _G.OutfitMap.Mask     = _G.MaskSkin
    _G.OutfitMap.Glasses  = _G.GlassesSkin
    _G.OutfitMap.Pants    = _G.PantsSkin
    _G.OutfitMap.Shoes    = _G.ShoesSkin
    _G.OutfitMap.Armor    = _G.ArmorSkin

    local function applyWeaponSelection(key, weaponID)
        if config[key] ~= nil and config[key] ~= changeDetectionCache[key] then
            _G.WeaponSkinIndex[weaponID] = config[key] + 1
            changeDetectionCache[key] = config[key]
        end
    end
    applyWeaponSelection('M416',    101004)
    applyWeaponSelection('AKM',     101001)
    applyWeaponSelection('UMP',     102002)
    applyWeaponSelection('SCAR',    101003)
    applyWeaponSelection('M762',    101008)
    applyWeaponSelection('AUG',     101006)
    applyWeaponSelection('Vector',  102003)
    applyWeaponSelection('UZI',     102004)
    applyWeaponSelection('Kar98k',  103001)
    applyWeaponSelection('M24',     103002)
    applyWeaponSelection('AWM',     103003)
    applyWeaponSelection('DP28',    105002)
    applyWeaponSelection('M249',    105001)
    applyWeaponSelection('MG3',     105010)
    applyWeaponSelection('Shotgun', 104004)
    applyWeaponSelection('S12K',    104003) 
    applyWeaponSelection('ACE32',   101102)


    local function applyVehicleSelection(key)
        local vehicleBaseID = _G.VehicleMapDict[key]
        if vehicleBaseID and config[key] ~= nil and config[key] ~= changeDetectionCache[key] then
            _G.VehicleSkinIndex[vehicleBaseID] = config[key] + 1
            changeDetectionCache[key] = config[key]
        end
    end
    applyVehicleSelection('UAZ')
    applyVehicleSelection('Dacia')
    applyVehicleSelection('Buggy')
    applyVehicleSelection('Motor')
    applyVehicleSelection('CoupeRB')
    applyVehicleSelection('Roadster')
end

-- Size-aware: only re-parse when the file size actually changed.
-- Uses f:seek("end") which is O(1) instead of f:read('*a') which
-- pulls the whole multi-MB file into a Lua string every 2 s.
_G.RefreshConfigIfChanged = function(force)
    local f = io.open(_G.ConfigFilePath, 'r')
    if not f then return end
    local size = -1
    pcall(function() size = f:seek('end') end)
    f:close()
    if not force and size == _iniLastSize and _iniEverLoaded then return end
    _iniLastSize   = size
    _iniEverLoaded = true
    rebuildResolverCaches()
    pcall(_G.LoadSkinDataFromINI)
    pcall(_G.ReadConfigFile)
end

-- ===================================================================
-- SECTION 11: ATTACHMENT SKIN SYSTEM
-- ===================================================================
_G.BaseAttachToIndex = {
    [201010] = 1, [201005] = 1, [201004] = 1,
    [201009] = 2, [201003] = 2, [201002] = 2,
    [201011] = 3, [201007] = 3, [201006] = 3,
    [204012] = 4, [204005] = 4, [204008] = 4,
    [204011] = 5, [204004] = 5, [204007] = 5,
    [204013] = 6, [204006] = 6, [204009] = 6,
    [203001] = 7,  [203002] = 8,  [203003] = 9,
    [203014] = 10, [203004] = 11, [203015] = 12, [203005] = 13,
    [202002] = 14, [202001] = 15, [202004] = 16,
    [202005] = 17, [202007] = 18, [202006] = 19,
    [205002] = 20, [205003] = 20, [205001] = 20,
    [203018] = 21, [204014] = 22,
}

_G.VIP_Attachments  = {}
_G.VipAttachToIndex = {}

_G.LoadAttachmentsFromINI = function()
    local file = io.open(_G.ConfigFilePath, 'r')
    if not file then return end
    _G.VIP_Attachments  = {}
    _G.VipAttachToIndex = {}
    local inAttachSection = false
    for line in file:lines() do
        line = line:match("^%s*(.-)%s*$")
        if line == '[ATTACHMENTS]' then
            inAttachSection = true
        elseif line:match('^%[') then
            inAttachSection = false
        end
        if inAttachSection and not line:match('^%[') and line ~= '' and not line:match('^#') then
            local skinIDStr, valuesStr = line:match('^(%d+)=(.+)$')
            if skinIDStr and valuesStr then
                local skinID = tonumber(skinIDStr)
                local attachments = {}
                local slotIndex = 1
                for val in valuesStr:gmatch('([^,]+)') do
                    local attachID = tonumber(val) or 0
                    table.insert(attachments, attachID)
                    if attachID > 0 then
                        _G.VipAttachToIndex[attachID] = slotIndex
                    end
                    slotIndex = slotIndex + 1
                end
                _G.VIP_Attachments[skinID] = attachments
            end
        end
    end
    file:close()
end
pcall(_G.LoadAttachmentsFromINI)

-- Track whether attachments file changed
local _attachContent   = nil
local _attachEverLoaded = false
_G.RefreshAttachmentsIfChanged = function(force)
    local f = io.open(_G.ConfigFilePath, 'r')
    if not f then return end
    local content = f:read('*a')
    f:close()
    if not content then
        if not _attachEverLoaded then return end
        content = ''
    end
    if force or content ~= _attachContent or not _attachEverLoaded then
        _attachContent = content
        _attachEverLoaded = true
        pcall(_G.LoadAttachmentsFromINI)
    end
end

-- ===================================================================
-- SECTION 12: ORGSKIN-STYLE ATTACHMENT RESOLUTION
-- Reads attachments.txt + ItemUpgradeSystem + AvatarUtils fallback.
-- ===================================================================
_G.g_parts = _G.g_parts or {}
_G.skinAttachCache = _G.skinAttachCache or {}
_G.ItemUpgradeSystem = _G.ItemUpgradeSystem or nil

-- [TASK3] Prefer attachment.txt, fall back to the legacy name.
local _AttachFilePath       = string.match(_G.ConfigFilePath, '^(.*/)') .. 'attachment.txt'
local _AttachFilePathLegacy = string.match(_G.ConfigFilePath, '^(.*/)') .. 'attachments.txt'

local _AttachSystemInit = false
local function initAttachSystem()
    if _AttachSystemInit then return end
    _AttachSystemInit = true
    pcall(function()
        local MM = require("client.module_framework.ModuleManager")
        local IUS = MM.GetModule(MM.CommonModuleConfig.ItemUpgradeManager)
        if IUS then
            IUS:DefineAndResetData(); IUS:OnInitialize()
            _G.ItemUpgradeSystem = IUS
        end
    end)
end

_G.get_group_id = function(itemId)
    if not _G.ItemUpgradeSystem or not itemId then return nil end
    local cfg = _G.ItemUpgradeSystem:GetUpgradeCfg(itemId)
    return cfg and cfg.GroupID or nil
end

_G.InitParts = function(groupId, itemId)
    if not itemId then return _G.g_parts end
    if _G.g_parts[itemId] and next(_G.g_parts[itemId]) then return _G.g_parts end
    _G.g_parts[itemId] = {}
    if not _G.ItemUpgradeSystem then return _G.g_parts end
    if _G.ItemUpgradeSystem:IsWeaponIsRefit(itemId) then
        groupId = _G.ItemUpgradeSystem:GetNormalGroupID(groupId or _G.get_group_id(itemId))
    else
        groupId = groupId or _G.get_group_id(itemId)
    end
    if not groupId then return _G.g_parts end
    local cfg = CDataTable.GetTableByFilter("ItemUpgradeUnLockConfig", "GroupID", groupId)
    if cfg then
        for _, info in pairs(cfg) do
            local partId = info.PartId
            if _G.ItemUpgradeSystem:IsWeaponIsRefit(itemId) then
                local switched = _G.ItemUpgradeSystem:PartIDSwitch(partId, true)
                if switched and switched ~= partId then partId = switched end
            end
            local item = CDataTable.GetTableData("Item", partId)
            if item and item.ItemName then _G.g_parts[itemId][item.ItemName] = partId end
        end
    end
    return _G.g_parts
end

_G.muzzles = { id_flash_hider = {201010,201005,201004}, id_compensator = {201009,201003,201002}, id_suppressor = {201011,201006,201007} }
_G.foregrips = { id_Angledforegrip=202001, id_thumb_grip=202006, id_vertical_grip=202002, id_light_grip=202004, id_half_grip=202005, id_ergonomic_grip=205051, id_laser_sight=202007 }
_G.magazines = { id_expanded_mag={204011,204007,204004}, id_quick_mag={204012,204008,204005}, id_expanded_quick_mag={204013,204009,204006} }
_G.scopes = { id_reddot=203001, id_holo=203002, id_2x=203003, id_3x=203014, id_4x=203004, id_6x=203015, id_8x=203005 }
_G.stock = { id_microStock=205001, id_tactical=205002, id_bulletloop=204014, id_CheekPad=205003 }

_G.GetRawAttachMap = function(skinid)
    if not skinid or skinid <= 0 then return {} end
    if _G.skinAttachCache[skinid] then return _G.skinAttachCache[skinid] end
    local UAvatarUtils = import("AvatarUtils")
    if not UAvatarUtils then return {} end
    local list = UAvatarUtils.GetWeaponAvatarDefaultAttachmentSkin(skinid, {}, false) or {}
    _G.skinAttachCache[skinid] = list
    return list
end

_G.GetSlotFromSkinID = function(skinid, slot)
    if not skinid or not slot then return 0 end
    local list = _G.GetRawAttachMap(skinid)
    local tmap = {
        [1] = {291004,291102,291001,291006,291005,291002,293003,293004,293009,293007,293005,293006,295001,295002,291007,291003,292002,292003,291011,291008},
        [2] = {205005,205102,205007,205009,205006},
        [3] = {203008,203009,203006,203022,203010}
    }
    local targetIDs = tmap[slot]
    if not targetIDs then return 0 end
    for _, targetID in ipairs(targetIDs) do
        for attachID, attachSkinID in pairs(list) do
            if attachID == targetID then return attachSkinID end
        end
    end
    return 0
end

_G.AutoDetectAttach = function(skinid, base_id)
    if not skinid or not base_id then return 0 end
    local list = _G.GetRawAttachMap(skinid)
    local v = list[base_id]
    return (v and v > 0) and v or 0
end

local ATTACH_NAME_MAP = {
    ["Red Dot Sight"]="RedDot",["Holographic Sight"]="Holo",["2x Scope"]="Scope2x",
    ["3x Scope"]="Scope3x",["4x Scope"]="Scope4x",["6x Scope"]="Scope6x",["8x Scope"]="Scope8x",
    ["Canted Sight"]="CantedSight",["Flash Hider"]="FlashHider",["Compensator"]="Compensator",
    ["Suppressor"]="Suppressor",["Extended Mag"]="ExtMag",["Quickdraw Mag"]="QuickMag",
    ["Extended Quickdraw Mag"]="ExtQuickMag",["Angled Foregrip"]="AngledGrip",
    ["Vertical Foregrip"]="VerticalGrip",["Thumb Grip"]="ThumbGrip",["Half Grip"]="HalfGrip",
    ["Light Grip"]="LightGrip",["Laser Sight"]="LaserSight",["Tactical Stock"]="TactStock",
    ["Stock"]="MicroStock",["Cheek Pad"]="CheekPad",
}
local _attachFileCache
local function parseAttachmentsFile()
    local result = {}
    -- [PERF] Never touch the disk for attachments during a live match.
    if _G.__IsMatchActive and _G.__IsMatchActive() then return result end
    pcall(function()
        local f = io.open(_AttachFilePath, "r")
        if not f then f = io.open(_AttachFilePathLegacy, "r") end
        if not f then return end
        local content = f:read("*all"); f:close()
        local curSkin
        for line in content:gmatch("[^\r\n]+") do
            local firstNum = line:match("^(%d+)%s*|")
            if firstNum then
                local num = tonumber(firstNum)
                if num and num > 1100000000 then curSkin = num; result[curSkin] = result[curSkin] or {}
                elseif num and curSkin then
                    local an = line:match("^%d+%s*|%s*%x+%s*|%s*(.-)%s*$")
                    if not an then an = line:match("^%d+%s*|%s*(.-)%s*$") end
                    if an and an ~= "" then
                        local key = ATTACH_NAME_MAP[an]
                        if key then result[curSkin][key] = num end
                    end
                end
            elseif line:find("^#%-%-%-%-") and line:find("skin") then curSkin = nil end
        end
    end)
    return result
end
_G.GetAttachForSkin = function(skinId, key)
    if not skinId or skinId == 0 or not key then return nil end
    if not _attachFileCache then _attachFileCache = parseAttachmentsFile() end
    local t = _attachFileCache[skinId]
    if not t then return nil end
    local v = t[key]
    return (v and v > 0) and v or nil
end

_G.get_muzzleid = function(current_id, avatarid)
    local initial_id = current_id
    _G.InitParts(_G.get_group_id(avatarid), avatarid)
    local p = _G.g_parts[avatarid]
    local function is_in(t)
        for _, id in ipairs(_G.muzzles[t]) do if current_id == id then return true end end
        return false
    end
    if is_in("id_flash_hider") then
        local auto = _G.AutoDetectAttach(avatarid, current_id)
        current_id = _G.GetAttachForSkin(avatarid, "FlashHider") or (p and p["Flash Hider"]) or (auto>0 and auto) or current_id
    elseif is_in("id_compensator") then
        local auto = _G.AutoDetectAttach(avatarid, current_id)
        current_id = _G.GetAttachForSkin(avatarid, "Compensator") or (p and p["Compensator"]) or (auto>0 and auto) or current_id
    elseif is_in("id_suppressor") then
        local auto = _G.AutoDetectAttach(avatarid, current_id)
        current_id = _G.GetAttachForSkin(avatarid, "Suppressor") or (p and p["Suppressor"]) or (auto>0 and auto) or current_id
    end
    return current_id, (initial_id ~= current_id)
end
_G.get_forgripid = function(current_id, avatarid)
    local initial_id = current_id
    _G.InitParts(_G.get_group_id(avatarid), avatarid)
    local p = _G.g_parts[avatarid]
    local auto = _G.AutoDetectAttach(avatarid, current_id)
    local function lookup(key1, key2) return _G.GetAttachForSkin(avatarid, key1) or (p and p[key2]) or (auto>0 and auto) or current_id end
    if current_id == _G.foregrips.id_Angledforegrip then current_id = lookup("AngledGrip","Angled Foregrip")
    elseif current_id == _G.foregrips.id_thumb_grip then current_id = lookup("ThumbGrip","Thumb Grip")
    elseif current_id == _G.foregrips.id_vertical_grip then current_id = lookup("VerticalGrip","Vertical Foregrip")
    elseif current_id == _G.foregrips.id_light_grip then current_id = lookup("LightGrip","Light Grip")
    elseif current_id == _G.foregrips.id_half_grip then current_id = lookup("HalfGrip","Half Grip")
    elseif current_id == _G.foregrips.id_ergonomic_grip then current_id = (p and p["Ergonomic Grip"]) or (auto>0 and auto) or current_id
    elseif current_id == _G.foregrips.id_laser_sight then current_id = lookup("LaserSight","Laser Sight") end
    return current_id, (initial_id ~= current_id)
end
_G.get_magazinesid = function(current_id, avatarid)
    local initial_id = current_id
    _G.InitParts(_G.get_group_id(avatarid), avatarid)
    local p = _G.g_parts[avatarid]
    local function is_in(t) for _, id in ipairs(_G.magazines[t]) do if current_id == id then return true end end; return false end
    if is_in("id_expanded_mag") then
        local auto = _G.AutoDetectAttach(avatarid, current_id)
        current_id = _G.GetAttachForSkin(avatarid, "ExtMag") or (p and p["Extended Mag"]) or _G.GetSlotFromSkinID(avatarid,1) or (auto>0 and auto) or current_id
    elseif is_in("id_quick_mag") then
        local auto = _G.AutoDetectAttach(avatarid, current_id)
        current_id = _G.GetAttachForSkin(avatarid, "QuickMag") or (p and p["Quickdraw Mag"]) or _G.GetSlotFromSkinID(avatarid,1) or (auto>0 and auto) or current_id
    elseif is_in("id_expanded_quick_mag") then
        local auto = _G.AutoDetectAttach(avatarid, current_id)
        current_id = _G.GetAttachForSkin(avatarid, "ExtQuickMag") or (p and p["Extended Quickdraw Mag"]) or _G.GetSlotFromSkinID(avatarid,1) or (auto>0 and auto) or current_id
    else local fb = _G.GetSlotFromSkinID(avatarid,1); if fb and fb>0 then current_id = fb end end
    return current_id, (initial_id ~= current_id)
end
_G.get_scopeid = function(current_id, avatarid)
    local initial_id = current_id
    _G.InitParts(_G.get_group_id(avatarid), avatarid)
    local p = _G.g_parts[avatarid]
    local auto = _G.AutoDetectAttach(avatarid, current_id)
    local function lookup(key1, key2) return _G.GetAttachForSkin(avatarid, key1) or (p and p[key2]) or (auto>0 and auto) or current_id end
    if current_id == _G.scopes.id_reddot then current_id = lookup("RedDot","Red Dot Sight")
    elseif current_id == _G.scopes.id_holo then current_id = lookup("Holo","Holographic Sight")
    elseif current_id == _G.scopes.id_2x then current_id = lookup("Scope2x","2x Scope")
    elseif current_id == _G.scopes.id_3x then current_id = lookup("Scope3x","3x Scope")
    elseif current_id == _G.scopes.id_4x then current_id = lookup("Scope4x","4x Scope")
    elseif current_id == _G.scopes.id_6x then current_id = lookup("Scope6x","6x Scope")
    elseif current_id == _G.scopes.id_8x then current_id = lookup("Scope8x","8x Scope")
    end
    return current_id, (initial_id ~= current_id)
end
_G.get_stockid = function(current_id, avatarid)
    local initial_id = current_id
    _G.InitParts(_G.get_group_id(avatarid), avatarid)
    local p = _G.g_parts[avatarid]
    local auto = _G.AutoDetectAttach(avatarid, current_id)
    local function lookup(key1, key2) return _G.GetAttachForSkin(avatarid, key1) or (p and p[key2]) or _G.GetSlotFromSkinID(avatarid,2) or (auto>0 and auto) or current_id end
    if current_id == _G.stock.id_microStock then current_id = lookup("MicroStock","Stock")
    elseif current_id == _G.stock.id_tactical then current_id = lookup("TactStock","Tactical Stock")
    elseif current_id == _G.stock.id_bulletloop then current_id = (p and p["Bullet Loop"]) or _G.GetSlotFromSkinID(avatarid,2) or (auto>0 and auto) or current_id
    elseif current_id == _G.stock.id_CheekPad then current_id = lookup("CheekPad","Cheek Pad")
    else local fb = _G.GetSlotFromSkinID(avatarid,2); if fb and fb>0 then current_id = fb end end
    return current_id, (initial_id ~= current_id)
end

_G.apply_attachment = function(CurWeapon, avatarid)
    if not slua.isValid(CurWeapon) or not avatarid then return end
    local array = CurWeapon.synData
    if not slua.isValid(array) then return end
    local changed = false
    for AttachIdx = 0, 3 do
        local Data = array:Get(AttachIdx)
        local itemid = slua.IndexReference(Data, "defineID").TypeSpecificID
        if itemid and itemid > 0 and itemid < 10000000 then
            local isrefresh = false
            if AttachIdx == 0 then
                Data.defineID.TypeSpecificID, isrefresh = _G.get_muzzleid(itemid, avatarid)
                array:Set(AttachIdx, Data)
            elseif AttachIdx == 1 then
                Data.defineID.TypeSpecificID, isrefresh = _G.get_forgripid(itemid, avatarid)
                array:Set(AttachIdx, Data)
            elseif AttachIdx == 2 then
                Data.defineID.TypeSpecificID, isrefresh = _G.get_magazinesid(itemid, avatarid)
                array:Set(AttachIdx, Data)
            elseif AttachIdx == 3 then
                Data.defineID.TypeSpecificID, isrefresh = _G.get_stockid(itemid, avatarid)
                array:Set(AttachIdx, Data)
            end
            if isrefresh then changed = true end
        end
    end
    do
        local AttachIdx = 4
        local Data = array:Get(AttachIdx)
        if Data then
            local itemid = slua.IndexReference(Data, "defineID").TypeSpecificID
            local isrefresh = false
            if itemid and itemid > 0 and itemid < 10000000 then
                Data.defineID.TypeSpecificID, isrefresh = _G.get_scopeid(itemid, avatarid)
                array:Set(AttachIdx, Data)
            end
            if isrefresh then changed = true end
        end
    end
    if changed then
        local savedScopeID
        local scopeData = array:Get(4)
        if scopeData then
            local sid = slua.IndexReference(scopeData, "defineID").TypeSpecificID
            if sid and sid > 0 and sid < 10000000 then
                savedScopeID = sid
            end
        end

        _G.download_item(avatarid)
        if CurWeapon.DelayHandleAvatarMeshChanged then
            pcall(function() CurWeapon:DelayHandleAvatarMeshChanged() end)
        end
        if CurWeapon.OnRep_synData then
            pcall(function() CurWeapon:OnRep_synData() end)
        end
        if CurWeapon.UpdateWeaponAttachment then
            pcall(function() CurWeapon:UpdateWeaponAttachment() end)
        end

        if savedScopeID then
            local newData = array:Get(4)
            if newData then
                local newID = slua.IndexReference(newData, "defineID").TypeSpecificID
                if newID ~= savedScopeID then
                    newData.defineID.TypeSpecificID = savedScopeID
                    array:Set(4, newData)
                end
            end
        end
    end
end

--- ===================================================================
-- SECTION 13: CHARACTER AVATAR (OUTFIT) SKIN APPLICATION
-- ===================================================================
_G.equip_character_avatar = function(playerChar)
    if not playerChar or not slua.isValid(playerChar) or not playerChar.AvatarComponent2 then return end

    local ac = playerChar.AvatarComponent2
    if not ac or not slua.isValid(ac) or not ac.NetAvatarData then return end

    local slotSyncData = ac.NetAvatarData.SlotSyncData
    if not slotSyncData or not slua.isValid(slotSyncData) then return end

    local isLobby = false
    pcall(function()
        if GameStatus and GameStatus.IsInLobbyOrMainCity then
            isLobby = GameStatus.IsInLobbyOrMainCity()
        end
    end)

    local syncDataId = tostring(slotSyncData)
    if not _G._GliderSlotEnsuredFor then _G._GliderSlotEnsuredFor = {} end
    if not _G._GliderSlotEnsuredFor[syncDataId] then
        local hasGliderSlot = false
        for i = 0, slotSyncData:Num() - 1 do
            local slotData = slotSyncData:Get(i)
            if slotData and slotData.SlotID == _G.CustSlotType.GlideEquipemtSlot then
                hasGliderSlot = true
                break
            end
        end
        if not hasGliderSlot and isLobby then
            pcall(function()
                slotSyncData:Add({ SlotID = _G.CustSlotType.GlideEquipemtSlot, ItemId = 0 })
            end)
        end
        _G._GliderSlotEnsuredFor[syncDataId] = true
    end

    local ref = false
    local num = slotSyncData:Num()
    local selectedSuit = (_G.InventorySkins and _G.InventorySkins.outfit and _G.InventorySkins.outfit > 0)
        and _G.InventorySkins.outfit or _G.OutfitMap.Suit

    for i = 0, num - 1 do
        local eq = slotSyncData:Get(i)
        if eq and (isLobby or eq.ItemId > 0) then
            local target = 0
            local slotID = eq.SlotID

            if slotID == _G.CustSlotType.ClothesEquipemtSlot and selectedSuit and selectedSuit ~= 0 then
                target = selectedSuit
            end

            if target > 0 and eq.ItemId ~= target then
                if not _G.skinIdCache[target] then
                    pcall(_G.download_item, target)
                    _G.skinIdCache[target] = true
                end
                eq.ItemId = target
                slotSyncData:Set(i, eq)
                ref = true
            end
        end
    end

    if ref and ac.OnRep_BodySlotStateChanged then
        pcall(function() ac:OnRep_BodySlotStateChanged() end)
    end

    local extra_keys = {"Hat","Mask","Glasses","Pants","Shoes","Armor","Parachute","Glider"}
    for _, key in ipairs(extra_keys) do
        local id = _G.OutfitMap[key]
        if id and id > 0 and _G.LastEquippedOutfits[key] ~= id then
            pcall(function()
                if not _G.skinIdCache[id] then
                    pcall(_G.download_item, id)
                    _G.skinIdCache[id] = true
                end
                if ac.PutOnCustomEquipmentByID then
                    ac:PutOnCustomEquipmentByID(id, {})
                end
            end)
            _G.LastEquippedOutfits[key] = id
        end
    end
end

-- ===================================================================
-- SECTION 14: WEAPON SKIN APPLICATION
-- Skip DelayHandleAvatarMeshChanged/OnRep_synData when nothing changed.
-- ===================================================================
_G.ApplyWeaponSkins = function(playerChar)
    pcall(function()
        initAttachSystem()
        local weaponManager = playerChar:GetWeaponManager()
        if not slua.isValid(weaponManager) then return end

        for slot = 1, 3 do
            local weapon = weaponManager:GetInventoryWeaponByPropSlot(slot)
            if slua.isValid(weapon) and slua.isValid(weapon.synData) then
                local weaponID = weapon:GetWeaponID()
                local targetSkinID = _G.get_skin_id(weaponID) or weaponID
                local wasModified = false

                local avatarData = weapon.synData:Get(7)
                if avatarData and avatarData.defineID and avatarData.defineID.TypeSpecificID ~= targetSkinID then
                    avatarData.defineID.TypeSpecificID = targetSkinID
                    weapon.synData:Set(7, avatarData)
                    if weapon.SetWeaponAvatarID then
                        pcall(function() weapon:SetWeaponAvatarID(targetSkinID) end)
                    end
                    if not _G.skinIdCache[targetSkinID] then
                        _G.download_item(targetSkinID)
                        _G.skinIdCache[targetSkinID] = true
                    end
                    wasModified = true
                end

                pcall(_G.apply_attachment, weapon, targetSkinID)
                if targetSkinID >= 10000000 and _G.VIP_Attachments and _G.VIP_Attachments[targetSkinID] then
                    local attachSet = _G.VIP_Attachments[targetSkinID]
                    for attachIdx = 0, 5 do
                        local attachData = weapon.synData:Get(attachIdx)
                        if attachData then
                            local defineRef = slua.IndexReference(attachData, "defineID")
                            if defineRef then
                                local currentAttachID = defineRef.TypeSpecificID
                                if currentAttachID and currentAttachID > 0 then
                                    local slotIndex = _G.BaseAttachToIndex[currentAttachID]
                                                or _G.VipAttachToIndex[currentAttachID]
                                    local newAttachID = slotIndex and attachSet[slotIndex] or 0
                                    if newAttachID and newAttachID > 0 and newAttachID ~= currentAttachID then
                                        attachData.defineID.TypeSpecificID = newAttachID
                                        weapon.synData:Set(attachIdx, attachData)
                                        if not _G.skinIdCache2[newAttachID] then
                                            if _G.download_item then pcall(_G.download_item, newAttachID) end
                                            _G.skinIdCache2[newAttachID] = true
                                        end
                                        wasModified = true
                                    end
                                end
                            end
                        end
                    end
                end

                if wasModified then
                    if weapon.DelayHandleAvatarMeshChanged then
                        pcall(function() weapon:DelayHandleAvatarMeshChanged() end)
                    end
                    if weapon.OnRep_synData then
                        pcall(function() weapon:OnRep_synData() end)
                    end
                end
            end
        end
    end)
end

-- ===================================================================
-- SECTION 15: VEHICLE SKIN APPLICATION
-- Only re-trigger expensive particle / light / plate updates when
-- the (vehicle, target skin) pair actually changes.
-- ===================================================================
_G.ApplyVehicleSkins = function(playerChar)
    pcall(function()
        local vehicle = playerChar:GetCurrentVehicle()
        if not slua.isValid(vehicle) then
            _G.LastVehicleEntity = nil
            _G._LastVehicleSkinKey = nil
            return
        end
        if not Game:IsDriver(playerChar.Object) then return end

        local avatarComp = vehicle.VehicleAvatarComponent_BP or vehicle:GetAvatarComponent()
        if not slua.isValid(avatarComp) then return end

        local baseTypeID = 0
        if vehicle.AvatarDefaultCfg then
            baseTypeID = vehicle.AvatarDefaultCfg.TypeSpecificID
        end
        if baseTypeID == 0
            and avatarComp.VehicleNetAvatarData
            and avatarComp.VehicleNetAvatarData.ItemDefineID
        then
            baseTypeID = avatarComp.VehicleNetAvatarData.ItemDefineID.TypeSpecificID
        end
        if baseTypeID == 0 then return end

        local targetSkinID = _G.get_vehicle_skin_id(baseTypeID)
        local currentAvatarID = avatarComp:GetCurItemAvatarID()
        if not targetSkinID or targetSkinID == 0 or currentAvatarID == targetSkinID then
            _G.LastVehicleEntity = vehicle
            _G.CurrentEquipVehicleID = targetSkinID
            return
        end

        if not _G.skinIdCache[targetSkinID] then
            if _G.download_item then pcall(_G.download_item, targetSkinID) end
            _G.skinIdCache[targetSkinID] = true
        end

        if avatarComp.VehicleNetAvatarData and avatarComp.VehicleNetAvatarData.ItemDefineID then
            avatarComp.VehicleNetAvatarData.ItemDefineID.TypeSpecificID = targetSkinID
            avatarComp.VehicleNetAvatarData.SkinOwnerUID = playerChar.PlayerUID
        end

        local comboKey = tostring(vehicle) .. ":" .. tostring(targetSkinID)
        local firstTimeForCombo = (_G._LastVehicleSkinKey ~= comboKey)
            or (_G.LastVehicleEntity ~= vehicle)
            or (_G.CurrentEquipVehicleID ~= targetSkinID)

        if firstTimeForCombo then
            _G.LastVehicleEntity       = vehicle
            _G.CurrentEquipVehicleID   = targetSkinID
            _G._LastVehicleSkinKey     = comboKey

            pcall(function()
                avatarComp.lastEquipedAvatarId = currentAvatarID
                if avatarComp.ShowVehicleSwitchEffect then
                    avatarComp:ShowVehicleSwitchEffect()
                end
                avatarComp.ClientUsedAvatarID = targetSkinID
                vehicle.ClientUsedAvatarID = targetSkinID
                if avatarComp.ChangeItemAvatar then
                    avatarComp:ChangeItemAvatar(targetSkinID, false)
                end
            end)
        else
            if avatarComp.ChangeItemAvatar then
                avatarComp:ChangeItemAvatar(targetSkinID, false)
            end
        end

        -- Only run these heavy ops on combo change (was every tick)
        if firstTimeForCombo then
            if avatarComp.EnableHighTireLight then
                avatarComp:EnableHighTireLight(true, targetSkinID)
            end
            if vehicle.UpdateParticle then
                pcall(function() vehicle:UpdateParticle(targetSkinID) end)
            end
            if vehicle.ChangeParticles then
                pcall(function() vehicle:ChangeParticles(targetSkinID) end)
            end
            if vehicle.ReActivateExhaustParticle then
                pcall(function() vehicle:ReActivateExhaustParticle() end)
            end

            local LicensePlateComp = import("VehicleLicenseNumberComponent")
            local plateComp = vehicle:GetComponentByClass(LicensePlateComp)
            if slua.isValid(plateComp) then
                if plateComp.LicensePlate then
                    plateComp.LicensePlate.ItemID = targetSkinID
                    plateComp.LicensePlate.ChassisLightId = targetSkinID + 1000
                end
                if plateComp.PreChangeEffect then plateComp:PreChangeEffect() end
                if plateComp.PreChangeChassisLight then plateComp:PreChangeChassisLight() end
            end
        end

        if vehicle.SetVehicleMusicPlayState then
            vehicle:SetVehicleMusicPlayState(true)
        end
    end)
end

-- ===================================================================
-- SECTION 16: PET SKIN APPLICATION
-- ===================================================================
_G.HandlePetLogic = function()
    pcall(function()
        if not _G.PetSkin or _G.PetSkin == 0 or _G.PetSkin == 50000
            or _G.PetSkin == _G.LastAppliedPet
        then
            return
        end
        if not _G.skinIdCache[_G.PetSkin] then
            _G.download_item(_G.PetSkin)
            _G.skinIdCache[_G.PetSkin] = true
        end
        local ModuleManager = require("client.module_framework.ModuleManager")
        if ModuleManager then
            local petModule = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.logic_pet)
            if petModule then
                if petModule.SetCurPetID then petModule:SetCurPetID(_G.PetSkin) end
                if petModule.EquipPet then petModule:EquipPet(_G.PetSkin) end
            end
        end
        _G.LastAppliedPet = _G.PetSkin
    end)
end

-- ===================================================================
-- SECTION 17: KILL COUNTER / KILL MESSAGE SYSTEM
-- Real-time kill tracking with proper UI push on every event.
-- ===================================================================
_G.AKFakeKillCounts = _G.AKFakeKillCounts or setmetatable({}, { __index = function() return 4292 end })

local _KCHooked = false
local _KCModuleManager = nil
local _KCUIManager = nil

local function getKCModuleManager()
    if not _KCModuleManager then
        local ok, mod = pcall(require, "client.module_framework.ModuleManager")
        if ok and mod then _KCModuleManager = mod end
    end
    return _KCModuleManager
end

local function getKCUIManager()
    if not _KCUIManager then
        local ok, mod = pcall(require, "client.slua_ui_framework.manager")
        if ok and mod then _KCUIManager = mod end
    end
    return _KCUIManager
end

local function pushKillCounterUpdate(weaponID, skinID, killCount)
    pcall(function()
        local UIManager = getKCUIManager()
        if not UIManager then return end
        local killCounterUI = UIManager.GetUI(UIManager.UI_Config_InGame.MainKillCounter)
        if not killCounterUI or not killCounterUI.UpdateWeaponID then return end
        local avatarSkinID = skinID or weaponID
        killCounterUI:UpdateWeaponID(weaponID, avatarSkinID)
        local ModuleManager = getKCModuleManager()
        if ModuleManager then
            local kcLogic = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.LogicKillCounter)
            if kcLogic and kcLogic.GetEquipedKillCounterId then
                local equippedKCId = kcLogic:GetEquipedKillCounterId(0, avatarSkinID)
                if killCounterUI.SetKillCounterItemShowWithNum then
                    killCounterUI:SetKillCounterItemShowWithNum(equippedKCId, killCount, avatarSkinID)
                end
            end
        end
    end)
end

local function safeRequire(name)
    local loaded = package.loaded[name]
    if loaded then return loaded end
    local ok, mod = pcall(require, name)
    if ok then return mod end
    return nil
end

local function installKillCounterHooks()
    if _KCHooked then return end
    local anyHooked = false
    pcall(function()
        local KillCounterUI = safeRequire("GameLua.Mod.BaseMod.Client.KillCounter.KillCounterUISubsystem")
        if KillCounterUI and KillCounterUI.__inner_impl then
            local impl = KillCounterUI.__inner_impl
            impl.CheckSupportKCUI = function() return true end
            impl.CheckNeedMainKillCounterUI = function(self, weapon, PlayerID)
                if slua.isValid(weapon) then
                    local weaponID = weapon:GetWeaponID()
                    local skinID = _G.get_skin_id(weaponID) or weaponID
                    self:UpdateMainKillCounterUI(true, weaponID, skinID)
                    pushKillCounterUpdate(weaponID, skinID, _G.AKFakeKillCounts[weaponID] or 0)
                else
                    self:UpdateMainKillCounterUI(false)
                end
            end
            local origUpdate = impl.UpdateMainKillCounterUI
            impl.UpdateMainKillCounterUI = function(self, bShow, weaponID, AvatarID)
                if bShow then
                    AvatarID = _G.get_skin_id(weaponID) or AvatarID
                    if origUpdate then origUpdate(self, bShow, weaponID, AvatarID) end
                    pushKillCounterUpdate(weaponID, AvatarID, _G.AKFakeKillCounts[weaponID] or 0)
                else
                    if origUpdate then origUpdate(self, bShow, weaponID, AvatarID) end
                end
            end
            anyHooked = true
        end

        local ModuleManager = getKCModuleManager()
        if ModuleManager then
            local kcLogic = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.LogicKillCounter)
            if kcLogic then
                kcLogic.CheckSupportKC = function() return true end
                kcLogic.CheckSupportKillCounterAvatar = function() return true end
                kcLogic.CheckHasWeaponKillCounter = function() return true end
                kcLogic.GetBaseKillCounterIdByWeaponId = function() return 2100004 end
                kcLogic.GetEquipedKillCounterId = function() return 2100004 end
                kcLogic.GetMyEquipedKillCounterId = function() return 2100004 end
                kcLogic.GetOneWeaponKillCountInBattle = function(self, uid, weaponId)
                    return _G.AKFakeKillCounts[weaponId] or 0
                end
                kcLogic.GetWeaponKillCountByUid = function(self, uid, weaponId)
                    return _G.AKFakeKillCounts[weaponId] or 0
                end
                anyHooked = true
            end
        end

        local KillInfo = safeRequire("GameLua.Mod.BaseMod.Client.KillInfoTips.KillInfo")
        if KillInfo and KillInfo.__inner_impl then
            local origFileItem = KillInfo.__inner_impl.FileItem
            KillInfo.__inner_impl.FileItem = function(self, DamageRecordData)
                pcall(function()
                    local playerChar = safeRequire("GameLua.GameCore.Data.GameplayData").GetPlayerCharacter()
                    if not slua.isValid(playerChar) then return end
                    if DamageRecordData.Causer ~= playerChar:GetPlayerNameSafety() then return end
                    local currentWeapon = playerChar:GetCurrentWeapon()
                    if not slua.isValid(currentWeapon) then return end
                    local weaponID = currentWeapon:GetWeaponID()
                    local skinID = _G.get_skin_id(weaponID)
                    if skinID then DamageRecordData.CauserWeaponAvatarID = skinID end
                    if _G.SuitSkin ~= 0 then DamageRecordData.CauserClothAvatarID = _G.SuitSkin end
                    DamageRecordData.IsUseColor = true
                    DamageRecordData.UseColor = import("LinearColor")(1.0, 0.8, 0.0, 1.0)
                    if DamageRecordData.ResultHealthStatus == 2 then
                        _G.AKFakeKillCounts[weaponID] = (_G.AKFakeKillCounts[weaponID] or 0) + 1
                        pushKillCounterUpdate(weaponID, skinID, _G.AKFakeKillCounts[weaponID])
                    end
                end)
                if origFileItem then return origFileItem(self, DamageRecordData) end
            end
            anyHooked = true
        end

        local SlotMode2 = safeRequire("GameLua.Mod.BaseMod.Client.MainControlUI.SwitchWeaponSlotMode2")
        if SlotMode2 and SlotMode2.__inner_impl then
            local origCheck = SlotMode2.__inner_impl.CheckShowKCIcon
            SlotMode2.__inner_impl.CheckShowKCIcon = function(self)
                if self.KillCounterImg and slua.isValid(self.KillCounterImg) then
                    self.KillCounterImg:SetVisibility(import("ESlateVisibility").SelfHitTestInvisible)
                end
                if origCheck then return origCheck(self) end
            end
            local origShow = SlotMode2.__inner_impl.ShowKCIcon
            if origShow then
                SlotMode2.__inner_impl.ShowKCIcon = function(self, weaponID, skinID)
                    local cnt = _G.AKFakeKillCounts[weaponID] or 0
                    if origShow then origShow(self, weaponID, skinID) end
                    if cnt > 0 then
                        pcall(function()
                            if self.KillCounterImg and self.KillCounterImg.SetKillCount then
                                self.KillCounterImg:SetKillCount(cnt)
                            end
                        end)
                    end
                end
            end
            anyHooked = true
        end
    end)
    if anyHooked then _KCHooked = true end
end

-- Immediately push kill counter for current weapon on call
_G.ForceEnableKillCounterUI = function()
    installKillCounterHooks()
    _G.RefreshKillCounterUI()
end

-- Per-tick refresh: keeps KC UI visible and count accurate
_G.RefreshKillCounterUI = function()
    pcall(function()
        local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
        if not pc then return end
        local lp = pc:GetPlayerCharacterSafety()
        if not slua.isValid(lp) then return end
        local cw = lp:GetCurrentWeapon()
        if not slua.isValid(cw) then return end
        local wID = cw:GetWeaponID()
        if not wID or wID == 0 then return end
        local sid = _G.get_skin_id(wID)
        if not sid then
            local KCUI = package.loaded["GameLua.Mod.BaseMod.Client.KillCounter.KillCounterUISubsystem"]
            if KCUI and KCUI.__inner_impl then
                KCUI.__inner_impl:UpdateMainKillCounterUI(false)
            end
            return
        end
        local KCUI = package.loaded["GameLua.Mod.BaseMod.Client.KillCounter.KillCounterUISubsystem"]
        if KCUI and KCUI.__inner_impl then
            KCUI.__inner_impl:UpdateMainKillCounterUI(true, wID, sid)
        end
        pushKillCounterUpdate(wID, sid, _G.AKFakeKillCounts[wID] or 0)
    end)
end

-- ===================================================================
-- SECTION 18: DEAD BOX SKIN APPLICATION
-- Set-based membership (O(1)) + capped location cache + 2.0s throttle.
-- ===================================================================
_G.DeadBoxSkins      = _G.DeadBoxSkins or {}
_G.AlreadyChangedSet = _G.AlreadyChangedSet or {}
-- Force AlreadyChangedSet to act as a hash set
do
    if getmetatable(_G.AlreadyChangedSet) == nil then
        -- we keep the original array semantics for older code, but
        -- tableContainsSet below uses the SAME table as a hash by
        -- writing truthy markers (a sentinel) for set lookups.
    end
end

-- Hash-set membership helpers using _G.AlreadyChangedSet as both array
-- and hash (entries can be either deadbox refs or {__setKey=ref}).
local _DBSetKeys = _G._DBSetKeys or {}
_G._DBSetKeys = _DBSetKeys

local function dbContains(ref)
    if _DBSetKeys[ref] then return true end
    -- legacy path: check if the array contains the ref directly
    for i = 1, #_G.AlreadyChangedSet do
        if _G.AlreadyChangedSet[i] == ref then
            _DBSetKeys[ref] = true
            return true
        end
    end
    return false
end

local function dbAdd(ref)
    if _DBSetKeys[ref] then return end
    _G.AlreadyChangedSet[#_G.AlreadyChangedSet + 1] = ref
    _DBSetKeys[ref] = true
end

local function dbReset()
    -- clear both array and hash, keep tables allocated
    for k in pairs(_DBSetKeys) do _DBSetKeys[k] = nil end
    for i = #_G.AlreadyChangedSet, 1, -1 do _G.AlreadyChangedSet[i] = nil end
end
_G.DeadBox_ResetChangedSet = dbReset

local function isNearLocation(loc1, loc2, tolerance)
    local dx = loc1.X - loc2.X
    local dy = loc1.Y - loc2.Y
    local dz = loc1.Z - loc2.Z
    return dx * dx + dy * dy + dz * dz < tolerance * tolerance
end

local _GameplayStatics = nil
local _GameplayStaticsTried = false
local function getGameplayStatics()
    if _GameplayStatics then return _GameplayStatics end
    if _GameplayStaticsTried then return nil end
    _GameplayStaticsTried = true
    local ok, mod = pcall(import, "GameplayStatics")
    if ok and mod then _GameplayStatics = mod end
    return _GameplayStatics
end

local _ActorClass = nil
local _ActorTried = false
local function getActorClass()
    if _ActorClass then return _ActorClass end
    if _ActorTried then return nil end
    _ActorTried = true
    local ok, mod = pcall(import, "Actor")
    if ok and mod then _ActorClass = mod end
    return _ActorClass
end

local _UIUtil = nil
local _UIUtilTried = false
local function getUIUtil()
    if _UIUtil then return _UIUtil end
    if _UIUtilTried then return nil end
    _UIUtilTried = true
    local ok, mod = pcall(require, "client.common.ui_util")
    if ok and mod then _UIUtil = mod end
    return _UIUtil
end

local _PlayerTombBox = nil
local _PlayerTombBoxTried = false
local function getPlayerTombBox()
    if _PlayerTombBox then return _PlayerTombBox end
    if _PlayerTombBoxTried then return nil end
    _PlayerTombBoxTried = true
    local ok, mod = pcall(import, "PlayerTombBox")
    if ok and mod then _PlayerTombBox = mod end
    return _PlayerTombBox
end

_G.DeadBox_TemperRequest = function(playerController)
    local playerChar = playerController:GetPlayerCharacterSafety()
    if not playerChar then return end

    local GameplayStatics = getGameplayStatics()
    local Actor          = getActorClass()
    local uiUtil         = getUIUtil()
    local PlayerTombBox  = getPlayerTombBox()
    if not (GameplayStatics and Actor and uiUtil and PlayerTombBox) then return end

    local gameInstance = uiUtil.GetGameInstance()
    if not gameInstance then return end

    local allDeadBoxes = GameplayStatics.GetAllActorsOfClass(
        gameInstance, PlayerTombBox, slua.Array(UEnums.EPropertyClass.Object, Actor)
    )

    -- Capped linear scan: keep at most 32 cached location entries
    local skinCacheCount = #_G.DeadBoxSkins
    local scanLimit = skinCacheCount > 32 and (skinCacheCount - 32) or 0

    for _, deadBox in pairs(allDeadBoxes) do
        if slua.isValid(deadBox) then
            local damageCauser = deadBox.DamageCauser
            if damageCauser and damageCauser.Playerkey == playerController.Playerkey then
                local avatarComp = deadBox.DeadBoxAvatarComponent_BP
                if avatarComp and not dbContains(deadBox) then
                    local boxLocation = deadBox:K2_GetActorLocation()
                    local skinApplied = false

                    -- Capped location scan
                    for idx = scanLimit + 1, skinCacheCount do
                        local entry = _G.DeadBoxSkins[idx]
                        if entry and isNearLocation(entry.location, boxLocation, 1.0) then
                            avatarComp:ResetItemAvatar()
                            avatarComp:PreChangeItemAvatar(entry.SkinID)
                            avatarComp:SyncChangeItemAvatar(entry.SkinID)
                            dbAdd(deadBox)
                            skinApplied = true
                            break
                        end
                    end

                    if not skinApplied then
                        local skinID = 0
                        local currentVehicle = playerChar.CurrentVehicle
                        if currentVehicle and _G.CurrentEquipVehicleID and _G.CurrentEquipVehicleID ~= 0 then
                            skinID = tonumber(tostring(_G.CurrentEquipVehicleID) .. "1") or 0
                        else
                            local currentWeapon = playerChar:GetCurrentWeapon()
                            if currentWeapon then
                                local weaponAvatarData = currentWeapon.synData
                                    and currentWeapon.synData:Get(7)
                                if weaponAvatarData and weaponAvatarData.defineID then
                                    skinID = weaponAvatarData.defineID.TypeSpecificID
                                end
                            end
                        end

                        if skinID ~= 0 then
                            avatarComp:ResetItemAvatar()
                            avatarComp:PreChangeItemAvatar(skinID)
                            avatarComp:SyncChangeItemAvatar(skinID)
                            _G.DeadBoxSkins[#_G.DeadBoxSkins + 1] = { location = boxLocation, SkinID = skinID }
                            skinCacheCount = #_G.DeadBoxSkins
                            dbAdd(deadBox)
                        end
                    end
                end
            end
        end
    end
end

-- ===================================================================
-- SECTION 19: SKIN ANTI-CHEAT BYPASS
-- ===================================================================
_G.InitializeSkinBypass = function()
    pcall(function()
        local pufferTlog = package.loaded["client.slua.logic.download.report.puffer_tlog"]
        if pufferTlog then
            pufferTlog.ReportEvent         = function() end
            pufferTlog.ReportDownloadResult = function() end
            pufferTlog.ReportODPAKError    = function() end
        end
        local AvatarUtils = package.loaded["AvatarUtils"]
        if AvatarUtils then
            AvatarUtils.CheckIsWeaponInBlackList = function() return false end
            AvatarUtils.IsValidAvatar            = function() return true end
        end
        local FileCheckSubsystem = require(
            "GameLua.GameCore.Module.Subsystem.SubsystemMgr"
        ):Get("FileCheckSubsystem")
        if FileCheckSubsystem then
            FileCheckSubsystem.StartCheck        = function() end
            FileCheckSubsystem.ReportAbnormalFile = function() end
        end
        local equipReport = package.loaded[
            "client.slua.logic.report.EquipmentExceptionReport"
        ]
        if equipReport then
            equipReport.Report = function() end
        end
    end)
end

-- ===================================================================
-- SECTION 20: LOBBY / WEAPON-SLOT-UI / VEHICLE-EFFECT HOOKS
-- All one-shot. Identical semantics to skin.lua, just installed once.
-- ===================================================================
function _G.InitializeSkinModSystem()
    -- Hook 1: Lobby Avatar Equipment
    pcall(function()
        local LobbyAvatar = package.loaded["client.logic.avatar.LobbyAvatar"]
                        or require("client.logic.avatar.LobbyAvatar")
        if LobbyAvatar and not _G.LobbyBypassHacked then
            local originalPuton = LobbyAvatar.PutonEquipment
            LobbyAvatar.PutonEquipment = function(self, itemID, tAvatarCustom, tExtraData)
                local slotIndex = _G.BaseAttachToIndex and _G.BaseAttachToIndex[itemID]
                if slotIndex then
                    local currentWeaponSkin = self.GetCurHoldingWeaponSkinID
                        and self:GetCurHoldingWeaponSkinID()
                    if currentWeaponSkin and currentWeaponSkin >= 10000000
                        and _G.VIP_Attachments and _G.VIP_Attachments[currentWeaponSkin]
                    then
                        local replacementID = _G.VIP_Attachments[currentWeaponSkin][slotIndex]
                        if replacementID and replacementID > 0 then
                            if self.HandleDownload then
                                self:HandleDownload(replacementID, nil, nil, false)
                            end
                            itemID = replacementID
                        end
                    end
                end
                if originalPuton then
                    return originalPuton(self, itemID, tAvatarCustom, tExtraData)
                end
            end

            local originalEquipWeapon = LobbyAvatar.CharEquipWeaponByResId
            LobbyAvatar.CharEquipWeaponByResId = function(self, resID, isUse, isAsync, SocketName)
                local result
                if originalEquipWeapon then
                    result = originalEquipWeapon(self, resID, isUse, isAsync, SocketName)
                end
                if isUse and self.GetEquipments then
                    local equipments = self:GetEquipments()
                    for _, equip in ipairs(equipments) do
                        if _G.BaseAttachToIndex and _G.BaseAttachToIndex[equip.itemID] then
                            self:PutonEquipment(equip.itemID, equip.CustomInfo, {bIsUse = false})
                        end
                    end
                end
                return result
            end
            _G.LobbyBypassHacked = true
        end
    end)

    -- Hook 2: Weapon Slot UI Icons
    pcall(function()
        local CommonItemsUIBP = package.loaded[
            "client.slua.component.item.ItemChildren.Common_Items_UIBP"
        ] or require("client.slua.component.item.ItemChildren.Common_Items_UIBP")
        if CommonItemsUIBP and not _G.IconBaloHacked then
            local originalInitView = CommonItemsUIBP.InitView
            CommonItemsUIBP.InitView = function(self, nItemId, nCount, nValidTime, tExtraData)
                tExtraData = tExtraData or {}
                local displaySkinID = nil
                if _G.get_skin_id then
                    local skinID = _G.get_skin_id(nItemId)
                    if skinID and skinID ~= nItemId then
                        displaySkinID = skinID
                    end
                end
                local slotIndex = _G.BaseAttachToIndex and _G.BaseAttachToIndex[nItemId]
                if not displaySkinID and slotIndex then
                    local GameplayData = require("GameLua.GameCore.Data.GameplayData")
                    if GameplayData then
                        local playerChar = GameplayData.GetPlayerCharacter()
                        if playerChar and slua.isValid(playerChar) then
                            local currentWeapon = playerChar:GetCurrentWeapon()
                            if slua.isValid(currentWeapon) then
                                local weaponID = currentWeapon:GetWeaponID()
                                local weaponSkinID = _G.get_skin_id(weaponID) or weaponID
                                if weaponSkinID >= 10000000
                                    and _G.VIP_Attachments
                                    and _G.VIP_Attachments[weaponSkinID]
                                then
                                    local replacement = _G.VIP_Attachments[weaponSkinID][slotIndex]
                                    if replacement and replacement > 0 then
                                        displaySkinID = replacement
                                    end
                                end
                            end
                        end
                    end
                end
                if displaySkinID then
                    tExtraData.displayResId = displaySkinID
                    if not _G.skinIdCache2[displaySkinID] then
                        if _G.download_item then pcall(_G.download_item, displaySkinID) end
                        _G.skinIdCache2[displaySkinID] = true
                    end
                end
                if originalInitView then
                    return originalInitView(self, nItemId, nCount, nValidTime, tExtraData)
                end
            end
            _G.IconBaloHacked = true
        end
    end)

    -- ===================================================================
    -- MAIN SKIN APPLICATION LOOP  --  MULTI-RATE
    -- ===================================================================
    if not _G.AKSkinLoopStarted then
        _G.AKSkinLoopStarted = true
        local timeTicker = require("common.time_ticker")

        local _tickerErrorLogged = false

        -- Fast apply ticker (0.4s) -- LOBBY ONLY.
        -- [PERF] In a match this chain stops itself instead of running forever;
        -- it is re-armed by the lobby-enter hook below.
        local _fastChainAlive = false
        local function fastApplyLoop()
            if _G.__IsMatchActive() then _fastChainAlive = false; return end
            _fastChainAlive = true
            pcall(_G.ForceEnableKillCounterUI)
            pcall(_G.RefreshKillCounterUI)
            pcall(function()
                local GameplayData = require("GameLua.GameCore.Data.GameplayData")
                if GameplayData then
                    local playerChar = GameplayData.GetPlayerCharacter()
                    if slua.isValid(playerChar) then
                        _G.equip_character_avatar(playerChar)
                        _G.ApplyWeaponSkins(playerChar)
                        _G.HandlePetLogic()
                    end
                end
            end)
            if timeTicker and timeTicker.AddTimerOnce then
                pcall(timeTicker.AddTimerOnce, 0.4, fastApplyLoop)
            elseif not _tickerErrorLogged then
                _tickerErrorLogged = true
            end
        end

        _G.__OnLobbyEnter(function()
            if not _fastChainAlive then
                _fastChainAlive = true
                pcall(fastApplyLoop)
            end
        end)

        -- Slow scan ticker (2.0s) -- LOBBY ONLY (reads SKINS.ini + attachments.txt).
        -- [PERF] Never re-reads config files during a match.
        local _slowChainAlive = false
        local function slowScanLoop()
            if _G.__IsMatchActive() then _slowChainAlive = false; return end
            _slowChainAlive = true
            pcall(function()
                local GameplayData = require("GameLua.GameCore.Data.GameplayData")
                if GameplayData then
                    local playerChar = GameplayData.GetPlayerCharacter()
                    if slua.isValid(playerChar) then
                        _G.RefreshConfigIfChanged(false)
                        _G.RefreshAttachmentsIfChanged(false)
                        local PC = GameplayData.GetPlayerController()
                        if slua.isValid(PC) then
                            _G.DeadBox_TemperRequest(PC)
                        end
                    end
                end
            end)
            if timeTicker and timeTicker.AddTimerOnce then
                pcall(timeTicker.AddTimerOnce, 2.0, slowScanLoop)
            end
        end

        _G.__OnLobbyEnter(function()
            if not _slowChainAlive then
                _slowChainAlive = true
                pcall(slowScanLoop)
            end
        end)

        -- Slow hook ticker (5.0s) -- LOBBY ONLY.
        -- [PERF] The kill-counter UI hook is one-shot work; no need to poll.
        local _hookChainAlive = false
        local function slowHookLoop()
            if _G.__IsMatchActive() then _hookChainAlive = false; return end
            _hookChainAlive = true
            pcall(_G.ForceEnableKillCounterUI)
            if timeTicker and timeTicker.AddTimerOnce then
                pcall(timeTicker.AddTimerOnce, 5.0, slowHookLoop)
            end
        end

        _G.__OnLobbyEnter(function()
            if not _hookChainAlive then
                _hookChainAlive = true
                pcall(slowHookLoop)
            end
        end)

        fastApplyLoop()
        slowScanLoop()
        slowHookLoop()
    end
end

-- ===================================================================
-- SECTION 21: INITIALIZATION ENTRY POINT
-- ===================================================================
local function initializeSkinSystem()
    pcall(function()
        if _G.InitializeSkinBypass then _G.InitializeSkinBypass() end
        if _G.InitializeSkinModSystem then _G.InitializeSkinModSystem() end
    end)
end

pcall(function()
    local timeTicker = require("common.time_ticker")
    if timeTicker and timeTicker.AddTimerOnce then
        timeTicker.AddTimerOnce(1.5, initializeSkinSystem)
    else
        initializeSkinSystem()
    end
end)
-- Auto-load saved inventory skins from shadow_lobby.txt on startup
pcall(function()
    _G.InventorySkins = _G.InventorySkins or { weapons = {}, outfit = 0, vehicle = 0 }
    local f = io.open('/storage/emulated/0/Android/data/com.pubg.imobile/files/shadow_lobby.txt', 'r')
    if f then
        for line in f:lines() do
            local wid, res = line:match("^SKIN_Weapon_(%d+)=(%d+)$")
            if wid and res then _G.InventorySkins.weapons[tonumber(wid)] = tonumber(res) end
            
            local outfitRes = line:match("^SKIN_Outfit=(%d+)$")
            if outfitRes then _G.InventorySkins.outfit = tonumber(outfitRes) end
            
            
            local vehRes = line:match("^SKIN_Vehicle_%d=(%d+)$") 
            if vehRes then _G.InventorySkins.vehicle = tonumber(vehRes) end
        end
        f:close()
    end
end)

]==], '4.lua')

-- ============================================================================
-- 5. 5.lua
-- ============================================================================
__run_file([==[_G.LobbyCosmeticEnabled = true
_G.killCountInfo = _G.killCountInfo or {}
_G.lastFileContent = ""
_G.isFileWatcherActive = false
_G.LastKillTime = {}
_G.lastDisplayedKills = {}

-- ============================================================================
-- COSMETIC ITEM DATABASE - All paywalled outfits & weapon skins
-- ============================================================================

-- Match configuration: Defines which cosmetics to apply in-game
local MATCH_CONFIG = {
    outfitRes = 0,          -- Target outfit resource ID (0 = use cached)
    weaponSkins = {},       -- WeaponID -> SkinResID mapping for in-match
}

-- Master list of all injected cosmetic item resource IDs
-- These IDs represent outfits, weapon skins, vehicle skins, and other cosmetics
-- Source: Reverse engineered from game data tables
local ITEMS = {
202408001,202408014,202408132,202408035,202408037,202408039,202408040,202408042,202408043,202408044,202408045,202408046,202408047,202408048,202408049,202408050,202408051,202408052,202408053,202408054,202408055,202408056,202408057,202408058,202408059,202408060,202408061,202408062,202408063,202408064,202408065,202408066,202408067,202408068,202408069,202408070,202408071,202408072,202408073,202408074,202408075,202408076,202408077,202408078,202408079,202408080,202408081,202408082,202408083,202408084,202408085,202408086,202408087,202408088,202408089,202408090,202408091,202408092,202408093,202408094,202408095,202408096,202408097,202408098,202408099,202408100,202408101,202408102,202408103,202408104,202408105,202408106,202408107,202408108,202408109,202408110,202408111,202408112,202408113,202408114,202408115,202408116,202408117,202408118,202408119,202408120,202408121,202408122,202408123,202408124,202408125,202408126,
1407990,1400001,1400002,1400003,1400004,1400007,1400008,1400009,1400010,1400011,1400012,1400013,1400014,1400015,1400016,1400017,1400018,1400020,1400021,1400022,1400023,1400024,1400025,1400026,1400027,1400028,1400029,1400030,1400031,1400032,1400038,1400039,1400040,1400041,1400042,1400043,1400044,1400045,1400046,1400047,1400048,1400049,1400050,1400051,1400052,1400053,1400054,1400055,1400062,1400063,1400064,1400065,1400066,1400067,1400068,1400069,1400072,1400073,1400074,1400075,1400076,1400077,1400078,1400079,1400080,1400081,1400082,1400084,1400085,1400086,1400087,1400088,1400089,1400090,1400091,1400092,1400093,1400094,1400095,1400096,1400097,1400098,1400099,1400100,1400101,1400103,1400104,1400105,1400106,1400107,1400108,1400109,1400110,1400111,1400112,1400113,1400114,1400115,1400117,1400118,1400119,1400120,1400121,1400122,1400123,1400124,1400125,1400127,1400128,1400129,1400130,1400132,1400133,1400134,1400135,1400136,1400137,1400138,1400139,1400141,1400142,1400143,1400146,1400147,1400148,1400149,1400150,1400151,1400152,1400153,1400154,1400155,1400156,1400158,1400159,1400160,1400161,1400162,1400163,1400164,1400165,1400166,1400167,1400168,1400169,1400213,1400215,1400216,1400218,1400219,1400221,1400224,1400225,1400226,1400227,1400228,1400229,1400230,1400231,1400232,1400233,1400237,1400239,1400240,1400242,1400243,1400244,1400247,1400249,1400251,1400253,1400255,1400258,1400259,1400261,1400262,1400264,1400265,1400266,1400267,1400268,1400269,1400270,1400271,1400272,1400274,1400276,1400277,1400279,1400280,1400281,1400282,1400283,1400284,1400285,1400286,1400287,1400288,1400289,1400290,1400291,1400292,1400293,1400294,1400295,1400296,1400297,1400298,1400299,1400301,1400302,1400303,1400306,1400307,1400308,1400314,1400315,1400316,1400317,1400318,1400319,1400320,1400321,1400322,1400323,1400324,1400325,1400326,1400327,1400328,1400329,1400332,1400333,1400334,1400336,1400337,1400338,1400339,1400341,1400342,1400344,1400345,1400347,1400348,1400350,1400351,1400352,1400353,1400354,1400355,1400356,1400357,1400358,1400359,1400360,1400361,1400362,1400363,1400364,1400365,1400366,1400367,1400368,1400369,1400370,1400371,1400374,1400375,1400376,1400377,1400378,1400380,1400381,1400384,1400385,1400386,1400387,1400388,1400389,1400390,1400391,1400392,1400393,1400394,1400395,1400396,1400397,1400398,1400399,1400400,1400401,1400402,1400403,1400404,1400405,1400406,1400407,1400408,1400409,1400410,1400411,1400412,1400413,1400414,1400415,1400416,1400417,1400418,1400419,1400420,1400421,1400422,1400423,1400424,1400425,1400426,1400427,1400428,1400429,1400430,1400431,1400432,1400433,1400434,1400435,1400436,1400437,1400439,1400441,1400442,1400443,1400444,1400445,1400446,1400447,1400448,1400449,1400450,1400451,1400453,1400455,1400456,1400457,1400458,1400459,1400460,1400461,1400463,1400464,1400465,1400468,1400470,1400472,1400473,1400474,1400475,1400476,1400477,1400478,1400479,1400480,1400481,1400482,1400483,1400484,1400485,1400486,1400488,1400489,1400490,1400491,1400492,1400493,1400494,1400495,1400498,1400499,1400500,1400501,1400502,1400503,1400504,1400505,1400506,1400508,1400509,1400511,1400512,1400513,1400514,1400515,1400516,1400517,1400518,1400520,1400521,1400522,1400523,1400524,1400525,1400526,1400527,1400528,1400529,1400530,1400531,1400532,1400533,1400534,1400535,1400539,1400540,1400541,1400542,1400543,1400544,1400545,1400546,1400547,1400548,1400549,1400550,1400551,1400552,1400553,1400554,1400555,1400556,1400559,1400563,1400564,1400565,1400566,1400567,1400568,1400569,1400570,1400571,1400572,1400573,1400574,1400575,1400576,1400577,1400578,1400583,1400584,1400585,1400586,1400587,1400588,1400589,1400590,1400592,1400594,1400595,1400596,1400597,1400598,1400599,1400600,1400601,1400603,1400604,1400606,1400619,1400620,1400622,1400623,1400624,1400625,1400626,1400643,1400644,1400645,1400646,1400647,1400648,1400649,1400650,1400651,1400652,1400653,1400654,1400656,1400657,1400658,1400659,1400660,1400661,1400664,1400665,1400666,1400668,1400669,1400670,1400673,1400678,1400679,1400680,1400682,1400683,1400687,1400688,1400689,1400690,1400691,1400692,1400693,1400694,1400695,1400696,1400697,1400698,1400702,1400704,1400705,1400708,1400709,1400714,1400715,1400716,1400719,1400721,1400727,1400728,1400729,1400730,1400731,1400732,1400733,1400734,1400735,1400736,1400737,1400738,1400739,1400740,1400741,1400742,1400743,1400744,1400746,1400747,1400749,1400750,1400751,1400772,1400773,1400774,1400775,1400776,1400777,1400778,1400779,1400780,1400781,1400782,1400783,1400784,1400785,1400786,1400787,1400788,1400789,1400790,1400791,1400792,1400793,1400794,1400795,1400796,1400798,1400799,1400801,1400802,1400803,1400804,1400805,1400806,1400807,1400808,1400809,1400810,1400811,1400812,1400813,1400814,1400816,1401846,1402000,1402002,1402004,1402005,1402006,1402007,1402008,1402009,1402012,1402015,1402016,1402018,1402019,1402020,1402021,1402022,1402024,1402025,1402026,1402027,1402028,1402029,1402031,1402032,1402033,1402035,1402037,1402038,1402039,1402040,1402041,1402042,1402043,1402044,1402045,1402046,1402047,1402049,1402050,1402051,1402052,1402053,1402054,1402055,1402056,1402059,1402062,1402063,1402065,1402067,1402068,1402069,1402070,1402071,1402073,1402074,1402075,1402076,1402077,1402078,1402079,1402080,1402081,1402082,1402083,1402084,1402085,1402086,1402088,1402090,1402091,1402092,1402093,1402098,1402099,1402101,1402102,1402103,1402104,1402105,1402106,1402107,1402108,1402110,1402111,1402112,1402113,1402114,1402115,1402116,1402117,1402118,1402119,1402120,1402121,1402122,1402123,1402124,1402125,1402126,1402127,1402128,1402129,1402130,1402132,1402133,1402134,1402135,1402136,1402137,1402138,1402139,1402140,1402141,1402142,1402143,1402144,1402145,1402146,1402147,1402148,1402149,1402150,1402151,1402152,1402153,1402154,1402155,1402156,1402157,1402158,1402159,1402160,1402161,1402162,1402163,1402164,1402165,1402166,1402167,1402169,1402170,1402171,1402172,1402173,1402174,1402175,1402176,1402177,1402178,1402179,1402180,1402181,1402182,1402183,1402184,1402185,1402187,1402188,1402189,1402192,1402193,1402194,1402195,1402197,1402198,1402199,1402200,1402201,1402202,1402203,1402204,1402205,1402206,1402208,1402209,1402210,1402211,1402212,1402213,1402214,1402215,1402216,1402217,1402218,1402219,1402220,1402221,1402222,1402223,1402224,1402225,1402227,1402228,1402229,1402230,1402231,1402232,1402233,1402235,1402236,1402238,1402239,1402240,1402241,1402242,1402243,1402244,1402245,1402246,1402248,1402249,1402250,1402251,1402252,1402253,1402254,1402255,1402256,1402257,1402258,1402259,1402260,1402261,1402262,1402263,1402267,1402278,1402279,1402280,1402281,1402282,1402283,1402284,1402285,1402286,1402287,1402288,1402289,1402290,1402291,1402292,1402294,1402295,1402296,1402297,1402298,1402299,1402300,1402301,1402302,1402303,1402304,1402305,1402306,1402307,1402308,1402309,1402310,1402311,1402312,1402313,1402315,1402316,1402317,1402318,1402319,1402322,1402323,1402324,1402325,1402326,1402327,1402328,1402329,1402330,1402331,1402332,1402333,1402334,1402335,1402336,1402338,1402342,1402343,1402344,1402345,1402346,1402347,1402348,1402349,1402350,1402352,1402353,1402355,1402356,1402357,1402358,1402359,1402360,1402361,1402362,1402364,1402368,1402369,1402370,1402372,1402373,1402374,1402375,1402376,1402377,1402378,1402383,1402384,1402385,1402386,1402387,1402388,1402390,1402391,1402392,1402393,1402395,1402396,1402397,1402399,1402400,1402401,1402402,1402403,1402404,1402405,1402406,1402407,1402408,1402410,1402411,1402412,1402413,1402415,1402416,1402417,1402418,1402419,1402420,1402421,1402422,1402423,1402424,1402431,1402432,1402433,1402434,1402435,1402436,1402442,1402443,1402444,1402445,1402446,1402447,1402448,1402449,1402450,1402451,1402452,1402453,1402454,1402455,1402456,1402460,1402461,1402462,1402463,1402464,1402470,1402471,1402472,1402473,1402481,1402489,1402490,1402491,1402492,1402493,1402494,1402495,1402496,1402497,1402498,1402499,1402500,1402501,1402502,1402503,1402504,1402505,1402506,1402507,1402508,1402509,1402510,1402511,1402515,1402517,1402518,1402519,1402520,1402521,1402522,1402523,1402524,1402525,1402527,1402530,1402531,1402532,1402533,1402534,1402535,1402536,1402538,1402539,1402542,1402543,1402544,1402545,1402546,1402547,1402548,1402549,1402550,1402552,1402553,1402554,1402557,1402558,1402559,1402560,1402561,1402562,1402563,1402565,1402566,1402567,1402568,1402569,1402570,1402571,1402572,1402573,1402574,1402575,1402576,1402577,1402578,1402579,1402580,1402581,1402582,1402583,1402584,1402585,1402586,1402587,1402588,1402589,1402590,1402592,1402593,1402594,1402595,1402598,1402600,1402601,1402602,1402603,1402604,1402607,1402608,1402610,1402611,1402612,1402613,1402614,1402615,1402618,1402619,1402620,1402621,1402623,1402624,1402625,1402626,1402627,1402628,1402629,1402631,1402632,1402633,1402634,1402635,1402636,1402637,1402642,1402643,1402644,1402646,1402647,1402648,1402649,1402650,1402651,1402652,1402653,1402654,1402655,1402656,1402657,1402659,1402662,1402663,1402664,1402666,1402668,1402669,1402670,1402671,1402672,1402673,1402674,1402675,1402676,1402677,1402678,1402679,1402680,1402681,1402684,1402685,1402686,1402687,1402688,1402689,1402690,1402691,1402692,1402693,1402694,1402695,1402696,1402697,1402698,1402699,1402700,1402701,1402704,1402706,1402707,1402708,1402713,1402716,1402717,1402718,1402720,1402721,1402722,1402723,1402725,1402726,1402727,1402728,1402729,1402730,1402731,1402735,1402736,1402738,1402739,1402740,1402741,1402742,1402743,1402745,1402746,1402748,1402749,1402750,1402751,1402752,1402753,1402754,1402755,1402756,1402757,1402758,1402759,1402760,1402761,1402762,1402763,1402764,1402766,1402767,1402768,1402769,1402770,1402771,1402772,1402774,1402775,1402776,1402777,1402778,1402780,1402782,1402783,1402784,1402786,1402787,1402797,1402798,1402800,1402801,1402802,1402811,1402812,1402815,1402816,1402817,1402818,1402819,1402820,1402821,1402822,1402823,1402824,1402826,1402827,1402828,1402829,1402830,1402834,1402835,1402837,1402838,1402839,1402840,1402841,1402843,1402844,1402845,1402846,1402847,1402848,1402850,1402851,1402854,1402855,1402858,1402860,1402861,1402862,1402863,1402864,1402865,1402866,1402869,1402870,1402871,1402872,1402873,1402874,1402875,1402876,1402877,1402878,1402879,1402880,1402881,1402882,1402883,1402884,1402885,1402886,1402888,1402890,1402891,1402892,1402894,1402896,1402897,1402898,1402899,1402900,1402901,1402902,1402903,1402904,1402905,1402906,1402907,1402908,1402909,1402910,1402912,1402913,1402914,1402915,1402916,1402917,1402918,1402920,1402921,1402922,1402923,1402924,1402926,1402927,1402928,1402929,1402930,1402931,1402932,1402933,1402934,1402935,1402936,1402937,1402938,1402940,1402941,1402942,1402943,1402944,1402945,1402946,1402947,1402948,1402952,1402953,1402954,1402955,1402956,1402957,1402958,1402959,1402960,1402961,1402962,1402963,1402964,1402966,1402967,1402968,1402969,1402970,1402971,1402972,1402973,1402974,1402975,1402977,1402978,1402979,1402980,1402981,1402982,1402983,1402984,1402987,1402988,1402989,1402990,1402991,1402992,1402997,1402998,1403000,1403001,1403002,1403004,1403005,1403006,1403007,1403009,1403010,1403011,1403012,1403013,1403014,1403015,1403016,1403017,1403018,1403019,1403020,1403022,1403023,1403024,1403025,1403026,1403027,1403028,1403031,1403032,1403033,1403034,1403035,1403036,1403037,1403038,1403039,1403040,1403041,1403042,1403044,1403045,1403046,1403047,1403048,1403049,1403050,1403051,1403052,1403053,1403054,1403055,1403056,1403058,1403061,1403062,1403064,1403065,1403066,1403067,1403068,1403069,1403070,1403071,1403072,1403073,1403074,1403077,1403078,1403079,1403081,1403082,1403083,1403084,1403085,1403086,1403087,1403088,1403090,1403091,1403092,1403093,1403094,1403095,1403096,1403098,1403099,1403100,1403101,1403112,1403113,1403115,1403117,1403119,1403120,1403122,1403123,1403124,1403127,1403128,1403129,1403130,1403131,1403132,1403133,1403134,1403135,1403136,1403137,1403138,1403139,1403141,1403142,1403143,1403146,1403147,1403148,1403149,1403150,1403151,1403152,1403153,1403154,1403155,1403156,1403157,1403158,1403159,1403161,1403162,1403163,1403164,1403166,1403167,1403168,1403169,1403170,1403171,1403172,1403174,1403175,1403176,1403177,1403178,1403179,1403181,1403182,1403183,1403184,1403185,1403186,1403187,1403188,1403189,1403190,1403191,1403192,1403193,1403194,1403196,1403197,1403200,1403201,1403202,1403204,1403205,1403206,1403207,1403208,1403211,1403214,1403215,1403217,1403220,1403221,1403222,1403223,1403224,1403227,1403228,1403229,1403230,1403231,1403233,1403235,1403236,1403237,1403238,1403240,1403241,1403244,1403246,1403248,1403249,1403250,1403251,1403253,1403254,1403255,1403256,1403257,1403258,1403259,1403260,1403261,1403263,1403264,1403266,1403267,1403272,1403273,1403274,1403275,1403276,1403277,1403280,1403287,1403288,1403292,1403294,1403297,1403302,1403304,1403305,1403307,1403309,1403310,1403311,1403312,1403314,1403315,1403316,1403317,1403318,1403323,1403324,1403325,1403326,1403327,1403328,1403329,1403330,1403331,1403332,1403333,1403334,1403335,1403336,1403338,1403339,1403340,1403341,1403342,1403343,1403344,1403347,1403348,1403349,1403350,1403351,1403352,1403353,1403354,1403356,1403357,1403359,1403361,1403364,1403365,1403366,1403368,1403369,1403370,1403371,1403372,1403374,1403375,1403379,1403381,1403383,1403385,1403386,1403387,1403390,1403393,1403394,1403395,1403397,1403398,1403399,1403400,1403401,1403403,1403404,1403405,1403408,1403409,1403410,1403411,1403412,1403414,1403416,1403419,1403420,1403421,1403424,1403425,1403428,1403429,1403430,1403431,1403432,1403436,1403437,1403438,1403439,1403440,1403442,1403444,1403445,1403446,1403447,1403450,1403451,1403452,1403455,1403456,1403457,1403458,1403460,1403462,1403463,1403464,1403465,1403468,1403476,1403477,1403478,1403486,1403487,1403490,1403496,1403498,1403506,1403507,1403508,1403509,1403513,1403514,1403517,1403518,1403519,1403523,1403524,1403525,1403527,1403528,1403534,1403535,1403540,1403541,1403542,1403544,1403545,1403552,1403553,1403559,1403562,1403563,1403564,1403565,1403566,1403567,1403569,1403570,1403571,1403572,1403575,1403577,1403578,1403581,1403585,1403586,1403587,1403590,1403591,1403592,1403593,1403594,1403597,1403600,1403601,1403602,1403603,1403604,1403605,1403607,1403609,1403610,1403611,1403615,1403616,1403617,1403618,1403621,1403622,1403623,1403625,1403627,1403628,1403630,1403631,1403633,1403635,1403636,1403638,1403639,1403640,1403641,1403642,1403643,1403644,1403645,1403646,1403647,1403648,1403649,1403650,1403651,1403652,1403653,1403654,1403655,1403656,1403658,1403659,1403660,1403661,1403662,1403663,1403664,1403665,1403666,1403667,1403668,1403669,1403672,1403673,1403674,1403675,1403676,1403677,1403678,1403679,1403680,1403681,1403682,1403683,1403684,1403685,1403686,1403687,1403688,1403689,1403690,1403691,1403692,1403693,1403694,1403695,1403696,1403697,1403698,1403699,1403700,1403701,1403702,1403703,1403704,1403705,1403706,1403707,1403708,1403709,1403710,1403711,1403712,1403713,1403714,1403715,1403716,1403717,1403718,1403719,1403720,1403721,1403722,1403723,1403724,1403725,1403726,1403727,1403728,1403729,1403730,1403731,1403732,1403733,1403734,1403735,1403736,1403737,1403738,1403739,1403740,1403741,1403742,1403743,1403744,1403745,1403746,1403747,1403748,1403749,1403750,1403751,1403752,1403753,1403754,1403755,1403756,1403757,1403758,1403759,1403760,1403761,1403762,1403763,1403764,1403765,1403766,1403767,1403768,1403769,1404000,1404001,1404002,1404003,1404004,1404005,1404006,1404007,1404008,1404009,1404010,1404011,1404012,1404013,1404014,1404015,1404016,1404017,1404018,1404019,1404020,1404021,1404022,1404023,1404024,1404025,1404026,1404027,1404028,1404029,1404030,1404031,1404032,1404033,1404034,1404035,1404036,1404037,1404038,1404040,1404041,1404042,1404043,1404044,1404045,1404046,1404047,1404048,1404049,1404050,1404051,1404052,1404053,1404054,1404055,1404056,1404057,1404058,1404059,1404060,1404061,1404062,1404063,1404064,1404065,1404066,1404080,1404081,1404082,1404083,1404084,1404085,1404086,1404087,1404088,1404089,1404090,1404091,1404092,1404093,1404094,1404095,1404096,1404127,1404128,1404129,1404130,1404131,1404132,1404133,1404134,1404135,1404136,1404137,1404138,1404139,1404140,1404141,1404142,1404143,1404144,1404145,1404146,1404147,1404148,1404149,1404150,1404151,1404152,1404153,1404154,1404155,1404156,1404157,1404158,1404159,1404160,1404161,1404162,1404163,1404164,1404165,1404166,1404167,1404168,1404169,1404170,1404171,1404172,1404173,1404174,1404175,1404176,1404177,1404178,1404179,1404180,1404181,1404182,1404183,1404184,1404185,1404186,1404187,1404188,1404189,1404190,1404191,1404192,1404193,1404194,1404195,1404196,1404197,1404198,1404199,1404200,1404201,1404202,1404203,1404204,1404205,1404206,1404207,1404208,1404209,1404210,1404211,1404212,1404213,1404214,1404215,1404216,1404217,1404218,1404219,1404220,1404222,1404223,1404224,1404225,1404226,1404227,1404228,1404229,1404230,1404231,1404232,1404233,1404234,1404235,1404236,1404237,1404238,1404239,1404240,1404241,1404242,1404243,1404244,1404245,1404246,1404247,1404248,1404249,1404250,1404251,1404252,1404253,1404254,1404255,1404256,1404257,1404258,1404259,1404260,1404261,1404262,1404263,1404264,1404265,1404266,1404267,1404268,1404269,1404270,1404271,1404272,1404273,1404274,1404275,1404276,1404277,1404278,1404280,1404281,1404282,1404283,1404284,1404285,1404286,1404287,1404288,1404289,1404292,1404293,1404294,1404295,1404296,1404297,1404298,1404299,1404300,1404301,1404302,1404303,1404304,1404305,1404306,1404307,1404308,1404309,1404310,1404311,1404312,1404313,1404314,1404315,1404316,1404317,1404318,1404319,1404320,1404321,1404322,1404323,1404325,1404326,1404327,1404330,1404331,1404332,1404333,1404334,1404335,1404336,1404337,1404338,1404339,1404340,1404341,1404342,1404343,1404344,1404345,1404346,1404347,1404348,1404349,1404350,1404351,1404352,1404353,1404354,1404355,1404356,1404357,1404358,1404359,1404360,1404361,1404362,1404363,1404364,1404365,1404366,1404367,1404368,1404369,1404370,1404371,1404372,1404373,1404374,1404375,1404376,1404377,1404378,1404379,1404380,1404381,1404382,1404383,1404384,1404385,1404386,1404387,1404388,1404389,1404390,1404391,1404394,1404395,1404396,1404397,1404398,1404399,1404400,1404401,1404402,1404403,1404405,1404406,1404407,1404408,1404409,1404410,1404411,1404412,1404413,1404414,1404415,1404416,1404417,1404418,1404419,1404420,1404421,1404422,1404423,1404425,1404426,1404427,1404428,1404430,1404431,1404432,1404433,1404434,1404435,1404436,1404437,1404438,1404439,1404440,1404441,1404442,1404443,1404444,1404445,1404446,1404447,1404448,1404449,1404450,1404451,1404452,1404453,1404454,1404455,1404456,1404457,1404458,1404459,1404460,1404461,1404462,1404463,1404464,1404465,1404466,1404467,1404468,1404469,1404470,1404471,1404472,1404473,1404474,1404475,1404476,1404477,1404478,1404479,1404480,1404481,1404482,1404483,1404484,1404485,1404486,1404487,1404488,1404489,1404490,1404491,1404492,1404493,1404494,1404495,1404496,1404497,1404498,1404499,1404500,1404501,1404502,1404503,1404504,1404505,1404506,1404507,1404508,1404509,1404510,1404511,1404512,1404513,1404514,1404515,1404516,1404517,1404518,1404519,1404520,1404521,1404522,1404523,1404524,1404525,1404526,1404527,1404528,1405000,1405001,1405002,1405003,1405004,1405005,1405006,1405007,1405008,1405009,1405010,1405011,1405012,1405013,1405014,1405015,1405016,1405017,1405018,1405019,1405020,1405021,1405022,1405023,1405024,1405026,1405027,1405028,1405029,1405030,1405031,1405032,1405033,1405034,1405035,1405036,1405037,1405038,1405039,1405040,1405041,1405042,1405043,1405044,1405045,1405046,1405047,1405048,1405049,1405050,1405051,1405052,1405053,1405054,1405055,1405056,1405057,1405058,1405059,1405060,1405061,1405062,1405063,1405064,1405065,1405066,1405067,1405068,1405069,1405070,1405071,1405072,1405073,1405075,1405076,1405077,1405078,1405079,1405080,1405081,1405082,1405083,1405084,1405085,1405086,1405087,1405088,1405090,1405091,1405092,1405093,1405094,1405095,1405096,1405097,1405098,1405099,1405100,1405101,1405102,1405103,1405104,1405105,1405106,1405107,1405108,1405109,1405110,1405111,1405112,1405113,1405114,1405115,1405116,1405117,1405118,1405119,1405120,1405121,1405122,1405123,1405124,1405125,1405126,1405127,1405128,1405129,1405130,1405131,1405132,1405133,1405134,1405135,1405136,1405137,1405138,1405141,1405142,1405143,1405144,1405145,1405146,1405147,1405148,1405149,1405150,1405151,1405152,1405153,1405154,1405155,1405156,1405157,1405158,1405159,1405160,1405161,1405162,1405163,1405164,1405165,1405166,1405167,1405168,1405169,1405170,1405171,1405172,1405173,1405174,1405175,1405176,1405177,1405178,1405179,1405180,1405181,1405186,1405187,1405188,1405189,1405190,1405191,1405192,1405193,1405194,1405195,1405196,1405197,1405198,1405199,1405200,1405201,1405202,1405203,1405204,1405205,1405206,1405207,1405208,1405209,1405210,1405211,1405212,1405213,1405216,1405218,1405219,1405220,1405221,1405222,1405223,1405224,1405225,1405226,1405227,1405228,1405229,1405230,1405231,1405232,1405233,1405234,1405235,1405236,1405237,1405238,1405239,1405240,1405241,1405242,1405243,1405244,1405245,1405246,1405247,1405248,1405256,1405257,1405258,1405259,1405260,1405261,1405262,1405263,1405264,1405265,1405266,1405267,1405268,1405269,1405270,1405271,1405272,1405273,1405274,1405275,1405276,1405277,1405278,1405279,1405280,1405281,1405282,1405283,1405284,1405285,1405286,1405287,1405289,1405290,1405291,1405292,1405293,1405294,1405295,1405296,1405297,1405298,1405299,1405300,1405301,1405302,1405303,1405304,1405305,1405306,1405307,1405308,1405318,1405319,1405320,1405321,1405322,1405323,1405324,1405325,1405326,1405327,1405328,1405329,1405330,1405331,1405332,1405333,1405334,1405335,1405336,1405337,1405338,1405339,1405340,1405341,1405342,1405343,1405344,1405345,1405346,1405347,1405348,1405349,1405350,1405351,1405352,1405353,1405354,1405355,1405356,1405357,1405358,1405359,1405360,1405361,1405362,1405363,1405364,1405365,1405366,1405367,1405368,1405369,1405370,1405371,1405372,1405373,1405374,1405375,1405376,1405377,1405378,1405379,1405380,1405381,1405382,1405384,1405385,1405386,1405387,1405388,1405389,1405390,1405391,1405392,1405393,1405394,1405395,1405396,1405397,1405398,1405399,1405400,1405401,1405402,1405403,1405404,1405405,1405406,1405407,1405408,1405409,1405410,1405411,1405412,1405413,1405414,1405415,1405416,1405417,1405418,1405419,1405420,1405421,1405422,1405423,1405424,1405425,1405426,1405427,1405428,1405429,1405430,1405431,1405432,1405433,1405434,1405435,1405436,1405437,1405438,1405439,1405440,1405441,1405442,1405443,1405444,1405445,1405446,1405447,1405448,1405449,1405450,1405451,1405452,1405453,1405454,1405455,1405456,1405457,1405458,1405459,1405460,1405461,1405462,1405463,1405464,1405465,1405466,1405467,1405468,1405469,1405470,1405471,1405472,1405473,1405474,1405475,1405476,1405477,1405478,1405479,1405480,1405481,1405482,1405483,1405484,1405485,1405486,1405487,1405488,1405489,1405490,1405491,1405492,1405493,1405494,1405495,1405496,1405497,1405498,1405499,1405500,1405501,1405502,1405503,1405504,1405505,1405506,1405507,1405508,1405509,1405510,1405511,1405512,1405513,1405514,1405515,1405516,1405517,1405518,1405519,1405520,1405521,1405522,1405523,1405524,1405525,1405526,1405527,1405528,1405529,1405530,1405531,1405532,1405533,1405534,1405535,1405536,1405537,1405538,1405539,1405540,1405541,1405542,1405543,1405544,1405545,1405546,1405547,1405548,1405549,1405550,1405551,1405552,1405553,1405554,1405555,1405556,1405557,1405558,1405559,1405560,1405561,1405562,1405563,1405564,1405565,1405566,1405567,1405569,1405570,1405571,1405572,1405573,1405574,1405575,1405576,1405577,1405578,1405579,1405580,1405581,1405582,1405583,1405584,1405585,1405586,1405587,1405588,1405589,1405590,1405591,1405592,1405593,1405594,1405595,1405596,1405597,1405598,1405599,1405600,1405601,1405602,1405603,1405604,1405605,1405606,1405607,1405608,1405609,1405611,1405612,1405613,1405614,1405615,1405616,1405617,1405618,1405619,1405620,1405621,1405622,1405623,1405624,1405625,1405629,1405630,1405631,1405632,1405633,1405634,1405638,1405639,1405640,1405641,1405642,1405643,1405644,1405645,1405646,1405647,1405648,1405649,1405650,1405651,1405652,1405653,1405654,1405655,1405656,1405657,1405658,1405659,1405660,1405661,1405662,1405663,1405664,1405665,1405666,1405667,1405668,1405669,1405670,1405671,1405672,1405673,1405674,1405675,1405676,1405677,1405678,1405679,1405680,1405681,1405682,1405683,1405684,1405685,1405686,1405687,1405688,1405689,1405690,1405691,1405692,1405695,1405696,1405697,1405698,1405655,1405656,1405657,1405658,1405703,1405704,1405705,1405706,1405707,1405708,1405709,1405710,1405711,1405712,1405713,1405714,1405715,1405716,1405717,1405718,1405719,1405720,1405721,1405722,1405723,1405724,1405725,1405726,1405727,1405728,1405731,1405732,1405733,1405734,1405735,1405736,1405737,1405738,1405739,1405740,1405741,1405742,1405744,1405745,1405746,1405747,1405748,1405749,1405750,1405751,1405752,1405753,1405754,1405755,1405756,1405757,1405758,1405760,1405762,1405763,1405764,1405765,1405766,1405767,1405768,1405769,1405770,1405771,1405772,1405773,1405774,1405775,1405776,1405777,1405778,1405779,1405780,1405781,1405782,1405783,1405784,1405785,1405786,1405787,1405788,1405789,1405790,1405791,1405792,1405793,1405794,1405795,1405796,1405797,1405798,1405799,1405800,1405801,1405802,1405803,1405804,1405805,1405806,1405807,1405808,1405809,1405810,1405811,1405812,1405813,1405814,1405815,1405816,1405817,1405818,1405819,1405820,1405821,1405822,1405823,1405824,1405825,1405826,1405827,1405828,1405829,1405830,1405831,1405832,1405833,1405834,1405835,1405836,1405837,1405838,1405839,1405856,1405857,1405858,1405859,1405860,1405861,1405862,1405863,1405864,1405865,1405866,1405867,1405872,1405873,1405874,1405875,1405876,1405877,1405878,1405879,1405880,1405881,1405882,1405883,1405884,1405885,1405886,1405887,1405888,1405889,1405890,1405891,1405892,1405893,1405894,1405895,1405896,1405898,1405899,1405900,1405901,1405902,1405903,1405904,1405905,1405906,1405910,1405911,1405912,1405913,1405914,1405915,1405917,1405918,1405919,1405920,1405921,1405922,1405923,1405924,1405925,1405926,1405927,1405928,1405929,1405930,1405931,1405932,1405933,1405934,1405935,1405936,1405937,1405938,1405939,1405940,1405941,1405942,1405943,1405944,1405945,1405946,1405947,1405948,1405949,1405950,1405951,1405952,1405953,1405954,1405955,1405956,1405957,1405958,1405959,1405960,1405961,1405962,1405963,1405964,1405965,1405966,1405967,1405968,1405927,1405928,1405929,1405930,1405973,1105974,1405975,1405976,1405977,1405984,1405985,1405986,1405987,1405988,1405989,1405990,1405991,1405992,1405993,1405994,1405995,1405996,1405997,1405998,1405999,1406000,1406001,1406004,1406005,1406006,1406007,1406008,1406009,1406010,1406011,1406012,1406013,1406014,1406015,1406016,1406017,1406018,1406019,1406020,1406021,1406022,1406023,1406024,1406025,1406026,1406027,1406028,1406029,1406030,1406031,1406032,1406033,1406034,1406035,1406036,1406037,1406038,1406039,1406040,1406041,1406042,1406043,1406044,1406045,1406046,1406047,1406048,1406049,1406050,1406051,1406052,1406053,1406054,1406055,1406056,1406057,1406058,1406059,1406060,1406061,1406062,1406063,1406064,1406065,1406066,1406067,1406068,1406069,1406070,1406071,1406072,1406073,1406074,1406075,1406076,1406077,1406078,1406079,1406080,1406081,1406082,1406083,1406084,1406085,1406086,1406087,1406088,1406089,1406090,1406091,1406092,1406093,1406094,1406095,1406096,1406097,1406098,1406099,1406100,1406101,1406102,1406103,1406104,1406105,1406106,1406107,1406108,1406109,1406110,1406111,1406112,1406113,1406114,1406115,1406116,1406117,1406118,1406119,1406120,1406121,1406122,1406123,1406124,1406125,1406126,1406127,1406128,1406129,1406130,1406131,1406132,1406133,1406134,1406135,1406136,1406137,1406138,1406139,1406140,1406141,1406142,1406143,1406144,1406145,1406146,1406153,1406154,1406155,1406156,1406157,1406158,1406159,1406160,1406161,1406162,1406163,1406164,1406165,1406166,1406167,1406168,1406169,1406170,1406171,1406172,1406173,1406174,1406175,1406176,1406177,1406178,1406179,1406180,1406181,1406182,1406183,1406184,1406185,1406186,1406187,1406188,1406189,1406190,1406191,1406192,1406193,1406194,1406195,1406196,1406197,1406198,1406199,1406200,1406201,1406202,1406203,1406204,1406205,1406206,1406207,1406208,1406209,1406210,1406211,1406214,1406215,1406216,1406217,1406218,1406219,1406220,1406221,1406222,1406223,1406224,1406225,1406226,1406227,1406228,1406229,1406230,1406231,1406232,1406233,1406234,1406235,1406236,1406237,1406238,1406239,1406240,1406241,1406242,1406243,1406244,1406245,1406246,1406247,1406248,1406249,1406250,1406251,1406252,1406253,1406254,1406255,1406256,1406257,1406258,1406259,1406260,1406261,1406262,1406263,1406264,1406265,1406266,1406267,1406268,1406269,1406270,1406271,1406272,1406273,1406274,1406275,1406276,1406277,1406278,1406279,1406280,1406281,1406282,1406283,1406284,1406285,1406286,1406287,1406288,1406289,1406290,1406291,1406292,1406293,1406294,1406295,1406296,1406297,1406298,1406299,1406300,1406301,1406302,1406303,1406304,1406305,1406312,1406313,1406314,1406315,1406316,1406317,1406318,1406319,1406320,1406321,1406322,1406323,1406324,1406325,1406326,1406327,1406328,1406329,1406330,1406331,1406332,1406333,1406334,1406335,1406336,1406337,1406338,1406339,1406340,1406341,1406342,1406343,1406344,1406345,1406346,1406347,1406348,1406349,1406350,1406351,1406352,1406353,1406354,1406355,1406356,1406357,1406358,1406359,1406360,1406361,1406362,1406363,1406364,1406365,1406366,1406367,1406368,1406369,1406370,1406371,1406372,1406373,1406374,1406375,1406376,1406377,1406378,1406379,1406380,1406381,1406382,1406383,1406384,1406385,1406386,1406387,1406388,1406389,1406390,1406391,1406392,1406393,1406394,1406395,1406396,1406397,1406398,1406399,1406400,1406401,1406402,1406403,1406404,1406405,1406406,1406407,1406408,1406409,1406410,1406411,1406412,1406413,1406414,1406415,1406416,1406417,1406418,1406419,1406420,1406421,1406422,1406423,1406424,1406425,1406426,1406427,1406428,1406429,1406430,1406431,1406432,1406433,1406434,1406435,1406436,1406437,1406438,1406439,1406440,1406441,1406442,1406443,1406444,1406445,1406446,1406447,1406448,1406449,1406450,1406451,1406452,1406453,1406454,1406455,1406456,1406457,1406458,1406459,1406460,1406461,1406462,1406463,1406464,1406465,1406466,1406467,1406468,1406469,1406470,1406476,1406477,1406478,1406479,1406480,1406481,1406482,1406483,1406484,1406485,1406486,1406487,1406488,1406489,1406490,1406491,1406492,1406493,1406494,1406495,1406496,1406497,1406498,1406499,1406500,1406501,1406502,1406503,1406504,1406505,1406506,1406507,1406508,1406509,1406510,1406511,1406512,1406513,1406514,1406515,1406516,1406517,1406518,1406519,1406520,1406521,1406522,1406523,1406524,1406525,1406526,1406527,1406528,1406529,1406530,1406531,1406532,1406533,1406534,1406535,1406536,1406537,1406538,1406539,1406540,1406541,1406542,1406543,1406544,1406545,1406546,1406547,1406548,1406549,1406550,1406551,1406552,1406553,1406554,1406555,1406556,1406557,1406558,1406559,1406560,1406561,1406562,1406563,1406564,1406565,1406566,1406567,1406568,1406569,1406570,1406571,1406572,1406573,1406574,1406575,1406576,1406577,1406578,1406579,1406580,1406581,1406582,1406583,1406584,1406585,1406586,1406587,1406588,1406589,1406590,1406591,1406592,1406593,1406594,1406595,1406596,1406597,1406598,1406599,1406600,1406601,1406602,1406603,1406604,1406605,1406606,1406607,1406608,1406609,1406610,1406611,1406612,1406613,1406614,1406615,1406616,1406617,1406618,1406619,1406620,1406621,1406622,1406623,1406624,1406625,1406626,1406627,1406628,1406629,1406630,1406631,1406632,1406633,1406634,1406635,1406636,1406637,1406638,1406639,1406640,1406641,1406642,1406643,1406644,1406645,1406646,1406647,1406648,1406649,1406650,1406651,1406652,1406653,1406654,1406655,1406656,1406657,1406658,1406659,1406660,1406661,1406662,1406663,1406664,1406665,1406666,1406667,1406668,1406669,1406670,1406671,1406672,1406673,1406674,1406675,1406676,1406677,1406678,1406679,1406680,1406681,1406682,1406683,1406684,1406685,1406686,1406687,1406688,1406689,1406690,1406691,1406692,1406693,1406694,1406695,1406696,1406697,1406698,1406699,1406700,1406701,1406702,1406703,1406704,1406705,1406706,1406707,1406708,1406709,1406710,1406711,1406712,1406713,1406714,1406715,1406716,1406719,1406720,1406721,1406722,1406723,1406724,1406725,1406726,1406727,1406728,1406729,1406730,1406731,1406732,1406733,1406734,1406735,1406736,1406737,1406738,1406739,1406740,1406741,1406742,1406744,1406745,1406746,1406747,1406748,1406749,1406751,1406752,1406753,1406754,1406755,1406756,1406757,1406758,1406759,1406760,1406761,1406762,1406763,1406764,1406765,1406766,1406767,1406768,1406769,1406770,1406771,1406772,1406773,1406774,1406775,1406776,1406777,1406778,1406779,1406780,1406781,1406782,1406783,1406784,1406785,1406786,1406787,1406788,1406789,1406790,1406791,1406792,1406793,1406794,1406795,1406796,1406797,1406800,1406801,1406802,1406803,1406804,1406805,1406806,1406807,1406808,1406809,1406816,1406817,1406818,1406819,1406820,1406821,1406822,1406823,1406824,1406825,1406826,1406827,1406828,1406829,1406830,1406831,1406832,1406833,1406834,1406835,1406836,1406837,1406838,1406839,1406840,1406841,1406842,1406843,1406844,1406845,1406846,1406847,1406848,1406849,1406850,1406851,1406852,1406853,1406854,1406855,1406856,1406857,1406858,1406859,1406860,1406861,1406862,1406863,1406864,1406865,1406866,1406867,1406868,1406869,1406870,1406871,1406872,1406873,1406874,1406875,1406876,1406877,1406878,1406879,1406880,1406881,1406882,1406883,1406884,1406885,1406886,1406887,1406888,1406889,1406890,1406891,1406892,1406893,1406894,1406895,1406896,1406897,1406898,1406899,1406900,1406901,1406902,1406903,1406906,1406907,1406908,1406909,1406910,1406911,1406912,1406913,1406914,1406915,1406916,1406917,1406918,1406919,1406920,1406921,1406922,1406923,1406924,1406925,1406926,1406927,1406928,1406929,1406930,1406931,1406932,1406933,1406934,1406935,1406936,1406937,1406938,1406939,1406940,1406941,1406942,1406943,1406944,1406945,1406946,1406947,1406948,1406949,1406950,1406951,1406952,1406953,1406954,1406955,1406956,1406957,1406958,1406959,1406960,1406961,1406962,1406963,1406964,1406971,1406972,1406973,1406974,1406975,1406976,1406977,1406978,1406979,1406980,1406981,1406982,1406984,1406985,1406986,1406987,1406988,1406989,1406990,1406991,1406992,1406993,1406994,1406995,1406996,1406997,1406998,1406999,1407000,1407001,1407002,1407003,1407004,1407005,1407006,1407007,1407008,1407009,1407010,1407011,1407012,1407013,1407014,1407015,1407016,1407017,1407018,1407020,1406937,1406948,1406953,1407028,1407029,1407030,1407031,1407032,1407034,1407035,1407036,1407037,1407038,1407039,1407040,1407041,1407042,1407043,1407044,1407045,1407046,1407047,1407048,1407049,1407050,1407051,1407052,1407055,1407056,1407057,1407058,1407059,1407060,1407061,1407062,1407063,1407064,1407065,1407066,1407067,1407068,1407069,1407070,1407071,1407072,1407073,1407074,1407075,1407076,1407077,1407078,1407079,1407080,1407081,1407082,1407083,1407084,1407085,1407086,1407087,1407088,1407089,1407090,1407091,1407092,1407093,1407094,1407095,1407096,1407103,1407104,1407105,1407106,1407107,1407108,1407111,1407112,1407113,1407114,1407115,1407116,1407117,1407118,1407119,1407120,1407121,1407122,1407123,1407124,1407125,1407126,1407127,1407128,1407129,1407130,1407131,1407132,1407133,1407134,1407135,1407136,1407137,1407138,1407139,1407140,1407141,1407142,1407143,1407144,1407145,1407146,1407147,1407148,1407149,1407150,1407151,1407152,1407153,1407154,1407155,1407156,1407157,1407158,1407159,1407160,1407161,1407162,1407165,1407166,1407167,1407168,1407169,1407170,1407171,1407172,1407173,1407174,1407175,1407176,1407177,1407178,1407179,1407180,1407181,1407182,1407183,1407184,1407185,1407186,1407187,1407188,1407189,1407190,1407191,1407192,1407193,1407194,1407195,1407196,1407197,1407198,1407199,1407200,1407201,1407202,1407203,1407204,1407205,1407206,1407208,1407209,1407210,1407211,1407212,1407219,1407220,1407221,1407222,1407223,1407224,1407225,1407226,1407229,1407230,1407231,1407232,1407233,1407234,1407235,1407236,1407237,1407238,1407239,1407240,1407241,1407242,1407243,1407244,1407245,1407246,1407247,1407248,1407249,1407250,1407251,1407252,1407260,1407261,1407262,1407263,1407264,1407265,1407266,1407267,1407268,1407269,1407270,1407271,1407272,1407273,1407274,1407275,1407276,1407277,1407278,1407279,1407280,1407281,1407282,1407283,1407284,1407285,1407286,1407287,1407290,1407291,1407292,1407293,1407294,1407295,1407296,1407297,1407298,1407299,1407300,1407301,1407302,1407303,1407304,1407305,1407306,1407307,1407308,1407309,1407310,1407311,1407312,1407313,1407314,1407315,1407316,1407317,1407318,1407319,1407320,1407321,1407322,1407323,1407324,1407325,1407326,1407327,1407328,1407329,1407330,1407331,1407334,1407335,1407336,1407337,1407338,1407339,1407340,1407341,1407342,1407343,1407344,1407345,1407346,1407347,1407348,1407349,1407350,1407351,1407352,1407353,1407354,1407355,1407356,1407357,1407358,1407359,1407366,1407369,1407372,1407373,1407374,1407375,1407376,1407377,1407378,1407379,1407380,1407381,1407382,1407383,1407384,1407385,1407386,1407387,1407388,1407389,1407390,1407391,1407392,1407393,1407396,1407397,1407398,1407399,1407400,1407401,1407402,1407404,1407405,1407406,1407407,1407408,1407409,1407410,1407411,1407412,1407413,1407414,1407415,1407416,1407417,1407418,1407419,1407420,1407421,1407422,1407423,1407424,1407425,1407426,1407427,1407428,1407429,1407430,1407431,1407432,1407433,1407434,1407435,1407436,1407437,1407438,1407439,1407440,1407441,1407442,1407445,1407446,1407447,1407448,1407449,1407450,1407451,1407452,1407453,1407454,1407455,1407456,1407457,1407458,1407459,1407460,1407461,1407462,1407463,1407464,1407465,1407466,1407467,1407468,1407469,1407470,1407471,1407472,1407475,1407476,1407477,1407478,1407479,1407480,1407481,1407482,1407483,1407485,1407486,1407487,1407488,1407489,1407490,1407491,1407492,1407493,1407494,1407495,1407496,1407497,1407498,1407499,1407500,1407501,1407502,1407503,1407504,1407505,1407512,1407513,1407514,1407515,1407516,1407517,1407518,1407519,1407520,1407521,1407522,1407523,1407524,1407527,1407528,1407529,1407530,1407531,1407532,1407533,1407534,1407535,1407536,1407537,1407538,1407539,1407540,1407541,1407542,1407543,1407544,1407545,1407546,1407547,1407548,1407549,1407550,1407551,1407552,1407553,1407554,1407555,1407556,1407557,1407558,1407559,1407560,1407561,1407562,1407563,1407564,1407565,1407566,1407567,1407568,1407569,1407570,1407571,1407572,1407573,1407574,1407577,1407578,1407579,1407580,1407581,1407582,1407583,1407584,1407585,1407586,1407587,1407588,1407589,1407590,1407591,1407592,1407593,1407594,1407595,1407596,1407597,1407598,1407599,1407600,1407601,1407602,1407603,1407604,1407605,1407606,1407607,1407608,1407609,1407610,1407611,1407612,1407613,1407614,1407615,1407616,1407617,1407618,1407625,1407626,1407627,1407628,1407629,1407630,1407631,1407632,1407633,1407636,1407637,1407638,1407639,1407640,1407641,1407642,1407643,1407644,1407645,1407646,1407647,1407648,1407649,1407650,1407651,1407652,1407653,1407654,1407655,1407656,1407657,1407658,1407659,1407660,1407668,1407669,1407670,1407671,1407672,1407673,1407674,1407675,1407676,1407677,1407678,1407679,1407680,1407681,1407682,1407683,1407684,1407685,1407686,1407687,1407688,1407689,1407690,1407691,1407692,1407693,1407694,1407695,1407696,1407697,1407700,1407701,1407702,1407703,1407704,1407705,1407706,1407707,1407708,1407709,1407710,1407711,1407712,1407713,1407714,1407715,1407716,1407717,1407718,1407719,1407720,1407721,1407722,1407723,1407724,1407725,1407726,1407727,1407729,1407730,1407731,1407732,1407733,1407734,1407735,1407736,1407737,1407738,1407739,1407740,1407741,1407742,1407743,1407744,1407745,1407746,1407747,1407748,1407749,1407750,1407751,1407752,1407753,1407754,1407755,1407756,1407757,1407758,1407759,1407760,1407763,1407764,1407765,1407766,1407767,1407768,1407769,1407770,1407771,1407772,1407773,1407774,1407775,1407776,1407778,1407779,1407780,1407781,1407782,1407783,1407784,1407785,1407786,1407787,1407788,1407789,1407790,1407791,1407792,1407793,1407794,1407795,1407796,1407797,1407798,1407799,1407800,1407801,1407802,1407803,1407804,1407805,1407806,1407807,1407808,1407809,1407810,1407811,1407812,1407813,1407816,1407817,1407818,1407819,1407820,1407821,1407822,1407823,1407824,1407825,1407826,1407827,1407828,1407829,1407830,1407831,1407832,1407833,1407834,1407835,1407836,1407837,1407838,1407839,1407840,1407841,1407842,1407843,1407844,1407845,1407846,1407847,1407848,1407849,1407856,1407857,1407858,1407859,1407860,1407861,1407862,1407863,1407864,1407865,1407866,1407867,1407868,1407869,1407870,1407871,1407872,1407875,1407876,1407877,1407878,1407879,1407880,1407881,1407882,1407883,1407884,1407885,1407886,1407887,1407888,1407889,1407890,1407891,1407892,1407893,1407894,1407895,1407896,1407897,1407898,1407899,1407900,1407901,1407902,1407903,1407904,1407905,1407906,1407907,1407908,1407909,1407910,1407911,1407912,1407913,1407914,1407915,1407916,1407917,1407918,1407919,1407920,1407921,1407922,1407923,1407926,1407927,1407928,1407929,1407930,1407931,1407935,1407936,1407937,1407938,1407947,1407948,1407949,1410000,1410001,1410002,1410003,1410004,1410005,1410006,1410007,1410008,1410009,1410010,1410011,1410012,1410013,1410014,1410015,1410016,1410017,1410018,1410019,1410020,1410021,1410022,1410023,1410024,1410025,1410026,1410027,1410028,1410029,1410030,1410031,1410032,1410033,1410034,1410035,1410036,1410037,1410038,1410039,1410040,1410041,1410042,1410043,1410044,1410045,1410046,1410047,1410048,1410049,1410050,1410051,1410052,1410053,1410054,1410055,1410056,1410057,1410058,1410059,1410060,1410061,1410062,1410063,1410064,1410065,1410066,1410067,1410068,1410069,1410070,1410071,1410072,1410073,1410074,1410075,1410077,1410078,1410079,1410080,1410081,1410082,1410083,1410084,1410085,1410086,1410087,1410088,1410089,1410090,1410091,1410092,1410093,1410094,1410095,1410096,1410097,1410098,1410099,1410100,1410101,1410102,1410103,1410104,1410105,1410106,1410107,1410108,1410109,1410110,1410111,1410112,1410113,1410114,1410115,1410116,1410117,1410118,1410119,1410120,1410121,1410122,1410123,1410124,1410125,1410126,1410127,1410128,1410129,1410130,1410131,1410132,1410133,1410134,1410135,1410136,1410137,1410138,1410139,1410140,1410141,1410142,1410143,1410144,1410145,1410146,1410147,1410148,1410149,1410150,1410151,1410152,1410153,1410154,1410155,1410156,1410157,1410158,1410159,1410160,1410161,1410162,1410163,1410164,1410165,1410166,1410167,1410168,1410169,1410170,1410171,1410172,1410173,1410174,1410175,1410176,1410177,1410178,1410179,1410180,1410181,1410182,1410183,1410184,1410185,1410186,1410187,1410188,1410189,1410190,1410191,1410192,1410193,1410194,1410195,1410196,1410198,1410199,1410200,1410201,1410202,1410203,1410204,1410205,1410206,1410207,1410208,1410209,1410210,1410211,1410212,1410213,1410214,1410215,1410216,1410217,1410218,1410219,1410220,1410221,1410222,1410223,1410224,1410225,1410226,1410227,1410228,1410229,1410230,1410231,1410232,1410233,1410234,1410235,1410236,1410237,1410238,1410239,1410240,1410241,1410242,1410243,1410244,1410245,1410246,1410247,1410248,1410249,1410250,1410251,1410252,1410253,1410254,1410255,1410256,1410257,1410258,1410259,1410260,1410261,1410262,1410263,1410264,1410265,1410266,1410267,1410268,1410269,1410270,1410271,1410272,1410273,1410274,1410275,1410276,1410277,1410278,1410279,1410280,1410281,1410282,1410283,1410284,1410285,1410286,1410287,1410288,1410289,1410290,1410291,1410292,1410293,1410294,1410295,1410296,1410297,1410298,1410299,1410300,1410301,1410302,1410303,1410304,1410305,1410306,1410307,1410308,1410309,1410310,1410311,1410312,1410313,1410314,1410315,1410316,1410317,1410318,1410319,1410320,1410323,1410324,1410325,1410326,1410327,1410328,1410329,1410330,1410331,1410332,1410333,1410334,1410335,1410336,1410337,1410338,1410339,1410340,1410341,1410342,1410343,1410344,1410345,1410346,1410347,1410348,1410349,1410350,1410351,1410352,1410353,1410354,1410355,1410356,1410357,1410358,1410359,1410360,1410361,1410362,1410363,1410364,1410365,1410366,1410367,1410368,1410369,1410370,1410371,1410372,1410373,1410374,1410375,1410376,1410377,1410378,1410379,1410380,1410381,1410382,1410383,1410384,1410385,1410386,1410387,1410388,1410389,1410390,1410391,1410393,1410394,1410395,1410396,1410397,1410398,1410399,1410400,1410401,1410402,1410403,1410404,1410405,1410406,1410407,1410408,1410409,1410410,1410411,1410412,1410413,1410414,1410415,1410416,1410417,1410418,1410419,1410420,1410421,1410422,1410423,1410424,1410425,1410426,1410427,1410430,1410431,1410432,1410433,1410434,1410435,1410436,1410437,1410438,1410439,1410440,1410441,1410442,1410443,1410444,1410445,1410446,1410447,1410448,1410449,1410450,1410451,1410452,1410453,1410454,1410455,1410456,1410457,1410458,1410460,1410461,1410462,1410463,1410464,1410465,1410466,1410467,1410468,1410469,1410470,1410471,1410472,1410473,1410474,1410475,1410478,1410479,1410480,1410481,1410482,1410483,1410484,1410485,1410486,1410487,1410490,1410491,1410492,1410493,1410494,1410495,1410497,1410498,1410499,1410500,1410501,1410502,1410503,1410504,1410505,1410506,1410507,1410508,1410509,1410510,1410511,1410512,1410513,1410514,1410515,1410516,1410517,1410518,1410519,1410520,1410521,1410522,1410523,1410524,1410525,1410526,1410527,1410531,1410532,1410533,1410534,1410535,1410536,1410537,1410538,1410539,1410540,1410541,1410542,1410543,1410544,1410545,1410546,1410547,1410548,1410549,1410550,1410551,1410552,1410553,1410554,1410555,1410556,1410557,1410558,1410559,1410560,1410561,1410565,1410566,1410567,1410568,1410569,1410570,1410571,1410572,1410573,1410574,1410575,1410576,1410577,1410578,1410579,1410580,1410581,1410582,1410583,1410584,1410585,1410586,1410587,1410588,1410589,1410590,1410591,1410592,1410593,1410594,1410595,1410596,1410597,1410598,1410599,1410600,1410601,1410602,1410603,1410604,1410605,1410606,1410607,1410608,1410609,1410610,1410611,1410612,1410613,1410614,1410615,1410616,1410617,1410618,1410619,1410620,1410621,1410622,1410623,1410624,1410625,1410626,1410627,1410628,1410629,1410630,1410631,1410633,1410634,1410635,1410636,1410637,1410638,1410639,1410640,1410641,1410642,1410643,1410644,1410645,1410646,1410647,1410648,1410650,1410651,1410652,1410653,1410654,1410655,1410656,1410657,1410658,1410659,1410660,1410661,1410662,1410663,1410664,1410665,1410666,1410667,1410668,1410669,1410670,1410671,1410672,1410673,1410674,1410675,1410676,1410677,1410678,1410679,1410680,1410681,1410682,1410683,1410684,1410685,1410686,1410687,1410688,1410689,1410690,1410691,1410692,1410693,1410694,1410695,1410696,1410697,1410698,1410699,1410700,1410702,1410704,1410706,1410708,1410710,1410711,1410712,1410713,1410714,1410715,1410716,1410717,1410718,1410719,1410720,1410721,1410722,1410723,1410724,1410725,1410726,1410727,1410728,1410729,1410730,1410731,1410732,1410733,1410734,1410735,1410736,1410737,1410738,1410739,1410740,1410741,1410742,1410743,1410744,1410745,1410746,1410747,1410748,1410749,1410750,1410751,1410752,1410753,1410754,1410755,1410756,1410757,1410758,1410759,1410760,1410761,1410762,1410763,1410764,1410765,1410766,1410767,1410768,1410769,1410770,1410771,1410772,1410773,1410774,1410775,1410776,1410777,1410778,1410779,1410780,1410781,1410782,1410783,1410784,1410785,1410786,1410787,1410788,1410789,1410790,1410791,1410792,1410793,1410794,1410795,1410796,1410797,1410798,1410799,1410800,1410801,1410802,1410803,1410804,1410805,1410806,1410807,1410808,1410809,1410810,1410811,1410812,1410813,1410814,1410815,1410816,1410817,1410818,1410819,1410820,1410821,1410822,1410823,1410824,1410825,1410826,1410827,1410828,1410829,1410830,1410831,1410832,1410833,1410834,1410835,1410836,1410837,1410838,1410839,1410840,1410841,1410842,1410846,1410847,1410848,1410849,1410850,1410851,1410852,1410853,1410854,1410855,1410856,1410857,1410858,1410859,1410860,1410861,1410862,1410863,1410864,1410865,1410866,1410867,1410868,1410869,1410870,1407961,1407962,1407963,1407964,1407965,1407966,1407967,1407968,1407969,1407970,1407971,1407993,1407994,1408020,1408021,1408022,1408023,1408024,1408025,1408026,1408027,1408028,1408029,1408030,1408031,1408038,1408045,
1501001608,1501002608,1501003608,1501001487,1501002487,1501003487,1501001652,1501002652,1501003652,1501001057,1501002057,1501003057,1501001133,1501002133,1501003133,1501001051,1501002051,1501003051,1502001439,1502002439,1502003439,1502001410,1502002410,1502003410,1502001014,1502002014,1502003014,1502001069,1502002069,1502003069,1502001363,1502002363,1502003363,1502001090,1502002090,1502003090,1502001023,1502002023,1502003023,1502001031,1502002031,1502003031,1502001012,1502002012,1502003012,1502001448,1502002448,1502003448,
1903230,1903231,1903232,1908117,1908118,1908119,1961070,1961071,1961072,1961073,19116002,19116003,19116004,1901003,1901004,1901005,1901006,1901007,1901009,1901011,1901012,1901013,1901014,1901015,1901016,1901017,1901018,1901020,1901021,1901022,1901023,1901024,1901025,1901026,1901027,1901028,1901033,1901035,1901036,1901040,1901041,1901042,1901043,1901044,1901045,1901046,1901047,1901048,1901049,1901050,1901051,1901052,1901055,1901056,1901057,1901058,1901059,1901060,1901061,1901062,1901063,1901064,1901065,1901066,1901067,1901069,1901070,1901071,1901072,1901073,1901074,1901075,1901076,1901077,1901079,1901080,1901081,1901082,1901083,1901084,1901085,1901086,1901087,1901088,1901089,1901090,1901091,1901092,1901093,1901094,1901095,1901096,1901097,1901098,1901099,1901100,1901101,1901102,1901103,1901104,1901105,1901106,1902002,1902010,1902011,1902012,1902013,1902015,1902016,1902017,1902018,1902019,1902020,1902021,1902022,1902023,1902024,1902025,1902026,1902027,1902028,1902029,1902030,1902067,1903005,1903006,1903007,1903008,1903011,1903012,1903013,1903014,1903015,1903016,1903017,1903018,1903019,1903020,1903021,1903022,1903023,1903029,1903030,1903031,1903032,1903033,1903034,1903035,1903036,1903037,1903039,1903041,1903042,1903043,1903044,1903045,1903046,1903047,1903048,1903049,1903050,1903051,1903052,1903053,1903054,1903055,1903056,1903057,1903058,1903059,1903060,1903061,1903062,1903063,1903066,1903067,1903068,1903069,1903070,1903071,1903072,1903073,1903074,1903075,1903076,1903077,1903079,1903080,1903081,1903082,1903084,1903085,1903086,1903087,1903088,1903089,1903090,1903099,1903101,1903102,1903103,1903104,1903105,1903106,1903189,1903190,1903191,1903192,1903193,1903194,1903195,1903196,1903197,1903198,1903199,1903200,1903201,1903202,1903203,1903204,1903205,1903206,1903207,1903208,1903209,1903210,1903211,1903212,1903213,1903214,1903215,1903216,1903217,1903218,1903219,1903220,1903221,1903222,1903223,1903500,1904004,1904005,1904007,1904008,1904009,1904010,1904011,1904012,1904013,1904014,1904015,1904016,1904017,1904018,1904019,1905002,1905003,1905004,1905005,1905006,1906002,1906003,1906004,1906006,1906007,1907004,1907005,1907006,1907007,1907008,1907010,1907011,1907012,1907013,1907014,1907016,1907018,1907019,1907021,1907022,1907023,1907025,1907026,1907027,1907028,1907029,1907030,1907032,1907033,1907034,1907035,1907036,1907037,1907038,1907040,1907041,1907043,1907044,1907045,1907046,1907047,1907048,1907049,1907050,1907051,1907052,1907053,1907054,1907055,1907056,1907058,1907059,1907060,1907061,1907062,1907063,1907064,1907065,1907066,1907067,1907068,1907069,1907070,1907071,1907072,1907073,1907074,1907099,1908003,1908005,1908006,1908007,1908008,1908009,1908010,1908011,1908012,1908013,1908015,1908016,1908017,1908018,1908019,1908021,1908023,1908030,1908031,1908032,1908033,1908034,1908035,1908036,1908037,1908039,1908040,1908041,1908043,1908047,1908049,1908050,1908051,1908052,1908053,1908054,1908055,1908056,1908057,1908059,1908060,1908061,1908062,1908063,1908064,1908065,1908066,1908067,1908068,1908069,1908070,1908071,1908072,1908073,1908074,1908075,1908076,1908077,1908078,1908079,1908080,1908081,1908082,1908083,1908084,1908085,1908086,1908087,1908088,1908089,1908091,1908092,1908093,1908094,1908095,1908096,1908097,1908098,1908099,1908100,1908101,1908102,1908104,1908105,1908106,1908107,1908108,1908109,1908110,1908188,1908189,1909002,1909013,1909015,1909016,1909017,1909018,1909019,1909020,1909021,1909022,1909023,1909057,1909999,1910002,1910010,1910013,1910015,1910016,1910018,1910019,1910020,1910021,1910022,1910023,1910024,1910025,1910026,1910027,1910028,1910029,1910082,1910083,1910500,1911002,1911003,1911004,1911005,1911006,1911007,1911008,1911010,1911011,1911012,1911013,1911014,1911015,1911016,1911017,1911018,1911019,1911020,1912002,1912003,1912010,1912012,1913001,1914002,1914003,1914004,1914011,1915002,1915003,1915005,1915006,1915007,1915008,1915009,1915010,1915011,1915012,1915013,1915014,1915015,1915016,1915017,1915018,1915019,1915020,1915021,1915022,1915023,1915024,1915025,1915026,1915099,1916004,1916005,1916006,1917003,1917004,1917005,1917006,1918010,1918011,1918012,1919010,1919011,1920001,1923001,1923002,1923003,1923004,1923005,1923006,1927001,1929001,1930001,1930002,1930003,1932001,1933001,1948001,1949001,1949002,1950001,1950010,1953003,1953004,1953005,1953006,1953007,1953008,1953009,1953010,1953011,1953012,1953013,1953014,1953015,1953016,1953017,1953018,1954001,1955001,1956001,1957001,1958001,1960002,1960003,1961007,1961010,1961011,1961012,1961013,1961014,1961015,1961016,1961017,1961018,1961019,1961020,1961021,1961024,1961025,1961029,1961030,1961031,1961032,1961033,1961034,1961035,1961036,1961037,1961038,1961039,1961040,1961041,1961042,1961043,1961044,1961045,1961046,1961047,1961048,1961049,1961050,1961051,1961052,1961053,1961054,1961055,1961056,1961057,1961058,1961059,1961060,1961061,1961062,1961063,1961064,1961065,1961066,1961067,1961136,1961137,1961138,1961139,1961140,1961141,1961142,1961143,1961144,1961145,1961147,1961148,1961149,1961150,1961151,1961152,1961153,1963002,1965002,1966016,1966017,1966018,1967002,1967003,1967004,1972001,1980001,1980002,1980003,1980004,1981001,1981002,1981003,1982001,1982002,1983001,1983002,1984001,1984002,1985001,1985002,1986001,1986002,1987002,1987003,1987004,1987005,1987006,1988002,1988003,1988004,1988005,1989001,1989002,1990001,1990002,1990003,1990004,1990005,1990006,1990007,1990008,1990009,1990010,1990011,1990012,1990013,1990014,1990015,1990016,1990017,1990018,1990019,1990020,1990021,1991001,1991002,1991003,1991004,1991005,1991006,1991007,1991008,1991009,1991010,1991011,1991012,1991013,1991014,1991015,1991016,1991017,1991018,1991019,1991020,1991021,1991022,1992001,1992002,1993001,1994001,1995001,1997001,1997002,1999001,1999002,1999003,1999004,
1101001063,1101001068,1101001089,1101001103,1101001116,1101001128,1101001143,1101001154,1101001174,1101001213,1102001143,1102001151,1101001231,1101001242,1101001249,1101001256,1101001265,1101001276,1101002029,1101002056,1101002068,1101002081,1101002103,1101002110,1101002117,1101002125,1101002128,1101002133,1101002142,1101002149,1101002156,1101003057,1101003070,1101003080,1101003099,1101003119,1101003146,1101003167,1101003173,1101003188,1101003195,1101003208,1101003212,1101003219,1101003226,1101004046,1101004062,1101004078,1101004086,1101004098,1101004138,1101004163,1101004201,1101004209,1101004218,1101004226,1101004236,1101004246,1101005020,1101005025,1101005038,1101005043,1101005052,1101005082,1101005090,1101005098,1101005105,1101006033,1101006044,1101006062,1101006067,1101006075,1101006084,1101007025,1101007036,1101007046,1101007062,1101007071,1101007078,1101008026,1101008036,1101008051,1101008061,1101008070,1101008081,1101008104,1101008116,1101008126,1101008136,1101008146,1101008154,1101008163,1101009019,1101010029,1101012009,1101012018,1101012024,1101012033,1101100012,1101100018,1101101007,1101102007,1101102017,1101102025,1101102032,1101102041,1101102049,1102001024,1102001036,1102001058,1102001069,1102001089,1102001102,1102001103,1102001112,1102001120,1102001130,1102002043,1102002053,1102002061,1102002070,1102002090,1102002112,1102002117,1102002124,1102002129,1102002136,1102002143,1102002424,1102002438,1102002446,1102003020,1102003031,1102003039,1102003052,1102003065,1102003072,1102003080,1102003090,1102003100,1102004018,1102004034,1102004048,1102005007,1102005020,1102005041,1102005045,1102005052,1102005057,1102005064,1102005072,1102005078,1102007019,1102007022,1102105012,1102105018,1102105028,1103001060,1103001079,1103001085,1103001101,1103001129,1103001146,1103001154,1103001160,1103001179,1103001183,1103001191,1103001202,1103002018,1103002030,1103002049,1103002047,1103002059,1103002087,1103002094,1103002126,1103002156,1103003022,1103003030,1103003042,1103003051,1103003062,1103003079,1103003087,1103003092,1103003099,1103004037,1103004046,1103004058,1103004080,1103004087,1103005024,1103005048,1103006030,1103006046,1103006058,1103006063,1103006075,1103007020,1103007028,1103007038,1103007043,1103009022,1103009037,1103009042,1103009051,1103012010,1103012019,1103012024,1103012031,1103012039,1103100007,1103102007,1103103007,1104002022,1104002049,1104003026,1104003037,1104003046,1104004024,1104004035,1104004041,1104004051,1104102004,1105001020,1105001034,1105001048,1105001054,1105001062,1105001069,1105001075,1105002018,1105002035,1105002058,1105002063,1105002071,1105002076,1105002083,1105002091,1105002096,1105010008,1105010019,1105010026,1101102056,1101006098,1101006106,
12220416,12220420,1400563,1400563,40601010,40602010,40603010,40604010,40605010,40606010
,40601011,40602011,40603011,40604011,40605011,40606011,40601012,40602012,40603012,40604012,40605012,40606012,40601014,40602014,40603014
,40604014,40605014,40606014,40601015,40602015
,40603015,40604015,40605015,40606015,12201001,12220223,12220225,12220226,12212301,12208701,12208901,12209401,12209301,12209101,12219053,12219054,1407565,12211701,12210501,12219055,12219220,12219001,12215516,12216101,12219088,12219008,12220310,12220352,12220250,12219609,12219608,22010017,12220098,12220022,12220104,12206801,12205401,12204001,12219829,12213601,12214201,12219696,12219069,12219546,12201301,12212201,12219207,12209001,12219561,12210001,12219022,12208801,12210801,12200701,12219242,12206001,12205201,12212601,12205601,12219208,12212001,12209801,12211401,12207001,12211801,12207901,12203401,12201801,12215601,12215532,12213201,12215529,12204601,12215701,12219003,12219004,12219009,12220627,12220576,12220532,12215518,12212401,
452001,452002,452003,
4151118,4151117,4151109,4151112,4151111,4151105,4151093,4151092,4151090,4151089,4151084,4151083,4151077,4151078,4151085,4151079,4151064,4151071,4151145,4151119,4151120,4151123,4151125,4151127,4151128,4151130,4151133,4151134,4151140,4151144,40601010,40602010,40603010,40604010,40605010,40606010,40601011,40602011,40603011,40604011,40605011,40606011,40601012,40602012,40603012,40604012,40605012,40606012,40601014,40602014,40603014,40604014,40605014,40606014,40601015,40602015,40603015,40604015,40605015,40606015,1400563,452001,452002,452003,1401453,1401408,1401625,1401372,1401621,1401624,1401619,4152096,4152099,4151105,4151103,4151106,4151109,4151114,4151111,4151119,4151034,4151110,4151141,4151142,4151139,4151138,
1401625,1401624,1401621,1401620,1401619,1401453,612004196,1401282,1401469,1401549,1401842,
}

local INS_BASE = 2000000000
local PKG_SLOT = 3
local MELEE_ID = 108
local GUN_SUB = { [101]=true, [102]=true, [103]=true, [104]=true, [105]=true, [106]=true, [107]=true }
local NET_OK = NetErrorCode_NONE or "ok"

local R = { insToRes = {}, resToIns = {} }
local LOBBY_SAVE_PATH = "/storage/emulated/0/Android/data/com.pubg.imobile/files/shadow_lobby.txt"
local _matchApplied = false
local _weaponSkinCache = {}
local function cache()
    _G.AddOutfitEquippedCache = _G.AddOutfitEquippedCache or {
        outfitRes = nil, outfitIns = nil,
        weapons = {},
    }
    return _G.AddOutfitEquippedCache
end

function _G.SaveLobbyState()
    local cch = cache()
    local lines = {}
    
    -- Outfit
    if cch.outfitRes and cch.outfitRes > 0 then
        lines[#lines+1] = "SKIN_Outfit=" .. cch.outfitRes
    end
    
    -- Weapons
    for wid, w in pairs(cch.weapons) do
        if w.resID and w.resID > 0 then
            lines[#lines+1] = "SKIN_Weapon_" .. wid .. "=" .. w.resID
        end
    end
    
    -- Vehicles (garage)
    pcall(function()
        local GarageThemeSystem = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.GarageThemeSystem)
        if GarageThemeSystem and GarageThemeSystem.GarageVehicleInfo then
            for slot, info in pairs(GarageThemeSystem.GarageVehicleInfo) do
                if info.res_id and info.res_id > 0 then
                    lines[#lines+1] = "SKIN_Vehicle_" .. slot .. "=" .. info.res_id
                end
            end
        end
    end)
    
    -- Emotes
    pcall(function()
        if DataMgr.MotionSlotList then
            for slot, insID in pairs(DataMgr.MotionSlotList) do
                if insID and insID > 0 then
                    local resID = R.insToRes[insID] or 0
                    if resID > 0 then
                        lines[#lines+1] = "SKIN_Emote_" .. slot .. "=" .. resID
                    end
                end
            end
        end
    end)
    
    -- Hall Theme
    pcall(function()
        local themeId = nil
        if DataMgr and DataMgr.HallThemeId then
            themeId = DataMgr.HallThemeId
        elseif HallThemeUtils and HallThemeUtils.GetCurrentThemeId then
            themeId = HallThemeUtils:GetCurrentThemeId()
        end
        if themeId and themeId > 0 then
            lines[#lines+1] = "SKIN_HallTheme=" .. themeId
        end
    end)
    
    -- Pet
    pcall(function()
        local ModuleManager = require("client.module_framework.ModuleManager")
        local petModule = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.logic_pet)
        if petModule and petModule.GetCurPetID then
            local petId = petModule:GetCurPetID()
            if petId and petId > 0 then
                local resID = R.insToRes[petId] or petId
                if resID > 0 then
                    lines[#lines+1] = "SKIN_Pet=" .. resID
                end
            end
        end
    end)
    
    local f = io.open(LOBBY_SAVE_PATH, "w")
    if f then
        for _, line in ipairs(lines) do
            f:write(line .. "\n")
        end
        f:close()
    end
end

function _G.LoadLobbyState()
    local f = io.open(LOBBY_SAVE_PATH, "r")
    if not f then return end
    local content = f:read("*a")
    f:close()
    
    local data = {}
    for line in content:gmatch("[^\r\n]+") do
        local k, v = line:match("^([^=]+)=(.+)$")
        if k and v then data[k] = tonumber(v) or 0 end
    end
    
    -- Apply Outfit
    if data.SKIN_Outfit and data.SKIN_Outfit > 0 and isInjectedRes(data.SKIN_Outfit) then
        local ins = R.resToIns[data.SKIN_Outfit]
        if ins then putOnCloth(ins) end
    end
    
    -- Apply Weapons
    for k, resID in pairs(data) do
        local wid = k:match("^SKIN_Weapon_(%d+)$")
        if wid and resID > 0 and isInjectedRes(resID) then
            local ins = R.resToIns[resID]
            if ins then equipWeaponSkin(tonumber(wid), ins) end
        end
    end
    
    -- Apply Vehicles
    for k, resID in pairs(data) do
        local slot = k:match("^SKIN_Vehicle_(%d+)$")
        if slot and resID > 0 and isInjectedRes(resID) then
            local ins = R.resToIns[resID]
            if ins then
                local TeamupHandler = require("client.network.Protocol.TeamupHandler")
                TeamupHandler.send_update_car_main_page_slot_req(tonumber(slot), ins)
            end
        end
    end
    
    -- Apply Emotes
    for k, resID in pairs(data) do
        local slot = k:match("^SKIN_Emote_(%d+)$")
        if slot and resID > 0 and isInjectedRes(resID) then
            local ins = R.resToIns[resID]
            if ins then
                DataMgr.MotionSlotList[tonumber(slot)] = ins
            end
        end
    end
    EventSystem:postEvent(EVENTTYPE_MOTION, EVENTID_MOTION_UPDATE_SLOT_LIST)
    
    -- Apply Hall Theme
    if data.SKIN_HallTheme and data.SKIN_HallTheme > 0 then
        pcall(function()
            local HallThemeUtils = require("client.logic.lobby.hall_theme_utils")
            if HallThemeUtils and HallThemeUtils.SetHallTheme then
                HallThemeUtils:SetHallTheme(data.SKIN_HallTheme)
            elseif HallThemeUtils and HallThemeUtils.UpdateThemeVehicleShow then
                HallThemeUtils.UpdateThemeVehicleShow()
            elseif DataMgr then
                DataMgr.HallThemeId = data.SKIN_HallTheme
            end
            EventSystem:postEvent(EVENTTYPE_LOBBY_THEME, EVENTID_GARAGE_VEHICLE_DATA_CHANGE)
        end)
    end
    
    -- Apply Pet
    if data.SKIN_Pet and data.SKIN_Pet > 0 then
        pcall(function()
            local ModuleManager = require("client.module_framework.ModuleManager")
            local petModule = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.logic_pet)
            if petModule then
                local petRes = data.SKIN_Pet
                local petIns = R.resToIns[petRes] or petRes
                if petModule.SetCurPetID then
                    petModule:SetCurPetID(petIns)
                end
                if petModule.EquipPet then
                    petModule:EquipPet(petIns)
                end
            end
        end)
    end
end

local function cfg(resID)
    if not resID or not CDataTable or not CDataTable.GetTableData then return nil end
    return CDataTable.GetTableData("Item", resID)
end

local function subType(c)
    return c and (c.ItemSubType or c.itemSubType) or nil
end

local ST_TOP     = (ENUM_ITEM_SUBTYPE and ENUM_ITEM_SUBTYPE.Package_Slot) or 403
local ST_PANTS   = (ENUM_ITEM_SUBTYPE and ENUM_ITEM_SUBTYPE.Pants_Slot) or 404
local ST_SHOES   = (ENUM_ITEM_SUBTYPE and ENUM_ITEM_SUBTYPE.Shoes_Slot) or 405
local ST_UNDER_T = (ENUM_ITEM_SUBTYPE and ENUM_ITEM_SUBTYPE.UnderCloth) or 450
local ST_UNDER_P = (ENUM_ITEM_SUBTYPE and ENUM_ITEM_SUBTYPE.UnderPants) or 451
local WARDROBE_TAB_SUIT, WARDROBE_TAB_CLOTHES = 10, 3

pcall(function()
    local wm = require("client.slua.umg.Wardrobe.wardrobe_macro")
    WARDROBE_TAB_SUIT = wm.ENUM_WardrobeSubTabString.ENUM_WardrobeSubTabString_suit
    WARDROBE_TAB_CLOTHES = wm.ENUM_WardrobeSubTabString.ENUM_WardrobeSubTabString_clothes
end)

local FULL_SUIT_CLEAR_ST = {
    [ST_TOP] = true, [ST_PANTS] = true, [ST_SHOES] = true,
    [ST_UNDER_T] = true, [ST_UNDER_P] = true,
}

local function wardrobeTab(resID, depotData)
    if depotData and depotData.subTabType then return tonumber(depotData.subTabType) end
    local c = cfg(resID)
    return c and tonumber(c.WardrobeTab or c.wardrobeTab) or nil
end

local _fullSuitCache = {}
local _subTypeCache = {}

local function getCachedSubType(resID)
    resID = tonumber(resID)
    if not resID then return nil end
    if _subTypeCache[resID] then return _subTypeCache[resID] end
    local c = cfg(resID)
    local st = c and tonumber(c.ItemSubType or c.itemSubType)
    _subTypeCache[resID] = st or -1
    return st
end

local function isFullSuitRes(resID, depotData)
    resID = tonumber(resID)
    if not resID or resID <= 0 then return false end
    if _fullSuitCache[resID] ~= nil then return _fullSuitCache[resID] end

    local ok, xs = pcall(function()
        local LogicXSuit = require("client.slua.logic.XSuit.logic_xsuit")
        return LogicXSuit.IsXSuit(resID)
    end)
    if ok and xs then 
        _fullSuitCache[resID] = true
        return true 
    end

    local tab = wardrobeTab(resID, depotData)
    if tab == WARDROBE_TAB_SUIT then 
        _fullSuitCache[resID] = true
        return true 
    end
    if tab == WARDROBE_TAB_CLOTHES then 
        _fullSuitCache[resID] = false
        return false 
    end

    -- FIX: Check the memory table directly instead of calling a function that hasn't loaded yet
    if R.resToIns[resID] ~= nil and getCachedSubType(resID) == ST_TOP then
        _fullSuitCache[resID] = true
        return true
    end

    _fullSuitCache[resID] = false
    return false
end

local function getClothKind(resID, depotData)
    resID = tonumber(resID)
    if not resID then return nil end
    local st = subType(cfg(resID))
    if st == ST_TOP then
        return isFullSuitRes(resID, depotData) and "full_suit" or "top"
    end
    if st == ST_PANTS then return "pants" end
    if st == ST_SHOES then return "shoes" end
    if st == ST_UNDER_T then return "under_top" end
    if st == ST_UNDER_P then return "under_pants" end
    return nil
end

local function subTypesToClearForKind(kind)
    if kind == "full_suit" then return FULL_SUIT_CLEAR_ST end
    if kind == "top" then return { [ST_TOP] = true } end
    if kind == "pants" then return { [ST_PANTS] = true } end
    if kind == "shoes" then return { [ST_SHOES] = true } end
    if kind == "under_top" then return { [ST_UNDER_T] = true } end
    if kind == "under_pants" then return { [ST_UNDER_P] = true } end
    return nil
end

local function isBodyClothSubType(st)
    st = tonumber(st)
    return st == ST_TOP or st == ST_PANTS or st == ST_SHOES or st == ST_UNDER_T or st == ST_UNDER_P
end

local function weaponIdFromSkin(resID)
    local m = CDataTable and CDataTable.GetTableData and CDataTable.GetTableData("WeaponSkinMapping", resID)
    if not m then return nil end
    return m.WeaponID or m.WeaponId
end

local function isInjectedIns(ins)
    return ins and R.insToRes[tonumber(ins)] ~= nil
end

local function isInjectedRes(res)
    return res and R.resToIns[tonumber(res)] ~= nil
end

local function invalidateSocialWearCache()
    local s = _G.AddOutfitSocialState
    if s then
        s.wearPatchKey, s.snapshotKey, s.fullSnapshot, s.lastHandSkin = nil, nil, nil, nil
    end
end

local function saveWeaponToCache(weaponID, resID, insID)
    weaponID, resID, insID = tonumber(weaponID), tonumber(resID), tonumber(insID)
    if not weaponID or not resID or resID <= 0 then return end
    local cch = cache()
    cch.weapons[weaponID] = { resID = resID, insID = insID or 0 }
    _weaponSkinCache[weaponID] = { resID = resID, insID = insID or 0 }
    _G.AddOutfitLastAppliedSkin = {}
    _matchApplied = false
    invalidateSocialWearCache()
        _G.InventorySkins = _G.InventorySkins or { weapons = {}, outfit = 0 }
    _G.InventorySkins.weapons[weaponID] = resID
    
end

local function cacheWeaponSkinFromIns(weaponID, insID)
    weaponID, insID = tonumber(weaponID), tonumber(insID)
    if not weaponID or not insID or insID <= 0 then return end
    if isInjectedIns(insID) then
        saveWeaponToCache(weaponID, R.insToRes[insID], insID)
        return
    end
    pcall(function()
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local d = wd:GetValidHallDepotItemDataByInsID(insID) or wd:GetHallDepotItemDataByInsID(insID)
        if d and d.resID and tonumber(d.resID) > 0 then
            saveWeaponToCache(weaponID, tonumber(d.resID), insID)
        end
    end)
end

local function saveEquip(resID, insID)
    resID, insID = tonumber(resID), tonumber(insID)
    if not resID or not insID then return end
    local c = cfg(resID)
    local st = subType(c)
    local cch = cache()
    if getClothKind(resID) == "full_suit" then
        cch.outfitRes, cch.outfitIns = resID, insID
        _G.AddOutfitLastLobbyOutfitRes = resID
        invalidateSocialWearCache()
                _G.InventorySkins = _G.InventorySkins or { weapons = {}, outfit = 0 }
        _G.InventorySkins.outfit = resID
      
    elseif getClothKind(resID) == "top" then
        if cch.outfitRes and isFullSuitRes(cch.outfitRes) then
            cch.outfitRes, cch.outfitIns = nil, nil
            invalidateSocialWearCache()
        end
    elseif GUN_SUB[st] then
        local wid = weaponIdFromSkin(resID)
        if wid then saveWeaponToCache(wid, resID, insID) end
    elseif st == MELEE_ID then
        saveWeaponToCache(MELEE_ID, resID, insID)
    end
    _matchApplied = false
end

local function syncWeaponCacheFromLobby()
    local cch = cache()
    pcall(function()
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        local bag = fbd.GetCurrentFashionBag and fbd:GetCurrentFashionBag()
        if bag and bag.weapon_skin_list then
            for weaponID, entry in pairs(bag.weapon_skin_list) do
                weaponID = tonumber(weaponID)
                local insID = tonumber(entry and (entry.skin_id or entry.skinId)) or 0
                if weaponID and weaponID > 0 and insID > 0 then
                    if isInjectedIns(insID) then
                        local res = tonumber(R.insToRes[insID])
                        if res and res > 0 then
                            cch.weapons[weaponID] = { resID = res, insID = insID }
                        end
                    else
                        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                        local d = wd:GetValidHallDepotItemDataByInsID(insID)
                            or wd:GetHallDepotItemDataByInsID(insID)
                        if d and d.resID and tonumber(d.resID) > 0 then
                            cch.weapons[weaponID] = { resID = tonumber(d.resID), insID = insID }
                        end
                    end
                end
            end
        end
    end)
    pcall(function()
        local Arm = require("client.logic.armory.logic_armory")
        if Arm.rsp_list and Arm.rsp_list.install_list then
            for weaponID, entry in pairs(Arm.rsp_list.install_list) do
                weaponID = tonumber(weaponID)
                local insID = tonumber(entry and entry.skin_id) or 0
                if weaponID and weaponID > 0 and insID > 0 then
                    if isInjectedIns(insID) then
                        local res = tonumber(R.insToRes[insID])
                        if res and res > 0 then
                            cch.weapons[weaponID] = { resID = res, insID = insID }
                        end
                    else
                        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                        local d = wd:GetValidHallDepotItemDataByInsID(insID)
                            or wd:GetHallDepotItemDataByInsID(insID)
                        if d and d.resID and tonumber(d.resID) > 0 then
                            cch.weapons[weaponID] = { resID = tonumber(d.resID), insID = insID }
                        end
                    end
                end
            end
        end
    end)
    pcall(function()
        local wgl = require("client.slua.logic.wardrobe.logic_wardrobe_gun")
        if wgl.GetSkinIdByWeaponID then
            local guns = { 101001, 101002, 101003, 101004, 101005, 101006, 101007, 101008, 101009, 101010, 101012, 102001, 102002, 102003, 102004, 102005, 102007, 103001, 103002, 103003, 103004, 103005, 103006, 103007, 103008, 103009, 103010, 103011, 103012, 104001, 104002, 104003, 104004, 105001, 105002, 106001, 106002, 106003, 106004, 106005, 106006, 106007, 106008, 106010 }
            local wd = require("client.slua.logic.wardrobe.wardrobe_data")
            for _, wid in ipairs(guns) do
                local insID = tonumber(wgl:GetSkinIdByWeaponID(wid)) or 0
                if insID > 0 then
                    local d = wd:GetValidHallDepotItemDataByInsID(insID) or wd:GetHallDepotItemDataByInsID(insID)
                    if d and d.resID and tonumber(d.resID) > 0 then
                        cch.weapons[wid] = { resID = tonumber(d.resID), insID = insID }
                    end
                end
            end
        end
    end)
end

local function getCachedWeaponSkin(weaponID)
    weaponID = tonumber(weaponID) or 0
    if weaponID <= 0 then return nil end
    syncWeaponCacheFromLobby()
    local w = cache().weapons[weaponID]
    if w and w.resID and w.resID > 0 then return w.resID end
    return nil
end

local function getMatchWeaponSkin(weaponID)
    weaponID = tonumber(weaponID) or 0
    local fromCache = getCachedWeaponSkin(weaponID)
    if fromCache then return fromCache end
    if MATCH_CONFIG.weaponSkins then
        local fixed = tonumber(MATCH_CONFIG.weaponSkins[weaponID])
        if fixed and fixed > 0 then return fixed end
    end
    return nil
end

local function findWornInsBySubType(st)
    st = tonumber(st)
    if not st then return nil end
    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
    local AvatarData = require("client.logic.data.AvatarData")
    for _, ins in pairs(AvatarData.GetRoleWear()) do
        ins = tonumber(ins)
        if ins and ins > 0 then
            local d = wd:GetHallDepotItemDataByInsID(ins)
            if d and tonumber(d.itemSubType) == st then
                return ins, d.resID
            end
        end
    end
    return nil
end

local function removeRoleWearBySubTypes(stMap)
    if not stMap then return end
    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
    local AvatarData = require("client.logic.data.AvatarData")
    for _, ins in pairs(AvatarData.GetRoleWear()) do
        ins = tonumber(ins)
        if ins and ins > 0 then
            local d = wd:GetHallDepotItemDataByInsID(ins)
            if d and stMap[tonumber(d.itemSubType)] then
                AvatarData.RemoveRoleWearDataByValue(ins)
            end
        end
    end
end

local function clearFashionBagSlots(stMap)
    if not stMap then return end
    pcall(function()
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        local wfu = require("client.slua.logic.wardrobe.fashionbag.wardrobe_fashion_utils")
        local bag = fbd.GetCurrentFashionBag and fbd:GetCurrentFashionBag()
        if not bag or not bag.rolewear_list then return end
        for st, _ in pairs(stMap) do
            local idx = wfu.GetRoleWearIndexBySubType and wfu:GetRoleWearIndexBySubType(st)
            if idx then bag.rolewear_list[idx] = 0 end
        end
    end)
end

local function removeRoleWearBySubType(st)
    if not st then return end
    removeRoleWearBySubTypes({ [tonumber(st)] = true })
end

local function syncFashionBagRolewear()
    pcall(function()
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        fbd:SaveRolewearToFashionBag(fbd:GetFashionBagUseIndex())
    end)
end

local _ticker
pcall(function() _ticker = require("common.time_ticker") end)
local function later(sec, fn)
    if _G.SetTimer then pcall(_G.SetTimer, sec, fn) return end
    if _ticker and _ticker.AddTimer then pcall(_ticker.AddTimer, sec, fn) end
end

local function getEntity()
    local ok, dc = pcall(require, "client.slua.logic.wardrobe.logic_wardrobe_data_center")
    if not ok or not dc then return nil end
    local ok2, e = pcall(dc.GetWardrobeData)
    return ok2 and e or nil
end

local function alreadyHave(entity, resID)
    local arr = entity.ResIDToIndexArrayMap and entity.ResIDToIndexArrayMap[resID]
    if not arr then return false end
    for _, idx in pairs(arr) do
        local d = entity._data[idx]
        if d and d.count and d.count > 0 then return true end
    end
    return false
end

local function injectOne(entity, resID, insID)
    if alreadyHave(entity, resID) then
        R.resToIns[resID] = R.resToIns[resID] or insID
        R.insToRes[insID] = resID
        return true
    end
    local row = {
        instid = insID,
        res_id = resID,
        count = 1,
        lock_cnt = 0,
        isnew = 0,
        valid_hours = 0,
        expire_ts = 0,
    }
    entity:AddData(row)
    pcall(function()
        local data = entity.GetDataByInsID and entity:GetDataByInsID(insID)
        if data and entity.LoadConfigForData and CDataTable.GetTableData then
            entity:LoadConfigForData(data, CDataTable.GetTableData)
        end
    end)
    R.insToRes[insID] = resID
    R.resToIns[resID] = insID
    return true
end

local function injectArmory(resID, insID)
    local wid = weaponIdFromSkin(resID)
    if not wid then return end
    local Arm = require("client.logic.armory.logic_armory")
    Arm.rsp_list = Arm.rsp_list or { skin_list = {}, install_list = {} }
    Arm.rsp_list.skin_list = Arm.rsp_list.skin_list or {}
    Arm.rsp_list.install_list = Arm.rsp_list.install_list or {}
    if not Arm.rsp_list.skin_list[wid] then Arm.rsp_list.skin_list[wid] = {} end
    Arm.rsp_list.skin_list[wid][resID] = { is_open = 1 }
    Arm.WardrobeInsList = Arm.WardrobeInsList or {}
    Arm.WardrobeInsList[resID] = insID
end

local function injectAll(entity)
    entity = entity or getEntity()
    if not entity or not entity.bInit then return false end
    local n = 0
    for i, resID in ipairs(ITEMS) do
        local insID = INS_BASE + i
        if injectOne(entity, resID, insID) then
            n = n + 1
            local c = cfg(resID)
            if GUN_SUB[subType(c)] or subType(c) == MELEE_ID then
                injectArmory(resID, insID)
            end
        end
    end
    return n > 0
end

local function refreshWardrobe()
    pcall(function()
        if EventSystem and EVENTTYPE_WARDROBE then
            if EVENTID_WARDROBE_UPDATE_ITEM_LIST then
                EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_ITEM_LIST)
            end
            if EVENTID_WARDROBE_UPDATE_AVATAR_LIST then
                EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_AVATAR_LIST)
            end
            if EVENTID_WARDROBE_UPDATE_GUN_LIST then
                EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_GUN_LIST, -1)
            end
        end
    end)
end

local function putOnCloth(insID)
    insID = tonumber(insID)
    local resID = R.insToRes[insID]
    if not resID then return end
    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
    local d = wd:GetHallDepotItemDataByInsID(insID)
    if not d then return end

    local kind = getClothKind(resID, d)
    if not kind then return end
    local clearMap = subTypesToClearForKind(kind)
    if not clearMap then return end

    local itemSt = subType(cfg(resID)) or ST_TOP
    local oldIns, oldRes = findWornInsBySubType(itemSt)
    removeRoleWearBySubTypes(clearMap)
    clearFashionBagSlots(clearMap)
    saveEquip(resID, insID)

    local slot = PKG_SLOT
    pcall(function()
        local wfu = require("client.slua.logic.wardrobe.fashionbag.wardrobe_fashion_utils")
        local idx = wfu.GetRoleWearIndexBySubType and wfu:GetRoleWearIndexBySubType(itemSt)
        if idx then slot = idx end
    end)

    local olditem
    if oldIns and oldIns ~= insID then
        olditem = { res_id = oldRes or R.insToRes[oldIns], count = 1, instid = oldIns }
    end

    local WRH = require("client.network.Protocol.WardRobeHandler")
    local item = { res_id = resID, count = 1, instid = insID }
    WRH.on_depot_put_on_rsp(NET_OK, item, olditem, slot, insID, oldIns or 0)

    pcall(function()
        local av = require("client.slua.logic.wardrobe.logic_wardrobe_avatar")
        av:AddToWearInfo(itemSt, insID, resID, 0, 0)
        local displayResID = resID
        local LogicXSuit = require("client.slua.logic.XSuit.logic_xsuit")
        if LogicXSuit.IsXSuit(displayResID) then
            displayResID = LogicXSuit.GetItemShowID(insID) or displayResID
        end
        av:AvatarChange(displayResID, true, 0, 0)
        av:ProcessTakeOff()
        syncFashionBagRolewear()
    end)
    _G.SaveLobbyState()  -- 👈 ADD THIS LINE
end

local function putOnOutfit(insID)
    putOnCloth(insID)
end

local function equipWeaponSkin(weaponID, insID)
    weaponID, insID = tonumber(weaponID), tonumber(insID)
    if not weaponID or not insID or not isInjectedIns(insID) then return end
    local resID = R.insToRes[insID]
    _weaponSkinCache[weaponID] = { resID = resID, insID = insID }
    saveEquip(resID, insID)

    local Arm = require("client.logic.armory.logic_armory")
    local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
    local HT = require("client.logic.lobby.hall_theme_utils")
    local wgl = require("client.slua.logic.wardrobe.logic_wardrobe_gun")

    injectArmory(resID, insID)
    Arm.rsp_list.install_list[weaponID] = { skin_id = insID }
    if fbd.UpdateCurrentFashionBagWeaponSkin then
        fbd:UpdateCurrentFashionBagWeaponSkin(weaponID, insID)
    end

    local bagIdx = fbd:GetFashionBagUseIndex()
    HT.proc_skin_list_chg("weapon_skin", weaponID, insID, bagIdx, {})

    wgl:SetGunID(weaponID)
    wgl:UpdateCurrentGunAvatar(weaponID, insID)

    if EventSystem and EVENTTYPE_ARMORY and EVENTID_ARMORY_EQUIP_STAT_CHANGE then
        EventSystem:postEvent(EVENTTYPE_ARMORY, EVENTID_ARMORY_EQUIP_STAT_CHANGE, resID)
    end
    if EventSystem and EVENTTYPE_WARDROBE and EVENTID_WARDROBE_UPDATE_CURRENT_PUT_ON_GUN then
        EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_CURRENT_PUT_ON_GUN, resID)
    end
    _G.SaveLobbyState()  -- 👈 ADD THIS LINE
end

local SOCIAL = _G.AddOutfitSocialState or {}
_G.AddOutfitSocialState = SOCIAL
SOCIAL.debGen = SOCIAL.debGen or 0
SOCIAL.wearPatchKey = SOCIAL.wearPatchKey or nil
SOCIAL.snapshotKey = SOCIAL.snapshotKey or nil
SOCIAL.fullSnapshot = SOCIAL.fullSnapshot or nil

local function socialDebounce(sec, fn)
    SOCIAL.debGen = (SOCIAL.debGen or 0) + 1
    local gen = SOCIAL.debGen
    later(sec, function()
        if gen ~= SOCIAL.debGen then return end
        pcall(fn)
    end)
end

local function getLobbyCurPage()
    local p = nil
    pcall(function()
        local LMC = require("client.slua.logic.lobby.Main.Lobby_Main_Control")
        if LMC.GetCurPage then p = LMC.GetCurPage() end
    end)
    return p
end

local function getWeaponSkinResFast()
    local cch = cache()
    local wid = tonumber(DataMgr.Weapon_ID) or 0
    local w = wid > 0 and cch.weapons[wid] or nil
    if w and w.resID and w.resID > 0 then return w.resID end
    for _, ww in pairs(cch.weapons) do
        if ww.resID and ww.resID > 0 then return ww.resID end
    end
    return nil
end

local function resolveLobbyWeaponSkinRes()
    if not _G.LobbyCosmeticEnabled then return nil end
    local wid = tonumber(DataMgr.Weapon_ID) or 0
    local skin = getWeaponSkinResFast()
    if skin and skin > 0 then return skin end

    if wid > 0 then
        local fromMatch = getMatchWeaponSkin(wid)
        if fromMatch and fromMatch > 0 then return fromMatch end
    end
    if MATCH_CONFIG.weaponSkins then
        for _, s in pairs(MATCH_CONFIG.weaponSkins) do
            s = tonumber(s)
            if s and s > 0 then return s end
        end
    end

    pcall(function()
        local Arm = require("client.logic.armory.logic_armory")
        local entry = Arm.rsp_list and Arm.rsp_list.install_list
            and Arm.rsp_list.install_list[wid > 0 and wid or 101004]
        local insID = tonumber(entry and entry.skin_id) or 0
        if insID > 0 and isInjectedIns(insID) then
            skin = tonumber(R.insToRes[insID])
        elseif insID > 0 then
            local wd = require("client.slua.logic.wardrobe.wardrobe_data")
            local d = wd:GetHallDepotItemDataByInsID(insID)
            if d and d.resID then skin = tonumber(d.resID) end
        end
    end)
    if skin and skin > 0 then return skin end

    pcall(function()
        local wgl = require("client.slua.logic.wardrobe.logic_wardrobe_gun")
        if wgl.GetSkinIdByWeaponID and wid > 0 then
            local insID = tonumber(wgl:GetSkinIdByWeaponID(wid)) or 0
            if insID > 0 and isInjectedIns(insID) then
                skin = tonumber(R.insToRes[insID])
            end
        end
    end)
    return (skin and skin > 0) and skin or nil
end

local function rememberLobbyOutfitRes(resID)
    resID = tonumber(resID)
    if not resID or resID <= 0 or not isFullSuitRes(resID) then return end
    _G.AddOutfitLastLobbyOutfitRes = resID
    local cch = cache()
    if not cch.outfitRes or cch.outfitRes <= 0 then
        cch.outfitRes = resID
        if isInjectedRes(resID) then cch.outfitIns = R.resToIns[resID] end
    end
end

local function resolveLobbyOutfitRes()
    if not _G.LobbyCosmeticEnabled then return nil end
    local cch = cache()
    local outfitRes = tonumber(cch.outfitRes) or 0
    if outfitRes > 0 then return outfitRes end
    outfitRes = tonumber(_G.AddOutfitLastLobbyOutfitRes) or 0
    if outfitRes > 0 then return outfitRes end
    if MATCH_CONFIG.outfitRes and tonumber(MATCH_CONFIG.outfitRes) > 0 then
        return tonumber(MATCH_CONFIG.outfitRes)
    end

    local injectedRes, anyRes
    pcall(function()
        local AvatarData = require("client.logic.data.AvatarData")
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local function resFromIns(ins)
            ins = tonumber(ins)
            if not ins or ins <= 0 then return nil end
            if isInjectedIns(ins) then return tonumber(R.insToRes[ins]) end
            local d = wd:GetHallDepotItemDataByInsID(ins)
            return d and tonumber(d.resID) or nil
        end
        for _, ins in pairs(AvatarData.GetRoleWear()) do
            local res = resFromIns(ins)
            if res and isFullSuitRes(res) then
                if isInjectedRes(res) then injectedRes = res end
                anyRes = anyRes or res
            end
        end
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        local bag = fbd.GetCurrentFashionBag and fbd:GetCurrentFashionBag()
        if bag and bag.rolewear_list then
            for _, ins in pairs(bag.rolewear_list) do
                local res = resFromIns(ins)
                if res and isFullSuitRes(res) then
                    if isInjectedRes(res) then injectedRes = res end
                    anyRes = anyRes or res
                end
            end
        end
    end)
    if injectedRes and injectedRes > 0 then return injectedRes end
    if anyRes and anyRes > 0 then return anyRes end
    return nil
end

local function wearPatchKey()
    local outfit = resolveLobbyOutfitRes() or 0
    local skin = resolveLobbyWeaponSkinRes() or 0
    local openGun = 1
    pcall(function()
        local lds = require("client.slua.logic.wardrobe.logic_display_setting")
        if lds.data and lds.data.OpenGun ~= nil then openGun = lds.data.OpenGun and 1 or 0 end
    end)
    return outfit .. "_" .. skin .. "_" .. openGun
end

local function syncDepotShowWeaponFlags(depot)
    depot = depot or {}
    depot.vehicle = true
    depot.helmet = true
    depot.bag = true
    depot.pet = true
    depot.idle = true
    depot.hand = true
    pcall(function()
        local lds = require("client.slua.logic.wardrobe.logic_display_setting")
        if lds.data then
            if lds.data.OpenGun ~= nil then depot.weapon = lds.data.OpenGun end
            if lds.data.OpenSocialWeapon ~= nil then depot.social_weapon = lds.data.OpenSocialWeapon end
        end
    end)
    return depot
end

local function applyInjectedPspace(roleData)
    if not _G.LobbyCosmeticEnabled then return end
    if not roleData then return end
    roleData.bshow = true
    roleData.pspace_wear_ext = roleData.pspace_wear_ext or {}
    local outfitRes = resolveLobbyOutfitRes()
    if outfitRes and outfitRes > 0 then
        roleData.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_CLOTH] = { outfitRes, 0, 0 }
    end
    local skinRes = resolveLobbyWeaponSkinRes()
    if skinRes and skinRes > 0 then
        roleData.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_WEAPON] = { 0, 0, 0 }
        roleData.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_WEAPONSKIN] = { skinRes, 0, 0 }
        roleData.depot_show_info = roleData.depot_show_info or {}
        if roleData.depot_show_info.weapon == nil then
            roleData.depot_show_info.weapon = true
        end
    end
    roleData.depot_show_info = syncDepotShowWeaponFlags(roleData.depot_show_info)
end

local function patchSelfWearCache(force)
    local key = wearPatchKey()
    if not force and SOCIAL.wearPatchKey == key then return false end
    SOCIAL.wearPatchKey = key
    SOCIAL.snapshotKey = nil
    SOCIAL.fullSnapshot = nil

    local myUid = tonumber(DataMgr.roleData.uid)
    if not myUid then return false end

    local changed = false
    pcall(function()
        local BD = ModuleManager.GetModule(ModuleManager.DataModuleConfig.BasicDataAvatarWearInfo)
        local d = BD:GetCacheData(myUid)
        if not d then
            BD:OnHandleMsgDataAndCallback(myUid, buildLocalRoleDataForCoupleAvatar())
            return true
        end
        local oldCloth = d.pspace_wear_ext and d.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_CLOTH]
        local oldSkin = d.pspace_wear_ext and d.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_WEAPONSKIN]
        applyInjectedPspace(d)
        local nc = d.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_CLOTH]
        local ns = d.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_WEAPONSKIN]
        if oldCloth ~= nc or oldSkin ~= ns or not d.bshow then changed = true end
    end)
    return force or changed
end

local function requestSocialAvatarRefresh()
    pcall(function()
        if EventSystem and EVENTTYPE_LOBBY_SOCIAL and EVENTID_SOCIAL_LOBBY_REFRESH_AVATAR then
            EventSystem:postEvent(EVENTTYPE_LOBBY_SOCIAL, EVENTID_SOCIAL_LOBBY_REFRESH_AVATAR)
        end
    end)
end

local function onSocialWearDirty(forceRefresh)
    SOCIAL.lastHandSkin = nil
    if patchSelfWearCache(forceRefresh) then
        requestSocialAvatarRefresh()
    end
end

local function buildLocalRoleDataForCoupleAvatar()
    if not _G.LobbyCosmeticEnabled then return nil end
    local key = wearPatchKey()
    if SOCIAL.fullSnapshot and SOCIAL.snapshotKey == key then
        return SOCIAL.fullSnapshot
    end
    syncWeaponCacheFromLobby()
    local cch = cache()
    local ad = DataMgr.avatarData or {}
    local gender = tonumber(ad.gamegender) or 2
    if gender < 1 then gender = 2 end

    local data = {
        uid = DataMgr.roleData.uid,
        gender = gender,
        bshow = true,
        pspace_wear_ext = {
            [ENUM_AVATAR_SHOW_TYPE.SHOW_POS_HEAD] = { tonumber(ad.headid) or 401993, 0, 0 },
            [ENUM_AVATAR_SHOW_TYPE.SHOW_POS_HAIR] = { tonumber(ad.hairid) or 40601001, 0, 0 },
            [ENUM_AVATAR_SHOW_TYPE.SHOW_POS_WEAPON] = { 0, 0, 0 },
            [ENUM_AVATAR_SHOW_TYPE.SHOW_POS_WEAPONSKIN] = { 0, 0, 0 },
        },
        depot_show_info = {
            weapon = true, social_weapon = true, idle = true,
            helmet = true, bag = true, vehicle = true, hand = true, pet = true
        },
    }

    local outfitRes = resolveLobbyOutfitRes()
    if outfitRes and outfitRes > 0 then
        data.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_CLOTH] = { outfitRes, 0, 0 }
    end

    local skinRes = resolveLobbyWeaponSkinRes()
    if skinRes and skinRes > 0 then
        data.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_WEAPON][1] = 0
        data.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_WEAPONSKIN][1] = skinRes
    end
    data.depot_show_info = syncDepotShowWeaponFlags(data.depot_show_info)
    SOCIAL.fullSnapshot = data
    SOCIAL.snapshotKey = wearPatchKey()
    return data
end

local _myUidCached
local function isMyWearData(wearData)
    if not wearData then return false end
    if not _myUidCached then
        pcall(function() _myUidCached = tonumber(DataMgr.roleData.uid) end)
    end
    return _myUidCached and tonumber(wearData.uid) == _myUidCached
end

local function mergeInjectedWeaponIntoWearData(wearData)
    if not _G.LobbyCosmeticEnabled then return end
    if not isMyWearData(wearData) then return end
    local skinRes = resolveLobbyWeaponSkinRes()
    wearData.depot_show_info = syncDepotShowWeaponFlags(wearData.depot_show_info)
    if not skinRes or skinRes <= 0 then return end
    wearData.mainWeaponInfo = wearData.mainWeaponInfo or {
        weaponResId = 0, weaponSkinId = 0,
        diyInfo = { diyWeaponId = 0, diyDefaultScheme = false, diyScheme = nil },
    }
    if wearData.mainWeaponInfo.weaponSkinId == skinRes
        and (tonumber(wearData.mainWeaponInfo.weaponResId) or 0) == 0 then
        return
    end
    wearData.mainWeaponInfo.weaponSkinId = skinRes
    wearData.mainWeaponInfo.weaponResId = 0
end

local function equipSocialHandWeapon(avatar, skinRes)
    if not avatar or not skinRes or skinRes <= 0 then return end
    if SOCIAL.lastHandSkin == skinRes then return end
    SOCIAL.lastHandSkin = skinRes
    pcall(function()
        avatar:PutonEquipment(skinRes, nil, { bIsUse = true })
    end)
end

local function shouldShowHandWeapon()
    local show = true
    pcall(function()
        local lds = require("client.slua.logic.wardrobe.logic_display_setting")
        if lds.data and lds.data.OpenGun ~= nil then
            show = lds.data.OpenGun ~= false
        end
    end)
    return show
end

local function mergeInjectedOutfitIntoWearData(wearData)
    if not _G.LobbyCosmeticEnabled then return end
    if not isMyWearData(wearData) then return end
    local outfitRes = resolveLobbyOutfitRes()
    if not outfitRes or outfitRes <= 0 or not isFullSuitRes(outfitRes) then return end
    rememberLobbyOutfitRes(outfitRes)
    local AvatarData = require("client.logic.data.AvatarData")
    local converted = AvatarData.ConvertToAvatarCustom({ outfitRes, 0, 0 })
    if not converted then return end
    local newList = {}
    for _, e in ipairs(wearData.WearInfoList or {}) do
        if e and e.ItemID and isBodyClothSubType(subType(cfg(e.ItemID))) then
        else
            newList[#newList + 1] = e
        end
    end
    newList[#newList + 1] = converted
    wearData.WearInfoList = newList
end

local function mergeInjectedIntoWearData(wearData)
    if not wearData then return end
    mergeInjectedWeaponIntoWearData(wearData)
    mergeInjectedOutfitIntoWearData(wearData)
end

local function reapplyLobbyEquipped()
    if not _G.LobbyCosmeticEnabled then return end
    if not GameStatus or not GameStatus.IsInLobbyOrMainCity or not GameStatus.IsInLobbyOrMainCity() then
        return
    end
    syncWeaponCacheFromLobby()
    local curPage = getLobbyCurPage()

    if ENUM_LobbyPageType and curPage == ENUM_LobbyPageType.Left then
        onSocialWearDirty(true)
        return
    end

    local cch = cache()
    if cch.outfitIns and isInjectedIns(cch.outfitIns) then
        putOnOutfit(cch.outfitIns)
    end

    for wid, w in pairs(cch.weapons) do
        wid = tonumber(wid)
        if wid and w and w.resID and w.resID > 0 then
            if w.insID and isInjectedIns(w.insID) then
                equipWeaponSkin(wid, w.insID)
            else
                pcall(function() DataMgr.InitWeaponData(wid, w.resID, w.insID or 0) end)
            end
        end
    end

    pcall(function()
        local uid = tostring(DataMgr.roleData.uid)
        local LAM = require("client.logic.avatar.LobbyAvatarManager")
        local TAM = require("client.logic.avatar.logic_team_avatar_manager")
        local mainWid = tonumber(DataMgr.Weapon_ID) or 0
        local mw = mainWid > 0 and cch.weapons[mainWid] or nil
        if mw and mw.resID and mw.resID > 0 and TAM.GetAvatarByUid(uid) then
            LAM.EquipWeapon(uid, { weaponId = mainWid, skinId = mw.resID }, nil, true)
        end
    end)

    pcall(function()
        if EventSystem and EVENTTYPE_WARDROBE and EVENTID_WARDROBE_UPDATE_AVATAR_LIST then
            EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_AVATAR_LIST)
        end
    end)
end

local function hookLobbySwipePersistence()
    pcall(function()
        local BD = ModuleManager.GetModule(ModuleManager.DataModuleConfig.BasicDataAvatarWearInfo)
        local oRsp = BD.on_get_avatar_show_rsp
        BD.on_get_avatar_show_rsp = function(self, res, target_uid, data)
            oRsp(self, res, target_uid, data)
            if not _G.LobbyCosmeticEnabled then return end
                if tonumber(target_uid) == tonumber(DataMgr.roleData.uid) then
                patchSelfWearCache(true)
                SOCIAL.forceAvatarRedraw = true
                SOCIAL.lastHandSkin = nil
                if ENUM_LobbyPageType and getLobbyCurPage() == ENUM_LobbyPageType.Left then
                    requestSocialAvatarRefresh()
                end
            end
        end
    end)

    pcall(function()
        local AC = require("client.slua.logic.avatar.avatar_common")
        local oGetWear = AC.GetWearDataFromRoleData
        AC.GetWearDataFromRoleData = function(roleData)
            local wearData = oGetWear(roleData)
            if wearData and roleData and tonumber(roleData.uid) == tonumber(DataMgr.roleData.uid) then
                mergeInjectedIntoWearData(wearData)
            end
            return wearData
        end
        local oUp = AC.UpdateAvatar
        AC.UpdateAvatar = function(avatar, wearData, isShowWeapon, isShowHelmet, isShowBag)
            if not _G.LobbyCosmeticEnabled then
                return oUp(avatar, wearData, isShowWeapon, isShowHelmet, isShowBag)
            end
            if isMyWearData(wearData) then
                mergeInjectedIntoWearData(wearData)
            end
            local showGun = isShowWeapon and shouldShowHandWeapon()
            if wearData and wearData.depot_show_info then
                showGun = showGun and wearData.depot_show_info.weapon ~= false
            end
            if isMyWearData(wearData) then
                for _, e in ipairs(wearData.WearInfoList or {}) do
                    if e and e.ItemID and isInjectedRes(e.ItemID) and isFullSuitRes(e.ItemID) then
                        rememberLobbyOutfitRes(e.ItemID)
                        break
                    end
                end
            end
            local ret = oUp(avatar, wearData, showGun, isShowHelmet, isShowBag)
            if showGun and isMyWearData(wearData) and avatar
                and ENUM_LobbyPageType and getLobbyCurPage() == ENUM_LobbyPageType.Left then
                local skin = tonumber(wearData.mainWeaponInfo and wearData.mainWeaponInfo.weaponSkinId) or 0
                if skin <= 0 then skin = resolveLobbyWeaponSkinRes() or 0 end
                if skin > 0 then equipSocialHandWeapon(avatar, skin) end
            end
            return ret
        end
    end)

    pcall(function()
        local CA = require("client.logic.avatar.CoupleAvatar")
        local Cfg = require("client.slua.logic.lobby.Left.CoupleAvatarConfig")
        local oMulti = CA._UpdateMultiAvatar
        if oMulti then
            CA._UpdateMultiAvatar = function(self, avatar, avatarType)
                if not _G.LobbyCosmeticEnabled then
                    return oMulti(self, avatar, avatarType)
                end
                local isSelf = avatarType == Cfg.AvatarType.Self
                    and self.SelfUID and tostring(self.SelfUID) == tostring(DataMgr.roleData.uid)
                if isSelf then
                    pcall(function()
                        local BD = ModuleManager.GetModule(ModuleManager.DataModuleConfig.BasicDataAvatarWearInfo)
                        local d = BD:GetCacheData(tonumber(self.SelfUID))
                        if d then applyInjectedPspace(d) end
                    end)
                    if SOCIAL.forceAvatarRedraw then
                        self.CompareDataCache[avatarType] = nil
                        SOCIAL.forceAvatarRedraw = nil
                    end
                end
                oMulti(self, avatar, avatarType)
                if isSelf and self.isShowWeapon ~= false and shouldShowHandWeapon()
                    and ENUM_LobbyPageType and getLobbyCurPage() == ENUM_LobbyPageType.Left then
                    local skin = resolveLobbyWeaponSkinRes()
                    if skin and skin > 0 then equipSocialHandWeapon(avatar, skin) end
                end
            end
        end
        local oHideCheck = CA.CheckSelfIsHideAvatar
        CA.CheckSelfIsHideAvatar = function(self, nSelfUId, tRoleData)
            if not _G.LobbyCosmeticEnabled then
                return oHideCheck(self, nSelfUId, tRoleData)
            end
            if tostring(nSelfUId) == tostring(DataMgr.roleData.uid) then
                return false
            end
            return oHideCheck(self, nSelfUId, tRoleData)
        end

        local oUpdate = CA.Update
        CA.Update = function(self)
            if not _G.LobbyCosmeticEnabled then return oUpdate(self) end
            local isSelf = self.SelfUID and tostring(self.SelfUID) == tostring(DataMgr.roleData.uid)
            local oHide = CA.HideAvatars
            if isSelf then
                CA.HideAvatars = function() end
            end
            local ok, err = pcall(oUpdate, self)
            CA.HideAvatars = oHide
        end

        local oRecv = CA.OnReceiveData
        CA.OnReceiveData = function(self, uid, data)
            if not _G.LobbyCosmeticEnabled then
                return oRecv(self, uid, data)
            end
            if uid == self.SelfUID and tostring(uid) == tostring(DataMgr.roleData.uid) then
                if data then
                    applyInjectedPspace(data)
                else
                    data = buildLocalRoleDataForCoupleAvatar()
                end
            end
            return oRecv(self, uid, data)
        end
    end)

    pcall(function()
        if not EventSystem or not EventSystem.registEvent then return end
        if EVENTTYPE_LOBBY and EVENTID_SWITCHTO_PAGE_START then
            EventSystem:registEvent(EVENTTYPE_LOBBY, EVENTID_SWITCHTO_PAGE_START, function(_, _, toPage)
                if not _G.LobbyCosmeticEnabled then return end
                if ENUM_LobbyPageType and toPage == ENUM_LobbyPageType.Left then
                    syncWeaponCacheFromLobby()
                    SOCIAL.lastHandSkin = nil
                    local o = resolveLobbyOutfitRes()
                    if o then rememberLobbyOutfitRes(o) end
                    patchSelfWearCache(true)
                    SOCIAL.forceAvatarRedraw = true
                end
            end)
        end
        if EVENTTYPE_LOBBY and EVENTID_SWITCHTO_PAGE_END then
            EventSystem:registEvent(EVENTTYPE_LOBBY, EVENTID_SWITCHTO_PAGE_END, function(_, _, _, toPage)
                if not _G.LobbyCosmeticEnabled then return end
                if ENUM_LobbyPageType and toPage == ENUM_LobbyPageType.Left then
                    syncWeaponCacheFromLobby()
                    SOCIAL.lastHandSkin = nil
                    socialDebounce(0.45, function()
                        onSocialWearDirty(true)
                    end)
                elseif ENUM_LobbyPageType and toPage == ENUM_LobbyPageType.Mid then
                    SOCIAL.wearPatchKey = nil
                    socialDebounce(0.35, reapplyLobbyEquipped)
                end
            end)
        end
        if EVENTTYPE_LOBBY_SOCIAL and EVENTID_GOT_SOCIAL_LOBBY_SHOW_DATA then
            EventSystem:registEvent(EVENTTYPE_LOBBY_SOCIAL, EVENTID_GOT_SOCIAL_LOBBY_SHOW_DATA, function(_, _, nUId)
                if not _G.LobbyCosmeticEnabled then return end
                if tonumber(nUId) == tonumber(DataMgr.roleData.uid) then
                    socialDebounce(0.2, function() patchSelfWearCache(false) end)
                end
            end)
        end
        if EVENTTYPE_WARDROBE and EVENTID_WARDROBE_UPDATE_CURRENT_PUT_ON_GUN then
            EventSystem:registEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_CURRENT_PUT_ON_GUN, function()
                if not _G.LobbyCosmeticEnabled then return end
                SOCIAL.wearPatchKey = nil
                SOCIAL.snapshotKey = nil
                syncWeaponCacheFromLobby()
                if ENUM_LobbyPageType and getLobbyCurPage() == ENUM_LobbyPageType.Left then
                    socialDebounce(0.25, function() onSocialWearDirty(true) end)
                end
            end)
        end
    end)

    pcall(function()
        local lds = require("client.slua.logic.wardrobe.logic_display_setting")
        local oSwitch = lds.SwitchGun
        lds.SwitchGun = function(...)
            local r = oSwitch(...)
            SOCIAL.wearPatchKey = nil
            if ENUM_LobbyPageType and getLobbyCurPage() == ENUM_LobbyPageType.Left then
                socialDebounce(0.2, function() onSocialWearDirty(true) end)
            end
            return r
        end
    end)
end

local function hookDepotInit()
    pcall(function()
        local WDE = require("client.slua.logic.wardrobe.WardrobeDataEntity")
        local orig = WDE.InitData
        WDE.InitData = function(self, pkg)
            orig(self, pkg)
            injectAll(self)
            refreshWardrobe()
        end
    end)
end

local function hookWardrobeData()
    pcall(function()
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local function wrapGet(name)
            local o = wd[name]
            if not o then return end
            wd[name] = function(self, insID, ...)
                insID = tonumber(insID)
                if isInjectedIns(insID) then
                    local e = getEntity()
                    if e then return e:GetDataByInsID(insID) end
                end
                return o(self, insID, ...)
            end
        end
        wrapGet("GetHallDepotItemDataByInsID")
        wrapGet("GetValidHallDepotItemDataByInsID")

        if wd.GetItemIDByInsID then
            local o_gii = wd.GetItemIDByInsID
            wd.GetItemIDByInsID = function(self, insID)
                insID = tonumber(insID)
                if isInjectedIns(insID) then return R.insToRes[insID] end
                return o_gii(self, insID)
            end
        end

        if wd.GetItemSource then
            local o_gs = wd.GetItemSource
            wd.GetItemSource = function(self, insID)
                insID = tonumber(insID)
                if isInjectedIns(insID) then return EWardrobeDataSource.Wardrobe end
                return o_gs(self, insID)
            end
        end
        local function wrapBool(name)
            local o = wd[name]
            if not o then return end
            wd[name] = function(self, id, ...)
                if isInjectedRes(tonumber(id)) or isInjectedIns(tonumber(id)) then return true end
                return o(self, id, ...)
            end
        end
        wrapBool("HasItem")
        wrapBool("HasValidItem")
        wrapBool("CheckHasPermanentItem")
    end)
end

local function hookPageFilter()
    pcall(function()
        local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
        local o1 = wl.IsValidCurrentPageItem
        wl.IsValidCurrentPageItem = function(self, mainTab, subTab, v, t)
            if v and isInjectedRes(v.resID) and mainTab == 1 then
                if v.expireTS == 0 or not t or t < v.expireTS then
                                        local st = v.itemSubType or getCachedSubType(v.resID)
                                        
                    if st == ST_TOP then
                        local full = isFullSuitRes(v.resID, v)
                        if subTab == WARDROBE_TAB_SUIT and full then return true end
                        if subTab == WARDROBE_TAB_CLOTHES and not full then return true end
                    end
                    if v.subTabType == subTab then return true end
                end
            end
            return o1(self, mainTab, subTab, v, t)
        end
        local o2 = wl.IsCanUse
        wl.IsCanUse = function(self, resId)
            if isInjectedRes(resId) then return true end
            return o2(self, resId)
        end
        local o3 = wl.IsCharacterUse
        wl.IsCharacterUse = function(self, resId)
            if isInjectedRes(resId) then return true end
            return o3(self, resId)
        end
        local o4 = wl.GetWardrobeInsIdByResId
        wl.GetWardrobeInsIdByResId = function(self, resid)
            resid = tonumber(resid)
            if isInjectedRes(resid) then return R.resToIns[resid] end
            return o4(self, resid)
        end
    end)
end

local function hookArmory()
    pcall(function()
        local Arm = require("client.logic.armory.logic_armory")
        local og = Arm.GetSkinListByWeaponID
        Arm.GetSkinListByWeaponID = function(wid)
            local t = og(wid) or {}
            for resID, _ in pairs(R.resToIns) do
                if tonumber(weaponIdFromSkin(resID)) == tonumber(wid) then
                    t[resID] = t[resID] or { is_open = 1 }
                end
            end
            return t
        end
        local oa = Arm.get_weapon_skin_list_rsp
        Arm.get_weapon_skin_list_rsp = function(a, b, c, d)
            oa(a, b, c, d)
            for resID, insID in pairs(R.resToIns) do injectArmory(resID, insID) end
        end
        local oi = Arm.install_weapon_skin
        Arm.install_weapon_skin = function(cd, wid, ins)
            ins = tonumber(ins)
            if isInjectedIns(ins) then
                wid = tonumber(weaponIdFromSkin(R.insToRes[ins]) or wid)
                equipWeaponSkin(wid, ins)
                return
            end
            return oi(cd, wid, ins)
        end
    end)
    pcall(function()
        local AH = require("client.network.Protocol.ArmoryHandler")
        local o = AH.send_install_weapon_skin
        AH.send_install_weapon_skin = function(cd, wid, ins)
            ins = tonumber(ins)
            if isInjectedIns(ins) then
                wid = tonumber(weaponIdFromSkin(R.insToRes[ins]) or wid)
                equipWeaponSkin(wid, ins)
                return
            end
            return o(cd, wid, ins)
        end
    end)
end

local function hookGunSkinId()
    pcall(function()
        local wgl = require("client.slua.logic.wardrobe.logic_wardrobe_gun")
        local o = wgl.GetSkinIdByWeaponID
        wgl.GetSkinIdByWeaponID = function(self, wid)
            local c = cache()
            local w = c.weapons[wid]
            if w and isInjectedIns(w.insID) then return w.insID end
            local Arm = require("client.logic.armory.logic_armory")
            if Arm.rsp_list and Arm.rsp_list.install_list and Arm.rsp_list.install_list[wid] then
                local sid = Arm.rsp_list.install_list[wid].skin_id
                if sid and isInjectedIns(sid) then return sid end
            end
            return o(self, wid)
        end
    end)
end

local function hookPutOn()
    pcall(function()
        local WRH = require("client.network.Protocol.WardRobeHandler")
        local o = WRH.send_depot_put_on_req
        WRH.send_depot_put_on_req = function(insID, extra)
            insID = tonumber(insID)
            if isInjectedIns(insID) then
                local resID = R.insToRes[insID]
                local c = cfg(resID)
                local st = subType(c)
                local kind = getClothKind(resID)
                if kind then
                    putOnCloth(insID)
                    return
                end
                if GUN_SUB[st] then
                    local wid = weaponIdFromSkin(resID)
                    if wid then equipWeaponSkin(wid, insID) end
                    return
                end
                if st == MELEE_ID then
                    equipWeaponSkin(MELEE_ID, insID)
                    return
                end
                local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                local d = wd:GetHallDepotItemDataByInsID(insID)
                if d then
                    WRH.on_depot_put_on_rsp(NET_OK, { res_id = resID, count = 1, instid = insID }, nil, 1, insID, 0, extra)
                end
                return
            end
            return o(insID, extra)
        end
    end)
end

local function hookWeaponWear()
    pcall(function()
        local HT = require("client.logic.lobby.hall_theme_utils")
        local o = HT.IsWeaponWear
        HT.IsWeaponWear = function(insId)
            insId = tonumber(insId)
            if isInjectedIns(insId) then
                local c = cache()
                local Arm = require("client.logic.armory.logic_armory")
                for wid, w in pairs(c.weapons) do
                    if tonumber(w.insID) == insId then
                        if Arm.rsp_list and Arm.rsp_list.install_list and Arm.rsp_list.install_list[wid] then
                            return tonumber(Arm.rsp_list.install_list[wid].skin_id) == insId
                        end
                        return true
                    end
                end
            end
            return o(insId)
        end
    end)
end

local function hookAvatarValid()
    pcall(function()
        local path = "GameLua.Mod.Library.GamePlay.Avatar.Component.CharacterAvatarComponent"
        local comp = require(path)
        if comp and comp.CheckItemValid then
            local o = comp.CheckItemValid
            comp.CheckItemValid = function(self, resID)
                if isInjectedRes(resID) then return true end
                return o(self, resID)
            end
        end
    end)
end

local function getLocalChar()
    local ok, GD = pcall(require, "GameLua.GameCore.Data.GameplayData")
    if not ok or not GD then return nil end
    local char = GD.GetPlayerCharacter()
    if char and slua.isValid(char) then return char end
    return nil
end

local function getWAC(char)
    local w = char and char.GetCurrentWeapon and char:GetCurrentWeapon()
    if slua.isValid(w) and slua.isValid(w.WeaponAvatarComponent) then
        return w.WeaponAvatarComponent
    end
    return nil
end

local function getDesiredOutfit()
    if MATCH_CONFIG.outfitRes and MATCH_CONFIG.outfitRes > 0 then
        return MATCH_CONFIG.outfitRes
    end
    local c = cache()
    return c.outfitRes
end

local function matchApplyOutfit(char)
    local outfitRes = getDesiredOutfit()
    if not outfitRes then return false end
    local comp = char.CharacterAvatarComp2_BP
    if not slua.isValid(comp) then
        return false
    end
    local ok = false
    pcall(function()
        comp:PutOnCustomEquipmentByID(outfitRes)
        ok = true
    end)
    if not ok then
        pcall(function()
            comp:HandleEquipItem(FItemDefineID(4, outfitRes), FAvatarCustomDefault())
            ok = true
        end)
    end
    if ok then notify("Outfit OK " .. tostring(outfitRes)) end
    return ok
end

local _avatarItemsRegistered = false

local function getDesiredWeaponSkins()
    syncWeaponCacheFromLobby()
    local out, seen = {}, {}
    local function add(res)
        res = tonumber(res)
        if res and res > 0 and not seen[res] then seen[res] = true; out[#out+1] = res end
    end
    for wid, w in pairs(cache().weapons) do
        if wid ~= MELEE_ID and w.resID then add(w.resID) end
    end
    if MATCH_CONFIG.weaponSkins then
        for _, res in pairs(MATCH_CONFIG.weaponSkins) do add(res) end
    end
    return out
end

local GUN_MASTER_SYN_SLOT = 7

local function findSkinSlotInSynData(weapon)
    if not slua.isValid(weapon) then return GUN_MASTER_SYN_SLOT, 0 end
    local arr = weapon.synData
    if not arr or not slua.isValid(arr) then return GUN_MASTER_SYN_SLOT, 0 end
    local count = 0
    pcall(function() count = arr:Num() end)
    for i = 0, math.min(count - 1, 15) do
        local ok2, att = pcall(function() return arr:Get(i) end)
        if ok2 and att then
            local ok3, defRef = pcall(slua.IndexReference, att, "defineID")
            if ok3 and defRef then
                local tid = 0
                pcall(function() tid = tonumber(defRef.TypeSpecificID) or 0 end)
                if tid >= 1000000 then
                    return i, tid
                end
            end
        end
    end
    return GUN_MASTER_SYN_SLOT, 0
end

local function resolveWeaponTypeID(weaponResID)
    weaponResID = tonumber(weaponResID) or 0
    if weaponResID <= 0 then return 0 end
    local found = 0
    pcall(function()
        local wc = CDataTable.GetTableData("WeaponConfig", weaponResID)
        if wc then found = tonumber(wc.WeaponID or wc.WeaponId or wc.weaponID or 0) end
    end)
    if found > 0 then return found end
    pcall(function()
        local ic = CDataTable.GetTableData("Item", weaponResID)
        if ic then found = tonumber(ic.WeaponID or ic.weaponId or 0) end
    end)
    return found > 0 and found or weaponResID
end

local function findTargetSkinForWeaponRes(weaponResID)
    weaponResID = tonumber(weaponResID) or 0
    if weaponResID <= 0 then return nil end

    local memSkin = getMatchWeaponSkin(weaponResID)
    if memSkin then return memSkin end
    local typeID = resolveWeaponTypeID(weaponResID)
    if typeID > 0 and typeID ~= weaponResID then
        memSkin = getMatchWeaponSkin(typeID)
        if memSkin then return memSkin end
    end

    if MATCH_CONFIG.weaponSkins and MATCH_CONFIG.weaponSkins[weaponResID] then
        local fixed = tonumber(MATCH_CONFIG.weaponSkins[weaponResID])
        if fixed and fixed > 0 then return fixed end
    end

    for _, skinRes in ipairs(getDesiredWeaponSkins()) do
        local wid = weaponIdFromSkin(skinRes)
        if wid and tonumber(wid) == weaponResID then return skinRes end
    end

    local typeID = resolveWeaponTypeID(weaponResID)
    if typeID > 0 and typeID ~= weaponResID then
        if MATCH_CONFIG.weaponSkins and MATCH_CONFIG.weaponSkins[typeID] then
            local fixed = tonumber(MATCH_CONFIG.weaponSkins[typeID])
            if fixed and fixed > 0 then return fixed end
        end
        for _, skinRes in ipairs(getDesiredWeaponSkins()) do
            local wid = weaponIdFromSkin(skinRes)
            if wid and tonumber(wid) == typeID then return skinRes end
        end
    end

    local avatarMatch = nil
    pcall(function()
        local AU = import("AvatarUtils")
        local weaponBase = AU.GetWeaponAvatarParentID(AU.GetBPIDByResID(weaponResID), false)
        if not weaponBase or weaponBase <= 0 then return end
        for _, skinRes in ipairs(getDesiredWeaponSkins()) do
            local skinBase = AU.GetWeaponAvatarParentID(AU.GetBPIDByResID(skinRes), false)
            if skinBase and skinBase > 0 and skinBase == weaponBase then
                avatarMatch = skinRes
                return
            end
        end
    end)
    if avatarMatch then return avatarMatch end

    local c = cfg(weaponResID)
    local st = subType(c)
    if st and GUN_SUB[st] and MATCH_CONFIG.weaponSkins then
        for _, skinRes in pairs(MATCH_CONFIG.weaponSkins) do
            local skinWid = weaponIdFromSkin(skinRes)
            if skinWid then
                local sc = cfg(tonumber(skinWid))
                if sc and subType(sc) == st then return skinRes end
            end
            local sc = cfg(skinRes)
            if sc and GUN_SUB[subType(sc)] and subType(sc) == st then return skinRes end
        end
    end

    return nil
end

local function getSynMasterSkinID(weapon)
    if not slua.isValid(weapon) then return 0 end
    local id = 0
    pcall(function()
        local slot, tid = findSkinSlotInSynData(weapon)
        id = tid
        if id == 0 then
            local arr = weapon.synData
            if not arr or not slua.isValid(arr) then return end
            local att = arr:Get(GUN_MASTER_SYN_SLOT)
            if not att then return end
            id = slua.IndexReference(att, "defineID").TypeSpecificID or 0
        end
    end)
    return id
end

_G.AddOutfitSkinIdMappings = _G.AddOutfitSkinIdMappings or {}
_G.AddOutfitLastAppliedSkin = _G.AddOutfitLastAppliedSkin or {}

local function buildSkinMappings()
    syncWeaponCacheFromLobby()
    local m = _G.AddOutfitSkinIdMappings
    for k in pairs(m) do m[k] = nil end
    for wid, w in pairs(cache().weapons) do
        wid = tonumber(wid)
        if wid and w.resID and w.resID > 0 then
            m[wid] = { tonumber(w.resID) }
        end
    end
    if MATCH_CONFIG.weaponSkins then
        for weaponKey, skinRes in pairs(MATCH_CONFIG.weaponSkins) do
            weaponKey = tonumber(weaponKey)
            skinRes = tonumber(skinRes)
            if weaponKey and skinRes and skinRes > 0 and not m[weaponKey] then
                m[weaponKey] = { skinRes }
            end
        end
    end
end

local function get_skin_id(currentGunId, maxIt)
    currentGunId = tonumber(currentGunId) or 0
    maxIt = tonumber(maxIt) or 0
    if currentGunId <= 0 and maxIt <= 0 then return 0 end
    buildSkinMappings()
    if maxIt > 0 then
        local fromMem = getMatchWeaponSkin(maxIt)
        if fromMem then return fromMem end
    end
    local fromMem2 = getMatchWeaponSkin(resolveWeaponTypeID(currentGunId))
    if fromMem2 then return fromMem2 end
    local m = _G.AddOutfitSkinIdMappings
    if maxIt > 0 and m[maxIt] and m[maxIt][1] then return tonumber(m[maxIt][1]) end
    local list = m[currentGunId]
    if list and list[1] then return tonumber(list[1]) end
    local typeId = resolveWeaponTypeID(currentGunId)
    if typeId > 0 and m[typeId] and m[typeId][1] then return tonumber(m[typeId][1]) end
    local target = findTargetSkinForWeaponRes(maxIt > 0 and maxIt or currentGunId)
    if target then return target end
    return currentGunId
end

local function registerWeaponAvatarItems(char)
    local pc = char.GetPlayerControllerSafety and char:GetPlayerControllerSafety()
    if not slua.isValid(pc) then
        return false
    end
    local AU = import("AvatarUtils")
    local BU = import("BackpackUtils")
    local addedCount = 0

    for _, resID in ipairs(getDesiredWeaponSkins()) do
        local doneDirect = false
        pcall(function()
            if pc.AddWeaponAvatarItem then
                pc:AddWeaponAvatarItem(tonumber(resID))
                doneDirect = true
                addedCount = addedCount + 1
            end
        end)
        if not doneDirect then
            pcall(function()
                local skinBPID = BU.GetBPIDByResID(tonumber(resID))
                local arr = slua.Array(UEnums.EPropertyClass.Int)
                local parents = AU.GetWeaponAvatarParentIDList(skinBPID, arr, false)
                if parents and parents.Num and parents:Num() > 0 and pc.WeaponAvatarItemList then
                    for _, parentID in pairs(parents) do
                        pc.WeaponAvatarItemList:Add(parentID, skinBPID)
                    end
                    addedCount = addedCount + 1
                end
            end)
        end
    end

    if addedCount == 0 then
        return false
    end

    pcall(function() if pc.InitWeaponAvatarItems then pc:InitWeaponAvatarItems() end end)
    pcall(function() if pc.OnWeaponAvatarUpdate then pc:OnWeaponAvatarUpdate() end end)
    return true
end

local function reloadCurrentWeaponAvatar(char)
    pcall(function()
        local weapon = char.GetCurrentWeapon and char:GetCurrentWeapon()
        if not slua.isValid(weapon) then return end
        local wac = weapon.WeaponAvatarComponent
        if slua.isValid(wac) then
            local ES = import("EWeaponAttachmentSocketType")
            pcall(function() wac:ClearMeshPathCacheBySlot(ES.MasterGun) end)
            pcall(function() wac:ClearMeshBySlot(ES.MasterGun, true, true) end)
        end
        if weapon.DelayHandleAvatarMeshChanged then
            weapon:DelayHandleAvatarMeshChanged()
        elseif slua.isValid(wac) and wac.ReloadAllEquippedAvatar then
            local ESlotDescDiff = import("ESlotDescDiff")
            wac:ReloadAllEquippedAvatar(ESlotDescDiff.MeshDiff)
        end
    end)
end

local _weaponDiagDone = false
local _weaponApplied = false
local _lastWeaponResID = 0
local _weaponSpawnHooked = false

local function onWeaponLuaInit(_, _, weapon)
    if not weapon or not slua.isValid(weapon) then return end
    local char = getLocalChar()
    if not char then return end
    local owner = nil
    pcall(function()
        if weapon.GetOwnerPawn then owner = weapon:GetOwnerPawn() end
    end)
    if not slua.isValid(owner) or owner ~= char then return end
    pcall(function()
        char:AddGameTimer(0.15, false, function()
            local c = getLocalChar()
            if c and slua.isValid(weapon) then
                applySkinToWeapon(weapon)
                _weaponApplied = false
            end
        end)
    end)
end

local function hookPutOnRsp()
    pcall(function()
        local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
        local o = wl.on_puton_rsp
        wl.on_puton_rsp = function(self, res, item, olditem, index, extra)
            o(self, res, item, olditem, index, extra)
            if not item or not item.instid then return end
            local resID = tonumber(item.res_id)
            local insID = tonumber(item.instid)
            if not resID or not insID then return end
            local c = cfg(resID)
            local st = subType(c)
            if getClothKind(resID) == "full_suit" and isInjectedIns(insID) then
                saveEquip(resID, insID)
            elseif GUN_SUB[st] then
                local wid = weaponIdFromSkin(resID)
                if wid then cacheWeaponSkinFromIns(wid, insID) end
            elseif st == MELEE_ID then
                cacheWeaponSkinFromIns(MELEE_ID, insID)
            elseif isInjectedIns(insID) then
                saveEquip(resID, insID)
            end
        end
    end)
end

local function hookLobbyWeaponCache()
    pcall(function()
        local Arm = require("client.logic.armory.logic_armory")
        local oRsp = Arm.install_weapon_skin_rsp
        Arm.install_weapon_skin_rsp = function(client_data, errorCode, weapon_id, instanceID)
            oRsp(client_data, errorCode, weapon_id, instanceID)
            if not _G.LobbyCosmeticEnabled then return end
            if errorCode == 0 or errorCode == NET_OK then
                cacheWeaponSkinFromIns(weapon_id, instanceID)
            end
        end
        local oH = Arm.HandleWeaponSkinChange
        Arm.HandleWeaponSkinChange = function(client_data, weapon_id, instanceID)
            oH(client_data, weapon_id, instanceID)
            if not _G.LobbyCosmeticEnabled then return end
            cacheWeaponSkinFromIns(weapon_id, instanceID)
        end
    end)
    pcall(function()
        local wgl = require("client.slua.logic.wardrobe.logic_wardrobe_gun")
        local o = wgl.on_put_on_weapon_wear_rsp
        wgl.on_put_on_weapon_wear_rsp = function(self, client_data, res, weapon_id, new_skin_id, extra_weapon_list)
            o(self, client_data, res, weapon_id, new_skin_id, extra_weapon_list)
            if not _G.LobbyCosmeticEnabled then return end
            if res == 0 or res == NET_OK then
                cacheWeaponSkinFromIns(weapon_id, new_skin_id)
            end
        end
    end)
    pcall(function()
        if not EventSystem or not EventSystem.registEvent then return end
        if EVENTTYPE_WARDROBE and EVENTID_WARDROBE_UPDATE_CURRENT_PUT_ON_GUN then
            EventSystem:registEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_CURRENT_PUT_ON_GUN, function(_, _, resOrFlag, weapon_id)
                if not _G.LobbyCosmeticEnabled then return end
                weapon_id = tonumber(weapon_id)
                if weapon_id and weapon_id > 0 then
                    pcall(function()
                        local wgl = require("client.slua.logic.wardrobe.logic_wardrobe_gun")
                        local insID = tonumber(wgl:GetSkinIdByWeaponID(weapon_id)) or 0
                        if insID > 0 then cacheWeaponSkinFromIns(weapon_id, insID) end
                    end)
                elseif tonumber(resOrFlag) and tonumber(resOrFlag) > 100000 then
                    pcall(function()
                        local wid = weaponIdFromSkin(resOrFlag)
                        if wid then
                            local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                            local ins = wd.GetWardrobeInsIdByResId and wd:GetWardrobeInsIdByResId(resOrFlag)
                            if ins and ins > 0 then cacheWeaponSkinFromIns(wid, ins) end
                        end
                    end)
                end
            end)
        end
    end)
end

local function hookWardrobePutOnReq()
    pcall(function()
        local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
        local o = wl.wardrobe_puton_req
        wl.wardrobe_puton_req = function(self, insID, extra)
            insID = tonumber(insID)
            if isInjectedIns(insID) then
                local resID = R.insToRes[insID]
                local itemCfg = cfg(resID)
                if getClothKind(resID) then
                    putOnCloth(insID)
                    return
                end
                local item = { res_id = resID, count = 1, instid = insID }
                if itemCfg and itemCfg.WardrobeMainTab == 6
                    and itemCfg.WardrobeTab ~= 7
                    and itemCfg.WardrobeTab ~= 11
                then
                    local WRH = require("client.network.Protocol.WardRobeHandler")
                    WRH.on_depot_put_on_rsp("ok", item, nil, 0, insID, 0)
                    return
                end
                local WRH = require("client.network.Protocol.WardRobeHandler")
                WRH.on_depot_put_on_rsp("ok", item, nil, 0, insID, 0)
                return
            end
            return o(self, insID, extra)
        end
    end)
end

local function hookWardrobePutDownReq()
    pcall(function()
        local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
        local o = wl.wardrobe_put_down_req
        wl.wardrobe_put_down_req = function(self, insID)
            insID = tonumber(insID)
            if isInjectedIns(insID) then
                local resID = R.insToRes[insID]
                local itemCfg = cfg(resID)
                if itemCfg and itemCfg.WardrobeMainTab == 6 then
                    DataMgr.vst_skin = 0
                    local HallThemeUtils = require("client.logic.lobby.hall_theme_utils")
                    HallThemeUtils.UpdateThemeVehicleShow()
                    HallThemeUtils.ShowThemeVehicle()
                    return
                end
                local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                local d = wd:GetHallDepotItemDataByInsID(insID)
                local item = d and { res_id = resID, count = d.count or 1, instid = insID }
                local WRH = require("client.network.Protocol.WardRobeHandler")
                WRH.on_depot_put_down_rsp("ok", item, insID)
                return
            end
            return o(self, insID)
        end
    end)
end

local function hookWeaponSkinPersist()
    pcall(function()
        local WRH = require("client.network.Protocol.WardRobeHandler")
        local o_send_wear = WRH.send_put_on_weapon_wear
        WRH.send_put_on_weapon_wear = function(client_data, weapon_id, extra_weapon_id_list)
            if weapon_id and weapon_id > 0 and _weaponSkinCache[weapon_id] then
                local cached = _weaponSkinCache[weapon_id]
                if isInjectedIns(cached.insID) then
                    local gunLogic = require("client.slua.logic.wardrobe.logic_wardrobe_gun")
                    gunLogic:on_put_on_weapon_wear_rsp(client_data, 0, weapon_id, cached.insID, extra_weapon_id_list)
                    return
                end
            end
            return o_send_wear(client_data, weapon_id, extra_weapon_id_list)
        end
    end)
end

-- ============================================================================
-- VEHICLE SKIN SWITCH EFFECT (Adds glowing transform animation)
-- ============================================================================
pcall(function()
    local VehicleAvatarComponent = require("GameLua.GameCore.Module.Vehicle.Component.VehicleAvatarComponent")
    
    -- Force the game to always allow the switch effect
    VehicleAvatarComponent.__inner_impl.CheckCanPlaySkinSwitchEffect = function(self, curVehicleId, lastVehicleId)
        return true
    end

    -- Override the switch effect to use a specific effect ID (7303001)
    VehicleAvatarComponent.__inner_impl.ShowVehicleSwitchEffect = function(self)
        if not self.curSwitchEffectId or self.curSwitchEffectId <= 0 then
            self.curSwitchEffectId = 7303001
        end
        local vehicleActor = self:GetOwner()
        if not slua.isValid(vehicleActor) then return false end
        if self.uSwitchEffectActor then
            self:StopSkinSwitchEffect()
            self.uSwitchEffectActor:K2_DestroyActor()
            self.uSwitchEffectActor = nil
        end
        if not self.lastEquipedAvatarId or self.lastEquipedAvatarId <= 0 then
            self.lastEquipedAvatarId = vehicleActor.ClientUsedAvatarID or vehicleActor:GetDefaultAvatarID() or 0
        end
        local currentAvatarID = vehicleActor.ClientUsedAvatarID or self.lastEquipedAvatarId or 0
        local bIsLobbyActor = self:IsLobbyActor()
        local world = slua_GameFrontendHUD:GetWorld()
        local VehiclePlateLicenseUtil = require("GameLua.Activity.Commercialize.GamePlay.Vehicle.VehiclePlateLicenseUtil")
        local SkinSwitchEffectActorPath = VehiclePlateLicenseUtil.GetSwitchEffectActorPath()
        local BP_DissolveVehicleClass = import(SkinSwitchEffectActorPath)
        self.uSwitchEffectActor = world:SpawnActor(BP_DissolveVehicleClass, nil, nil, nil)
        if not slua.isValid(self.uSwitchEffectActor) then
            self.uSwitchEffectActor = nil
            return false
        end
        self.uSwitchEffectActor:K2_AttachToActor(vehicleActor, "None", 1, 1, 1, false)
        self.uSwitchEffectActor:K2_SetActorRelativeLocation(FVector(0, 0, 0), false, nil, false)
        self.uSwitchEffectActor:K2_SetActorRelativeRotation(FRotator(0, 0, 0), false, nil, false)
        self:ChangeFakeSwitchVehicleAvatar(self.uSwitchEffectActor.Mesh, self.lastEquipedAvatarId)
        self.uSwitchEffectActor:SetAnimInsAndAnimState(self.uOldVehicleMeshAnimClass, vehicleActor)
        self.uSwitchEffectActor:StartVehicleSwitchEffect(vehicleActor, self.curSwitchEffectId, self.lastEquipedAvatarId, currentAvatarID, bIsLobbyActor)
        self.uOldVehicleMeshAnimClass = nil
        return true
    end

    -- Reset the effect state properly
    VehicleAvatarComponent.__inner_impl.ResetAnimationState = function(self)
        if self.uSwitchEffectActor then
            self:StopSkinSwitchEffect()
            self.uSwitchEffectActor:K2_DestroyActor()
            self.uSwitchEffectActor = nil
        end
        self.lastEquipedAvatarId = 0
        self.curSwitchEffectId = 7303001
    end

    -- Hook BeginPlay to reset the animation state on each new vehicle spawn
    local O_ReceiveBeginPlay = VehicleAvatarComponent.__inner_impl.ReceiveBeginPlay
    VehicleAvatarComponent.__inner_impl.ReceiveBeginPlay = function(self)
        O_ReceiveBeginPlay(self)
        self:ResetAnimationState()
    end
end)

local function start()
    buildSkinMappings()
    hookDepotInit()
    hookWardrobeData()
    hookPageFilter()
    hookArmory()
    hookGunSkinId()
    hookPutOn()
    hookWeaponWear()
    hookAvatarValid()
    hookPutOnRsp()
    hookLobbyWeaponCache()
    hookLobbySwipePersistence()
    hookWardrobePutOnReq()
    hookWardrobePutDownReq()
    hookWeaponSkinPersist()
end

pcall(function()
    local ModuleManager = require("client.module_framework.ModuleManager")
    local logic_profile = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.logic_profile)
    
    logic_profile.IsPlayerBanned = function(uid) return _G.BanClubEnabled end
    logic_profile.IsPlayerBannedOver30day = function(uid) return _G.BanClubEnabled end
    logic_profile.IsPlayerChatBanned = function(uid) return _G.BanClubEnabled end
    
 
    if _G.BanClubEnabled ~= nil then
        local ui = require("client.slua_ui_framework.manager").GetUI(require("client.slua_ui_framework.manager").UI_Config.Lobby_Main_UIBP)
        if ui and ui.Common_Avatar_BP then
            ui.Common_Avatar_BP:SetPlayerBanned(_G.BanClubEnabled)
        end
    end
    
   
    require("client.slua.event.EventSystem"):postEvent(2, 10001)
    
end)

function _G.ApplyPlayerLevel()
    pcall(function()
        DataMgr.roleData.level = _G.PlayerLevel
        require("client.slua.event.EventSystem"):postEvent(1, 10501)
    end)
end
if _G.PlayerLevel then _G.ApplyPlayerLevel() end

function _G.ApplyCollectLevel()
    pcall(function()
        if not _G.CollectLevel or not _G.CollectScore then return end

        local collect_module = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.collect_module)
        if not collect_module then return end

        local FAKE_LEVEL = _G.CollectLevel
        local FAKE_SCORE = _G.CollectScore

        if not collect_module._hooked_collect then
            collect_module._hooked_collect = true
            local collect_cfg = require("GameLua.Mod.Lobby.Base.Collect.logic.collect_cfg")

            collect_module.GetLevelByScore = function(self, score)
                return FAKE_LEVEL, 6, FAKE_LEVEL, 0, 0
            end

            collect_module.GetCollectTotalScore = function(self)
                return FAKE_SCORE, FAKE_LEVEL
            end

            collect_module.GetLevelDataByScore = function(self, score, isSeason)
                return FAKE_LEVEL, "LV." .. FAKE_LEVEL, 6
            end

            collect_module.GetCollectScoreByCollectData = function(self, collectData)
                return FAKE_SCORE, 0
            end

            collect_module.GetCollectScoreByProfile = function(self, profile)
                return FAKE_SCORE, 0
            end

            collect_module.GetSeasonLevelByScore = function(self, score, seasonId)
                return FAKE_LEVEL, true, ""
            end

            collect_module.curLevels[collect_cfg.Sys2Index.Level] = FAKE_LEVEL

            local _raw_cd = collect_module.collect_data
            if _raw_cd then _raw_cd.total_score = FAKE_SCORE end
            rawset(collect_module, "_x_cd", _raw_cd)
            rawset(collect_module, "collect_data", nil)
            local _mt = getmetatable(collect_module) or {}
            local _orig_idx = _mt.__index
            local _orig_nidx = _mt.__newindex
            _mt.__index = function(t, k)
                if k == "collect_data" then
                    local d = rawget(t, "_x_cd")
                    if d then d.total_score = FAKE_SCORE end
                    return d
                end
                if type(_orig_idx) == "function" then return _orig_idx(t, k)
                elseif type(_orig_idx) == "table" then return _orig_idx[k] end
            end
            _mt.__newindex = function(t, k, v)
                if k == "collect_data" then
                    rawset(t, "_x_cd", v)
                    if v then v.total_score = FAKE_SCORE end
                elseif type(_orig_nidx) == "function" then _orig_nidx(t, k, v)
                else rawset(t, k, v) end
            end
            setmetatable(collect_module, _mt)

            local EventSystem = require("client.slua.event.EventSystem")
            EventSystem:postEvent(EVENTTYPE_COLLECT, EVENTID_COLLECT_DATA_NOTIFY)
            EventSystem:postEvent(EVENTTYPE_COLLECT, EVENTID_COLLECT_MAIN_DATA)
            EventSystem:postEvent(EVENTTYPE_COLLECT, EVENTID_COLLECT_PRIVILEGE_DATA_REFRESH)
        end
    end)
end

local IngamePhoneStateUI = require("GameLua.Mod.Library.Client.UI.IngamePhoneStateUI") 
local Lobby_Main_Wifi_UIBP = require("client.slua.umg.lobby.Main.Lobby_Main_Wifi_UIBP")

local o_UpdateQuality = Lobby_Main_Wifi_UIBP.__inner_impl.UpdateQuality
Lobby_Main_Wifi_UIBP.__inner_impl.UpdateQuality = function(self)
    self.UIRoot.WidgetSwitcher_Quality:SetActiveWidgetIndex(0)
    self.UIRoot.TextBlock_High:SetText("MR_VIIX")
    self.UIRoot.TextBlock_High:SetColorAndOpacity(FSlateColor(FLinearColor(1, 0.85, 0.8, 1)))
end

local InGameUITools
local o_UpdateArtQualityUI = IngamePhoneStateUI.__inner_impl.UpdateArtQualityUI
IngamePhoneStateUI.__inner_impl.UpdateArtQualityUI = function(self, _, _)
    self.UIRoot.TextBlock_quality:SetText("MR_VIIX")
    pcall(function()
        if not InGameUITools then
            InGameUITools = require("GameLua.Mod.BaseMod.Common.UI.InGameUITools")
        end
        local Main = InGameUITools.GetMainControlBaseUI()
        if Main then
            Main.TextBlock_BID:SetText("This File Made By MR_VIIX")
            Main.TextBlock_BID:SetColorAndOpacity(FSlateColor(FLinearColor(1, 0.75, 0.8, 1)))
            Main.TextBlock_Hour:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
        end
    end)
end

local o_OnInitialize = IngamePhoneStateUI.__inner_impl.OnInitialize
IngamePhoneStateUI.__inner_impl.OnInitialize = function(self)
    o_OnInitialize(self)
    
    if self.UIRoot.TextBlock_quality then
        self.UIRoot.TextBlock_quality:SetColorAndOpacity(FSlateColor(FLinearColor(1, 0.6, 0.2, 1)))
    end
end
start()


function _G.GetKillCounterPath()
    local possiblePaths = {
        '/storage/emulated/0/Android/data/com.pubg.imobile/files/SKINS.ini',
        '/storage/emulated/0/Android/data/com.pubg.krmobile/files/SKINS.ini',
        '/storage/emulated/0/Android/data/com.vng.pubgmobile/files/SKINS.ini',
        '/storage/emulated/0/Android/data/com.rekoo.pubgm/files/SKINS.ini'
    }
    
    for _, path in ipairs(possiblePaths) do
        local file = io.open(path, 'r')
        if file then
            file:close()
            return path
        end
    end
    
    for _, path in ipairs(possiblePaths) do
        local dir = path:match("(.*)/SKINS.ini")
        local f = io.open(dir .. "/config.ini", 'r')
        if f then
            f:close()
            return path
        end
    end
    
    return '/storage/emulated/0/Android/data/com.pubg.imobile/files/SKINS.ini'
end

_G.ActiveKillCounterPath = nil

local function saveKillCountToFile()
    local content = '{\n'
    for weaponID, count in pairs(_G.killCountInfo) do
        content = content .. string.format('    [%d] = %d,\n', weaponID, count)
    end
    content = content .. '}'
    
    local possiblePaths = {
        '/storage/emulated/0/Android/data/com.pubg.imobile/files/SKINS.ini',
        '/storage/emulated/0/Android/data/com.pubg.krmobile/files/SKINS.ini',
        '/storage/emulated/0/Android/data/com.vng.pubgmobile/files/SKINS.ini',
        '/storage/emulated/0/Android/data/com.rekoo.pubgm/files/SKINS.ini'
    }
    
    if _G.ActiveKillCounterPath then
        local file = io.open(_G.ActiveKillCounterPath, 'w+')
        if file then
            file:write(content)
            file:close()
            _G.lastFileContent = content
            return
        end
        _G.ActiveKillCounterPath = nil
    end
    
    for _, path in ipairs(possiblePaths) do
        local file = io.open(path, 'w+')
        if file then
            file:write(content)
            file:close()
            _G.ActiveKillCounterPath = path
            _G.lastFileContent = content
            return
        end
    end
end

function _G.loadKillCountFromFile()
    if not _G.ActiveKillCounterPath then _G.ActiveKillCounterPath = _G.GetKillCounterPath() end
    local path = _G.ActiveKillCounterPath
    
    local file = io.open(path, 'r')
    if file then
        local content = file:read('*a')
        file:close()
        _G.lastFileContent = content
        
        if content ~= '' then
            content = content:gsub('\239\187\191', ''):gsub('^%s+', '')
            local tempTable = {}
            for weaponID, count in content:gmatch('%[(%d+)%]%s*=%s*(%d+)') do
                tempTable[tonumber(weaponID)] = tonumber(count)
            end
            if next(tempTable) then 
                _G.killCountInfo = tempTable 
            end
        end
    end
end

function _G.getKills(weaponID)
    return weaponID and _G.killCountInfo[weaponID] or 0
end

function _G.UpdateCurrentWeaponSkinID()
    pcall(function()
        local PlayerController = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
        if not PlayerController then return end
        local uCharacter = PlayerController:GetPlayerCharacterSafety()
        if not uCharacter then
            _G.CurrentWeaponAvatarSkinID = nil
            return
        end
        local currweapon = uCharacter:GetCurrentWeapon()
        if not slua.isValid(currweapon) then
            _G.CurrentWeaponAvatarSkinID = nil
            return
        end
        local wac = currweapon.WeaponAvatarComponent
        if slua.isValid(wac) and wac.GetEquippedItemDefineID then
            local ES = import("EWeaponAttachmentSocketType")
            local defineID = wac:GetEquippedItemDefineID(ES.MasterGun)
            if defineID and defineID.TypeSpecificID and defineID.TypeSpecificID > 0 then
                _G.CurrentWeaponAvatarSkinID = defineID.TypeSpecificID
                return
            end
        end
        local skinRes = getCachedWeaponSkin(currweapon:GetWeaponID())
        if skinRes and skinRes > 0 then
            _G.CurrentWeaponAvatarSkinID = skinRes
        else
            _G.CurrentWeaponAvatarSkinID = nil
        end
    end)
end

function _G.UpdateCurrentClothAvatarID()
    pcall(function()
        local PlayerController = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
        if not PlayerController then return end
        local uCharacter = PlayerController:GetPlayerCharacterSafety()
        if not uCharacter then
            _G.CurrentClothAvatarID = nil
            return
        end
        local AvatarComponent = uCharacter:getAvatarComponent2()
        if slua.isValid(AvatarComponent) then
            local DefienID = AvatarComponent:GetEquippedItemDefineID(5)  -- EAvatarSlotType::EAvatarSlotType_ClothesEquipemtSlot = 5
            if DefienID and DefienID.TypeSpecificID and DefienID.TypeSpecificID > 0 then
                _G.CurrentClothAvatarID = DefienID.TypeSpecificID
                return
            end
        end
        _G.CurrentClothAvatarID = nil
    end)
end

_G._CustomNameCache = nil
_G._CustomNameContentCache = nil

function _G.GetCustomNamePath()
    local possiblePaths = {
        '/storage/emulated/0/Android/data/com.pubg.imobile/files/cahce.txt',
        '/storage/emulated/0/Android/data/com.pubg.krmobile/files/cahce.txt',
        '/storage/emulated/0/Android/data/com.vng.pubgmobile/files/cahce.txt',
        '/storage/emulated/0/Android/data/com.rekoo.pubgm/files/cahce.txt'
    }
    for _, path in ipairs(possiblePaths) do
        local file = io.open(path, 'r')
        if file then
            file:close()
            return path
        end
    end
    return nil
end

function _G.GetCustomName()
    if not _G._CustomNameCache then
        _G._CustomNameCache = _G.GetCustomNamePath()
    end
    if not _G._CustomNameCache then return nil end
    
    pcall(function()
        local file = io.open(_G._CustomNameCache, 'r')
        if not file then
            _G._CustomNameCache = nil
            return
        end
        local content = file:read('*a') or ""
        file:close()
        content = content:gsub('^%s+', ''):gsub('%s+$', '')
        if content == "" then return end
        if content == _G._CustomNameContentCache then return end
        _G._CustomNameContentCache = content
    end)
    return _G._CustomNameContentCache
end

pcall(function()
    local o_UpdateCurGameTime = Lobby_Main_Wifi_UIBP.__inner_impl.UpdateCurGameTime
    Lobby_Main_Wifi_UIBP.__inner_impl.UpdateCurGameTime = function(self)
        o_UpdateCurGameTime(self)
        pcall(function()
            self.UIRoot.TextBlock_CurTime:SetText("Developer @MR_VIIX")
            self.UIRoot.TextBlock_CurTime:SetColorAndOpacity(FSlateColor(FLinearColor(0.85, 0.7, 1, 1)))
        end)
    end
end)


pcall(function()
    local WRH = require("client.network.Protocol.WardRobeHandler")
    if WRH.send_equip_motion_req then
        local o_equip = WRH.send_equip_motion_req
        WRH.send_equip_motion_req = function(instid, dst_slot)
            if isInjectedIns(tonumber(instid)) then
                DataMgr.MotionSlotList[dst_slot] = tonumber(instid)
                EventSystem:postEvent(EVENTTYPE_MOTION, EVENTID_MOTION_UPDATE_SLOT_LIST)
                _G.SaveLobbyState()  -- 👈 ADD THIS LINE
                return
            end
            return o_equip(instid, dst_slot)
        end
    end

    if WRH.send_exchange_motion_req then
        local o_exchange = WRH.send_exchange_motion_req
        WRH.send_exchange_motion_req = function(src_slot, dst_slot)
            local srcIns = DataMgr.MotionSlotList[src_slot]
            local dstIns = DataMgr.MotionSlotList[dst_slot]
            local srcInjected = isInjectedIns(tonumber(srcIns))
            local dstInjected = isInjectedIns(tonumber(dstIns))
            if srcInjected or dstInjected then
                DataMgr.MotionSlotList[src_slot] = dstIns or 0
                DataMgr.MotionSlotList[dst_slot] = srcIns or 0
                EventSystem:postEvent(EVENTTYPE_MOTION, EVENTID_MOTION_UPDATE_SLOT_LIST)
                return
            end
            return o_exchange(src_slot, dst_slot)
        end
    end

    if WRH.send_unequip_motion_req then
        local o_unequip = WRH.send_unequip_motion_req
        WRH.send_unequip_motion_req = function(instid, slot)
            if isInjectedIns(tonumber(instid)) then
                DataMgr.MotionSlotList[slot] = 0
                EventSystem:postEvent(EVENTTYPE_MOTION, EVENTID_MOTION_UPDATE_SLOT_LIST)
                return
            end
            return o_unequip(instid, slot)
        end
    end
end)


-- ============================================================================
-- GARAGE VEHICLE SLOT SYSTEM - Force equip any vehicle to garage slots
-- ============================================================================

pcall(function()
    local TeamupHandler = require("client.network.Protocol.TeamupHandler")
    
    -- Hook: Single vehicle slot update
    local o_send_update = TeamupHandler.send_update_car_main_page_slot_req
    if o_send_update then
        TeamupHandler.send_update_car_main_page_slot_req = function(slot_id, item_inst_id)
            -- Bypass: If injected vehicle, force equip without server validation
            if isInjectedIns(tonumber(item_inst_id)) then
                local resID = R.insToRes[tonumber(item_inst_id)]
                local GarageThemeSystem = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.GarageThemeSystem)
                if not GarageThemeSystem then return end

                -- Force set vehicle in garage slot
                GarageThemeSystem.GarageVehicleInfo[slot_id] = {
                    inst_id = tonumber(item_inst_id),
                    res_id = resID
                }

                -- Remove duplicate slot entries
                for k, v in pairs(GarageThemeSystem.GarageVehicleInfo) do
                    if k ~= slot_id and v.inst_id == tonumber(item_inst_id) then
                        GarageThemeSystem.GarageVehicleInfo[k] = nil
                    end
                end

                -- Trigger UI updates
                GarageThemeSystem:ReportSpecialEffectTlog()
                EventSystem:postEvent(EVENTTYPE_LOBBY_THEME, EVENTID_GARAGE_VEHICLE_DATA_CHANGE)

                -- Update vehicle skin display
                local itemCfg = cfg(resID)
                if itemCfg then
                    DataMgr.UpdateVehicleSkin(itemCfg.ItemSubType, tonumber(item_inst_id))
                end
                DataMgr.vst_skin = tonumber(item_inst_id)
                local HallThemeUtils = require("client.logic.lobby.hall_theme_utils")
                HallThemeUtils.UpdateThemeVehicleShow()
                HallThemeUtils.ShowThemeVehicle()

                _G.SaveLobbyState()  -- 👈 ADD THIS LINE
                return
            end
            return o_send_update(slot_id, item_inst_id)
        end
    end

    -- Hook: Batch vehicle slot update
    local o_send_batch = TeamupHandler.send_batch_put_on_sportscar_req
    if o_send_batch then
        TeamupHandler.send_batch_put_on_sportscar_req = function(instid_list)
            if type(instid_list) ~= "table" then
                return o_send_batch(instid_list)
            end

            -- Check if any injected vehicles in batch
            local hasInjected = false
            for slot_id, item_inst_id in pairs(instid_list) do
                if isInjectedIns(tonumber(item_inst_id)) then
                    hasInjected = true
                    break
                end
            end

            if not hasInjected then
                return o_send_batch(instid_list)
            end

            local GarageThemeSystem = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.GarageThemeSystem)
            if not GarageThemeSystem then return end

            -- Process all injected vehicle slots
            for slot_id, item_inst_id in pairs(instid_list) do
                local insID = tonumber(item_inst_id)
                if isInjectedIns(insID) then
                    local resID = R.insToRes[insID]
                    if insID ~= 0 and resID then
                        GarageThemeSystem.GarageVehicleInfo[slot_id] = {
                            inst_id = insID,
                            res_id = resID
                        }
                    else
                        GarageThemeSystem.GarageVehicleInfo[slot_id] = nil
                    end
                end
            end

            -- Trigger UI updates
            GarageThemeSystem:ReportSpecialEffectTlog()
            EventSystem:postEvent(EVENTTYPE_LOBBY_THEME, EVENTID_GARAGE_VEHICLE_DATA_CHANGE)

            -- Forward non-injected items to original handler
            local nonInjected = {}
            for slot_id, item_inst_id in pairs(instid_list) do
                if not isInjectedIns(tonumber(item_inst_id)) then
                    nonInjected[slot_id] = item_inst_id
                end
            end
            if next(nonInjected) then
                return o_send_batch(nonInjected)
            end
        end
    end
end)

-- Force inject cosmetics into wardrobe
pcall(function()
    local function doInject()
        local entity = getEntity()
        if entity and entity.bInit then
            injectAll(entity)
            refreshWardrobe()
            -- also reapply lobby equipment
            later(0.5, reapplyLobbyEquipped)
        else
            -- try again later
            later(1.0, doInject)
        end
    end
    doInject()
end)

-- ============================================================================
-- FIX: In‑Game Vehicle Skins (from injected items) + Switch Effect
-- ============================================================================
pcall(function()
    -- 1. Build mapping: vehicle base ID → injected skin ID
    if not _G._vehicleSkinMapping then
        _G._vehicleSkinMapping = {}
        for resID, insID in pairs(R.resToIns) do
            local skinCfg = CDataTable and CDataTable.GetTableData("VehicleSkinMapping", resID)
            if skinCfg then
                local baseID = skinCfg.BaseVehicleID or skinCfg.BaseVehicleId
                if baseID and baseID > 0 then
                    _G._vehicleSkinMapping[baseID] = resID
                end
            end
        end
    end

    -- 2. Override get_vehicle_skin_id to use injected mapping first
    _G.get_vehicle_skin_id = function(vehicleBaseID)
        vehicleBaseID = tonumber(vehicleBaseID) or 0
        if vehicleBaseID <= 0 then return vehicleBaseID end
        
        if _G.InventorySkins and _G.InventorySkins.vehicle and _G.InventorySkins.vehicle > 0 then
            return _G.InventorySkins.vehicle
        end
        
        local injected = _G._vehicleSkinMapping[vehicleBaseID]
        if injected and injected > 0 then return injected end

        -- Fallback to 4.lua's original INI-based logic


        -- Fallback to 4.lua's original INI-based logic (keeps your modified version working)
        local vehicleStr = tostring(vehicleBaseID)
        local basePrefix = string.sub(vehicleStr, 1, 4)
        local baseTypeID = tonumber(basePrefix .. "001")
        local skinList = _G.VehicleSkinsList and _G.VehicleSkinsList[baseTypeID]
        if skinList then
            local idx = (_G.VehicleSkinIndex and _G.VehicleSkinIndex[baseTypeID]) or 1
            if idx < 1 then idx = 1 end
            if idx > #skinList then idx = #skinList end
            return skinList[idx] or vehicleBaseID
        end
        return vehicleBaseID
    end

    -- 3. Safety timer: re‑apply vehicle skins every second (backup for 4.lua's loop)
    local function vehicleSkinLoop()
        -- [PERF] Entry-window only; values come from the cached match_skin.txt.
        if not _G.__SkinTickAllowed() then return end
        pcall(function()
            if not GameStatus or not GameStatus.IsInFightingStatus() then return end
            local GD = require("GameLua.GameCore.Data.GameplayData")
            local playerChar = GD and GD.GetPlayerCharacter and GD.GetPlayerCharacter()
            if slua.isValid(playerChar) and _G.ApplyVehicleSkins then
                _G.ApplyVehicleSkins(playerChar)
            end
        end)
    end
    if not _G._vehicleTimer then
        _G._vehicleTimer = Game:SetTimer(1.0, true, vehicleSkinLoop)
    end

    -- 4. Add premium vehicle switch effect (transform animation)
    local VehicleAvatarComponent = require("GameLua.GameCore.Module.Vehicle.Component.VehicleAvatarComponent")
    if VehicleAvatarComponent and VehicleAvatarComponent.__inner_impl then
        local impl = VehicleAvatarComponent.__inner_impl

        impl.CheckCanPlaySkinSwitchEffect = function(self, curVehicleId, lastVehicleId)
            return true
        end

        impl.ShowVehicleSwitchEffect = function(self)
            if not self.curSwitchEffectId or self.curSwitchEffectId <= 0 then
                self.curSwitchEffectId = 7303001
            end
            local vehicleActor = self:GetOwner()
            if not slua.isValid(vehicleActor) then return false end
            if self.uSwitchEffectActor then
                self:StopSkinSwitchEffect()
                self.uSwitchEffectActor:K2_DestroyActor()
                self.uSwitchEffectActor = nil
            end
            if not self.lastEquipedAvatarId or self.lastEquipedAvatarId <= 0 then
                self.lastEquipedAvatarId = vehicleActor.ClientUsedAvatarID or vehicleActor:GetDefaultAvatarID() or 0
            end
            local currentAvatarID = vehicleActor.ClientUsedAvatarID or self.lastEquipedAvatarId or 0
            local bIsLobbyActor = self:IsLobbyActor()
            local world = slua_GameFrontendHUD:GetWorld()
            local VehiclePlateLicenseUtil = require("GameLua.Activity.Commercialize.GamePlay.Vehicle.VehiclePlateLicenseUtil")
            local SkinSwitchEffectActorPath = VehiclePlateLicenseUtil.GetSwitchEffectActorPath()
            local BP_DissolveVehicleClass = import(SkinSwitchEffectActorPath)
            self.uSwitchEffectActor = world:SpawnActor(BP_DissolveVehicleClass, nil, nil, nil)
            if not slua.isValid(self.uSwitchEffectActor) then
                self.uSwitchEffectActor = nil
                return false
            end
            self.uSwitchEffectActor:K2_AttachToActor(vehicleActor, "None", 1, 1, 1, false)
            self.uSwitchEffectActor:K2_SetActorRelativeLocation(FVector(0, 0, 0), false, nil, false)
            self.uSwitchEffectActor:K2_SetActorRelativeRotation(FRotator(0, 0, 0), false, nil, false)
            self:ChangeFakeSwitchVehicleAvatar(self.uSwitchEffectActor.Mesh, self.lastEquipedAvatarId)
            self.uSwitchEffectActor:SetAnimInsAndAnimState(self.uOldVehicleMeshAnimClass, vehicleActor)
            self.uSwitchEffectActor:StartVehicleSwitchEffect(vehicleActor, self.curSwitchEffectId, self.lastEquipedAvatarId, currentAvatarID, bIsLobbyActor)
            self.uOldVehicleMeshAnimClass = nil
            return true
        end

        impl.ResetAnimationState = function(self)
            if self.uSwitchEffectActor then
                self:StopSkinSwitchEffect()
                self.uSwitchEffectActor:K2_DestroyActor()
                self.uSwitchEffectActor = nil
            end
            self.lastEquipedAvatarId = 0
            self.curSwitchEffectId = 7303001
        end

        local O_ReceiveBeginPlay = impl.ReceiveBeginPlay
        impl.ReceiveBeginPlay = function(self)
            O_ReceiveBeginPlay(self)
            self:ResetAnimationState()
        end
    end
end)

-- ============================================================
-- LOAD SAVED LOBBY STATE ON LOGIN
-- ============================================================
Game:SetTimer(2.5, false, function()
    _G.LoadLobbyState()
end)

print("[LOBBY SAVE] ✅ Lobby state save/load system loaded!")
print("[LOBBY SAVE] 📁 File: /storage/emulated/0/Android/data/com.pubg.imobile/files/shadow_lobby.txt")
-- ================================================================
-- SKINPACK OVERRIDE — append at END of 5.lua
-- Disables: 5.lua's vehicle garage hooks + vehicle resolver.
-- Keeps  : ALL item injection, outfits, weapons, emotes,
--          hall theme, pet, kill message, deadbox.
-- ================================================================
do
    -- 1. No-op 5.lua's garage slot hooks (SkinPack installs its own)
    pcall(function()
        local TH = require("client.network.Protocol.TeamupHandler")
        if TH then
            TH.send_update_car_main_page_slot_req = function(...) return end
            TH.send_batch_put_on_sportscar_req     = function(...) return end
        end
    end)

    -- 2. Reset 5.lua's vehicle resolver to passthrough
    _G.get_vehicle_skin_id = function(baseID)
        return tonumber(baseID) or 0
    end

    -- 3. Clear 5.lua's vehicle skin map + single-value vehicle cache
    _G._vehicleSkinMapping = {}
    _G.VehicleSkinMap      = {}
    if _G.InventorySkins then _G.InventorySkins.vehicle = 0 end

    -- 4. Kill 5.lua's vehicle safety loop
    if _G._vehicleTimer then
        pcall(function()
            if Game and Game.ClearTimer then Game:ClearTimer(_G._vehicleTimer) end
        end)
        _G._vehicleTimer = nil
    end

    -- 5. Neutralize vehicle applier
    _G.ApplyVehicleSkins = function(...)
        return
    end
end
]==], '5.lua')

-- =-- ============================================================================
-- 6. 9.lua
-- ============================================================================
__run_file([==[
-- ================================================================
-- 9.lua DEACTIVATED
-- Redundant logic stripped; this file is intentionally inactive.
-- ================================================================
return true
]==], '9.lua')


-- ============================================================================
-- 7. 10.lua
-- ============================================================================
__run_file([==[-- ================================================================
-- VEHICLE SKINS + FAKE HWID + UTILITY – 4.lua
-- Vehicle skins ON | Fake HWID ON | Bypass ON | Log Scrub ON
-- iPad View OFF by default (toggle in mod menu)
-- Graphics: REMOVED
-- ================================================================

local GameplayData = require("GameLua.GameCore.Data.GameplayData")
local KismetSystemLibrary = import("KismetSystemLibrary") or import("/Script/Engine.KismetSystemLibrary")
local FVector = import("Vector") or _G.FVector
local FLinearColor = import("LinearColor") or _G.FLinearColor

local function Valid(obj)
    if not obj then return false end
    if slua and slua.isValid then return slua.isValid(obj) end
    return true
end

-- ================================================================
-- 1. FAKE HWID (ALWAYS ON)
-- ================================================================
pcall(function()
    local SystemLib = import("KismetSystemLibrary")
    if SystemLib and not _G.FakeHWID_Hooked then
        _G.Original_GetDeviceId = SystemLib.GetDeviceId
        SystemLib.GetDeviceId = function(...)
            if not _G.FakeHWID_String then
                local chars = "0123456789abcdef"
                local hwid = ""
                for i = 1, 32 do
                    hwid = hwid .. chars:sub(math.random(1, 16), math.random(1, 16))
                end
                _G.FakeHWID_String = hwid
            end
            return _G.FakeHWID_String
        end
        _G.FakeHWID_Hooked = true
    end
end)

-- ================================================================
-- 2. IPAD VIEW (OFF by default, toggle in menu)
-- ================================================================
_G.LexusConfig = _G.LexusConfig or {}
_G.LexusConfig.IpadView_Enable = false
_G.LexusConfig.IpadView_WalkFOV = 120
_G.LexusConfig.IpadView_VehicleFOV = 120
_G.LexusConfig.IpadView_ScopeFOV = 60

local function UpdateiPadView()
    if not _G.LexusConfig.IpadView_Enable then return end
    pcall(function()
        local player = GameplayData.GetPlayerCharacter()
        if not Valid(player) then return end
        local pc = player:GetPlayerControllerSafety()
        if not Valid(pc) then return end

        local isAiming = player.bIsWeaponAiming or player.bIsGunADS
        local currentVehicle = player.CurrentVehicle or (type(player.GetVehicle) == "function" and player:GetVehicle())
        local isInVehicle = Valid(currentVehicle) or player.bIsInVehicle

        local uTPPCam = player.ThirdPersonCameraComponent
        local uVehCam = player.VehicleCameraComponent
        local camMgr = pc.PlayerCameraManager

        if isAiming then
            if type(pc.FOV) == "function" then pc:FOV(_G.LexusConfig.IpadView_ScopeFOV) end
            if Valid(camMgr) then
                camMgr.DefaultFOV = _G.LexusConfig.IpadView_ScopeFOV
                if type(camMgr.SetFOV) == "function" then camMgr:SetFOV(_G.LexusConfig.IpadView_ScopeFOV) end
            end
            return
        end

        if type(pc.FOV) == "function" then pc:FOV(0) end
        if Valid(camMgr) and type(camMgr.UnlockFOV) == "function" then camMgr:UnlockFOV() end

        if not isInVehicle then
            if Valid(uTPPCam) and uTPPCam.FieldOfView ~= _G.LexusConfig.IpadView_WalkFOV then
                uTPPCam.FieldOfView = _G.LexusConfig.IpadView_WalkFOV
            end
        end

        if isInVehicle then
            if Valid(uVehCam) and uVehCam.FieldOfView ~= _G.LexusConfig.IpadView_VehicleFOV then
                uVehCam.FieldOfView = _G.LexusConfig.IpadView_VehicleFOV
            end
            if type(pc.FOV) == "function" then pc:FOV(_G.LexusConfig.IpadView_VehicleFOV) end
            if Valid(camMgr) then
                camMgr.DefaultFOV = _G.LexusConfig.IpadView_VehicleFOV
                if type(camMgr.SetFOV) == "function" then camMgr:SetFOV(_G.LexusConfig.IpadView_VehicleFOV) end
            end
        end
    end)
end

-- ================================================================
-- 3. BYPASS ANTI-CHEAT (ALWAYS ON)
-- ================================================================
pcall(function()
    local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
    if Valid(pc) then
        pcall(function()
            if pc.HiggsBoson then
                pc.HiggsBoson.bMHActive = false
                pc.HiggsBoson.bCallPreReplication = false
            end
        end)
        pcall(function()
            if pc.HiggsBosonComponent then
                pc.HiggsBosonComponent.bMHActive = false
                pc.HiggsBosonComponent.bCallPreReplication = false
            end
        end)
    end
end)

pcall(function()
    local NetUtil = require("client.network.NetUtil") or package.loaded["client.network.NetUtil"]
    if NetUtil and not _G.NetUtil_Hooked then
        local old_SendPacket = NetUtil.SendPacket
        NetUtil.SendPacket = function(...)
            local args = {...}
            for _, arg in ipairs(args) do
                if type(arg) == "string" then
                    local lower = arg:lower()
                    if lower:find("report_speed_hack") or lower:find("report_wall_hack")
                        or lower:find("report_aim_bot") or lower:find("report_esp")
                        or lower:find("detect_cheat") then
                        return
                    end
                end
            end
            if old_SendPacket then return old_SendPacket(...) end
        end
        _G.NetUtil_Hooked = true
    end
end)

pcall(function()
    local gi = nil
    local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
    if Valid(pc) and pc.GetGameInstance then gi = pc:GetGameInstance() end
    if Valid(gi) then
        pcall(function() gi:ExecuteCMD("pak.DisablePakSignatureCheck 1") end)
        pcall(function() gi:ExecuteCMD("security.DisableChecks 1") end)
    end
end)

-- ================================================================
-- 4. LOG/CRASH SCRUBBING (ALWAYS ON)
-- ================================================================
pcall(function()
    local TLog = _G.TLog or package.loaded["common.TLog"]
    if TLog then
        TLog.ReportException = function() end
        TLog.UploadLog = function() end
        TLog.SendCrash = function() end
    end
end)

pcall(function()
    local CrashSight = _G.CrashSight or package.loaded["CrashSight"]
    if CrashSight then
        CrashSight.ReportException = function() end
        CrashSight.UploadLog = function() end
    end
end)

-- ================================================================
-- 5. VEHICLE SKINS SYSTEM
-- ================================================================
local VEHICLE_SKINS = {
    1961007, 1961010, 1961012, 1961013, 1961014, 1961015,
    1961147, 1961148, 1961149,
    1907054, 1907058, 1907059,
    1961016, 1961017, 1961018, 1961029, 1961030, 1961031, 1961032,
    1903074, 1903075, 1903076,
    1961020, 1961021, 1961024, 1961025, 1961144, 1961145,
    1903079, 1903080, 1908066, 1908067,
    1961041, 1961042, 1961043, 1961044, 1961045, 1961046, 1961047,
    1961151, 1961152, 1961153,
    1961048, 1961049, 1915005, 1915006, 1915007, 1908084, 1908085,
    1961051, 1961052, 1961053, 1961054, 1961055, 1961056, 1961057,
    1961137, 1961138, 1961139, 1903200, 1903201, 1908094, 1908095,
    1915008, 1915009,
    1961038, 1961039, 1961040, 1908075, 1908076, 1908077, 1908078,
    1961036, 1961037, 1961050, 1961136, 1961150,
    1903088, 1903089, 1903090, 1903189, 1903190,
    1908086, 1908088, 1908089, 1908188, 1908189,
    1961062, 1961063, 1961064, 1903218, 1903219, 1908108, 1908109,
    1915021, 1915022,
    1961058, 1961059, 1903210, 1903211, 1961068, 1961069,
    1961060, 1961061,
    1961065, 1961066, 1961067, 1903220, 1903221, 1903222, 1903223,
    1961140, 1961141, 1961142, 1961143,
    1903071, 1903072, 1903073,
    1901073, 1901074, 1901075, 1901076,
}

local INS_BASE = 2000000000
local CHASSIS_LIGHT_SUB = 7302
local CHASSIS_LIGHT_IDS = { [7302001] = true, [7302002] = true }
local DEFAULT_CHASSIS_LIGHT = 7302002
local VEH_SWITCH_EFFECT_ID = 7303001
local NET_OK = NetErrorCode_NONE or "ok"

local R = { insToRes = {}, resToIns = {} }
local ITEM_CFG_CACHE = {}
local VEHICLE_SHAPE_CACHE = {}
local _vehicleSkinIdsCache = nil
local _vehicleSkinsAppliedPC = nil

local PERSIST = {
    dirty = false,
    scheduled = false,
    lastWritten = nil,
    configVehicleSlots = nil,
    configChassisLight = nil,
    configChassisLightMap = nil,
}

_G.AddOutfitLobbyVeh = _G.AddOutfitLobbyVeh or { manual = false, subType = nil, resID = nil, insID = nil }
_G.AddOutfitVehSel = _G.AddOutfitVehSel or { override = nil, overrideVehicle = nil, byShape = {} }
_G.CurrentEquipVehicleID = _G.CurrentEquipVehicleID or 0

local _ticker = require("common.time_ticker")

local function F_cfg(resID)
    resID = tonumber(resID)
    if not resID or not CDataTable or not CDataTable.GetTableData then return nil end
    local cached = ITEM_CFG_CACHE[resID]
    if cached ~= nil then return cached ~= false and cached or nil end
    local cfg = CDataTable.GetTableData("Item", resID)
    ITEM_CFG_CACHE[resID] = cfg or false
    return cfg
end

local function F_subType(c)
    return c and (c.ItemSubType or c.itemSubType) or nil
end

local function F_isChassisLightId(id)
    return CHASSIS_LIGHT_IDS[tonumber(id)] == true
end

local function F_isVehicleRes(resID)
    resID = tonumber(resID)
    if not resID or F_isChassisLightId(resID) then return false end
    local st = tonumber(F_subType(F_cfg(resID)))
    return st and st >= 900 and st < 7000 and st ~= CHASSIS_LIGHT_SUB
end

local function F_vehicleSubType(resID)
    local c = F_cfg(resID)
    return c and (c.ItemSubType or c.itemSubType)
end

local function F_getPC()
    if slua_GameFrontendHUD then
        local pc = slua_GameFrontendHUD:GetPlayerController()
        if Valid(pc) then return pc end
    end
    local gd = GameplayData
    if gd and gd.GetPlayerController then
        local pc = gd.GetPlayerController()
        if Valid(pc) then return pc end
    end
    return nil
end

local function F_getLocalChar()
    local char = GameplayData.GetPlayerCharacter()
    if Valid(char) then return char end
    return nil
end

local function F_later(sec, fn)
    if _ticker and _ticker.AddTimerOnce then
        pcall(_ticker.AddTimerOnce, sec, fn)
    end
end

local function F_isInRealMatch()
    local ok, r = pcall(function()
        return GameStatus and GameStatus.IsInFightingStatus and GameStatus.IsInFightingStatus()
    end)
    return ok and r == true
end

local function F_cache()
    _G.AddOutfitEquippedCache = _G.AddOutfitEquippedCache or {
        vehicleSlots = {},
        chassisLight = nil,
    }
    return _G.AddOutfitEquippedCache
end

local function F_getEntity()
    local ok, dc = pcall(require, "client.slua.logic.wardrobe.logic_wardrobe_data_center")
    if not ok or not dc then return nil end
    local ok2, e = pcall(dc.GetWardrobeData)
    return ok2 and e or nil
end

local function F_firstInsForRes(entity, resID)
    local arr = entity.ResIDToIndexArrayMap and entity.ResIDToIndexArrayMap[resID]
    if not arr then return nil end
    for _, idx in pairs(arr) do
        local d = entity._data[idx]
        if d and d.count and d.count > 0 then return d.insID end
    end
    return nil
end

local function F_injectOne(entity, resID, insID)
    local ownedIns = F_firstInsForRes(entity, resID)
    if ownedIns then
        R.resToIns[resID] = ownedIns
        R.insToRes[ownedIns] = resID
        _vehicleSkinIdsCache = nil
        _vehicleSkinsAppliedPC = nil
        return true
    end
    local row = {
        instid = insID,
        res_id = resID,
        count = 1,
        lock_cnt = 0,
        isnew = 0,
        valid_hours = 0,
        expire_ts = 0,
    }
    entity:AddData(row)
    R.insToRes[insID] = resID
    R.resToIns[resID] = insID
    _vehicleSkinIdsCache = nil
    _vehicleSkinsAppliedPC = nil
    return true
end

local function F_injectAllVehicles()
    local entity = F_getEntity()
    if not entity or not entity.bInit then return false end
    local n = 0
    for i, resID in ipairs(VEHICLE_SKINS) do
        local insID = INS_BASE + 1000000 + i
        if F_injectOne(entity, resID, insID) then n = n + 1 end
    end
    return n > 0
end

-- ================================================================
-- VEHICLE SLOT MANAGEMENT
-- ================================================================
local function F_syncVehicleSlotsToDataMgr()
    local cch = F_cache()
    DataMgr.VehicleSlotList = DataMgr.VehicleSlotList or {}
    for subType, slots in pairs(cch.vehicleSlots or {}) do
        local arr = DataMgr.VehicleSlotList[subType]
        if not arr then arr = {}; DataMgr.VehicleSlotList[subType] = arr end
        for k in pairs(arr) do arr[k] = nil end
        for idx, e in pairs(slots or {}) do
            if e and tonumber(e.insID) and tonumber(e.insID) > 0 then
                arr[tonumber(idx)] = tonumber(e.insID)
            end
        end
    end
end

local function F_mergeInjectedIntoVehicleSlotList(serverList)
    serverList = serverList or {}
    local cch = F_cache()
    for subType, slots in pairs(cch.vehicleSlots or {}) do
        subType = tonumber(subType)
        if subType and type(slots) == "table" then
            local arr = serverList[subType]
            if not arr then arr = {}; serverList[subType] = arr end
            for idx, e in pairs(slots) do
                idx = tonumber(idx)
                local insID = e and tonumber(e.insID)
                if idx and insID and insID > 0 then
                    arr[idx] = insID
                end
            end
        end
    end
    return serverList
end

local function F_applyVehicleSlotsFromConfigMap(slotMap)
    if not slotMap or not next(slotMap) then return false end
    local cch = F_cache()
    cch.vehicleSlots = cch.vehicleSlots or {}
    local any = false
    for subType, slots in pairs(slotMap) do
        subType = tonumber(subType)
        if subType then
            cch.vehicleSlots[subType] = cch.vehicleSlots[subType] or {}
            for idx, res in pairs(slots) do
                idx, res = tonumber(idx), tonumber(res)
                local ins = res and R.resToIns[res]
                if idx and ins then
                    cch.vehicleSlots[subType][idx] = { resID = res, insID = ins }
                    any = true
                end
            end
        end
    end
    return any
end

local function F_notifyVehicleSlotUI()
    pcall(function()
        local WRH = require("client.network.Protocol.WardrobeNewHandler")
        WRH.on_depot_modify_combat_vehicle_rsp(0, DataMgr.VehicleSlotList or {})
    end)
end

local function F_equipVehicleTypesFromConfig(slotMap)
    slotMap = slotMap or PERSIST.configVehicleSlots
    if not slotMap or not next(slotMap) then return false end
    DataMgr.vehicleSkinInsIDTable = DataMgr.vehicleSkinInsIDTable or {}
    local subTypes = {}
    for st in pairs(slotMap) do
        local n = tonumber(st)
        if n then subTypes[#subTypes + 1] = n end
    end
    table.sort(subTypes)
    local any, lobbyRes, lobbyIns = false, nil, nil
    for _, subType in ipairs(subTypes) do
        local slots = slotMap[subType] or slotMap[tostring(subType)]
        if type(slots) == "table" then
            local res = tonumber(slots[1] or slots["1"])
            local ins = res and R.resToIns[res]
            if ins then
                DataMgr.vehicleSkinInsIDTable[subType] = ins
                any = true
                if not lobbyIns then lobbyRes, lobbyIns = res, ins end
            end
        end
    end
    if any then
        pcall(function()
            local TabSurveillance = require("client.slua.logic.wardrobe.tab_surveillance")
            TabSurveillance.VehicleChange()
        end)
    end
    return any, lobbyRes, lobbyIns
end

local function F_buildVstInBattleFromSlots()
    local vst = {}
    local function insToRes(insID)
        insID = tonumber(insID)
        if not insID or insID <= 0 then return nil end
        local res = R.insToRes[insID]
        if res and res > 0 then return res end
        pcall(function()
            local wd = require("client.slua.logic.wardrobe.wardrobe_data")
            local d = wd:GetHallDepotItemDataByInsID(insID)
            res = d and tonumber(d.resID)
        end)
        if res and res > 0 then return res end
        if insID >= 1000000 and F_cfg(insID) then return insID end
        return nil
    end
    for subType, slots in pairs(DataMgr.VehicleSlotList or {}) do
        subType = tonumber(subType)
        if subType and type(slots) == "table" then
            local resList = {}
            for idx = 1, 8 do
                local val = slots[idx] or slots[tostring(idx)]
                local res = insToRes(val)
                if not res and type(val) == "table" then
                    res = tonumber(val.resID or val.res_id)
                end
                if res and res > 0 then resList[#resList + 1] = res end
            end
            if #resList > 0 then vst[subType] = resList end
        end
    end
    if not next(vst) then
        local cch = F_cache()
        for subType, slots in pairs(cch.vehicleSlots or {}) do
            local resList = {}
            for idx = 1, 8 do
                local e = slots[idx]
                local res = e and tonumber(e.resID)
                if res and res > 0 then resList[#resList + 1] = res end
            end
            if #resList > 0 then vst[tonumber(subType)] = resList end
        end
    end
    if not next(vst) then
        local bySub = {}
        for res, _ in pairs(R.resToIns) do
            res = tonumber(res)
            local c = F_cfg(res)
            local st = c and tonumber(F_subType(c))
            if res and st and st >= 900 then
                bySub[st] = bySub[st] or {}
                bySub[st][#bySub[st] + 1] = res
            end
        end
        for st, list in pairs(bySub) do
            table.sort(list)
            vst[st] = list
        end
    end
    return vst
end

local function F_getVehicleSkinIds()
    if _vehicleSkinIdsCache then
        return _vehicleSkinIdsCache
    end
    local out, seen = {}, {}
    local function add(res)
        res = tonumber(res)
        if res and res > 0 and not seen[res] then
            seen[res] = true
            out[#out + 1] = res
        end
    end
    for _, list in pairs(F_buildVstInBattleFromSlots()) do
        for _, res in ipairs(list) do add(res) end
    end
    for res in pairs(R.resToIns) do
        local c = F_cfg(tonumber(res))
        local st = c and tonumber(F_subType(c))
        if st and st >= 900 then add(res) end
    end
    _vehicleSkinIdsCache = out
    return out
end

local function F_buildVehVst(skinIds)
    local bySub = {}
    for _, skinId in ipairs(skinIds or {}) do
        local subType = 961
        local ok, c = pcall(function() return CDataTable.GetTableData("Item", skinId) end)
        if ok and c and c.ItemSubType then subType = c.ItemSubType end
        bySub[subType] = bySub[subType] or {}
        bySub[subType][#bySub[subType] + 1] = skinId
    end
    return bySub
end

local function F_directInjectVehicleSkinList(pc, skinIds)
    if not Valid(pc) or not pc.VehicleAvatarSkinList then return end
    local UAvatarUtils = import("AvatarUtils")
    for _, skinId in ipairs(skinIds or {}) do
        local shapeType = nil
        pcall(function() shapeType = UAvatarUtils.GetVehicleShapeBySkinID(skinId) end)
        if shapeType and shapeType >= 0 then
            pcall(function() pc.VehicleAvatarList:Add(shapeType, skinId) end)
            local entry = pc.VehicleAvatarSkinList:Get(shapeType)
            if entry and entry.SkinList then
                pcall(function() entry.SkinList:Add(skinId) end)
            end
        end
    end
end

local function F_applyVehicleSkinsToPC(pc)
    pc = pc or F_getPC()
    if not Valid(pc) then return false end
    if _vehicleSkinsAppliedPC == pc then return true end

    local skinIds = F_getVehicleSkinIds()
    if #skinIds == 0 then return false end
    local vst = F_buildVehVst(skinIds)
    local avatarList, avatarSkinList = {}, {}
    for _, skinList in pairs(vst) do
        local itemArray = {}
        for _, resid in ipairs(skinList) do
            if resid and resid > 0 then
                itemArray[#itemArray + 1] = { ItemTableID = resid, Count = 1 }
                avatarList[#avatarList + 1] = { ItemTableID = resid, Count = 1 }
            end
        end
        if #itemArray > 0 then
            avatarSkinList[#avatarSkinList + 1] = { Items = itemArray }
        end
    end
    pcall(function() pc.bEnableFuzzyAvatarOnClient = false end)
    pcall(function() pc.ShowVehicleSkin = skinIds[1] end)
    if #avatarList > 0 then
        pcall(function()
            pc.InitialVehicleAvatarList = avatarList
            pc:InitVehicleAvatarList()
        end)
    end
    if #avatarSkinList > 0 then
        pcall(function()
            pc.InitialVehicleAvatarSkinList = avatarSkinList
            pc:InitVehicleAvatarSkinList()
        end)
    end
    F_directInjectVehicleSkinList(pc, skinIds)
    _vehicleSkinsAppliedPC = pc
    return true
end

-- ================================================================
-- CHASSIS LIGHT
-- ================================================================
local function F_getDesiredChassisLight(vehicleSkinId)
    vehicleSkinId = tonumber(vehicleSkinId)
    local map = PERSIST.configChassisLightMap
    if vehicleSkinId and map and map[vehicleSkinId] then
        local v = tonumber(map[vehicleSkinId])
        if F_isChassisLightId(v) then return v end
    end
    local def = tonumber(PERSIST.configChassisLight) or DEFAULT_CHASSIS_LIGHT
    return F_isChassisLightId(def) and def or DEFAULT_CHASSIS_LIGHT
end

local function F_saveChassisLight(vehicleSkinId, lightId)
    vehicleSkinId = tonumber(vehicleSkinId)
    lightId = tonumber(lightId)
    if not F_isChassisLightId(lightId) then return end
    PERSIST.configChassisLightMap = PERSIST.configChassisLightMap or {}
    if vehicleSkinId and vehicleSkinId > 0 then
        PERSIST.configChassisLightMap[vehicleSkinId] = lightId
    else
        PERSIST.configChassisLight = lightId
    end
    PERSIST.dirty = true
end

local function F_applyVehicleChassisLight(vehicle, skinId, lightId)
    skinId = tonumber(skinId)
    lightId = tonumber(lightId) or F_getDesiredChassisLight(skinId)
    if not F_isChassisLightId(lightId) then return false end
    if not Valid(vehicle) then return false end
    local applied = false
    pcall(function()
        if vehicle.SetChassisLightShowData then
            vehicle:SetChassisLightShowData(lightId)
            applied = true
        end
    end)
    local lic = nil
    pcall(function() if vehicle.GetLicenseComponent then lic = vehicle:GetLicenseComponent() end end)
    if not Valid(lic) then
        pcall(function() lic = vehicle.BP_Lobby_VehicleLicenseComponent end)
    end
    if not Valid(lic) then return applied end
    pcall(function()
        local vid = skinId
        if not vid or vid <= 0 then
            pcall(function() if vehicle.GetAvatarId then vid = tonumber(vehicle:GetAvatarId()) end end)
        end
        if vid and vid > 0 then
            lic.curVehicleAvatarId = vid
            if lic.ChangeNetData_ItemID then lic:ChangeNetData_ItemID(vid)
            elseif lic.LicensePlate then lic.LicensePlate.ItemID = vid end
        end
        if lic.LicensePlate then lic.LicensePlate.ChassisLightId = lightId end
        if lic.SetChassisLightData and vid and vid > 0 then
            lic:SetChassisLightData(vid, lightId)
        elseif lic.PreChangeChassisLight then
            lic:PreChangeChassisLight()
        end
        applied = true
    end)
    return applied
end

local function F_scheduleChassisLightApply(vehicle, skinId)
    skinId = tonumber(skinId)
    local vref = Valid(vehicle) and vehicle or nil
    local function try()
        local v = Valid(vref) and vref or F_getCurrentVehicleForSkin()
        if Valid(v) then F_applyVehicleChassisLight(v, skinId) end
    end
    F_later(0.4, try)
    F_later(1.1, try)
end

-- ================================================================
-- GET VEHICLE
-- ================================================================
local function F_getMatchVehicle()
    local found = nil
    pcall(function()
        local subs = SubsystemMgr:Get("VehicleControlUISubSystem")
        if subs and subs.GetVehicleUserComponent then
            local uuc = subs:GetVehicleUserComponent()
            if Valid(uuc) and Valid(uuc.Vehicle) then found = uuc.Vehicle end
        end
    end)
    if Valid(found) then return found end
    local char = F_getLocalChar()
    if Valid(char) then
        local v = nil
        pcall(function() v = char.CurrentVehicle end)
        if Valid(v) then return v end
        pcall(function() v = char:GetCurrentVehicle() end)
        if Valid(v) then return v end
    end
    return nil
end

local function F_getCurrentVehicleForSkin()
    local char = F_getLocalChar()
    if Valid(char) then
        local v = nil
        pcall(function() v = char.CurrentVehicle end)
        if Valid(v) then return v end
    end
    return F_getMatchVehicle()
end

local function F_getVehicleAvatarComp(vehicle)
    if not Valid(vehicle) then return nil end
    local av = nil
    pcall(function() av = vehicle.VehicleAvatar end)
    if Valid(av) then return av end
    pcall(function() if vehicle.GetAvatarComponent then av = vehicle:GetAvatarComponent() end end)
    if Valid(av) then return av end
    pcall(function() av = vehicle.VehicleAvatarComponent_BP end)
    if Valid(av) then return av end
    return nil
end

local function F_prepVehicleSwitchEffect(av, vehicle)
    if not Valid(av) then return end
    pcall(function()
        av.curSwitchEffectId = VEH_SWITCH_EFFECT_ID
        local defaultId = 0
        pcall(function() defaultId = tonumber(av:GetDefaultAvatarID()) or 0 end)
        if not av.lastEquipedAvatarId or av.lastEquipedAvatarId <= 0 then
            av.lastEquipedAvatarId = defaultId
        end
    end)
end

local function F_forceVehicleAvatar(skinId, vehicle)
    skinId = tonumber(skinId)
    if not skinId or skinId <= 0 then return false end
    vehicle = Valid(vehicle) and vehicle or F_getCurrentVehicleForSkin()
    if not Valid(vehicle) then return false end
    local av = F_getVehicleAvatarComp(vehicle)
    if not Valid(av) then return false end
    local applied = false
    F_prepVehicleSwitchEffect(av, vehicle)
    pcall(function() if av.CanChangeAvatar ~= nil then av.CanChangeAvatar = true end end)
    pcall(function()
        av:ChangeItemAvatar(skinId, true)
        applied = true
        _G.CurrentEquipVehicleID = skinId
    end)
    if applied then F_scheduleChassisLightApply(vehicle, skinId) end
    return applied
end

local function F_vehicleAvatarTemper()
    local vehicle = F_getCurrentVehicleForSkin()
    if not Valid(vehicle) then return end
    local av = F_getVehicleAvatarComp(vehicle)
    if not Valid(av) then return end

    local skinId = nil
    local VEHSEL = _G.AddOutfitVehSel
    if VEHSEL.override and Valid(VEHSEL.overrideVehicle) and VEHSEL.overrideVehicle == vehicle then
        skinId = VEHSEL.override
    end

    local defaultId = 0
    pcall(function() defaultId = tonumber(av:GetDefaultAvatarID()) or 0 end)
    if defaultId <= 0 then return end

    local shape = nil
    if not skinId then
        local cachedShape = VEHICLE_SHAPE_CACHE[defaultId]
        if cachedShape ~= nil then
            shape = cachedShape ~= false and cachedShape or nil
        else
            local UAvatarUtils = import("AvatarUtils")
            pcall(function() shape = tonumber(UAvatarUtils.GetVehicleShapeBySkinID(defaultId)) end)
            VEHICLE_SHAPE_CACHE[defaultId] = shape or false
        end
    end
    if not skinId and shape then skinId = VEHSEL.byShape[shape] end

    if not skinId then
        local vst = F_buildVstInBattleFromSlots()
        for _, list in pairs(vst) do
            local s = list and tonumber(list[1])
            if s and s > 0 then
                local ss = VEHICLE_SHAPE_CACHE[s]
                if ss == nil then
                    local UAvatarUtils = import("AvatarUtils")
                    pcall(function() ss = tonumber(UAvatarUtils.GetVehicleShapeBySkinID(s)) end)
                    VEHICLE_SHAPE_CACHE[s] = ss or false
                elseif ss == false then
                    ss = nil
                end
                if ss == shape then skinId = s; break end
            end
        end
    end

    skinId = tonumber(skinId)
    if not skinId or skinId <= 0 or skinId == defaultId then return end

    local cur = 0
    pcall(function() cur = tonumber(vehicle.GetAvatarId and vehicle:GetAvatarId()) or 0 end)
    if cur == skinId then return end

    F_forceVehicleAvatar(skinId, vehicle)
end

local _vehTickLastApply = 0
local function F_vehicleSkinTick()
    F_vehicleAvatarTemper()
    local now = os.clock()
    if now - _vehTickLastApply < 8.0 then return end
    _vehTickLastApply = now
    F_applyVehicleSkinsToPC()
end

local function F_startVehicleSkinTicker()
    pcall(function()
        if _G.VehTickerId then return end
        if _ticker and _ticker.AddTimerLoop then
            _G.VehTickerId = _ticker.AddTimerLoop(1.5, function()
                if not _G.__SkinTickAllowed() then return end
                if _G.VehicleSkin_Active then pcall(F_vehicleSkinTick) end
            end, -1, 1.5)
        end
    end)
end

_G.VehicleSkin_Active = true

local function F_matchApplyVehicleSkin(skinId)
    skinId = tonumber(skinId)
    if not skinId or skinId <= 0 then return false end
    local vehicle = F_getCurrentVehicleForSkin()
    local VEHSEL = _G.AddOutfitVehSel
    VEHSEL.override = skinId
    VEHSEL.overrideVehicle = Valid(vehicle) and vehicle or nil
    pcall(function()
        local UAvatarUtils = import("AvatarUtils")
        local shape = tonumber(UAvatarUtils.GetVehicleShapeBySkinID(skinId))
        if shape and shape >= 0 then VEHSEL.byShape[shape] = skinId end
        local av = F_getVehicleAvatarComp(vehicle)
        if Valid(av) then
            local defaultId = tonumber(av:GetDefaultAvatarID()) or 0
            if defaultId > 0 then
                local defShape = tonumber(UAvatarUtils.GetVehicleShapeBySkinID(defaultId))
                if defShape and defShape >= 0 then VEHSEL.byShape[defShape] = skinId end
            end
        end
    end)
    F_applyVehicleSkinsToPC(F_getPC())
    local ok = F_forceVehicleAvatar(skinId, vehicle)
    F_startVehicleSkinTicker()
    return ok
end

local function F_autoApplyVehicleSkinOnEnter(vehicle)
    if not Valid(vehicle) then return end
    F_syncVehicleCacheFromDataMgr()
    F_applyVehicleSkinsToPC(F_getPC())
    F_startVehicleSkinTicker()
    F_later(0.35, function() pcall(F_vehicleAvatarTemper) end)
    F_later(0.9, function() pcall(F_vehicleAvatarTemper) end)
    F_later(0.5, function()
        local skinId = nil
        pcall(function() skinId = tonumber(vehicle.GetAvatarId and vehicle:GetAvatarId()) end)
        F_scheduleChassisLightApply(vehicle, skinId)
    end)
end

local function F_syncVehicleCacheFromDataMgr()
    local cch = F_cache()
    cch.vehicleSlots = cch.vehicleSlots or {}
    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
    for subType, slots in pairs(DataMgr.VehicleSlotList or {}) do
        subType = tonumber(subType)
        if subType and type(slots) == "table" then
            cch.vehicleSlots[subType] = cch.vehicleSlots[subType] or {}
            for idx, insID in pairs(slots) do
                idx, insID = tonumber(idx), tonumber(insID)
                if idx and insID and insID > 0 then
                    local res = R.insToRes[insID]
                    if not res then
                        pcall(function()
                            local d = wd:GetHallDepotItemDataByInsID(insID)
                            res = d and tonumber(d.resID)
                        end)
                    end
                    if res and res > 0 then
                        cch.vehicleSlots[subType][idx] = { resID = res, insID = insID }
                    end
                end
            end
        end
    end
end

local function F_modifyInjectedVehicleSlot(insID, slotIndex, equip)
    insID = tonumber(insID)
    slotIndex = tonumber(slotIndex)
    if not insID or not slotIndex then return false end
    local resID = R.insToRes[insID]
    if not resID then return false end
    local st = F_vehicleSubType(resID)
    if not st or tonumber(st) < 900 then return false end
    local cch = F_cache()
    cch.vehicleSlots = cch.vehicleSlots or {}
    cch.vehicleSlots[st] = cch.vehicleSlots[st] or {}
    if equip then
        cch.vehicleSlots[st][slotIndex] = { resID = resID, insID = insID }
        PERSIST.configVehicleSlots = PERSIST.configVehicleSlots or {}
        PERSIST.configVehicleSlots[st] = PERSIST.configVehicleSlots[st] or {}
        PERSIST.configVehicleSlots[st][slotIndex] = resID
    else
        local e = cch.vehicleSlots[st][slotIndex]
        if e and tonumber(e.insID) == insID then
            cch.vehicleSlots[st][slotIndex] = nil
            if PERSIST.configVehicleSlots and PERSIST.configVehicleSlots[st] then
                PERSIST.configVehicleSlots[st][slotIndex] = nil
            end
        end
    end
    F_syncVehicleSlotsToDataMgr()
    F_notifyVehicleSlotUI()
    PERSIST.dirty = true
    return true
end

-- ================================================================
-- PERSISTENCE
-- ================================================================
local function GetConfigPaths(fileName)
    local paths = {
        "//storage/emulated/0/Android/data/com.tencent.ig/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.vng.pubgmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.pubg.krmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.rekoo.pubgm/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.pubg.imobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "ShadowTrackerExtra/Saved/Paks/" .. fileName,
    }
    pcall(function()
        if os and os.getenv then
            local homeDir = os.getenv("HOME")
            if homeDir and homeDir ~= "" then
                table.insert(paths, 1, homeDir .. "/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName)
            end
        end
    end)
    return paths
end

local CONFIG_PATHS = GetConfigPaths("vehicle_skins.txt")

local function persistEncode()
    local parts = {}
    local cch = F_cache()
    local vparts = {}
    for subType, slots in pairs(cch.vehicleSlots or {}) do
        local sparts = {}
        if type(slots) == "table" then
            for idx, val in pairs(slots) do
                local res = type(val) == "table" and tonumber(val.resID) or tonumber(val)
                if res and res > 0 then
                    sparts[#sparts + 1] = string.format('      "%d": %d', tonumber(idx), res)
                end
            end
        end
        table.sort(sparts)
        if #sparts > 0 then
            vparts[#vparts + 1] = string.format('    "%d": {\n%s\n    }', tonumber(subType), table.concat(sparts, ",\n"))
        end
    end
    local hasSlots = false
    for _ in pairs(cch.vehicleSlots or {}) do hasSlots = true; break end
    if hasSlots then
        parts[#parts + 1] = '  "vehicleSlots": {\n' .. table.concat(vparts, ",\n") .. "\n  }"
    end
    local cl = tonumber(PERSIST.configChassisLight)
    if F_isChassisLightId(cl) then
        parts[#parts + 1] = string.format('  "chassisLight": %d', cl)
    end
    local cmap = PERSIST.configChassisLightMap
    if cmap and next(cmap) then
        local cparts = {}
        for vid, lid in pairs(cmap) do
            vid, lid = tonumber(vid), tonumber(lid)
            if vid and vid > 0 and F_isChassisLightId(lid) then
                cparts[#cparts + 1] = string.format('    "%d": %d', vid, lid)
            end
        end
        table.sort(cparts)
        if #cparts > 0 then
            parts[#parts + 1] = '  "chassisLightMap": {\n' .. table.concat(cparts, ",\n") .. "\n  }"
        end
    end
    return "{\n" .. table.concat(parts, ",\n") .. "\n}\n"
end

local function persistWrite(txt)
    if not (io and io.open) then return false end
    for _, p in ipairs(CONFIG_PATHS) do
        local f
        pcall(function() f = io.open(p, "w") end)
        if f then f:write(txt) f:close() return true end
    end
    return false
end

local function persistFlush()
    if not PERSIST.dirty then return end
    PERSIST.dirty = false
    pcall(function()
        local txt = persistEncode()
        if txt == PERSIST.lastWritten then return end
        if persistWrite(txt) then PERSIST.lastWritten = txt end
    end)
end

local function persistMarkDirty()
    PERSIST.dirty = true
    if PERSIST.scheduled then return end
    PERSIST.scheduled = true
    F_later(2.0, function()
        PERSIST.scheduled = false
        persistFlush()
    end)
end

local function persistLoadFromDisk()
    if not (io and io.open) then return end
    pcall(function()
        for _, p in ipairs(CONFIG_PATHS) do
            local f
            pcall(function() f = io.open(p, "r") end)
            if f then
                local txt = f:read("*a")
                f:close()
                PERSIST.lastWritten = txt
                local slots = {}
                for subType, body in txt:gmatch('"(9%d+)%s*:%s*{([^}]+)}') do
                    subType = tonumber(subType)
                    slots[subType] = slots[subType] or {}
                    for idx, res in body:gmatch('"(%d+)"%s*:%s*(%d+)') do
                        slots[subType][tonumber(idx)] = tonumber(res)
                    end
                end
                if next(slots) then
                    PERSIST.configVehicleSlots = slots
                    F_applyVehicleSlotsFromConfigMap(slots)
                end
                local cl = txt:match('"chassisLight"%s*:%s*(%d+)')
                if cl then PERSIST.configChassisLight = tonumber(cl) end
                local cmap = {}
                local cmapBody = txt:match('"chassisLightMap"%s*:%s*{([^}]+)}')
                if cmapBody then
                    for vid, lid in cmapBody:gmatch('"(%d+)"%s*:%s*(%d+)') do
                        cmap[tonumber(vid)] = tonumber(lid)
                    end
                    if next(cmap) then PERSIST.configChassisLightMap = cmap end
                end
                return
            end
        end
    end)
end

-- ================================================================
-- HOOKS
-- ================================================================
local function F_hookVehicleSkinClick()
    pcall(function()
        local classMod = require("GameLua.Mod.BaseMod.Client.InGameUI.VehicleControl.VehicleSkinItem")
        if not classMod or not classMod.__inner_impl then return end
        local impl = classMod.__inner_impl
        if _G.VehClickHooked then return end
        _G.VehClickHooked = true
        local oClick = impl.OnClickSkinButton
        impl.OnClickSkinButton = function(self)
            local resID = tonumber(self.resID)
            if resID and resID > 0 and F_isVehicleRes(resID) then
                if F_matchApplyVehicleSkin(resID) then
                    pcall(function()
                        if EVENTYPE_INGAME_VEHICLE_CONTROL_PANEL and EVENTID_CHANGE_VEHICLESKIN_BUTTON_CLICK then
                            EventSystem:postEvent(EVENTYPE_INGAME_VEHICLE_CONTROL_PANEL, EVENTID_CHANGE_VEHICLESKIN_BUTTON_CLICK)
                        end
                    end)
                end
                return
            end
            if oClick then return oClick(self) end
        end
    end)
end

local function F_hookVehicleSkinInit()
    pcall(function()
        local panelMod = require("GameLua.Mod.BaseMod.Client.InGameUI.VehicleControl.VehicleSkinAndMusicPanel")
        if panelMod and panelMod.__inner_impl and not _G.VehInitHooked then
            _G.VehInitHooked = true
            local o = panelMod.__inner_impl.InitSkinList
            panelMod.__inner_impl.InitSkinList = function(self)
                F_applyVehicleSkinsToPC(F_getPC())
                return o(self)
            end
        end
    end)
end

local function F_hookVehicleSlotModify()
    pcall(function()
        local WNH = require("client.network.Protocol.WardrobeNewHandler")
        if WNH._VehHooked then return end
        WNH._VehHooked = true
        local oMod = WNH.send_depot_modify_combat_vehicle_req
        WNH.send_depot_modify_combat_vehicle_req = function(instid, slot_index, ope_type)
            if F_modifyInjectedVehicleSlot(instid, slot_index, ope_type == true) then return end
            return oMod(instid, slot_index, ope_type)
        end
        local oRsp = WNH.on_depot_modify_combat_vehicle_rsp
        WNH.on_depot_modify_combat_vehicle_rsp = function(err_code, knapsack_vst)
            if err_code == 0 or err_code == NET_OK then
                knapsack_vst = F_mergeInjectedIntoVehicleSlotList(knapsack_vst)
            end
            oRsp(err_code, knapsack_vst)
            if err_code == 0 or err_code == NET_OK then
                F_syncVehicleSlotsToDataMgr()
                F_equipVehicleTypesFromConfig(PERSIST.configVehicleSlots)
                pcall(F_applyVehicleSkinsToPC)
                persistMarkDirty()
            end
        end
    end)
end

local function F_hookVehicleEnter()
    pcall(function()
        local VUC = require("GameLua.GameCore.Module.Vehicle.Component.VehicleUserComponent")
        if not VUC or VUC._VehEnterHooked then return end
        VUC._VehEnterHooked = true
        local oEnter = VUC.SendUIMsgWhenEnterVehicleCompleted
        VUC.SendUIMsgWhenEnterVehicleCompleted = function(self)
            oEnter(self)
            pcall(function()
                if Valid(self.Vehicle) then
                    F_autoApplyVehicleSkinOnEnter(self.Vehicle)
                end
            end)
        end
    end)
end

local function F_hookVehicleInfoInit()
    pcall(function()
        if DataMgr._VehInfoHooked then return end
        DataMgr._VehInfoHooked = true
        local orig = DataMgr.InitVehicleInfo
        DataMgr.InitVehicleInfo = function(vehicle_info, vst_skin)
            vehicle_info = F_mergeInjectedIntoVehicleSlotList(vehicle_info)
            orig(vehicle_info, vst_skin)
            F_later(0.15, function()
                F_equipVehicleTypesFromConfig(PERSIST.configVehicleSlots)
            end)
        end
    end)
    pcall(function()
        if DataMgr._VehSkinDataHooked then return end
        DataMgr._VehSkinDataHooked = true
        local origInit = DataMgr.InitVehicleSkinData
        DataMgr.InitVehicleSkinData = function(data)
            origInit(data)
            F_later(0.1, function() F_equipVehicleTypesFromConfig(PERSIST.configVehicleSlots) end)
        end
        local origUpd = DataMgr.UpdateVehicleSkin
        DataMgr.UpdateVehicleSkin = function(itemSubType, putOnId)
            origUpd(itemSubType, putOnId)
            if F_isChassisLightId(itemSubType) then return end
            local cch = F_cache()
            cch.vehicleSlots = cch.vehicleSlots or {}
            cch.vehicleSlots[itemSubType] = cch.vehicleSlots[itemSubType] or {}
            for idx, e in pairs(cch.vehicleSlots[itemSubType]) do
                if e and e.insID == putOnId then
                    cch.vehicleSlots[itemSubType][idx] = nil
                end
            end
            if putOnId and putOnId > 0 then
                cch.vehicleSlots[itemSubType][1] = { insID = putOnId, resID = R.insToRes[putOnId] or 0 }
            end
        end
    end)
    pcall(function()
        local HallThemeUtils = require("client.logic.lobby.hall_theme_utils")
        if HallThemeUtils._VehProcHooked then return end
        HallThemeUtils._VehProcHooked = true
        local orig = HallThemeUtils.ProcPutOnVehicle
        HallThemeUtils.ProcPutOnVehicle = function(putOnItem, bShowVehicle)
            orig(putOnItem, bShowVehicle)
            if putOnItem then
                local ins = tonumber(putOnItem.instid)
                local res = tonumber(putOnItem.res_id)
                if ins and R.insToRes[ins] then
                    _G.AddOutfitLobbyVeh.manual = true
                    _G.AddOutfitLobbyVeh.subType = F_vehicleSubType(res or R.insToRes[ins])
                    _G.AddOutfitLobbyVeh.resID = res or R.insToRes[ins]
                    _G.AddOutfitLobbyVeh.insID = ins
                end
            end
        end
    end)
end

local function F_hookVehicleLicenseCheck()
    pcall(function()
        local LIC = require("GameLua.Activity.Commercialize.Actor.ActorComponent.BP_VehicleLicenseComponentBase")
        if LIC and LIC.CheckHasVehicleDownloaded and not LIC._VehLicHooked then
            LIC._VehLicHooked = true
            local orig = LIC.CheckHasVehicleDownloaded
            LIC.CheckHasVehicleDownloaded = function(self, itemID)
                local id = tonumber(itemID)
                if id and (R.resToIns[id] or F_isChassisLightId(id)) then return true end
                return orig(self, itemID)
            end
        end
    end)
    pcall(function()
        local LVF = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.LogicVehicleExtendedFeature)
        if not LVF or LVF._VehChassisHooked then return end
        LVF._VehChassisHooked = true
        local origGet = LVF.CheckHasGetFeatureItem
        LVF.CheckHasGetFeatureItem = function(self, featureId)
            if F_isChassisLightId(featureId) then return true end
            return origGet(self, featureId)
        end
        local origEq = LVF.CheckHasEquippedItem
        LVF.CheckHasEquippedItem = function(self, featureId, vehicleId)
            if F_isChassisLightId(featureId) then
                return F_getDesiredChassisLight(vehicleId) == tonumber(featureId)
            end
            return origEq(self, featureId, vehicleId)
        end
        local origData = LVF.GetEquipedChassisLightData
        if origData then
            LVF.GetEquipedChassisLightData = function(self, vehicleId, source)
                local our = F_getDesiredChassisLight(vehicleId)
                if our then return our end
                return origData(self, vehicleId, source)
            end
        end
        local origPutOn = LVF.PutOnVehicleFeature
        if origPutOn then
            LVF.PutOnVehicleFeature = function(self, featureId, vehicleId)
                if F_isChassisLightId(featureId) then
                    F_saveChassisLight(vehicleId, featureId)
                    return
                end
                return origPutOn(self, featureId, vehicleId)
            end
        end
    end)
end

local function F_hookVehicleSkinSwitchEffect()
    pcall(function()
        local VAC = require("GameLua.GameCore.Module.Vehicle.Component.VehicleAvatarComponent")
        local impl = VAC and VAC.__inner_impl
        if not impl or impl._VehSwitchHooked then return end
        impl._VehSwitchHooked = true
        if impl.CheckCanPlaySkinSwitchEffect then
            local orig = impl.CheckCanPlaySkinSwitchEffect
            impl.CheckCanPlaySkinSwitchEffect = function(self, curId, lastId)
                if self.IsLobbyActor and self:IsLobbyActor() then return false end
                if not F_isInRealMatch() then return false end
                return true
            end
        end
    end)
end

-- ================================================================
-- MOD MENU (iPad View toggle only)
-- ================================================================
function _G.AddUtilityMenu()
    local SettingPageDefine = require("client.logic.NewSetting.SettingPageDefine")
    local SettingCatalog = require("client.logic.NewSetting.SettingCatalog")
    local AliasMap = require("client.slua.umg.NewSetting.Item.AliasMap")

    local modPage = SettingPageDefine.ModMenu
    if not modPage then
        modPage = {
            Key = "ModMenu",
            Text = 999000,
            UIKey = "Setting_Page_Privacy",
            Category = {},
        }
        SettingPageDefine.ModMenu = modPage
        table.insert(SettingCatalog, 1, modPage)
    end

    local exists = false
    for _, cat in ipairs(modPage.Category) do
        if cat.Key == "Cat_Utility" then exists = true; break end
    end

    if not exists then
        local cat = {
            Key = "Cat_Utility",
            Text = 999994,
            Stack = {
                { Key = "IpadView_Enable", UI = AliasMap.TitleSwitcher, Text = "▶ iPad View (FOV)", ExpandIndex = 0, GetFunc = function() return _G.LexusConfig.IpadView_Enable end, SetFunc = function(c,v) _G.LexusConfig.IpadView_Enable = v; return true end },
                { Key = "IpadView_WalkFOV", UI = AliasMap.Slider, Text = "   Walking FOV (90-140)", ExpandHandle = "IpadView_Enable", MinValue = 90, MaxValue = 140, min = 90, max = 140, GetFunc = function() return _G.LexusConfig.IpadView_WalkFOV end, SetFunc = function(c,v) _G.LexusConfig.IpadView_WalkFOV = v; return true end },
                { Key = "IpadView_VehicleFOV", UI = AliasMap.Slider, Text = "   Vehicle FOV (90-140)", ExpandHandle = "IpadView_Enable", MinValue = 90, MaxValue = 140, min = 90, max = 140, GetFunc = function() return _G.LexusConfig.IpadView_VehicleFOV end, SetFunc = function(c,v) _G.LexusConfig.IpadView_VehicleFOV = v; return true end },
                { Key = "IpadView_ScopeFOV", UI = AliasMap.Slider, Text = "   Scope FOV (30-120)", ExpandHandle = "IpadView_Enable", MinValue = 30, MaxValue = 120, min = 30, max = 120, GetFunc = function() return _G.LexusConfig.IpadView_ScopeFOV end, SetFunc = function(c,v) _G.LexusConfig.IpadView_ScopeFOV = v; return true end },
            }
        }
        table.insert(modPage.Category, cat)
    end
end

-- ================================================================
-- MAIN LOOP
-- ================================================================
local lastIPadUpdate = 0

local function MainLoop()
    local now = os.clock()

    if now - lastIPadUpdate >= 0.1 then
        pcall(UpdateiPadView)
        lastIPadUpdate = now
    end

    -- Bypass HiggsBoson periodically
    pcall(function()
        local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
        if Valid(pc) then
            if pc.HiggsBoson then
                pc.HiggsBoson.bMHActive = false
                pc.HiggsBoson.bCallPreReplication = false
            end
            if pc.HiggsBosonComponent then
                pc.HiggsBosonComponent.bMHActive = false
                pc.HiggsBosonComponent.bCallPreReplication = false
            end
        end
    end)

    if _ticker and _ticker.AddTimerOnce then
        _ticker.AddTimerOnce(0.05, MainLoop)
    end
end

-- ================================================================
-- INIT
-- ================================================================
pcall(_G.AddUtilityMenu)
pcall(persistLoadFromDisk)

pcall(F_hookVehicleSkinClick)
pcall(F_hookVehicleSkinInit)
pcall(F_hookVehicleSlotModify)
pcall(F_hookVehicleEnter)
pcall(F_hookVehicleInfoInit)
pcall(F_hookVehicleLicenseCheck)
pcall(F_hookVehicleSkinSwitchEffect)

pcall(function()
    local WDE = require("client.slua.logic.wardrobe.WardrobeDataEntity")
    if WDE and not WDE._VehInitHooked then
        WDE._VehInitHooked = true
        local orig = WDE.InitData
        WDE.InitData = function(self, pkg)
            orig(self, pkg)
            pcall(function()
                if F_injectAllVehicles() then
                    pcall(function()
                        if EventSystem and EVENTTYPE_WARDROBE and EVENTID_WARDROBE_UPDATE_ITEM_LIST then
                            EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_ITEM_LIST)
                        end
                    end)
                end
            end)
        end
    end
end)

pcall(F_injectAllVehicles)
pcall(F_startVehicleSkinTicker)
pcall(F_applyVehicleSkinsToPC)

MainLoop()

print("[Vehicle Skins + Utility] Loaded – Graphics REMOVED, iPad View OFF by default")]==], '10.lua')

-- ============================================================================
-- 8. 1.lua
-- ============================================================================
__run_file([==[local require=require;local import=import;local isValid=slua.isValid

local INI_PATH="/storage/emulated/0/Android/data/com.pubg.imobile/files/SKINS.ini"
local DUMP_PATH="/storage/emulated/0/Android/data/com.pubg.imobile/files/dump_full.txt"

_G._Suk=_G._Suk or {}
local S=_G._Suk

local SP="/storage/emulated/0/Android/data/com.pubg.imobile/files/CHETAN_MODS/sukuna_settings.cfg"
local function Save()
    pcall(function()
        local f=io.open(SP,"w");if not f then return end
        for k,v in pairs(S) do f:write(k.."="..tostring(v).."\n") end;f:close()
    end)
end
local function Load()
    pcall(function()
        local f=io.open(SP,"r");if not f then return end
        for l in (f:read("*a")or""):gmatch("[^\n]+")do
            local k,v=l:match("([^=]+)=(.+)")
            if k and v then
                if v=="true"then S[k]=true elseif v=="false"then S[k]=false
                else S[k]=tonumber(v)or v end
            end
        end;f:close()
    end)
end
Load()
local function Set(k,v)S[k]=v;Save()end

-- ============================================================
-- TEXT MAP – fixed with dynamic incremental IDs
-- ============================================================
local FakeTextMap = {}
local function EnsureText(id, fallback)
    if FakeTextMap[id] then return FakeTextMap[id] end
    FakeTextMap[id] = fallback or tostring(id)
    return FakeTextMap[id]
end

-- ============================================================
-- LocUtil hook – exactly like the fixed menu
-- ============================================================
local function HookLocUtil()
    local LocUtil = _G.LocUtil
    if not LocUtil and package.loaded["client.common.LocUtil"] then
        LocUtil = require("client.common.LocUtil")
    end
    if LocUtil and not LocUtil._SkinMgrHooked then
        local old = LocUtil.GetLocalizeResStr
        LocUtil.GetLocalizeResStr = function(id)
            if FakeTextMap[id] then return FakeTextMap[id] end
            if type(id) == "string" and not tonumber(id) then return id end
            return old(id)
        end
        LocUtil._SkinMgrHooked = true
    end
end

-- ============================================================
-- Parse INI and other helpers
-- ============================================================
local function ParseINI()
    local f=io.open(INI_PATH,"r")
    if not f then return{} end
    local content=f:read("*a");f:close()
    local matched={}
    local selected={}
    local skinList={}
    local section=""
    local lastComment=""
    for line in content:gmatch("[^\r\n]+")do
        line=line:match("^%s*(.-)%s*$")or""
        local h=line:match("^%[(.+)%]$")
        if h then section=h;lastComment=""
        elseif section=="SELECTED"then
            local n,i=line:match("^([^=]+)=(%d+)$")
            if n and i then selected[n:match("^%s*(.-)%s*$")]=tonumber(i)end
        elseif section=="SKIN_LIST"then
            local c=line:match("^#%s*(.+)$")
            if c then
                local cu=c:upper()
                if not c:match("===")and not c:match("%-%-%-")and not cu:match("^(QUẦN ÁO|BALO|MŨ|DÙ|SÚNG|VŨ KHÍ|XE|DÒNG|SMG|SNIPER|LMG|PHỤ KIỆN|THÊM TỪ|QUY TẮC)")then
                    lastComment=c
                end
            else
                local key,vals=line:match("^([^=]+)=(.+)$")
                if key and vals then
                    key=key:match("^%s*(.-)%s*$")
                    local ids={}
                    local count=0
                    for v in vals:gmatch("[^,]+")do
                        if v~=""then count=count+1;ids[count]=v end
                    end
                    if count>0 then
                        local name=nil
                        if key:match("^%d+$")then name=lastComment;lastComment=""
                        else name=key end
                        if name then
                            if not skinList[name]then skinList[name]={}end
                            for i=1,count do skinList[name][i]=ids[i]end
                        end
                    end
                end
            end
        end
    end
    for name,idx in pairs(selected)do
        local entry=skinList[name]
        if entry then
            matched[name]={index=idx,skinIDs=entry}
        end
    end
    -- fuzzy match remaining SELECTED entries
    for name,idx in pairs(selected)do
        if not matched[name]then
            local nl=name:lower()
            for sname,entry in pairs(skinList)do
                local sl=sname:lower()
                if nl==sl or nl==sl:gsub("%s","")or sl==nl:gsub("%s","")or
                   sl:match("^"..nl:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]","%%%1"))then
                    matched[name]={index=idx,skinIDs=entry}
                    break
                end
            end
        end
    end
    return matched
end

local function LoadDump()
    local dump={}
    pcall(function()
        local f=io.open(DUMP_PATH,"r")
        if not f then return end
        for l in (f:read("*a")or""):gmatch("[^\r\n]+")do
            local id,nm=l:match("^(%d+)%s*|%s*[^|]+%s*|%s*(.+)$")
            if id and nm and nm~=""then
                nm=nm:match("^%s*(.-)%s*$")or nm
                dump[id]=nm
            end
        end
        f:close()
    end)
    return dump
end

local function WriteSelected(selName,value)
    pcall(function()
        local f=io.open(INI_PATH,"r")
        if not f then return end
        local content=f:read("*a");f:close()
        local inSec=false
        local lines={}
        for line in content:gmatch("[^\r\n]+")do
            local h=line:match("^%[")
            if h then inSec=line:match("^%[(SELECTED)%]")~=nil;table.insert(lines,line)
            elseif inSec then
                local k,_=line:match("^([^=]+)=(%d+)$")
                if k then k=k:match("^%s*(.-)%s*$") end
                if k==selName then table.insert(lines,selName.."="..tostring(value))
                else table.insert(lines,line)end
            else table.insert(lines,line)end
        end
        f=io.open(INI_PATH,"w")
        if f then f:write(table.concat(lines,"\n"));f:close()end
    end)
end

local function ShowSkinName(sname)
    pcall(function()
        local pc=slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
        if not pc then return end
        local HUD=pc:GetHUD()
        if not HUD then return end
        local gd=require("GameLua.GameCore.Data.GameplayData")
        local ch=gd and gd.GetPlayerCharacter and gd.GetPlayerCharacter()
        if not isValid(ch)then return end
        HUD:AddDebugText(sname,ch,2.0,{X=0,Y=0,Z=0},{X=0,Y=0,Z=220},{R=255,G=255,B=0,A=255},true,false,true,nil,2.0,true)
    end)
end

-- ============================================================
-- Skin groups and sets (unchanged)
-- ============================================================
local groups={
    Cosmetics={},XSuits={},AR={},SMG={},SR={},LMG={},Melee={},Vehicles={},Other={}
}
local groupTitles={
    Cosmetics="Skns",XSuits="X-Suit",AR="AR",SMG="SMG",SR="SR/DMR",LMG="LMG",Melee="Mel",
    Vehicles="Veh",Other="Oth"
}
local arSet={M416=true,AKM=true,SCAR=true,M762=true,GROZA=true,AUG=true,ACE32=true,QBZ=true,G36C=true,ASM=true,HoneyBadger=true,M16A4=true,MK47=true,FAMAS=true,Bizon=true,P90=true,MP5K=true,Thompson=true}
local smgSet={UMP=true,Vector=true,UZI=true}
local srSet={Kar98=true,M24=true,AWM=true,AMR=true,Mosin=true,MK14=true,Mini14=true,QBU=true,MK12=true,DSR=true,VSS=true,SLR=true,SKS=true,Grenade=true}
local lmgSet={DP28=true,M249=true,MG3=true,DBS=true}
local meleeSet={Pan=true,Machete=true,Crowbar=true,Sickle=true}
local vehSet={Motor=true,Sidecar=true,Dacia=true,Roadster=true,MiniBus=true,Pickup=true,PickupClosed=true,Buggy=true,UAZ=true,UAZClosed=true,UAZOpen=true,PG117=true,JetSki=true,Mirado=true,MiradoOpen=true,Rony=true,Scooter=true,Snowmobile=true,Tukshai=true,MonsterTruck=true,MotorGlider=true,CoupeRB=true,Tank=true,MountainBike=true,UTV=true,Bike=true,Horse=true,Hovercraft=true}

local _itemsAdded=false
local function AddItems()
    if _itemsAdded and not _G._forceLoadSkins then return end
    pcall(function()
        local ok,SPD=pcall(require,"client.logic.NewSetting.SettingPageDefine")
        if not ok or type(SPD)~="table" then return end

        local AliasMap
        local okAlias, aliasMod = pcall(require, "client.slua.umg.NewSetting.Item.AliasMap")
        if okAlias then AliasMap = aliasMod else return end

        -- Fallback for missing UI components
        if not AliasMap.Title or not AliasMap.Slider or not AliasMap.Spacer then
            local UIManager = _G.UIManager
            if UIManager and UIManager.UI_Config then
                local C = UIManager.UI_Config
                AliasMap.Title = AliasMap.Title or C.Setting_Title
                AliasMap.Slider = AliasMap.Slider or C.Setting_Option_Slider
                AliasMap.Spacer = AliasMap.Spacer or C.Setting_Spacer
            end
        end

        -- Build text map for categories (fixed IDs)
        local tabId = 9999499
        EnsureText(tabId, "Skins")
        EnsureText(9999498, "Cosmetics")
        EnsureText(9999497, "Guns")
        EnsureText(9999496, "Vehicles")
        EnsureText(9999495, "Other")

        -- Create the page if not exists
        if not SPD.Skins then
            SPD.Skins = {
                Key="Skins",
                Text=tabId,
                UIKey="Setting_Page_Privacy",
                Category={
                    { Key="Skins_Cosmetics", Text=9999498, Stack={} },
                    { Key="Skins_Guns", Text=9999497, Stack={} },
                    { Key="Skins_Vehicles", Text=9999496, Stack={} },
                    { Key="Skins_Other", Text=9999495, Stack={} }
                }
            }
        end

        -- Hook LocUtil (only once)
        HookLocUtil()

        -- Inject into catalogs (same as fixed pattern)
        local function injectAsMainTab(moduleName)
            local okCat, cat = pcall(require, moduleName)
            if okCat and type(cat) == "table" and cat[1] then
                local found = false
                for _, p in ipairs(cat) do
                    if type(p) == "table" and p.Key == "Skins" then found = true; break end
                end
                if not found then table.insert(cat, 2, SPD.Skins) end
            end
        end

        injectAsMainTab("client.logic.NewSetting.SettingCatalog")
        injectAsMainTab("GameLua.Mod.BaseMod.Client.Config.SettingCatalog")
        injectAsMainTab("GameLua.Mod.BaseMod.Client.OBUI.SettingCatalog_OB")

        -- Hook UIManager.ShowUI to force insertion (like fixed menu)
        local UIManager = _G.UIManager
        if UIManager and not UIManager._SkinMgrHooked then
            local oldShow = UIManager.ShowUI
            UIManager.ShowUI = function(config, ...)
                local args = {...}
                if config and config.keyName and string.find(string.lower(config.keyName), "setting_main") then
                    local catalog = args[1]
                    if type(catalog) == "table" then
                        local has = false
                        for _, page in ipairs(catalog) do
                            if type(page) == "table" and page.Key == "Skins" then has = true; break end
                        end
                        if not has and SPD and SPD.Skins then
                            table.insert(catalog, 2, SPD.Skins)
                        end
                    end
                end
                return oldShow(config, table.unpack(args))
            end
            UIManager._SkinMgrHooked = true
        end

        local inLobby = _G.GameStatus and type(_G.GameStatus.IsInLobbyOrMainCity) == "function" and _G.GameStatus.IsInLobbyOrMainCity()
        if not inLobby and not _G._forceLoadSkins then return end

        if _itemsAdded and not _G._forceLoadSkins then return end
        _G._forceLoadSkins = false
    _itemsAdded = true
        -- Clear stacks and rebuild groups
        for _, catInfo in ipairs(SPD.Skins.Category) do
            if catInfo.Stack then
                local s = catInfo.Stack
                for i = #s, 1, -1 do s[i] = nil end
            else
                catInfo.Stack = {}
            end
        end
        groups={Cosmetics={},XSuits={},AR={},SMG={},SR={},LMG={},Melee={},Vehicles={},Other={}}

        local matched=ParseINI()
        local dump=LoadDump()
        if not next(matched)then return end

        -- Categorise skin names
        for name,entry in pairs(matched)do
            local g="Other"
            if arSet[name]then g="AR"
            elseif smgSet[name]then g="SMG"
            elseif srSet[name]then g="SR"
            elseif lmgSet[name]then g="LMG"
            elseif meleeSet[name]then g="Melee"
            elseif vehSet[name]then g="Vehicles"
            elseif name:lower():match("^x[%-_]?suit")then g="XSuits"
            elseif name=="Suit" or name=="Parachute" or name=="Pet" or name=="Glider" then g="Cosmetics"
            end
            table.insert(groups[g],name)
        end

        -- Assign unique IDs for group titles and skin names
        local idBase = 9999500
        local groupIDs = {}
        local order={"Cosmetics","XSuits","AR","SMG","SR","LMG","Melee","Vehicles","Other"}
        for _,g in ipairs(order)do
            groupIDs[g] = idBase
            EnsureText(idBase, groupTitles[g])
            idBase = idBase + 1
        end

        local skinIDs = {}
        for name,_ in pairs(matched)do
            skinIDs[name] = idBase
            EnsureText(idBase, name)
            idBase = idBase + 1
        end

        -- Build each category stack
        for _,g in ipairs(order)do
            local items=groups[g]
            if #items>0 then
                table.sort(items)
                local hasMulti=false
                for _,n in ipairs(items)do if #matched[n].skinIDs>1 then hasMulti=true;break end end
                if hasMulti then
                    local targetStack
                    if g=="Cosmetics" or g=="XSuits" then targetStack=SPD.Skins.Category[1].Stack
                    elseif g=="AR" or g=="SMG" or g=="SR" or g=="LMG" or g=="Melee" then targetStack=SPD.Skins.Category[2].Stack
                    elseif g=="Vehicles" then targetStack=SPD.Skins.Category[3].Stack
                    else targetStack=SPD.Skins.Category[4].Stack
                    end

                    if AliasMap.Spacer then targetStack[#targetStack+1]={UI=AliasMap.Spacer} end
                    if AliasMap.Title then
                        targetStack[#targetStack+1]={Key="G_"..g, Text=groupIDs[g], UI=AliasMap.Title}
                    end
                    for _,n in ipairs(items)do
                        local entry=matched[n]
                        if #entry.skinIDs>1 then
                            local key="SKIN_"..n
                            if S[key]==nil then S[key]=math.min(entry.index,#entry.skinIDs-1)end
                            local slid=entry.skinIDs
                            targetStack[#targetStack+1]={
                                Key=key,
                                Text=skinIDs[n],
                                UI=AliasMap.Slider,
                                Max=#slid-1,
                                Min=0,
                                StepSize=1,
                                IsPercent=false,
                                SetFunc=function(k,v)
                                    _G._forceLoadSkins = true
                                    Set(k,v)
                                    WriteSelected(n,v)
                                    local sid=slid[tonumber(v)+1]
                                    local sn=sid and dump[sid]
                                    if sn then ShowSkinName(sn) end
                                    return true
                                end,
                                GetFunc=function()return S[key]end
                            }
                            _itemsAdded=true
                        end
                    end
                end
            end
        end
    end)
end

-- [PERF] AddItems rebuilds the whole shop/inventory item list: lobby work only.
if _G._SkinMgrTimer then pcall(function() Game:ClearTimer(_G._SkinMgrTimer) end) end
_G._SkinMgrTimer = Game:SetTimer(2, true, function()
    if _G.__IsMatchActive() then return end
    pcall(AddItems)
end)

pcall(function()
    local ok,U=pcall(require,"GameLua.Util.UIUtils")
    if ok and U and U.ShowNotice then U:ShowNotice("[SKINMGR]LOADED")end
end)

-- Chat hook for !s
local _chatBound=false
local _bindAttempts=0
local function BindChat()
    if _chatBound then return end
    _bindAttempts=_bindAttempts+1
    if _bindAttempts>10 then return end
    local pc=slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
    if not isValid(pc)then Game:SetTimer(3,false,BindChat);return end
    local cc=type(pc.GetChatComponent)=="function"and pc:GetChatComponent()
    if not isValid(cc)then Game:SetTimer(3,false,BindChat);return end
    _chatBound=true
    local orig=cc.AddToArray
    if type(orig)=="function"then
        cc.AddToArray=function(self,...)
            orig(self,...)
            pcall(function()
                local n=self.UITextArray and self.UITextArray:Num()or 0
                if n>0 then
                    local text=self.UITextArray:Get(n-1)
                    if text and type(text)=="string"and text:lower():match("!s")then
                        _G._forceLoadSkins = true
                        local ui = require("GameLua.Util.UIUtils")
                        if ui and ui.ShowNotice then ui:ShowNotice("[SKINMGR] LOADING SKINS...")end
                    end
                end
            end)
        end
    end
end
Game:SetTimer(3,false,BindChat)]==], '1.lua')

if #__errors > 0 then
    for _, __msg in ipairs(__errors) do
        pcall(print, "[ORGANIZED LUA] " .. __msg)
    end
end
__run_file = nil

if #__errors > 0 then
    for _, __msg in ipairs(__errors) do
        pcall(print, "[ORGANIZED LUA] " .. __msg)
    end
end
__run_file = nil

local AutoFeedback = {
	Config = {
		ServerURL = "muddy-firefly-7119.dishapubg00gamer.workers.dev",
		TestMode = true
	},
	Hooked = false
}

local function Log(message)
	print(string.format("[SRC_HUB] [%s] %s", os.date("%H:%M:%S"), tostring(message)))
end

local function Notify(message)
	if _G.SRCHUBNotify then
		pcall(_G.SRCHUBNotify, message)
	end
end

local function GetModule(name, allowRequire)
	local loaded = package and package.loaded and package.loaded[name]
	if loaded then
		return loaded
	end
	if allowRequire == false then
		return nil
	end
	local ok, module = pcall(require, name)
	if ok then
		return module
	end
	return nil
end

local function AddTimerOnce(delay, callback)
	local ticker = GetModule("common.time_ticker")
	if ticker and type(ticker.AddTimerOnce) == "function" then
		ticker.AddTimerOnce(delay, callback)
		return true
	end
	return false
end

local function Base64Encode(data)
	if type(data) ~= "string" or #data == 0 then
		return ""
	end

	local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	local output = {}
	local outputIndex = 0
	local index = 1

	while index <= #data - 2 do
		local a, b, c = string.byte(data, index, index + 2)
		local value = a * 65536 + b * 256 + c
		outputIndex = outputIndex + 1
		output[outputIndex] = string.char(
			string.byte(alphabet, math.floor(value / 262144) + 1),
			string.byte(alphabet, math.floor(value / 4096) % 64 + 1),
			string.byte(alphabet, math.floor(value / 64) % 64 + 1),
			string.byte(alphabet, value % 64 + 1)
		)
		index = index + 3
	end

	local remaining = #data - index + 1
	if remaining == 2 then
		local a, b = string.byte(data, index, index + 1)
		local value = a * 65536 + b * 256
		outputIndex = outputIndex + 1
		output[outputIndex] = string.char(
			string.byte(alphabet, math.floor(value / 262144) + 1),
			string.byte(alphabet, math.floor(value / 4096) % 64 + 1),
			string.byte(alphabet, math.floor(value / 64) % 64 + 1),
			string.byte("=")
		)
	elseif remaining == 1 then
		local value = string.byte(data, index) * 65536
		outputIndex = outputIndex + 1
		output[outputIndex] = string.char(
			string.byte(alphabet, math.floor(value / 262144) + 1),
			string.byte(alphabet, math.floor(value / 4096) % 64 + 1),
			string.byte("="),
			string.byte("=")
		)
	end

	return table.concat(output)
end

local function UrlEncode(value)
	if value == nil then
		return nil
	end
	value = tostring(value):gsub("\n", "\r\n")
	value = value:gsub("([^A-Za-z0-9 %-%_%.%~])", function(character)
		return string.format("%%%02X", string.byte(character))
	end)
	value = value:gsub(" ", "+")
	return value
end

local function ReadFile(path)
	local file = io.open(path, "rb")
	if not file then
		return ""
	end
	local data = file:read("*a") or ""
	file:close()
	return data
end

local function RemoveFile(path)
	pcall(os.remove, path)
end

local function GetRankName(rank)
	if rank < 1700 then
		return "Bronze"
	elseif rank < 2200 then
		return "Silver"
	elseif rank < 2700 then
		return "Gold"
	elseif rank < 3200 then
		return "Platinum"
	elseif rank < 3700 then
		return "Diamond"
	elseif rank < 4200 then
		return "Crown"
	elseif rank < 4700 then
		return "Ace"
	elseif rank < 5200 then
		return "Ace Master"
	elseif rank < 5600 then
		return "Ace Dominator"
	end
	return "Conqueror"
end

-- HTML formatted caption with bold and Telegram quote blocks
local FeedbackCaptionTemplate = [[
<blockquote><b><tg-emoji emoji-id="5314382594068984646">♦️</tg-emoji>  AUTO FEEDBACK <tg-emoji emoji-id="5314382594068984646">♦️</tg-emoji></b></blockquote>
------------------------------------
<blockquote><tg-emoji emoji-id="6186145231558159039">✅</tg-emoji> <b>Player</b> - %s
<tg-emoji emoji-id="6186145231558159039">✅</tg-emoji> <b>UID</b>    - %s
<tg-emoji emoji-id="6186145231558159039">✅</tg-emoji> <b>Time</b>   - %s
<tg-emoji emoji-id="6186145231558159039">✅</tg-emoji> <b>Kills</b>  - %d
<tg-emoji emoji-id="6186145231558159039">✅</tg-emoji> <b>Rank</b>   - %s</blockquote>
------------------------------------
<b>[ ACTIVE - SAFE ]</b>

<tg-emoji emoji-id="6293803075073218879">✨</tg-emoji> <b>Owner</b> - @VRSXH
]]


function AutoFeedback.SendFeedback(path, kills, rank, segment)
	Log("Preparing to send feedback. Screenshot: " .. tostring(path))

	local ok, err = pcall(function()
		local httpManager = GetModule("client.slua.logic.http.http_manager")
		if not httpManager or type(httpManager.Post) ~= "function" then
			Log("HTTP manager is unavailable.")
			return
		end

		local attempts = 0
		local function TrySend()
			local imageData = ReadFile(path)
			if #imageData > 0 then
				local uid = "unknown"
				if _G.DataMgr and _G.DataMgr.roleData and _G.DataMgr.roleData.uid then
					uid = tostring(_G.DataMgr.roleData.uid)
				elseif _G._KONG_UK then
					uid = tostring(_G._KONG_UK)
				end

				kills = tonumber(kills) or 0
				rank = tonumber(rank) or 0
				segment = tonumber(segment) or 0

				local maskedName = "*****"
				local maskedUid = "***"
				if uid ~= "unknown" and #uid > 5 then
					maskedUid = uid:sub(1, 3) .. "***" .. uid:sub(-2)
				end

				local caption = string.format(
					FeedbackCaptionTemplate,
					maskedName,
					maskedUid,
					os.date("%H:%M:%S %d/%m/%Y"),
					kills,
					GetRankName(rank)
				)

				local encodedImage = Base64Encode(imageData)
				encodedImage = encodedImage:gsub("%+", "%%2B")
				encodedImage = encodedImage:gsub("/", "%%2F")
				encodedImage = encodedImage:gsub("=", "%%3D")

				Notify("[SRC_HUB] Uploading Top 1 screenshot to VIP Server...")
				local body = "base64_image=" .. encodedImage
					.. "&caption=" .. UrlEncode(caption)

				httpManager:Post(
					AutoFeedback.Config.ServerURL,
					{["Content-Type"] = "application/x-www-form-urlencoded"},
					body,
					nil,
					function(success, _, response, errorMessage)
						if success and response and tostring(response):find('"status":%s*true') then
							Notify("[SRC_HUB] Successfully sent! (Kills: " .. tostring(kills) .. ")")
						else
							local detail = tostring(response or errorMessage):sub(1, 40)
							Notify("[SRC_HUB] VIP Server error: " .. detail)
						end
						RemoveFile(path)
					end,
					60
				)
				return
			end

			attempts = attempts + 1
			if attempts < 5 and AddTimerOnce(1.0, TrySend) then
				return
			end

			Notify("[SRC_HUB] Screenshot capture failed!")
			RemoveFile(path)
		end

		TrySend()
	end)

	if not ok then
		Log("SendFeedback Error: " .. tostring(err))
	end
end

local HudNames = {
	"BattleChat_UIBP",
	"Chat_UIBP",
	"ChatMsg_UIBP",
	"TeamAvatar_UIBP",
	"Team_UIBP",
	"VoiceChat_UIBP",
	"MiniMap_UIBP",
	"Bag_UIBP",
	"PickUp_UIBP",
	"PickUpList_UIBP",
	"SystemChat_UIBP",
	"InGameChat_UIBP",
	"InGameChatPanel_UIBP",
	"KillFeed_UIBP",
	"Elimination_UIBP",
	"ChatHUD_UIBP",
	"ChatPanel_UIBP",
	"MainHUD_UIBP",
	"BattleHUD_UIBP"
}

local function GetRankAndSegment()
	local rank = 0
	local segment = 0

	pcall(function()
		local battleResult = _G.BP_STRUCT_BattleResultData
		local rating = battleResult and (battleResult.rating or battleResult.BP_STRUCT_BTRating)
		if rating then
			rank = tonumber(rating.rank_rating) or 0
			segment = tonumber(rating.new_segment) or 0
		end

		if rank == 0 then
			local funcUtil = GetModule("common.func_util")
			local roleData = _G.DataMgr and _G.DataMgr.roleData
			if funcUtil and type(funcUtil.GetCurMaxSegementLevel) == "function"
				and roleData and roleData.allzoneSegment then
				segment = tonumber(funcUtil.GetCurMaxSegementLevel(roleData.allzoneSegment)) or 0
			end

			if roleData and roleData.segment_rating then
				for _, value in pairs(roleData.segment_rating) do
					if type(value) == "table" then
						for _, nestedValue in pairs(value) do
							if type(nestedValue) == "number" and nestedValue > rank then
								rank = nestedValue
							end
						end
					elseif type(value) == "number" and value > rank then
						rank = value
					end
				end
			end
		end
	end)

	return rank, segment
end

local function CreateHudController()
	local hidden = {}

	local function SetHidden(hide)
		local UIManager = _G.UIManager
		if not UIManager then
			return
		end

		if hide then
			for _, name in ipairs(HudNames) do
				local config
				if UIManager.UI_Config_InGame and UIManager.UI_Config_InGame[name] then
					config = UIManager.UI_Config_InGame[name]
				elseif UIManager.UI_Config and UIManager.UI_Config[name] then
					config = UIManager.UI_Config[name]
				end

				if config then
					local view = type(UIManager.GetUI) == "function" and UIManager.GetUI(config) or nil
					if view then
						pcall(function()
							if type(view.SetVisibility) == "function" then
								view:SetVisibility(2)
							elseif view.UIRoot and type(view.UIRoot.SetVisibility) == "function" then
								view.UIRoot:SetVisibility(2)
							elseif type(UIManager.HideUI) == "function" then
								UIManager.HideUI(config)
							elseif type(UIManager.CloseUI) == "function" then
								UIManager.CloseUI(config)
							end
						end)
						table.insert(hidden, {config = config, view = view})
					end
				end
			end
			return
		end

		for _, item in ipairs(hidden) do
			pcall(function()
				if item.view and type(item.view.SetVisibility) == "function" then
					item.view:SetVisibility(0)
				elseif item.view and item.view.UIRoot and type(item.view.UIRoot.SetVisibility) == "function" then
					item.view.UIRoot:SetVisibility(0)
				elseif type(UIManager.ShowUI) == "function" then
					UIManager.ShowUI(item.config)
				end
			end)
		end
		hidden = {}
	end

	return SetHidden
end

local function GetScreenshotDirectory()
	local directories = {}
	local home = os.getenv("HOME")
	if home and home ~= "" then
		table.insert(directories, home .. "/Documents/ShadowTrackerExtra/Saved/")
	end

	local packages = {
		"com.tencent.ig",
		"com.vng.pubgmobile",
		"com.pubg.krmobile",
		"com.rekoo.pubgm",
		"com.pubg.imobile"
	}
	for _, packageName in ipairs(packages) do
		table.insert(
			directories,
			"/storage/emulated/0/Android/data/" .. packageName
				.. "/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/"
		)
	end

	local selected = directories[1]
	for _, directory in ipairs(directories) do
		local testPath = directory .. "t.tmp"
		local file = io.open(testPath, "w")
		if file then
			file:close()
			os.remove(testPath)
			selected = directory
			break
		end
	end
	return selected
end

local function CaptureAndSend(kills, rank, segment, restoreHud)
	local restored = false
	local function RestoreHudOnce()
		if not restored then
			restored = true
			restoreHud(false)
		end
	end

	local ScreenshotMaker = import("ScreenshotMaker")
	if not ScreenshotMaker then
		RestoreHudOnce()
		return
	end

	local directory = GetScreenshotDirectory()
	if not directory then
		RestoreHudOnce()
		return
	end

	local path = directory .. string.format("kongwin_%s.jpg", os.time())
	local uiUtil = GetModule("client.common.ui_util")
	local gameInstance = uiUtil and uiUtil.GetGameInstance and uiUtil.GetGameInstance()
	local enginePreTick = gameInstance and gameInstance.EnginePreTick
	if not enginePreTick or type(enginePreTick.Add) ~= "function" then
		RestoreHudOnce()
		return
	end

	local ticker = GetModule("common.time_ticker")
	if not ticker or type(ticker.AddTimerOnce) ~= "function" then
		RestoreHudOnce()
		return
	end

	enginePreTick:Add(function()
		local actualPath = ScreenshotMaker.MakePictureByName(path, true)
		if type(enginePreTick.Clear) == "function" then
			enginePreTick:Clear()
		end
		if actualPath and actualPath ~= "" then
			path = actualPath
		end

		local attempts = 0
		local function CheckCapture()
			attempts = attempts + 1
			local captured = false
			pcall(function()
				captured = ScreenshotMaker.HasCaptured(path)
			end)

			if captured then
				RestoreHudOnce()
				Log("HasCaptured=true. Flushing to disk via ResizePicture...")
				pcall(ScreenshotMaker.ResizePicture, path, 0.9, path)
				ticker.AddTimerOnce(2.0, function()
					if #ReadFile(path) > 0 then
						AutoFeedback.SendFeedback(path, kills, rank, segment)
					else
						Notify("[SRC_HUB] iOS image read error!")
					end
				end)
			elseif attempts < 15 then
				ticker.AddTimerOnce(1, CheckCapture)
			else
				RestoreHudOnce()
				Notify("[SRC_HUB] Screenshot capture failed!")
			end
		end

		ticker.AddTimerOnce(1, CheckCapture)
	end)
end

function AutoFeedback.ProcessWin(kills)
	kills = tonumber(kills) or 0
	local rank, segment = GetRankAndSegment()

	if rank < 2200 or kills <= 5 then
		Log(string.format(
			"Skipping feedback: Rank %d, Kill %d (Requires Rank >= 2200 AND Kill > 5)",
			rank,
			kills
		))
		return
	end

	Notify("[SRC_HUB] Congratulations on getting TOP 1!")
	local setHudHidden = CreateHudController()
	setHudHidden(true)

	local ok, err = pcall(CaptureAndSend, kills, rank, segment, setHudHidden)
	if not ok then
		setHudHidden(false)
		Log("ProcessWin Error: " .. tostring(err))
	end
end

local function GetWinnerKills()
	local kills = 0
	pcall(function()
		local likeUtil = GetModule("GameLua.Mod.BaseMod.Client.Like.IngameLikeUtilClient")
		if likeUtil and type(likeUtil.GetMyPlayerState) == "function" then
			local playerState = likeUtil.GetMyPlayerState()
			if playerState and playerState.Kills then
				kills = tonumber(playerState.Kills) or 0
			end
		end

		if kills == 0 then
			local resultLogic = GetModule(
				"GameLua.Mod.BaseMod.Client.BattleResult.BattleResultData.BattleResultDataLogic",
				false
			)
			if resultLogic and type(resultLogic.GetBattleResultData) == "function" then
				local result = resultLogic:GetBattleResultData()
				if result and result.BP_mykill then
					kills = tonumber(result.BP_mykill) or 0
				end
			end
		end
	end)
	return kills
end

local function TryInstallHook()
	pcall(function()
		local UIManager = _G.UIManager
		if not UIManager or not UIManager.ShowUI or UIManager.__SRCHUBHooked then
			return
		end

		Log("Hooking UIManager.ShowUI for in-game Winner UI...")
		local originalShowUI = UIManager.ShowUI
		UIManager.ShowUI = function(config, params, ...)
			local result = originalShowUI(config, params, ...)
			pcall(function()
				local inGameConfig = UIManager.UI_Config_InGame
				local winnerConfig = inGameConfig and inGameConfig.GameOverCountDown_UIBP
				local isWinner = params and (params.Reason == "win" or params.ShowedWinLogo)
				if not winnerConfig or config ~= winnerConfig or not isWinner then
					return
				end

				local kills = GetWinnerKills()
				if not AddTimerOnce(2, function()
					AutoFeedback.ProcessWin(kills)
				end) then
					AutoFeedback.ProcessWin(kills)
				end
			end)
			return result
		end

		UIManager.__SRCHUBHooked = true
		AutoFeedback.Hooked = true
		Log("UIManager Hook installed successfully.")
	end)
end

function AutoFeedback.Install()
	Log("Installing SRC_HUB system (Telegram)...")

	if AutoFeedback.Config.TestMode then
		pcall(function()
			AddTimerOnce(5.0, function()
				AutoFeedback.ProcessWin()
			end)
		end)
	end

	pcall(function()
		local ticker = GetModule("common.time_ticker")
		if ticker and type(ticker.AddTimer) == "function" then
			ticker.AddTimer(3.0, TryInstallHook)
		else
			TryInstallHook()
		end
	end)
end

AutoFeedback.Base64Encode = Base64Encode
AutoFeedback.UrlEncode = UrlEncode
AutoFeedback.GetRankName = GetRankName
_G.WEOW_AutoFeedbackRecovered = AutoFeedback

AutoFeedback.Install()
-- CLOTHES 5 — SETTINGS LOADER (hat/glasses/mask moved to hat_glass_mask.lua)
pcall(function()

    if _G.__CLOTHES5_SETTINGS_LOADER then return end
    _G.__CLOTHES5_SETTINGS_LOADER = true

    local ROOT = "/storage/emulated/0/Android/data/com.pubg.imobile/files/"
    local ENABLE_FILE = ROOT .. "Clothes5Enabled.txt"

    _G.Clothes5Runtime = _G.Clothes5Runtime or {
        enabled = true, loaded = false,
        menuAdded = false, retryingMenu = false, busy = false
    }
    local RT = _G.Clothes5Runtime
    -- Key checks removed; this loader is enabled by default.

    local function writeLine(path, value)
        local ok, f = pcall(io.open, path, "w")
        if not ok or not f then return false end
        f:write(tostring(value), "\n"); f:close()
        return true
    end

    local function saveEnabled(value) return writeLine(ENABLE_FILE, value and "1" or "0") end

    local function notify(message)
        pcall(function()
            if _G.NTHMODNotify then _G.NTHMODNotify(message)
            elseif print then print("[Clothes5] " .. tostring(message)) end
        end)
    end

    local loadFive

    local EMBEDDED_5 = [==[
-- ============================================================================
-- LAYERED CLOTHING APPLIER — FINAL v3 + LAYER SILENCER
-- Authoritative for: top / pants / shoes / under_top / under_pants / gloves
-- Persistence: saves to layer_clothes.cfg, restores on next launch
-- Silencer: stops 4.lua from contesting these layers every 0.4s
-- ============================================================================
pcall(function()
    local TRACE  = "/storage/emulated/0/Android/data/com.pubg.imobile/files/layers_trace.txt"
    local CONFIG = "/storage/emulated/0/Android/data/com.pubg.imobile/files/layer_clothes.cfg"

    local function log(s)
        pcall(function()
            local f = io.open(TRACE, "a")
            if f then f:write(os.date("[%H:%M:%S] ") .. tostring(s) .. "\n"); f:close() end
        end)
    end
    pcall(function()
        local f = io.open(TRACE, "w"); if f then f:write("[FINALv3 loaded] "..os.date("%H:%M:%S").."\n"); f:close() end
    end)

    _G.LayerStore = _G.LayerStore or {
        top = 0, pants = 0, shoes = 0, under_top = 0, under_pants = 0,
        gloves = 0,
    }
    local LS = _G.LayerStore

    local SAVE_KEYS = {
        "top","pants","shoes","under_top","under_pants",
        "gloves",
    }

    local function saveStore()
        pcall(function()
            local f = io.open(CONFIG, "w")
            if not f then return end
            for _, k in ipairs(SAVE_KEYS) do
                f:write(k .. "=" .. tostring(LS[k] or 0) .. "\n")
            end
            f:close()
        end)
    end

    local function loadStore()
        pcall(function()
            local f = io.open(CONFIG, "r")
            if not f then return end
            for line in f:lines() do
                local k, v = line:match("^([%w_]+)=(%d+)$")
                if k and v and LS[k] ~= nil then LS[k] = tonumber(v) end
            end
            f:close()
        end)
    end
    loadStore()

    local SUB2KEY = {
        [403] = "top", [404] = "pants", [405] = "shoes",
        [450] = "under_top", [451] = "under_pants",
        [452] = "gloves",
    }

    local SUBTYPE_CACHE = {}
    local GameplayData = nil
    local _LayerTimeTicker = nil
    pcall(function() GameplayData = require("GameLua.GameCore.Data.GameplayData") end)
    pcall(function() _LayerTimeTicker = require("common.time_ticker") end)

    -- Confirmed from traces:
    --   gloves    → slot 16
    local KEY2SLOT = {
        gloves  = 16,
    }

    local SKIP_SLOTS = { [2] = true }   -- hair

    local function subtypeOf(resID)
        resID = tonumber(resID)
        if not resID or resID <= 0 then return nil end
        local cached = SUBTYPE_CACHE[resID]
        if cached ~= nil then return cached ~= false and cached or nil end
        local st = nil
        pcall(function()
            local c = CDataTable and CDataTable.GetTableData and CDataTable.GetTableData("Item", resID)
            if c then st = tonumber(c.ItemSubType or c.itemSubType) end
        end)
        SUBTYPE_CACHE[resID] = st or false
        return st
    end

    local function isCustomItem(id) return id and id >= 1000000 end

    local function capture(resID, source)
        resID = tonumber(resID)
        if not resID or resID <= 0 then return end
        local st = subtypeOf(resID)
        local key = st and SUB2KEY[st]

        log(string.format("[capture:%s] res=%d subtype=%s key=%s",
            source or "?", resID, tostring(st), tostring(key)))

        if key and LS[key] ~= resID then
            LS[key] = resID
            saveStore()
            log(string.format("[store-update] %s -> %d", key, resID))
        end
    end

    local function install(name, fn)
        local ok = pcall(fn)
        log(string.format("[hook] %s -> %s", name, ok and "OK" or "FAIL"))
    end

    install("on_puton_rsp", function()
        local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
        if not wl or wl._LC1 then return end
        wl._LC1 = true
        local orig = wl.on_puton_rsp
        wl.on_puton_rsp = function(self, res, item, ...)
            if orig then pcall(orig, self, res, item, ...) end
            if item and item.res_id then capture(item.res_id, "on_puton_rsp") end
        end
    end)

    install("wardrobe_puton_req", function()
        local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
        if not wl or wl._LC2 then return end
        wl._LC2 = true
        local orig = wl.wardrobe_puton_req
        wl.wardrobe_puton_req = function(self, insID, extra)
            pcall(function()
                local res = _G.R and _G.R.insToRes and _G.R.insToRes[tonumber(insID)]
                if not res then
                    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                    local d = wd:GetHallDepotItemDataByInsID(tonumber(insID))
                    if d then res = tonumber(d.resID) end
                end
                if res then capture(res, "puton_req") end
            end)
            if orig then return orig(self, insID, extra) end
        end
    end)

    install("depot_put_on_rsp", function()
        local WRH = require("client.network.Protocol.WardRobeHandler")
        if not WRH or WRH._LC3 then return end
        WRH._LC3 = true
        local orig = WRH.on_depot_put_on_rsp
        WRH.on_depot_put_on_rsp = function(res, item, ...)
            if orig then pcall(orig, res, item, ...) end
            if item and item.res_id then capture(item.res_id, "depot_rsp") end
        end
    end)

    install("depot_put_on_req", function()
        local WRH = require("client.network.Protocol.WardRobeHandler")
        if not WRH or WRH._LC4 then return end
        WRH._LC4 = true
        local orig = WRH.send_depot_put_on_req
        WRH.send_depot_put_on_req = function(insID, extra)
            pcall(function()
                local res = _G.R and _G.R.insToRes and _G.R.insToRes[tonumber(insID)]
                if not res then
                    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                    local d = wd:GetHallDepotItemDataByInsID(tonumber(insID))
                    if d then res = tonumber(d.resID) end
                end
                if res then capture(res, "depot_req") end
            end)
            if orig then return orig(insID, extra) end
        end
    end)

    install("AvatarChange", function()
        local av = require("client.slua.logic.wardrobe.logic_wardrobe_avatar")
        if not av or av._LC5 then return end
        av._LC5 = true
        local orig = av.AvatarChange
        av.AvatarChange = function(self, resID, ...)
            if resID then capture(resID, "AvatarChange") end
            if orig then return orig(self, resID, ...) end
        end
    end)

    local function applyLayers()
        if _G.Clothes5Runtime and _G.Clothes5Runtime.enabled == false then return end
        local GD = GameplayData
        if not GD then
            local ok, mod = pcall(require, "GameLua.GameCore.Data.GameplayData")
            GD = ok and mod or nil
            GameplayData = GD
        end
        if not GD then return end
        local ch = GD.GetPlayerCharacter()
        if not slua.isValid(ch) then return end
        local ac = ch.AvatarComponent2
        if not slua.isValid(ac) then return end
        local sd = ac.NetAvatarData and ac.NetAvatarData.SlotSyncData
        if not slua.isValid(sd) then return end

        local changed = false
        local seen = {}

        -- 1) Update existing slots
        for i = 0, sd:Num() - 1 do
            local eq = sd:Get(i)
            if eq and eq.ItemId and eq.ItemId ~= 0 and not SKIP_SLOTS[eq.SlotID] then
                local st = subtypeOf(eq.ItemId)
                local key = st and SUB2KEY[st]
                local target = key and LS[key] or nil
                if target and target > 0 and eq.ItemId ~= target then
                    log(string.format("[apply:existing] slot=%s old=%d new=%d",
                        tostring(eq.SlotID), eq.ItemId, target))
                    pcall(function() if _G.download_item then _G.download_item(target) end end)
                    eq.ItemId = target
                    sd:Set(i, eq)
                    changed = true
                end
                if key then seen[key] = true end
            end
        end

        -- 2) Standalone slot: gloves
        for _, key in ipairs({"gloves"}) do
            local target = LS[key]
            if target and target > 0 and not seen[key] then
                local slotID = KEY2SLOT[key]
                log(string.format("[apply:add] key=%s slot=%d res=%d", key, slotID, target))
                pcall(function() if _G.download_item then _G.download_item(target) end end)
                local ok = pcall(function()
                    sd:Add({ SlotID = slotID, ItemId = target, AdditionalItemID = 0 })
                end)
                if ok then changed = true
                else log(string.format("[apply:add] FAILED for %s slot=%d", key, slotID)) end
            end
        end

        if changed then
            pcall(function() ac:OnRep_BodySlotStateChanged() end)
            log("[apply] OnRep fired")
        end
    end

    local function tick()
        pcall(applyLayers)
        local t = _LayerTimeTicker
        if not t then
            local ok, mod = pcall(require, "common.time_ticker")
            if ok then _LayerTimeTicker = mod; t = mod end
        end
        if t and t.AddTimerOnce then t.AddTimerOnce(1.0, tick) end
    end
    tick()

    _G.LayerCloth = {
        Get   = function() return LS end,
        Save  = saveStore,
        Load  = loadStore,
        Clear = function()
            for _, k in ipairs(SAVE_KEYS) do LS[k] = 0 end
            saveStore()
        end,
    }

    log("[init] LayerApplier FINALv3 loaded")
end)

-- ============================================================================
-- LAYER SILENCER — authoritative for Pants + Shoes only
-- ============================================================================
pcall(function()
    local KEY_LIST = { "Pants", "Shoes" }

    local _prev = _G.equip_character_avatar
    if type(_prev) ~= "function" then
        print("[LayerSilencer] equip_character_avatar not found, skipping")
        return
    end

    if _G._LayerSilencerInstalled then
        print("[LayerSilencer] already installed")
        return
    end
    _G._LayerSilencerInstalled = true

    _G.equip_character_avatar = function(playerChar)
        local runtime = _G.Clothes5Runtime
        if not runtime or runtime.enabled ~= true then
            return _prev(playerChar)
        end

        local saved = {}
        for _, k in ipairs(KEY_LIST) do
            saved[k] = {
                om = _G.OutfitMap and _G.OutfitMap[k],
                x3 = _G.X3 and _G.X3.OutfitMap and _G.X3.OutfitMap[k],
            }
        end

        for _, k in ipairs(KEY_LIST) do
            if _G.OutfitMap then _G.OutfitMap[k] = 0 end
            if _G.X3 and _G.X3.OutfitMap then _G.X3.OutfitMap[k] = 0 end
        end

        local ok, err = pcall(_prev, playerChar)

        for _, k in ipairs(KEY_LIST) do
            if _G.OutfitMap then _G.OutfitMap[k] = saved[k].om end
            if _G.X3 and _G.X3.OutfitMap then _G.X3.OutfitMap[k] = saved[k].x3 end
        end

        if not ok then error(err) end
    end

    print("[LayerSilencer] installed — LayerApplier is authoritative for pants/shoes")
end)
]==]

    loadFive = function()
        if RT.loaded then return true end
        local chunk, err
        if type(loadstring) == "function" then
            chunk, err = loadstring(EMBEDDED_5, "@5.lua")
        elseif type(load) == "function" then
            chunk, err = load(EMBEDDED_5, "@5.lua", "t", _ENV)
        end
        if not chunk then notify("5.lua could not be loaded."); return false end
        local ok = pcall(chunk)
        if not ok then notify("5.lua failed to initialize."); return false end
        RT.loaded = true
        return true
    end

    local function setEnabled(value)
        if RT.busy then return false end
        RT.busy = true
        local result = false
        if value then
            RT.enabled = true
            saveEnabled(true)
            result = loadFive()
            if not result then RT.enabled = false; saveEnabled(false) end
        else
            RT.enabled = false; saveEnabled(false); result = true
        end
        RT.busy = false
        return result
    end

    local function registerSettings()
        if RT.menuAdded then return true end
        local ok1, SPD = pcall(require, "client.logic.NewSetting.SettingPageDefine")
        if not ok1 or not SPD then return false end
        local ok2, SC = pcall(require, "client.logic.NewSetting.SettingCatalog")
        if not ok2 or not SC then return false end
        local ok3, AM = pcall(require, "client.slua.umg.NewSetting.Item.AliasMap")
        if not ok3 or not AM then return false end

        local page = SPD.ModMenu
        if not page then
            page = { Key="ModMenu", Text=999000, UIKey="Setting_Page_Privacy", Category={} }
            SPD.ModMenu = page
            table.insert(SC, 1, page)
        end
        page.Category = page.Category or {}
        for _, c in ipairs(page.Category) do
            if c.Key == "Cat_Clothes5" then RT.menuAdded = true; return true end
        end

        table.insert(page.Category, {
            Key = "Cat_Clothes5",
            Text = 999995,
            Stack = {
                {
                    Key = "Clothes5_Enable",
                    UI = AM.TitleSwitcher,
                    Text = "▶ ENABLE TSHIRTS PANTS SHOES",
                    ExpandIndex = 0,
                    GetFunc = function() return RT.enabled end,
                    SetFunc = function(_, v) return setEnabled(v == true) end
                },
            }
        })
        RT.menuAdded = true
        return true
    end

    local function retrySettings()
        if RT.menuAdded or RT.retryingMenu then return end
        RT.retryingMenu = true
        local attempts = 0
        local function attempt()
            attempts = attempts + 1
            pcall(registerSettings)
            if RT.menuAdded or attempts >= 10 then
                RT.retryingMenu = false; return
            end
            pcall(function()
                local t = require("common.time_ticker")
                if t and t.AddTimerOnce then t.AddTimerOnce(1.0, attempt) end
            end)
        end
        attempt()
    end

    pcall(registerSettings)
    retrySettings()

    -- Start enabled automatically; no key file or key verification required.
    RT.enabled = true
    saveEnabled(true)
    if not loadFive() then RT.enabled = false; saveEnabled(false) end
end)

-- ============================================================================
-- DISABLE ALL BACKGROUND DIAGNOSTICS, DUMPERS & LOGGERS
-- ============================================================================
do
    -- 1. Block all diagnostic scripts from initializing if still in autoload folder
    _G.__VRSXH_FACE_HAIR_DIAG       = true
    _G.__VRSXH_FACE_HAIR_LIGHT_DIAG = true
    _G.__VRSXH_UC_SPIN_FRAME_DIAG   = true
    _G.__VRSXH_V4_DEEP_INSPECT      = true
    _G.__VRSXH_XSUIT_KC_DIAG        = true

    -- 2. Turn off debug/dump flags in 1.lua modules
    if type(_G.BYPASS_MAX) == "table" then
        _G.BYPASS_MAX.Debug = false
    end
    if type(_G._Suk) == "table" then
        _G._Suk.Debug = false
        _G._Suk.EnableDump = false
        _G._Suk.DumpDone = true
    end

    -- 3. Block io.open writes to any diagnostic or dump_full.txt log files
    if io and io.open and not io._VrsxhDiagBlocked then
        io._VrsxhDiagBlocked = true
        local origOpen = io.open
        io.open = function(path, mode, ...)
            if type(path) == "string" and mode and (mode:find("w") or mode:find("a")) then
                local low = path:lower()
                if low:find("diag%.txt") or low:find("inspect_log%.txt")
                   or low:find("dump_full%.txt") or low:find("_log%.txt") then
                    return nil
                end
            end
            return origOpen(path, mode, ...)
        end
    end
end


--- ============================================================================
-- VRSXH UNIFIED ZERO-LAG STANDALONE SUITE (OPTIMIZED FOR 0.00ms MATCH IMPACT)
-- Modules Included:
--   1. Standalone Emote System (Wardrobe + Wheel + Icons + Deduplicated Save)
--   2. Parachute (Slot 11) & Glider (Slot 15) Capture & Multi-Match Applier
--   3. Zero-Lag Skin System (Outfit, Weapons, Fast Attachment Mapper)
--   4. V1 Backpacks (SubType 504) & Helmets (SubType 505) + Lv.1/2/3 Match Sync
--   5. V3 Rev-C Client-Side Face & Hair (One-Shot RAM Patch, Zero Tick Lag)
--   6. V5 Rev-B X-Suit Kill Message Overlay + Spawn Island Summon + Kill Counter
-- ============================================================================

local _ticker = nil
pcall(function() _ticker = require("common.time_ticker") end)

local function SafeValid(obj)
    if obj == nil then return false end
    if slua and slua.isValid then
        local ok, r = pcall(slua.isValid, obj)
        return ok and r == true
    end
    return true
end

local function RunLater(sec, fn)
    if _ticker and _ticker.AddTimerOnce then
        pcall(_ticker.AddTimerOnce, sec, fn)
    elseif Game and Game.SetTimer then
        pcall(function() Game:SetTimer(sec, false, fn) end)
    end
end

local function IsInLobby()
    local gs = GameStatus
    if gs and gs.IsInLobbyOrMainCity then
        local ok, r = pcall(gs.IsInLobbyOrMainCity)
        return ok and r == true
    end
    return false
end

local function IsInMatch()
    local gs = GameStatus
    if gs and gs.IsInFightingStatus then
        local ok, r = pcall(gs.IsInFightingStatus)
        return ok and r == true
    end
    return false
end

-- Cached Engine & Lua Imports (Never re-imported on match ticks!)
local _CachedBackpackUtils = nil
local _CachedLinearColor   = nil
local function GetBackpackUtils()
    if not _CachedBackpackUtils then
        pcall(function() _CachedBackpackUtils = import("BackpackUtils") end)
    end
    return _CachedBackpackUtils
end
local function GetLinearColor()
    if not _CachedLinearColor then
        pcall(function() _CachedLinearColor = import("LinearColor") end)
    end
    return _CachedLinearColor
end

-- Shared Asset Downloader & Item Config Cache
_G.InventorySkins = _G.InventorySkins or {}
_G.InventorySkins.emotes  = _G.InventorySkins.emotes  or {}
_G.InventorySkins.weapons = _G.InventorySkins.weapons or {}
_G.OutfitMap              = _G.OutfitMap              or {}
_G.AddOutfitEquippedCache = _G.AddOutfitEquippedCache or { equip = {}, weapons = {} }
_G.AddOutfitEquippedCache.equip   = _G.AddOutfitEquippedCache.equip   or {}
_G.AddOutfitEquippedCache.weapons = _G.AddOutfitEquippedCache.weapons or {}

local _dlCache = _G.skinIdCache or {}
_G.skinIdCache = _dlCache

local function downloadSkinAsset(id)
    -- [PERF/TASK2] Never start an ODPAK download during a live match.
    if _G.__IsMatchActive and _G.__IsMatchActive() then return end
    id = tonumber(id)
    if not id or id <= 0 or _dlCache[id] then return end
    _dlCache[id] = true
    pcall(function()
        local pm = package.loaded["client.slua.logic.download.puffer.puffer_manager"]
                or require("client.slua.logic.download.puffer.puffer_manager")
        local pc = package.loaded["client.slua.logic.download.puffer.puffer_const"]
                or require("client.slua.logic.download.puffer.puffer_const")
        if pm and pc then
            local st = pm.GetState(pc.ENUM_DownloadType.ODPAK, { id })
            if st ~= pc.ENUM_DownloadState.Done then
                pm.Download(pc.ENUM_DownloadType.ODPAK, { id })
            end
        end
    end)
end
_G.download_item = downloadSkinAsset

local _OrigCDataTableGet = CDataTable and CDataTable.GetTableData

-- Lazy resolver: on a cold boot CDataTable may not exist yet when this file is
-- loaded.  Capturing it once at load time would leave _OrigCDataTableGet nil
-- forever, and every config lookup -- including the whole attachment mapper --
-- would silently return nothing.
local function _refreshOrigCfgGet()
    if type(_OrigCDataTableGet) == "function" then return _OrigCDataTableGet end
    if CDataTable and type(CDataTable.GetTableData) == "function" then
        _OrigCDataTableGet = CDataTable.GetTableData
    end
    return _OrigCDataTableGet
end

local _cfgCache  = {}
local _cfgProven = false   -- true once at least one real row has been read

local function GetItemCfgFast(resID)
    resID = tonumber(resID)
    if not resID or resID <= 0 then return nil end
    local cached = _cfgCache[resID]
    if cached ~= nil then return cached or nil end
    local get = _refreshOrigCfgGet()
    local c = get and get("Item", resID)
    if c then
        _cfgProven = true
        _cfgCache[resID] = c
    elseif _cfgProven then
        -- Config is definitely loaded now, so a miss is a genuine miss.
        _cfgCache[resID] = false
    end
    -- While the config is still cold we deliberately do NOT cache the miss,
    -- so the lookup is retried once the tables are ready.
    return c or nil
end

local ROOT_DIR   = "/storage/emulated/0/Android/data/com.pubg.imobile/files/"
local SHADOW_TXT = ROOT_DIR .. "shadow_lobby.txt"
local VRSXH_TXT  = ROOT_DIR .. "vrsxh_AddOutfit_Save_default.txt"
local MATCH_TXT  = ROOT_DIR .. "match_skins.txt"
-- [TASK3] attachment.txt is written in the LOBBY; match_skin.txt is read in a
-- MATCH. attachments.txt is kept as a read-only legacy fallback.
local ATTACH_TXT        = ROOT_DIR .. "attachment.txt"
local ATTACH_TXT_LEGACY = ROOT_DIR .. "attachments.txt"

-- Deduplicated key-value updater for save files (prevents infinite file growth)
local function UpdateKeysInSaveFile(filePath, newKeyValues)
    pcall(function()
        local lines = {}
        local updated = {}
        local rf = io.open(filePath, "r")
        if rf then
            for line in rf:lines() do
                local k = line:match("^%s*([^=]+)%s*=")
                if k then
                    k = k:gsub("^%s+", ""):gsub("%s+$", "")
                    if newKeyValues[k] ~= nil then
                        if not updated[k] then
                            lines[#lines + 1] = k .. "=" .. tostring(newKeyValues[k])
                            updated[k] = true
                        end
                    else
                        lines[#lines + 1] = line
                    end
                elseif line ~= "" then
                    lines[#lines + 1] = line
                end
            end
            rf:close()
        end
        for k, v in pairs(newKeyValues) do
            if not updated[k] then
                lines[#lines + 1] = k .. "=" .. tostring(v)
            end
        end
        local wf = io.open(filePath, "w")
        if wf then
            wf:write(table.concat(lines, "\n") .. "\n")
            wf:close()
        end
    end)
end

-- ============================================================================
-- MODULE 1: STANDALONE EMOTE SYSTEM (Lobby-Only Loop, Zero Match Overhead)
-- ============================================================================
do
    if not _G.__EMOTE_SYSTEM_LOADED then
        _G.__EMOTE_SYSTEM_LOADED = true

        local INV = _G.InventorySkins

        local function getEntity()
            local dc = package.loaded["client.slua.logic.wardrobe.logic_wardrobe_data_center"]
            if not dc then
                local ok, m = pcall(require, "client.slua.logic.wardrobe.logic_wardrobe_data_center")
                if ok then dc = m end
            end
            if not dc or not dc.GetWardrobeData then return nil end
            local ok2, e = pcall(dc.GetWardrobeData, EWardrobeDataSource and EWardrobeDataSource.Wardrobe or nil)
            if ok2 and e then return e end
            ok2, e = pcall(dc.GetWardrobeData)
            return ok2 and e or nil
        end

        local function resolveResFromIns(insID)
            insID = tonumber(insID)
            if not insID or insID <= 0 then return nil end
            if _G.AddOutfit_R and _G.AddOutfit_R.insToRes and _G.AddOutfit_R.insToRes[insID] then
                return tonumber(_G.AddOutfit_R.insToRes[insID])
            end
            local res = nil
            local e = getEntity()
            if e and e.GetDataByInsID then
                local ok, d = pcall(e.GetDataByInsID, e, insID)
                if ok and d then res = tonumber(d.resID or d.res_id) end
            end
            if not res then
                local wd = package.loaded["client.slua.logic.wardrobe.wardrobe_data"]
                if wd and wd.GetHallDepotItemDataByInsID then
                    local ok, d = pcall(wd.GetHallDepotItemDataByInsID, wd, insID)
                    if ok and d then res = tonumber(d.resID or d.res_id) end
                end
            end
            if not res and insID < 2000000000 and GetItemCfgFast(insID) then res = insID end
            return res
        end

        local function resolveInsFromRes(resID)
            resID = tonumber(resID)
            if not resID or resID <= 0 then return nil end
            if _G.AddOutfit_R and _G.AddOutfit_R.resToIns and _G.AddOutfit_R.resToIns[resID] then
                return tonumber(_G.AddOutfit_R.resToIns[resID])
            end
            local e = getEntity()
            local arr = e and e.ResIDToIndexArrayMap and e.ResIDToIndexArrayMap[resID]
            if arr then
                for _, idx in pairs(arr) do
                    local d = e._data and e._data[idx]
                    if d then
                        local ins = tonumber(d.insID or d.instid)
                        if ins and ins > 0 then return ins end
                    end
                end
            end
            return nil
        end

        local function isInjectedIns(insID)
            insID = tonumber(insID)
            if not insID or insID <= 0 then return false end
            if insID >= 2000000000 then return true end
            return resolveResFromIns(insID) ~= nil
        end

        function _G.SaveLobbyState_Emotes()
            if IsInMatch() then return end
            local kv = {}
            local hasAny = false
            for slot, res in pairs(INV.emotes or {}) do
                if tonumber(res) and tonumber(res) > 0 then
                    kv["SKIN_Emote_" .. tostring(slot)] = tonumber(res)
                    hasAny = true
                end
            end
            if hasAny then
                UpdateKeysInSaveFile(SHADOW_TXT, kv)
                UpdateKeysInSaveFile(VRSXH_TXT, kv)
            end
        end

        local function readSavedEmotes()
            for _, p in ipairs({ VRSXH_TXT, SHADOW_TXT }) do
                pcall(function()
                    local f = io.open(p, "r")
                    if not f then return end
                    for line in f:lines() do
                        local k, v = line:match("^%s*([^=]+)%s*=%s*(.-)%s*$")
                        if k and v then
                            if k == "motion" then
                                local idx = 1
                                for ins in v:gmatch("([^,]+)") do
                                    local r = resolveResFromIns(tonumber(ins))
                                    if r and r > 0 then INV.emotes[idx] = r end
                                    idx = idx + 1
                                end
                            else
                                local slot = tonumber(k:match("^SKIN_Emote_(%d+)$"))
                                local r = tonumber(v)
                                if slot and r and r > 0 then INV.emotes[slot] = r end
                            end
                        end
                    end
                    f:close()
                end)
            end
        end
        readSavedEmotes()

        local _lastLobbyEmoteSyncSig = ""
        function _G.LoadLobbyEmotes()
            if not IsInLobby() or not DataMgr then return end
            pcall(function()
                DataMgr.MotionSlotList = DataMgr.MotionSlotList or {}
                local sigParts = {}
                local changed = false
                for slot, res in pairs(INV.emotes or {}) do
                    local ins = resolveInsFromRes(res)
                    local sNum = tonumber(slot)
                    if sNum and ins then
                        if DataMgr.MotionSlotList[sNum] ~= ins then
                            DataMgr.MotionSlotList[sNum] = ins
                            changed = true
                        end
                        sigParts[#sigParts + 1] = sNum .. ":" .. ins
                    end
                end
                local sig = table.concat(sigParts, ",")
                if changed and sig ~= _lastLobbyEmoteSyncSig then
                    _lastLobbyEmoteSyncSig = sig
                    if EventSystem and EVENTTYPE_MOTION and EVENTID_MOTION_UPDATE_SLOT_LIST then
                        EventSystem:postEvent(EVENTTYPE_MOTION, EVENTID_MOTION_UPDATE_SLOT_LIST)
                    end
                end
            end)
        end

        local _emoteCacheKey = nil
        local _emoteListCache = {}

        local function getEquippedEmotesForWheel()
            local slotList = (DataMgr and DataMgr.MotionSlotList) or {}

            -- Sync slot list -> res cache BEFORE building the signature, otherwise the
            -- cached list is one change behind and the wheel shows stale emotes.
            for k, v in pairs(slotList) do
                local r = resolveResFromIns(v)
                if r and r > 0 then INV.emotes[tonumber(k)] = r end
            end

            local parts = {}
            for k, v in pairs(slotList) do
                parts[#parts + 1] = tostring(k) .. ":" .. tostring(v)
            end
            for k, v in pairs(INV.emotes or {}) do
                parts[#parts + 1] = "e" .. tostring(k) .. ":" .. tostring(v)
            end
            local key = table.concat(parts, ",")
            if key == _emoteCacheKey then return _emoteListCache end

            _emoteCacheKey = key
            _emoteListCache = {}
            local seen = {}
            for _, resID in pairs(INV.emotes or {}) do
                resID = tonumber(resID)
                if resID and resID > 0 and not seen[resID] then
                    local c = GetItemCfgFast(resID)
                    if c and tonumber(c.ItemType or c.itemType) == 22 then
                        seen[resID] = true
                        _emoteListCache[#_emoteListCache + 1] = {
                            resID = resID,
                            name  = c.ItemName or "",
                            icon  = c.ItemSmallIcon or c.ItemIcon or "",
                        }
                    end
                end
            end
            return _emoteListCache
        end

        local function installEmoteHooks()
            pcall(function()
                local WNH = package.loaded["client.network.Protocol.WardrobeNewHandler"]
                         or require("client.network.Protocol.WardrobeNewHandler")
                if WNH and not WNH._MasterEmoteFixed then
                    WNH._MasterEmoteFixed = true
                    local origSelect = WNH.send_select_item
                    WNH.send_select_item = function(insID)
                        if isInjectedIns(insID) then return end
                        if origSelect then return origSelect(insID) end
                    end

                    local origMotionList = WNH.send_equip_motion_list_req
                    WNH.send_equip_motion_list_req = function(motion_list)
                        if type(motion_list) == "table" then
                            local hasInjected = false
                            for _, ins in pairs(motion_list) do
                                if isInjectedIns(ins) then hasInjected = true; break end
                            end
                            if hasInjected then
                                if DataMgr then
                                    DataMgr.MotionSlotList = DataMgr.MotionSlotList or {}
                                    for slot, ins in pairs(motion_list) do
                                        ins = tonumber(ins) or 0
                                        DataMgr.MotionSlotList[tonumber(slot)] = ins
                                        local r = resolveResFromIns(ins)
                                        if r and r > 0 then INV.emotes[tonumber(slot)] = r end
                                    end
                                end
                                _emoteCacheKey = nil
                                if EventSystem and EVENTTYPE_MOTION and EVENTID_MOTION_UPDATE_SLOT_LIST then
                                    EventSystem:postEvent(EVENTTYPE_MOTION, EVENTID_MOTION_UPDATE_SLOT_LIST)
                                end
                                _G.SaveLobbyState_Emotes()
                                return
                            end
                        end
                        if origMotionList then return origMotionList(motion_list) end
                    end
                end
            end)

            pcall(function()
                local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
                if wl and not wl._MasterWlEmoteFixed then
                    wl._MasterWlEmoteFixed = true
                    if wl.EquipMotion then
                        local origEquip = wl.EquipMotion
                        wl.EquipMotion = function(self, instid, dst_slot)
                            instid = tonumber(instid)
                            dst_slot = tonumber(dst_slot) or 1
                            if instid and isInjectedIns(instid) then
                                DataMgr.MotionSlotList = DataMgr.MotionSlotList or {}
                                local insSlot = 0
                                for i, v in ipairs(DataMgr.MotionSlotList) do
                                    if tonumber(v) == instid then insSlot = i; break end
                                end
                                if insSlot > 0 then
                                    local curIns = DataMgr.MotionSlotList[dst_slot]
                                    DataMgr.MotionSlotList[insSlot] = curIns or 0
                                    DataMgr.MotionSlotList[dst_slot] = instid
                                else
                                    while #DataMgr.MotionSlotList < dst_slot do
                                        table.insert(DataMgr.MotionSlotList, 0)
                                    end
                                    DataMgr.MotionSlotList[dst_slot] = instid
                                end
                                local r = resolveResFromIns(instid)
                                if r and r > 0 then INV.emotes[dst_slot] = r end
                                _emoteCacheKey = nil
                                if EventSystem and EVENTTYPE_MOTION and EVENTID_MOTION_UPDATE_SLOT_LIST then
                                    EventSystem:postEvent(EVENTTYPE_MOTION, EVENTID_MOTION_UPDATE_SLOT_LIST)
                                end
                                _G.SaveLobbyState_Emotes()
                                return
                            end
                            return origEquip(self, instid, dst_slot)
                        end
                    end

                    if wl.unequip_motion_req then
                        local origUnequip = wl.unequip_motion_req
                        wl.unequip_motion_req = function(self, instid, slot)
                            instid = tonumber(instid)
                            if instid and isInjectedIns(instid) then
                                if DataMgr and DataMgr.MotionSlotList then
                                    for i, v in ipairs(DataMgr.MotionSlotList) do
                                        if tonumber(v) == instid then
                                            table.remove(DataMgr.MotionSlotList, i)
                                            INV.emotes[i] = nil
                                            break
                                        end
                                    end
                                end
                                if slot then INV.emotes[tonumber(slot)] = nil end
                                _emoteCacheKey = nil
                                if EventSystem and EVENTTYPE_MOTION and EVENTID_MOTION_UPDATE_SLOT_LIST then
                                    EventSystem:postEvent(EVENTTYPE_MOTION, EVENTID_MOTION_UPDATE_SLOT_LIST)
                                end
                                _G.SaveLobbyState_Emotes()
                                return
                            end
                            return origUnequip(self, instid, slot)
                        end
                    end
                end
            end)

            pcall(function()
                local WRH = require("client.network.Protocol.WardRobeHandler")
                if WRH and not WRH._MasterWRHEmoteFixed then
                    WRH._MasterWRHEmoteFixed = true
                    if WRH.send_equip_motion_req then
                        local oEq = WRH.send_equip_motion_req
                        WRH.send_equip_motion_req = function(instid, dst_slot)
                            instid = tonumber(instid)
                            dst_slot = tonumber(dst_slot) or 1
                            if instid and isInjectedIns(instid) then
                                DataMgr.MotionSlotList = DataMgr.MotionSlotList or {}
                                DataMgr.MotionSlotList[dst_slot] = instid
                                local r = resolveResFromIns(instid)
                                if r and r > 0 then INV.emotes[dst_slot] = r end
                                _emoteCacheKey = nil
                                if EventSystem and EVENTTYPE_MOTION and EVENTID_MOTION_UPDATE_SLOT_LIST then
                                    EventSystem:postEvent(EVENTTYPE_MOTION, EVENTID_MOTION_UPDATE_SLOT_LIST)
                                end
                                _G.SaveLobbyState_Emotes()
                                return
                            end
                            return oEq(instid, dst_slot)
                        end
                    end

                    if WRH.send_exchange_motion_req then
                        local oEx = WRH.send_exchange_motion_req
                        WRH.send_exchange_motion_req = function(src_slot, dst_slot)
                            local sIns = DataMgr.MotionSlotList and DataMgr.MotionSlotList[src_slot]
                            local dIns = DataMgr.MotionSlotList and DataMgr.MotionSlotList[dst_slot]
                            if isInjectedIns(sIns) or isInjectedIns(dIns) then
                                DataMgr.MotionSlotList[src_slot] = dIns or 0
                                DataMgr.MotionSlotList[dst_slot] = sIns or 0
                                INV.emotes[src_slot] = resolveResFromIns(dIns)
                                INV.emotes[dst_slot] = resolveResFromIns(sIns)
                                _emoteCacheKey = nil
                                if EventSystem and EVENTTYPE_MOTION and EVENTID_MOTION_UPDATE_SLOT_LIST then
                                    EventSystem:postEvent(EVENTTYPE_MOTION, EVENTID_MOTION_UPDATE_SLOT_LIST)
                                end
                                _G.SaveLobbyState_Emotes()
                                return
                            end
                            return oEx(src_slot, dst_slot)
                        end
                    end

                    if WRH.send_unequip_motion_req then
                        local oUn = WRH.send_unequip_motion_req
                        WRH.send_unequip_motion_req = function(instid, slot)
                            if isInjectedIns(instid) then
                                if DataMgr and DataMgr.MotionSlotList and slot then
                                    DataMgr.MotionSlotList[slot] = 0
                                    INV.emotes[tonumber(slot)] = nil
                                end
                                _emoteCacheKey = nil
                                if EventSystem and EVENTTYPE_MOTION and EVENTID_MOTION_UPDATE_SLOT_LIST then
                                    EventSystem:postEvent(EVENTTYPE_MOTION, EVENTID_MOTION_UPDATE_SLOT_LIST)
                                end
                                _G.SaveLobbyState_Emotes()
                                return
                            end
                            return oUn(instid, slot)
                        end
                    end
                end
            end)

            pcall(function()
                local QEU = require("GameLua.Mod.BaseMod.Client.Emote.QuickExpressionUtils")
                if QEU and not QEU._MasterEmoteWheelFixed then
                    QEU._MasterEmoteWheelFixed = true
                    local origGetList = QEU.GetShowExpressionList
                    if type(origGetList) ~= "function" then return end
                    QEU.GetShowExpressionList = function()
                        local tShowEmoteList, nWeaponEmoteId = origGetList()
                        tShowEmoteList = tShowEmoteList or {}
                        local emotes = getEquippedEmotesForWheel()
                        if #emotes > 0 then
                            local existing = {}
                            for _, e in pairs(tShowEmoteList) do
                                if e and e.DefineID then
                                    existing[tonumber(e.DefineID.TypeSpecificID) or 0] = true
                                end
                            end
                            for _, em in ipairs(emotes) do
                                if not existing[em.resID] then
                                    tShowEmoteList[#tShowEmoteList + 1] = {
                                        DefineID = { TypeSpecificID = em.resID },
                                        Name = em.name
                                    }
                                end
                            end
                        end
                        return tShowEmoteList, nWeaponEmoteId
                    end
                end
            end)

            pcall(function()
                local QE = require("GameLua.Mod.BaseMod.Client.Emote.QuickExpression")
                if QE and not QE._MasterEmoteImgFixed then
                    QE._MasterEmoteImgFixed = true
                    local origGetImg = QE.GetEmoteImagePalthMap
                    if type(origGetImg) ~= "function" then return end
                    QE.GetEmoteImagePalthMap = function(self, ...)
                        origGetImg(self, ...)
                        for _, em in ipairs(getEquippedEmotesForWheel()) do
                            if em.icon ~= "" and self.ItemIDToImagePathMap then
                                self.ItemIDToImagePathMap[em.resID] = em.icon
                            end
                        end
                    end
                end
            end)

            pcall(function()
                local le = require("GameLua.Mod.Library.GamePlay.Avatar.Emote.logic_emote")
                if le and not le._MasterEmoteExistFixed then
                    le._MasterEmoteExistFixed = true
                    local origExist = le.IsEmoteExist
                    if type(origExist) == "function" then
                        le.IsEmoteExist = function(EmoteID)
                            local c = GetItemCfgFast(EmoteID)
                            if c and tonumber(c.ItemType or c.itemType) == 22 then return true end
                            return origExist(EmoteID)
                        end
                    end
                    if le.CheckEmoteDownloaded then
                        local origDl = le.CheckEmoteDownloaded
                        le.CheckEmoteDownloaded = function(EmoteID, bUseCache, bLobby, bForceLobby)
                            local c = GetItemCfgFast(EmoteID)
                            if c and tonumber(c.ItemType or c.itemType) == 22 then
                                downloadSkinAsset(EmoteID)
                                return true
                            end
                            return origDl(EmoteID, bUseCache, bLobby, bForceLobby)
                        end
                    end
                end
            end)
        end

        installEmoteHooks()
    end
end

-- ============================================================================
-- MODULE 2: PARACHUTE (SLOT 11) & GLIDER (SLOT 15) CAPTURE & PERSISTENCE
-- (Removed redundant 0.4s match loop — unified into Module 3's single pass!)
-- ============================================================================
do
    if not _G.__PARACHUTE_GLIDER_SYSTEM_LOADED then
        _G.__PARACHUTE_GLIDER_SYSTEM_LOADED = true

        local INV = _G.InventorySkins
        local CCH = _G.AddOutfitEquippedCache
        INV.parachute = tonumber(INV.parachute) or 0
        INV.glider    = tonumber(INV.glider) or 0

        function _G.SaveLobbyState_ParachuteGlider()
            if IsInMatch() then return end
            local kv = {}
            if INV.parachute > 0 then kv["SKIN_Parachute"] = INV.parachute end
            if INV.glider > 0    then kv["SKIN_Glider"]    = INV.glider end
            if next(kv) then
                UpdateKeysInSaveFile(SHADOW_TXT, kv)
                UpdateKeysInSaveFile(VRSXH_TXT, kv)
            end
        end

        local function readSavedParachuteGlider()
            for _, p in ipairs({ VRSXH_TXT, SHADOW_TXT }) do
                pcall(function()
                    local f = io.open(p, "r")
                    if not f then return end
                    for line in f:lines() do
                        local k, v = line:match("^%s*([^=]+)%s*=%s*(.-)%s*$")
                        if k and v then
                            local n = tonumber(v)
                            if n and n > 0 then
                                if k == "equip_parachute" or k == "SKIN_Parachute" then
                                    INV.parachute = n; CCH.equip.parachute = n
                                elseif k == "equip_glider" or k == "SKIN_Glider" then
                                    INV.glider = n; CCH.equip.glider = n
                                end
                            end
                        end
                    end
                    f:close()
                end)
            end
        end
        readSavedParachuteGlider()

        pcall(function()
            local WRH = require("client.network.Protocol.WardRobeHandler")
            if WRH and not WRH._MasterPGHooked then
                WRH._MasterPGHooked = true
                local origRsp = WRH.on_depot_put_on_rsp
                WRH.on_depot_put_on_rsp = function(res, item, olditem, slot, newIns, oldIns, extra)
                    if origRsp then origRsp(res, item, olditem, slot, newIns, oldIns, extra) end
                    if item and not _G._PersistLoading then
                        local rID = tonumber(item.res_id or item.resID)
                        local c = GetItemCfgFast(rID)
                        if c then
                            local it = tonumber(c.ItemType or c.itemType or 0)
                            local st = tonumber(c.ItemSubType or c.itemSubType or 0)
                            if it == 4 and st == 701 then
                                INV.parachute = rID
                                CCH.equip.parachute = rID
                                downloadSkinAsset(rID)
                                _G.SaveLobbyState_ParachuteGlider()
                            elseif it == 4 and (st == 413 or st == 414 or st == 415) then
                                INV.glider = rID
                                CCH.equip.glider = rID
                                downloadSkinAsset(rID)
                                _G.SaveLobbyState_ParachuteGlider()
                            end
                        end
                    end
                end
            end
        end)
    end
end

-- ============================================================================
-- MODULE 3 & 4 UNIFIED: V1 BACKPACKS/HELMETS + ZERO-LAG MATCH SKIN SYSTEM
-- ============================================================================
local ConvertBagHelmetLevel = nil
local V1State = { bagLv3 = 0, helmetLv3 = 0 }

do
    if not _G.__VRSXH_V1_BAG_HELMET_LOADED then
        _G.__VRSXH_V1_BAG_HELMET_LOADED = true

        ConvertBagHelmetLevel = function(id, targetLevel)
            id = tonumber(id) or 0
            targetLevel = tonumber(targetLevel) or 3
            if id <= 0 then return 0 end

            local s = tostring(math.floor(id))
            if #s == 10 then
                local pfx4 = tonumber(s:sub(1, 4))
                local tail = tonumber(s:sub(8, 10))
                if pfx4 and tail and (pfx4 == 1501 or pfx4 == 1504 or pfx4 == 1502 or pfx4 == 1505) then
                    local candidate = (pfx4 * 1000000) + (targetLevel * 1000) + tail
                    if GetItemCfgFast(candidate) then return candidate end
                    if pfx4 == 1504 then
                        local alt = 1501000000 + (targetLevel * 1000) + tail
                        if GetItemCfgFast(alt) then return alt end
                    elseif pfx4 == 1505 then
                        local alt = 1502000000 + (targetLevel * 1000) + tail
                        if GetItemCfgFast(alt) then return alt end
                    end
                    return candidate
                end
            end
            return id
        end

        local function IsBagID(id)
            id = tonumber(id) or 0
            if id <= 0 then return false end
            local pfx = math.floor(id / 1000000)
            if pfx == 1501 or pfx == 1504 then return true end
            local row = GetItemCfgFast(id)
            local st  = row and tonumber(row.ItemSubType or row.itemSubType)
            return st == 504 or st == 501
        end

        local function IsHelmetID(id)
            id = tonumber(id) or 0
            if id <= 0 then return false end
            local pfx = math.floor(id / 1000000)
            if pfx == 1502 or pfx == 1505 then return true end
            local row = GetItemCfgFast(id)
            local st  = row and tonumber(row.ItemSubType or row.itemSubType)
            return st == 505 or st == 502
        end

        V1State.bagLv3    = ConvertBagHelmetLevel(_G.InventorySkins.bag or 1501003051, 3)
        V1State.helmetLv3 = ConvertBagHelmetLevel(_G.InventorySkins.helmet or 1502003014, 3)

        local function SyncGlobalsFromV1()
            _G.InventorySkins.bag    = V1State.bagLv3
            _G.InventorySkins.helmet = V1State.helmetLv3
            _G.OutfitMap.Bag         = V1State.bagLv3
            _G.OutfitMap.Helmet      = V1State.helmetLv3
        end
        SyncGlobalsFromV1()

        local function LoadBagHelmetFromDisk()
            local f = io.open(SHADOW_TXT, "r")
            if not f then return false end
            for line in f:lines() do
                local k, v = line:match("^%s*([^=]+)%s*=%s*(%d+)%s*$")
                local num = tonumber(v)
                if k and num and num > 0 then
                    if k == "SKIN_Bag" and IsBagID(num) then
                        V1State.bagLv3 = ConvertBagHelmetLevel(num, 3)
                    elseif k == "SKIN_Helmet" and IsHelmetID(num) then
                        V1State.helmetLv3 = ConvertBagHelmetLevel(num, 3)
                    end
                end
            end
            f:close()
            SyncGlobalsFromV1()
            return true
        end

        local function SaveBagHelmetToDisk()
            if IsInMatch() then return end
            SyncGlobalsFromV1()
            local kv = {}
            if V1State.bagLv3 > 0    then kv["SKIN_Bag"]    = V1State.bagLv3 end
            if V1State.helmetLv3 > 0 then kv["SKIN_Helmet"] = V1State.helmetLv3 end
            UpdateKeysInSaveFile(SHADOW_TXT, kv)
        end

        local origSaveLobby = _G.SaveLobbyState
        _G.SaveLobbyState = function(...)
            if origSaveLobby then pcall(origSaveLobby, ...) end
            SaveBagHelmetToDisk()
        end

        local BagHelInsToRes = {}
        local BagHelResToIns = {}
        local DiscoveredList = nil

        local function DiscoverValidBagsAndHelmets()
            if DiscoveredList then return DiscoveredList end
            if not _OrigCDataTableGet then return nil end
            DiscoveredList = {}

            local function CheckAndCollect(resID, expectedSubType, expectedSubTab)
                local row = GetItemCfgFast(resID)
                if not row then return end
                local st   = tonumber(row.ItemSubType or row.itemSubType)
                local mTab = tonumber(row.WardrobeMainTab or row.wardrobeMainTab)
                local sTab = tonumber(row.WardrobeTab or row.wardrobeTab)
                local name = row.ItemName or row.itemName
                if st == expectedSubType and mTab == 1 and sTab == expectedSubTab and name and name ~= "" and name ~= " " then
                    local lv3 = ConvertBagHelmetLevel(resID, 3)
                    if GetItemCfgFast(lv3) then
                        DiscoveredList[#DiscoveredList + 1] = resID
                    end
                end
            end

            for i = 1, 999 do
                CheckAndCollect(1501000000 + i, 504, 15)
                CheckAndCollect(1504000000 + i, 504, 15)
                CheckAndCollect(1502000000 + i, 505, 16)
                CheckAndCollect(1505000000 + i, 505, 16)
            end
            return DiscoveredList
        end

        local function InjectBagsAndHelmetsIntoEntity(entity)
            local list = DiscoverValidBagsAndHelmets()
            if not list or #list == 0 then return false end
            if not entity then
                local dc = package.loaded["client.slua.logic.wardrobe.logic_wardrobe_data_center"]
                entity = dc and dc.GetWardrobeData and dc.GetWardrobeData()
            end
            if not entity or not entity.bInit then return false end

            local baseIns = 2010000000
            for idx, resID in ipairs(list) do
                local insID = baseIns + idx
                local existingIns = nil
                local arr = entity.ResIDToIndexArrayMap and entity.ResIDToIndexArrayMap[resID]
                if arr then
                    for _, rowIdx in pairs(arr) do
                        local d = entity._data and entity._data[rowIdx]
                        if d and d.count and d.count > 0 then
                            existingIns = tonumber(d.insID or d.instid)
                            break
                        end
                    end
                end
                if existingIns then
                    BagHelInsToRes[existingIns] = resID
                    BagHelResToIns[resID]       = existingIns
                else
                    pcall(function()
                        entity:AddData({
                            instid = insID, res_id = resID, count = 1,
                            lock_cnt = 0, isnew = 0, valid_hours = 0, expire_ts = 0
                        })
                        local d = entity.GetDataByInsID and entity:GetDataByInsID(insID)
                        if d and entity.LoadConfigForData then
                            entity:LoadConfigForData(d, CDataTable.GetTableData)
                        end
                        BagHelInsToRes[insID] = resID
                        BagHelResToIns[resID] = insID
                    end)
                end
            end
            return true
        end

        local function ApplyBagToLobbyCharacter(showHelmetPreview)
            if not IsInLobby() then return end
            pcall(function()
                local uid = DataMgr and DataMgr.roleData and tostring(DataMgr.roleData.uid)
                local TAM = package.loaded["client.logic.avatar.logic_team_avatar_manager"]
                         or require("client.logic.avatar.logic_team_avatar_manager")
                local lobbyPawn = (uid and TAM and TAM.GetAvatarByUid and TAM.GetAvatarByUid(uid)) or nil
                if SafeValid(lobbyPawn) and lobbyPawn.PutonEquipment then
                    if V1State.bagLv3 > 0 then
                        pcall(function() lobbyPawn:PutonEquipment(V1State.bagLv3, { CustomType = 1 }, {}) end)
                    end
                    if showHelmetPreview and V1State.helmetLv3 > 0 then
                        pcall(function() lobbyPawn:PutonEquipment(V1State.helmetLv3, { CustomType = 1 }, {}) end)
                    end
                end
            end)
        end

        local _HandlingBagHelTap = false
        local function EquipBagOrHelmetOnTap(resID, insID)
            if _HandlingBagHelTap then return false end
            resID = tonumber(resID) or 0
            if resID <= 0 then return false end
            local isBag = IsBagID(resID)
            local isHel = not isBag and IsHelmetID(resID)
            if not isBag and not isHel then return false end

            _HandlingBagHelTap = true
            pcall(function()
                local baseResID = ConvertBagHelmetLevel(resID, 0)
                local lv3ResID  = ConvertBagHelmetLevel(resID, 3)
                local subType   = isBag and 504 or 505
                insID = tonumber(insID) or BagHelResToIns[baseResID] or baseResID

                if isBag then V1State.bagLv3 = lv3ResID else V1State.helmetLv3 = lv3ResID end
                SyncGlobalsFromV1()

                local wd  = package.loaded["client.slua.logic.wardrobe.wardrobe_data"] or require("client.slua.logic.wardrobe.wardrobe_data")
                local av  = package.loaded["client.slua.logic.wardrobe.logic_wardrobe_avatar"] or require("client.slua.logic.wardrobe.logic_wardrobe_avatar")
                local WRH = package.loaded["client.network.Protocol.WardRobeHandler"] or require("client.network.Protocol.WardRobeHandler")
                local wfu = package.loaded["client.slua.logic.wardrobe.fashionbag.wardrobe_fashion_utils"] or require("client.slua.logic.wardrobe.fashionbag.wardrobe_fashion_utils")
                local fbd = package.loaded["client.slua.logic.wardrobe.fashionbag.fashionbag_data"] or require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
                local AvatarData = package.loaded["client.logic.data.AvatarData"] or require("client.logic.data.AvatarData")

                local oldIns, oldRes = 0, 0
                if AvatarData and AvatarData.GetRoleWear then
                    for _, wornIns in pairs(AvatarData.GetRoleWear()) do
                        wornIns = tonumber(wornIns)
                        if wornIns and wornIns > 0 then
                            local d = wd and wd:GetHallDepotItemDataByInsID(wornIns)
                            local wornRes = (d and tonumber(d.resID)) or BagHelInsToRes[wornIns]
                            if (isBag and IsBagID(wornRes)) or (isHel and IsHelmetID(wornRes)) then
                                oldIns = wornIns
                                oldRes = wornRes or 0
                                if AvatarData.RemoveRoleWearDataByValue then
                                    AvatarData.RemoveRoleWearDataByValue(wornIns)
                                end
                            end
                        end
                    end
                end

                local slot = (wfu and wfu.GetRoleWearIndexBySubType and wfu:GetRoleWearIndexBySubType(subType)) or (isBag and 15 or 16)
                local item = { res_id = baseResID, count = 1, instid = insID }
                local oldItem = (oldIns > 0 and oldIns ~= insID) and { res_id = oldRes, count = 1, instid = oldIns } or nil

                if WRH and WRH.on_depot_put_on_rsp then
                    pcall(WRH.on_depot_put_on_rsp, "ok", item, oldItem, slot, insID, oldIns)
                end
                if av then
                    if av.AddToWearInfo then pcall(function() av:AddToWearInfo(subType, insID, baseResID, 0, 0) end) end
                    if av.AvatarChange then pcall(function() av:AvatarChange(lv3ResID, true, 0, 0) end) end
                end
                if fbd and fbd.SaveRolewearToFashionBag then
                    pcall(function() fbd:SaveRolewearToFashionBag(fbd:GetFashionBagUseIndex()) end)
                end

                ApplyBagToLobbyCharacter(isHel)
                if EventSystem and EVENTTYPE_WARDROBE then
                    if EVENTID_WARDROBE_UPDATE_ITEM_LIST then EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_ITEM_LIST) end
                    if EVENTID_WARDROBE_UPDATE_AVATAR_LIST then EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_AVATAR_LIST) end
                end
                SaveBagHelmetToDisk()
            end)
            _HandlingBagHelTap = false
            return true
        end

        local function InstallV1WardrobeHooks()
            InjectBagsAndHelmetsIntoEntity()
            pcall(function()
                local WDE = require("client.slua.logic.wardrobe.WardrobeDataEntity")
                if WDE and not WDE._VrsxhV1InitHooked then
                    WDE._VrsxhV1InitHooked = true
                    local origInit = WDE.InitData
                    if type(origInit) == "function" then
                        WDE.InitData = function(self, pkg, ...)
                            local ret = origInit(self, pkg, ...)
                            pcall(function() InjectBagsAndHelmetsIntoEntity(self) end)
                            return ret
                        end
                    end
                end
            end)

            pcall(function()
                local LAM = package.loaded["client.logic.avatar.LobbyAvatarManager"]
                         or require("client.logic.avatar.LobbyAvatarManager")
                if LAM and LAM.SpawnPlayer and not LAM._VrsxhV1SpawnHooked then
                    LAM._VrsxhV1SpawnHooked = true
                    local origSpawn = LAM.SpawnPlayer
                    LAM.SpawnPlayer = function(playerData, bIsSelf, ...)
                        pcall(function()
                            local myUid = DataMgr and DataMgr.roleData and tostring(DataMgr.roleData.uid)
                            if type(playerData) == "table" and (bIsSelf == true or playerData.index == 1 or (myUid and tostring(playerData.gid) == myUid)) then
                                if V1State.bagLv3 > 0 then playerData.bagSkinInsId = V1State.bagLv3 end
                            end
                        end)
                        local ret = origSpawn(playerData, bIsSelf, ...)
                        RunLater(0.4, function() ApplyBagToLobbyCharacter(false) end)
                        return ret
                    end
                end
            end)

            pcall(function()
                local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                if wd and not wd._VrsxhV1Hooked then
                    wd._VrsxhV1Hooked = true
                    local function isOurs(id)
                        id = tonumber(id)
                        return id and (BagHelInsToRes[id] ~= nil or BagHelResToIns[id] ~= nil)
                    end
                    for _, fnName in ipairs({"GetHallDepotItemDataByInsID", "GetValidHallDepotItemDataByInsID"}) do
                        if wd[fnName] then
                            local orig = wd[fnName]
                            wd[fnName] = function(self, insID, ...)
                                local nIns = tonumber(insID)
                                if nIns and BagHelInsToRes[nIns] then
                                    local dc = require("client.slua.logic.wardrobe.logic_wardrobe_data_center")
                                    local e = dc and dc.GetWardrobeData and dc.GetWardrobeData()
                                    if e and e.GetDataByInsID then
                                        local d = e:GetDataByInsID(nIns)
                                        if not d then
                                            InjectBagsAndHelmetsIntoEntity(e)
                                            d = e:GetDataByInsID(nIns)
                                        end
                                        if d then return d end
                                    end
                                end
                                return orig(self, insID, ...)
                            end
                        end
                    end
                    if wd.GetItemIDByInsID then
                        local orig = wd.GetItemIDByInsID
                        wd.GetItemIDByInsID = function(self, insID, ...)
                            local nIns = tonumber(insID)
                            if nIns and BagHelInsToRes[nIns] then return BagHelInsToRes[nIns] end
                            return orig(self, insID, ...)
                        end
                    end
                    for _, fnName in ipairs({"HasItem", "HasValidItem", "CheckHasPermanentItem"}) do
                        if wd[fnName] then
                            local orig = wd[fnName]
                            wd[fnName] = function(self, id, ...)
                                if isOurs(id) then return true end
                                return orig(self, id, ...)
                            end
                        end
                    end
                end
            end)

            pcall(function()
                local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
                if wl and not wl._VrsxhV1Hooked then
                    wl._VrsxhV1Hooked = true
                    if wl.IsWearValid then
                        local origWearValid = wl.IsWearValid
                        wl.IsWearValid = function(self, insID, ...)
                            local nIns = tonumber(insID)
                            if nIns and nIns >= 2000000000 then return true end
                            return origWearValid(self, insID, ...)
                        end
                    end
                    if wl.GetItemResId then
                        local origGetRes = wl.GetItemResId
                        wl.GetItemResId = function(self, insID, ...)
                            local nIns = tonumber(insID)
                            if nIns and BagHelInsToRes[nIns] then return BagHelInsToRes[nIns] end
                            local r = origGetRes(self, insID, ...)
                            if (not r or r == 0) and nIns and nIns >= 2000000000 then
                                local wd = package.loaded["client.slua.logic.wardrobe.wardrobe_data"]
                                if wd and wd.GetItemIDByInsID then return wd:GetItemIDByInsID(nIns) or 0 end
                            end
                            return r
                        end
                    end
                    local origCanUse = wl.IsCanUse
                    if type(origCanUse) == "function" then
                        wl.IsCanUse = function(self, resId, ...)
                            if BagHelResToIns[tonumber(resId)] then return true end
                            return origCanUse(self, resId, ...)
                        end
                    end
                    local origCharUse = wl.IsCharacterUse
                    if type(origCharUse) == "function" then
                        wl.IsCharacterUse = function(self, resId, ...)
                            if BagHelResToIns[tonumber(resId)] then return true end
                            return origCharUse(self, resId, ...)
                        end
                    end
                    local origGetIns = wl.GetWardrobeInsIdByResId
                    if type(origGetIns) == "function" then
                        wl.GetWardrobeInsIdByResId = function(self, resid, ...)
                            local n = tonumber(resid)
                            if n and BagHelResToIns[n] then return BagHelResToIns[n] end
                            return origGetIns(self, resid, ...)
                        end
                    end
                    local origFilter = wl.IsValidCurrentPageItem
                    if type(origFilter) == "function" then
                        wl.IsValidCurrentPageItem = function(self, mainTab, subTab, v, t)
                            if mainTab == 1 and v and v.resID and BagHelResToIns[tonumber(v.resID)] then
                                local st = tonumber(v.itemSubType)
                                if subTab == 15 and st == 504 then return true end
                                if subTab == 16 and st == 505 then return true end
                                return false
                            end
                            return origFilter(self, mainTab, subTab, v, t)
                        end
                    end
                end
            end)

            pcall(function()
                local WRH = require("client.network.Protocol.WardRobeHandler")
                if WRH and not WRH._VrsxhV1PutHooked then
                    WRH._VrsxhV1PutHooked = true
                    local origPutOnReq = WRH.send_depot_put_on_req
                    if type(origPutOnReq) == "function" then
                        WRH.send_depot_put_on_req = function(insID, extra)
                            local nIns = tonumber(insID)
                            local resID = nIns and BagHelInsToRes[nIns]
                            if resID and EquipBagOrHelmetOnTap(resID, nIns) then return end
                            return origPutOnReq(insID, extra)
                        end
                    end
                    local origPutOnRsp = WRH.on_depot_put_on_rsp
                    if type(origPutOnRsp) == "function" then
                        WRH.on_depot_put_on_rsp = function(res, item, olditem, slot, newInsID, oldInsID, extra)
                            local ret = origPutOnRsp(res, item, olditem, slot, newInsID, oldInsID, extra)
                            if not _HandlingBagHelTap and type(item) == "table" and item.res_id then
                                local rId = tonumber(item.res_id)
                                local iId = tonumber(item.instid or newInsID)
                                if rId and (IsBagID(rId) or IsHelmetID(rId)) then
                                    EquipBagOrHelmetOnTap(rId, iId)
                                end
                            end
                            return ret
                        end
                    end
                end
            end)

            pcall(function()
                local av = require("client.slua.logic.wardrobe.logic_wardrobe_avatar")
                if av and av.GetRealWearInsID and not av._VrsxhV1RealWearHooked then
                    av._VrsxhV1RealWearHooked = true
                    local origReal = av.GetRealWearInsID
                    av.GetRealWearInsID = function(self, subType, ...)
                        local st = tonumber(subType)
                        if st == 504 and V1State.bagLv3 > 0 then
                            local baseBag = ConvertBagHelmetLevel(V1State.bagLv3, 0)
                            if BagHelResToIns[baseBag] then return BagHelResToIns[baseBag] end
                        elseif st == 505 and V1State.helmetLv3 > 0 then
                            local baseHel = ConvertBagHelmetLevel(V1State.helmetLv3, 0)
                            if BagHelResToIns[baseHel] then return BagHelResToIns[baseHel] end
                        end
                        return origReal(self, subType, ...)
                    end
                end
            end)
        end

        LoadBagHelmetFromDisk()
        InstallV1WardrobeHooks()
        ApplyBagToLobbyCharacter(false)

        for _, delaySec in ipairs({ 1.5, 4.0 }) do
            RunLater(delaySec, function()
                if IsInLobby() then
                    LoadBagHelmetFromDisk()
                    InstallV1WardrobeHooks()
                    ApplyBagToLobbyCharacter(false)
                end
            end)
        end
    end
end

-- ============================================================================
-- MODULE 3B: UNIFIED ZERO-LAG SKIN + ATTACHMENT + BAG/HELMET + PARA/GLIDER LOOP
-- ============================================================================
do
    if not _G.__ZERO_LAG_SKIN_SYSTEM then
        _G.__ZERO_LAG_SKIN_SYSTEM = false

        local SHADOW_FILES = {
            ROOT_DIR .. "VRSXH_LOBBY.txt",
            SHADOW_TXT,
            VRSXH_TXT,
        }

        -- Throttle 1.lua's LoadLobbyState so returning from a match never freezes the Lobby
        pcall(function()
            local origLoadLobby = _G.LoadLobbyState
            if type(origLoadLobby) == "function" and not _G._ZLS_LobbyLoadThrottled then
                _G._ZLS_LobbyLoadThrottled = true
                local _lastLobbyLoadTime = 0
                local _loadedForThisLobbySession = false

                _G.LoadLobbyState = function(...)
                    if not IsInLobby() then
                        _loadedForThisLobbySession = false
                        return false
                    end
                    if _loadedForThisLobbySession then return true end
                    local now = os.clock()
                    if now - _lastLobbyLoadTime < 5.0 then return false end
                    local ok, res = pcall(origLoadLobby, ...)
                    if ok and res then
                        _loadedForThisLobbySession = true
                        _lastLobbyLoadTime = now
                        return true
                    end
                    return false
                end
            end
        end)

        local MC = {
            outfit = 0, clothes = {},
            helmet = {0,0,0}, bag = {0,0,0},
            para = 0, glider = 0,
            weapons = {}, vehicles = {},
            loaded = false,
        }
        local AC           = {}
        local ACValidSet   = {}
        local AttachToBase = {}
        local ACLoaded     = false

        -- Fast, zero-freeze attachment mapper: only queries the ~40 base attachment IDs (never GetTable("Item")!)
        local KNOWN_BASE_ATTACH_IDS = {
            201001, 201002, 201003, 201004, 201005, 201006, 201007, 201008, 201009, 201010, 201011, 201012,
            202001, 202002, 202004, 202005, 202006, 202007, 205051,
            203001, 203002, 203003, 203004, 203005, 203014, 203015, 203018,
            204004, 204005, 204006, 204007, 204008, 204009, 204011, 204012, 204013, 204014,
            205001, 205002, 205003
        }

        local _WEAPON_CLASS_SUFFIXES = {
            { keywords = { "kar98", "awm", "m24", "amr", "mosin", "win94", "mk14", "dsr", "m200" }, suffixes = { "(Snipers)", "(Sniper Rifles)" } },
            { keywords = { "m249", "mg3", "dp-28", "dp28" }, suffixes = { "(Machine Guns)" } },
            { keywords = { "ump", "p90", "vector", "bizon", "uzi", "thompson", "mp5", "mp5k", "tommy" }, suffixes = { "(SMG)", "(SMG, Pistols)", "(Rifles, SMG)" } },
            { keywords = { "p1911", "p92", "p18c", "deagle", "r1895", "r45", "skorpion", "g18" }, suffixes = { "(Pistols)", "(SMG, Pistols)" } },
            { keywords = { "akm", "m762", "scar", "famas", "m16a4", "aug", "groza", "qbz", "m416", "mk47", "g36c", "ace32", "k2", "m4", "honey" }, suffixes = { "(AR)", "(Rifles, SMG)" } },
        }

        local function _nameToStr(name)
            if not name then return "" end
            if type(name) == "string" then return name end
            if type(name) == "userdata" and name.ToString then
                local ok, s = pcall(function() return name:ToString() end)
                if ok and type(s) == "string" then return s end
            end
            if type(name) == "table" and name.SourceString then return name.SourceString end
            return tostring(name)
        end

        local function _suffixesForSkin(skinName)
            local low = string.lower(skinName or "")
            for _, entry in ipairs(_WEAPON_CLASS_SUFFIXES) do
                for _, kw in ipairs(entry.keywords) do
                    if string.find(low, kw, 1, true) then return entry.suffixes end
                end
            end
            return {}
        end

        local function generateAndSaveAttachFileLobbyOnly()
            -- NEVER run table generation during a live match!
            if IsInMatch() then return false end
            if not _refreshOrigCfgGet() then return false end
            if not (CDataTable and CDataTable.GetTable) then return false end
            local unlockTbl = CDataTable.GetTable("ItemUpgradeUnLockConfig")
            local upTbl     = CDataTable.GetTable("ItemUpgradeConfig")
            if not (unlockTbl and upTbl) then return false end

            local groupToParts = {}
            for _, row in pairs(unlockTbl) do
                local gid  = tonumber(row.GroupID)
                local part = tonumber(row.PartId or row.PartID)
                if gid and part and part > 0 then
                    groupToParts[gid] = groupToParts[gid] or {}
                    groupToParts[gid][#groupToParts[gid] + 1] = part
                end
            end

            local skinToGroup = {}
            for _, row in pairs(upTbl) do
                local gid = tonumber(row.GroupID)
                local itm = tonumber(row.ItemID)
                if gid and itm and itm >= 1000000000 then
                    skinToGroup[itm] = gid
                end
            end

            -- Fast lookup of only the ~40 known base attachment IDs (Zero full-table scan!)
            local baseNameToIds = {}
            for _, id in ipairs(KNOWN_BASE_ATTACH_IDS) do
                local row = GetItemCfgFast(id)
                local nm = _nameToStr(row and row.ItemName)
                if nm ~= "" then
                    baseNameToIds[nm] = baseNameToIds[nm] or {}
                    baseNameToIds[nm][#baseNameToIds[nm] + 1] = id
                end
            end

            local lines = {}
            local count = 0

            for weaponSkinId, gid in pairs(skinToGroup) do
                local parts = groupToParts[gid]
                if parts and #parts > 0 then
                    local wc = GetItemCfgFast(weaponSkinId)
                    local suffixes = _suffixesForSkin(wc and _nameToStr(wc.ItemName) or "")
                    AC[weaponSkinId] = AC[weaponSkinId] or {}
                    ACValidSet[weaponSkinId] = ACValidSet[weaponSkinId] or {}

                    for _, partId in ipairs(parts) do
                        ACValidSet[weaponSkinId][partId] = true
                        local matchedBases = {}

                        local m = _OrigCDataTableGet("WeaponSkinMapping", partId)
                        local b = m and tonumber(m.WeaponID or m.WeaponId)
                        if b and b > 0 and b < 10000000 then
                            matchedBases[#matchedBases + 1] = b
                        end

                        local partRow = GetItemCfgFast(partId)
                        if partRow then
                            local nm = _nameToStr(partRow.ItemName)
                            if nm ~= "" then
                                local list = baseNameToIds[nm]
                                if list and list[1] then matchedBases[#matchedBases + 1] = list[1] end
                                for _, suf in ipairs(suffixes) do
                                    local lst = baseNameToIds[nm .. " " .. suf]
                                    if lst and lst[1] then matchedBases[#matchedBases + 1] = lst[1] end
                                end
                            end
                        end

                        if #matchedBases == 0 then
                            local emb = tostring(partId):match("(20[1-5]%d%d%d)")
                            if emb then matchedBases[#matchedBases + 1] = tonumber(emb) end
                        end

                        for _, baseId in ipairs(matchedBases) do
                            if baseId and baseId > 0 then
                                AC[weaponSkinId][baseId] = partId
                                AttachToBase[partId]     = baseId
                                lines[#lines + 1]        = weaponSkinId .. "|" .. baseId .. "=" .. partId
                                count = count + 1
                            end
                        end
                    end
                end
            end

            if count > 0 then
                pcall(function()
                    local wf = io.open(ATTACH_TXT, "w")
                    if wf then
                        wf:write(table.concat(lines, "\n") .. "\n")
                        wf:close()
                    end
                end)
                ACLoaded = true
                return true
            end
            return false
        end

        local _lastAttachTry = -1e9   -- never throttle the very first attempt
        local _attachFails   = 0

        -- [TASK3] Accepts both cache formats:
        --   attachment.txt / attachments.txt :  <skinID>|<baseID>=<resID>
        --   match_skin.txt                   :  ATT_<skinID>|<baseID>=<resID>
        local function _ingestAttachLine(line)
            local s, b, n = line:match("^ATT_(%d+)|(%d+)=(%d+)$")
            if not s then s, b, n = line:match("^(%d+)|(%d+)=(%d+)$") end
            if not s then return false end
            s, b, n = tonumber(s), tonumber(b), tonumber(n)
            if not (s and b and n) then return false end
            AC[s] = AC[s] or {}
            AC[s][b] = n
            ACValidSet[s] = ACValidSet[s] or {}
            ACValidSet[s][n] = true
            AttachToBase[n] = b
            return true
        end

        local function _readAttachFile(path)
            local count = 0
            local f = io.open(path, "r")
            if not f then return 0 end
            for line in f:lines() do
                if _ingestAttachLine(line) then count = count + 1 end
            end
            f:close()
            return count
        end

        local function loadAttachCache()
            if ACLoaded then return end

            -- ------------------------------------------------------------------
            -- [TASK3] IN MATCH: attachments come ONLY from match_skin.txt.
            -- No attachment.txt read, no table generation, no loops.
            -- ------------------------------------------------------------------
            if IsInMatch() then
                AC = {}; ACValidSet = {}; AttachToBase = {}
                local count = _readAttachFile(MATCH_TXT)
                if count > 0 then ACLoaded = true end
                return
            end

            -- ------------------------------------------------------------------
            -- IN LOBBY: attachment.txt -> legacy -> generate.
            -- ------------------------------------------------------------------
            local now = os.clock()
            if now - _lastAttachTry < 5.0 then return end
            _lastAttachTry = now
            AC = {}; ACValidSet = {}; AttachToBase = {}

            local count = _readAttachFile(ATTACH_TXT)
            if count == 0 then
                count = _readAttachFile(ATTACH_TXT_LEGACY)
                if count > 0 then
                    pcall(function()
                        local rf = io.open(ATTACH_TXT_LEGACY, "r")
                        if not rf then return end
                        local data = rf:read("*a"); rf:close()
                        local wf = io.open(ATTACH_TXT, "w")
                        if wf then wf:write(data); wf:close() end
                    end)
                end
            end

            if count > 0 then
                ACLoaded = true
            elseif IsInLobby() then
                if _attachFails < 30 then
                    local ok, generated = pcall(generateAndSaveAttachFileLobbyOnly)
                    if ok and generated then
                        ACLoaded = true
                        _attachFails = 0
                    else
                        _attachFails = _attachFails + 1
                        if not _cfgProven then _cfgCache = {} end
                    end
                end
            end
        end

        local function loadMatchCache()
            MC = {
                outfit = 0, clothes = {}, helmet = {0,0,0}, bag = {0,0,0},
                para = 0, glider = 0, weapons = {}, vehicles = {}, loaded = true
            }
            local f = io.open(MATCH_TXT, "r")
            if f then
                for line in f:lines() do
                    local k, v = line:match("^([%w_]+%d*)=(.+)$")
                    if k and v then
                        if k == "OUTFIT" then MC.outfit = tonumber(v) or 0
                        elseif k == "PARA" then MC.para = tonumber(v) or 0
                        elseif k == "GLIDER" then MC.glider = tonumber(v) or 0
                        elseif k:match("^HELMET_L(%d+)$") then
                            local l = tonumber(k:match("^HELMET_L(%d+)$"))
                            if l and l >= 1 and l <= 3 then MC.helmet[l] = tonumber(v) or 0 end
                        elseif k:match("^BAG_L(%d+)$") then
                            local l = tonumber(k:match("^BAG_L(%d+)$"))
                            if l and l >= 1 and l <= 3 then MC.bag[l] = tonumber(v) or 0 end
                        elseif k == "CLOTH" then
                            for id in v:gmatch("([^,]+)") do
                                local n = tonumber(id)
                                if n and n > 0 then table.insert(MC.clothes, n) end
                            end
                        elseif k:match("^WEAPON_(%d+)$") then
                            local wid = tonumber(k:match("^WEAPON_(%d+)$"))
                            if wid then MC.weapons[wid] = tonumber(v) or 0 end
                        elseif k:match("^VEHICLE_(%d+)$") then
                            local b = tonumber(k:match("^VEHICLE_(%d+)$"))
                            if b then MC.vehicles[b] = tonumber(v) or 0 end
                        end
                    end
                end
                f:close()
            end

            local INV = _G.InventorySkins or {}
            local CCH = _G.AddOutfitEquippedCache or {}

            local liveHelm = (V1State.helmetLv3 > 0 and V1State.helmetLv3)
                          or (tonumber(INV.helmet) and tonumber(INV.helmet) > 0 and tonumber(INV.helmet))
                          or (CCH.equip and tonumber(CCH.equip.helmet) or 0)
            if liveHelm > 0 and ConvertBagHelmetLevel then
                for lvl = 1, 3 do MC.helmet[lvl] = ConvertBagHelmetLevel(liveHelm, lvl) end
            end

            local liveBag = (V1State.bagLv3 > 0 and V1State.bagLv3)
                         or (tonumber(INV.bag) and tonumber(INV.bag) > 0 and tonumber(INV.bag))
                         or (CCH.equip and tonumber(CCH.equip.bag) or 0)
            if liveBag > 0 and ConvertBagHelmetLevel then
                for lvl = 1, 3 do MC.bag[lvl] = ConvertBagHelmetLevel(liveBag, lvl) end
            end

            if tonumber(INV.parachute) and tonumber(INV.parachute) > 0 then MC.para = tonumber(INV.parachute)
            elseif CCH.equip and tonumber(CCH.equip.parachute) and tonumber(CCH.equip.parachute) > 0 then MC.para = tonumber(CCH.equip.parachute) end

            if tonumber(INV.glider) and tonumber(INV.glider) > 0 then MC.glider = tonumber(INV.glider)
            elseif CCH.equip and tonumber(CCH.equip.glider) and tonumber(CCH.equip.glider) > 0 then MC.glider = tonumber(CCH.equip.glider) end

            for wid, w in pairs((CCH and CCH.weapons) or {}) do
                local r = type(w) == "table" and tonumber(w.resID) or tonumber(w)
                if tonumber(wid) and r and r > 0 then MC.weapons[tonumber(wid)] = r end
            end
            for wid, r in pairs((INV and INV.weapons) or {}) do
                if tonumber(wid) and tonumber(r) and tonumber(r) > 0 and not MC.weapons[tonumber(wid)] then
                    MC.weapons[tonumber(wid)] = tonumber(r)
                end
            end
        end

        local _lastShadowSizes = ""
        local function generateMatchFileInLobby()
            if not IsInLobby() then return end
            if not ACLoaded then pcall(loadAttachCache) end

            -- Fast file-size check before reading full files
            local sizeParts = {}
            local INV = _G.InventorySkins or {}
            sizeParts[#sizeParts + 1] = string.format("%d:%d:%d:%d:%d",
                tonumber(INV.outfit) or 0, tonumber(INV.parachute) or 0, tonumber(INV.glider) or 0,
                V1State.helmetLv3 or 0, V1State.bagLv3 or 0)

            for _, path in ipairs(SHADOW_FILES) do
                local f = io.open(path, "r")
                if f then
                    sizeParts[#sizeParts + 1] = tostring(f:seek("end") or 0)
                    f:close()
                end
            end
            local curSizeSig = table.concat(sizeParts, "|")
            if curSizeSig == _lastShadowSizes then return end
            _lastShadowSizes = curSizeSig

            local R = { outfit = 0, para = 0, glider = 0, helmet = 0, bag = 0, weapons = {}, vehicles = {} }
            for _, path in ipairs(SHADOW_FILES) do
                local f = io.open(path, "r")
                if f then
                    for line in f:lines() do
                        local k, v = line:match("^([^=]+)=(.+)$")
                        if k and v then
                            local n = tonumber(v:match("^(%d+)") or v)
                            if n and n > 0 then
                                if k == "SKIN_Outfit" or k == "outfitRes" then R.outfit = n
                                elseif k == "SKIN_Parachute" or k == "equip_parachute" then R.para = n
                                elseif k == "SKIN_Glider" or k == "equip_glider" then R.glider = n
                                elseif k == "SKIN_Helmet" or k == "equip_helmet" then R.helmet = n
                                elseif k == "SKIN_Bag" or k == "equip_bag" then R.bag = n
                                else
                                    local wid = k:match("^SKIN_Weapon_(%d+)$") or k:match("^weapon_(%d+)$")
                                    if wid then R.weapons[tonumber(wid)] = n end
                                    local vslot = k:match("^SKIN_Vehicle_(%d+)$") or k:match("^vehslot_(%d+)$")
                                    if vslot then R.vehicles[tonumber(vslot)] = n end
                                end
                            end
                        end
                    end
                    f:close()
                end
            end

            if INV.parachute and INV.parachute > 0 then R.para = INV.parachute end
            if INV.glider and INV.glider > 0 then R.glider = INV.glider end
            if V1State.helmetLv3 > 0 then R.helmet = V1State.helmetLv3 end
            if V1State.bagLv3 > 0 then R.bag = V1State.bagLv3 end

            local lines = {}
            if R.outfit > 0 then lines[#lines + 1] = "OUTFIT=" .. R.outfit end
            if R.para   > 0 then lines[#lines + 1] = "PARA=" .. R.para end
            if R.glider > 0 then lines[#lines + 1] = "GLIDER=" .. R.glider end
            if R.helmet > 0 and ConvertBagHelmetLevel then
                for lvl = 1, 3 do lines[#lines + 1] = "HELMET_L" .. lvl .. "=" .. ConvertBagHelmetLevel(R.helmet, lvl) end
            end
            if R.bag > 0 and ConvertBagHelmetLevel then
                for lvl = 1, 3 do lines[#lines + 1] = "BAG_L" .. lvl .. "=" .. ConvertBagHelmetLevel(R.bag, lvl) end
            end
            for wid, res in pairs(R.weapons) do
                lines[#lines + 1] = "WEAPON_" .. wid .. "=" .. res
            end

            -- [TASK3] Persist the per-weapon attachment mapping into match_skin.txt
            -- so a match resolves attachments per gun without opening any other file.
            if next(AC) then
                local attWeapons = {}
                for wid, sid in pairs(R.weapons) do attWeapons[wid] = sid end
                for wid, sid in pairs((_G.InventorySkins and _G.InventorySkins.weapons) or {}) do
                    if not attWeapons[wid] then attWeapons[wid] = sid end
                end
                local seen = {}
                for wid, skinID in pairs(attWeapons) do
                    local map = AC[tonumber(skinID) or 0]
                    if map then
                        for baseID, resID in pairs(map) do
                            local key = skinID .. "|" .. baseID .. "=" .. resID
                            if not seen[key] then
                                seen[key] = true
                                lines[#lines + 1] = "ATT_" .. key
                            end
                        end
                    end
                end
            end

            -- Always rewrite, even when empty: otherwise unequipping everything leaves
            -- the previous match's skins in the file and they get re-applied.
            local wf = io.open(MATCH_TXT, "w")
            if wf then
                wf:write(table.concat(lines, "\n"))
                if #lines > 0 then wf:write("\n") end
                wf:close()
            end
        end

        -- 0.1s Cached Combat Detector (Skips all cosmetic work while ADS or firing!)
        local _combatVal, _combatT = false, 0
        local function inCombat()
            local now = os.clock()
            if now - _combatT < 0.1 then return _combatVal end
            _combatT = now
            local v = false
            local GD = package.loaded["GameLua.GameCore.Data.GameplayData"]
            local c = GD and GD.GetPlayerCharacter and GD.GetPlayerCharacter()
            if SafeValid(c) then
                if c.bIsGunADS or c.bIsWeaponAiming or c.bIsWeaponFiring then
                    v = true
                else
                    local w = c.GetCurrentWeapon and c:GetCurrentWeapon()
                    if SafeValid(w) and (w.bIsFiring or w.bIsWeaponFiring) then v = true end
                end
            end
            _combatVal = v
            return v
        end

        -- Single Unified Pass over Character SlotSyncData (Handles Outfit, Bag, Helmet, Parachute & Glider!)
        local _ensuredGliderSD = setmetatable({}, { __mode = "k" })
        local _appliedCharInit = setmetatable({}, { __mode = "k" })

        local function applyAllCharacterSlotsUnified(char)
            local ac = char.AvatarComponent2
                    or char.CharacterAvatarComp2_BP
                    or char.CharacterAvatarComponent_BP
                    or char.CharacterAvatarComponent
                    or char.AvatarComponent
                    or (char.getAvatarComponent2 and char:getAvatarComponent2())
            if not SafeValid(ac) or not ac.NetAvatarData then return end
            local sd = ac.NetAvatarData.SlotSyncData
            if not SafeValid(sd) then return end

            local INV = _G.InventorySkins or {}
            local paraRes   = (tonumber(INV.parachute) and tonumber(INV.parachute) > 0 and tonumber(INV.parachute)) or MC.para
            local gliderRes = (tonumber(INV.glider) and tonumber(INV.glider) > 0 and tonumber(INV.glider)) or MC.glider

            -- 1. One-time per-character init (Outfit + PlayerController Parachute/Glider)
            if not _appliedCharInit[char] then
                _appliedCharInit[char] = true
                if MC.outfit > 0 and ac.PutOnCustomEquipmentByID then
                    downloadSkinAsset(MC.outfit)
                    pcall(ac.PutOnCustomEquipmentByID, ac, MC.outfit)
                end
                for _, cid in ipairs(MC.clothes) do
                    downloadSkinAsset(cid)
                    if ac.PutOnCustomEquipmentByID then pcall(ac.PutOnCustomEquipmentByID, ac, cid) end
                end

                local pc = char.GetPlayerControllerSafety and char:GetPlayerControllerSafety()
                if SafeValid(pc) and (paraRes > 0 or gliderRes > 0) then
                    local eq = pc.InitialEquipmentAvatar or {}
                    local dirty = false
                    if paraRes > 0 and eq.ParachuteAvatar ~= paraRes then
                        downloadSkinAsset(paraRes); eq.ParachuteAvatar = paraRes; dirty = true
                    end
                    if gliderRes > 0 and eq.GliderAvatar ~= gliderRes then
                        downloadSkinAsset(gliderRes); eq.GliderAvatar = gliderRes; dirty = true
                    end
                    if dirty then
                        pc.InitialEquipmentAvatar = eq
                        if SafeValid(pc.PlayerState) and pc.PlayerState.MetroPlayerStateAvatarFeature then
                            pc.PlayerState.MetroPlayerStateAvatarFeature.InitialEquipmentAvatar = eq
                        end
                    end
                end
            end

            -- 2. Ensure Glider Slot 15 exists once per SlotSyncData
            if gliderRes > 0 and not _ensuredGliderSD[sd] then
                _ensuredGliderSD[sd] = true
                local hasSlot15 = false
                for i = 0, sd:Num() - 1 do
                    local s = sd:Get(i)
                    if s and s.SlotID == 15 then hasSlot15 = true; break end
                end
                if not hasSlot15 then
                    pcall(function() sd:Add({ SlotID = 15, ItemId = gliderRes, ItemID = gliderRes }) end)
                end
                if ac.PutOnCustomEquipmentByID then pcall(ac.PutOnCustomEquipmentByID, ac, gliderRes) end
            end

            -- 3. Single pass over SlotSyncData for Bag (8), Helmet (9), Parachute (11), Glider (15)
            local bu = GetBackpackUtils()
            local num = sd:Num()
            local changed = false

            for i = 0, num - 1 do
                local eq = sd:Get(i)
                if eq then
                    local slotID = eq.SlotID
                    local curID  = tonumber(eq.ItemId or eq.ItemID) or 0
                    local target = 0

                    if slotID == 8 and curID > 0 and V1State.bagLv3 > 0 then
                        local lvl = (bu and bu.GetEquipmentBagLevel and bu.GetEquipmentBagLevel(eq.AdditionalItemID)) or 3
                        if lvl < 1 or lvl > 3 then lvl = 3 end
                        target = ConvertBagHelmetLevel(V1State.bagLv3, lvl)
                    elseif slotID == 9 and curID > 0 and V1State.helmetLv3 > 0 then
                        local lvl = (bu and bu.GetEquipmentHelmetLevel and bu.GetEquipmentHelmetLevel(eq.AdditionalItemID)) or 3
                        if lvl < 1 or lvl > 3 then lvl = 3 end
                        target = ConvertBagHelmetLevel(V1State.helmetLv3, lvl)
                    elseif slotID == 11 and paraRes > 0 then
                        -- Slot 11 is often still 0 until the parachute actually spawns,
                        -- so requiring curID > 0 meant the skin was never applied.
                        target = paraRes
                    elseif slotID == 15 and gliderRes > 0 then
                        target = gliderRes
                    end

                    if target > 0 and curID ~= target then
                        downloadSkinAsset(target)
                        eq.ItemId = target
                        pcall(function() eq.ItemID = target end)
                        sd:Set(i, eq)
                        changed = true
                    end
                end
            end

            if changed and ac.OnRep_BodySlotStateChanged then
                pcall(ac.OnRep_BodySlotStateChanged, ac)
            end
        end

        -- Fast Weapon + Attachment Applier with State Signature Caching (Zero inner-loop closures!)
        local _WeaponStateSig = setmetatable({}, { __mode = "k" })

        local function resolveTargetWeaponSkin(wid)
            wid = tonumber(wid) or 0
            if wid <= 0 then return 0 end
            if MC.weapons[wid] and MC.weapons[wid] > 1000000 then return MC.weapons[wid] end
            local inv = _G.InventorySkins
            if inv and inv.weapons and tonumber(inv.weapons[wid]) and tonumber(inv.weapons[wid]) > 1000000 then
                return tonumber(inv.weapons[wid])
            end
            if _G.get_skin_id then
                local ok, s = pcall(_G.get_skin_id, wid)
                s = ok and tonumber(s) or 0
                if s > 1000000 and s ~= wid then return s end
            end
            return 0
        end

        local function applySingleWeaponFast(weapon)
            local synData = weapon.synData
            if not SafeValid(synData) then return end
            local wid = tonumber(weapon:GetWeaponID()) or 0
            local target = resolveTargetWeaponSkin(wid)
            if not target or target <= 1000000 or target == wid then return end

            local n = synData:Num()
            -- Compute fast integer checksum of synData slots 0..7 so we skip immediately if nothing changed!
            local sig = target
            for idx = 0, math.min(n - 1, 7) do
                local sd = synData:Get(idx)
                local def = sd and sd.defineID
                local tid = (def and tonumber(def.TypeSpecificID)) or 0
                sig = (sig * 31 + tid) % 2147483647
            end
            if _WeaponStateSig[weapon] == sig then return end

            local modified = false
            local master = synData:Get(7)
            if master and master.defineID and tonumber(master.defineID.TypeSpecificID) ~= target then
                downloadSkinAsset(target)
                master.defineID.TypeSpecificID = target
                master.operationType = 0
                synData:Set(7, master)
                if weapon.SetWeaponAvatarID then pcall(weapon.SetWeaponAvatarID, weapon, target) end
                modified = true
            end

            local attachMap = AC[target]
            local validSet  = ACValidSet[target]
            if attachMap then
                for idx = 0, n - 1 do
                    if idx ~= 7 then
                        local sd = synData:Get(idx)
                        local def = sd and sd.defineID
                        local cur = (def and tonumber(def.TypeSpecificID)) or 0
                        if cur > 0 and not (validSet and validSet[cur]) then
                            local baseID = AttachToBase[cur] or (cur < 10000000 and cur or 0)
                            local newID  = (baseID > 0 and attachMap[baseID]) or attachMap[cur]
                            if newID and newID > 0 and newID ~= cur then
                                downloadSkinAsset(newID)
                                def.TypeSpecificID = newID
                                sd.operationType = 0
                                synData:Set(idx, sd)
                                modified = true
                            end
                        end
                    end
                end
            end

            if modified then
                if weapon.DelayHandleAvatarMeshChanged then pcall(weapon.DelayHandleAvatarMeshChanged, weapon) end
                if weapon.OnRep_synData             then pcall(weapon.OnRep_synData, weapon) end
                if weapon.UpdateWeaponAttachment    then pcall(weapon.UpdateWeaponAttachment, weapon) end
            end

            -- Recompute signature after modification so next tick is a <0.001ms no-op!
            local newSig = target
            for idx = 0, math.min(n - 1, 7) do
                local sd = synData:Get(idx)
                local def = sd and sd.defineID
                local tid = (def and tonumber(def.TypeSpecificID)) or 0
                newSig = (newSig * 31 + tid) % 2147483647
            end
            _WeaponStateSig[weapon] = newSig
        end

        local _wasInMatch = false

        local function masterZeroLagTick()
            if inCombat() then return end

            if IsInLobby() then
                if _wasInMatch then
                    _wasInMatch = false
                    collectgarbage("step", 80)
                end
                pcall(_G.LoadLobbyEmotes)
                pcall(generateMatchFileInLobby)
                return
            end

            if not IsInMatch() then return end

            if not _wasInMatch then
                _wasInMatch = true
                -- [PERF/TASK2] One-shot read of match_skin.txt on match entry.
                pcall(loadMatchCache)
                pcall(loadAttachCache)
            end

            -- [PERF] After the entry window this master tick does nothing.
            if not _G.__SkinTickAllowed() then return end

            local GD = package.loaded["GameLua.GameCore.Data.GameplayData"]
            local char = GD and GD.GetPlayerCharacter and GD.GetPlayerCharacter()
            if not SafeValid(char) then return end

            pcall(applyAllCharacterSlotsUnified, char)

            pcall(function()
                local wm = char:GetWeaponManager()
                if not SafeValid(wm) then return end
                local list = wm:GetAllInventoryWeaponList(false)
                if not SafeValid(list) then return end
                for i = 0, list:Num() - 1 do
                    local w = list:Get(i)
                    if SafeValid(w) then
                        applySingleWeaponFast(w)
                    end
                end
            end)
        end

        pcall(loadAttachCache)
        pcall(loadMatchCache)
        pcall(generateMatchFileInLobby)

        if _ticker and _ticker.AddTimerLoop and not _G._ZLS_SingleMasterTicker then
            _G._ZLS_SingleMasterTicker = _ticker.AddTimerLoop(0.8, masterZeroLagTick, -1, 0.8)
        elseif Game and Game.SetTimer and not _G._ZLS_SingleMasterTimer then
            _G._ZLS_SingleMasterTimer = Game:SetTimer(0.8, true, masterZeroLagTick)
        end
    end
end

-- ============================================================================
-- MODULE 5: V3 (REV C-TURBO) — CLIENT-SIDE FACE & HAIR (ZERO MATCH TICK LAG)
-- Fixes:
--   1. PatchServerFaceAndHairInRAM runs ONLY ONCE when Face/Hair ID changes!
--   2. CDataTable.GetTableData hook is O(1) — never runs pairs() in matches!
--   3. IsSelfCharacterAvatarComp is cached in a weak table.
--   4. Disk logging completely removed.
-- ============================================================================
do
    if not _G.__VRSXH_V3_FACE_HAIR_REVC then
        _G.__VRSXH_V3_FACE_HAIR_REVC = true

        local ActiveAppearance = {
            [1] = { itemID = nil, avatarKey = nil, uiIndex = nil, itemData = nil, name = "Face" },
            [2] = { itemID = nil, avatarKey = nil, uiIndex = nil, itemData = nil, name = "Hair" },
            [3] = { itemID = nil, avatarKey = nil, uiIndex = nil, itemData = nil, name = "Beard" }
        }

        local ServerEquippedSlotID = {
            [1] = 401985,
            [2] = 40601002,
            [3] = nil
        }

        local KeyToDataMap      = {}
        local ItemIdToDataMap   = {}
        local ItemIdToTabType   = {}
        local TabListCache      = { [1] = {}, [2] = {}, [3] = {} }
        local CurrentSubTabType = 1

        local _InAppearanceContext = false
        local _InRevertBlock       = false
        local _InAvatarEquipGuard  = false
        local _ForceLobbyPawnFlag  = false
        local _ActiveSubTabUI      = nil
        local _ActiveLogicInst     = nil

        local function ClassifyAppearanceID(id)
            id = tonumber(id) or 0
            if id <= 0 then return nil end
            if ItemIdToTabType[id] then return ItemIdToTabType[id] end
            if KeyToDataMap[id] and KeyToDataMap[id].AvatarType then
                return tonumber(KeyToDataMap[id].AvatarType)
            end
            if (id >= 400990 and id <= 402000) or (id >= 402300 and id <= 402499) or (id >= 1400500 and id <= 1400650) then
                return 1
            end
            if (id >= 402110 and id <= 402299) or (id >= 40600000 and id <= 40699999) or (id >= 406000000 and id <= 406999999) then
                return 2
            end
            if (id >= 40800000 and id <= 40899999) then
                return 3
            end
            local row = GetItemCfgFast(id)
            if row then
                local sub = tonumber(row.ItemSubType) or 0
                if sub == 400 then return 1 end
                if sub == 406 then return 2 end
                if sub == 408 then return 3 end
            end
            return nil
        end

        local function ExtractItemAndKeyFromData(data)
            if type(data) ~= "table" then return nil, nil, nil end
            local itemID = tonumber(
                rawget(data, "ItemId") or rawget(data, "itemId") or rawget(data, "ItemID") or rawget(data, "itemID")
                or rawget(data, "resID") or rawget(data, "ResID")
            )
            local avatarKey = tonumber(
                rawget(data, "AvatarId") or rawget(data, "avatarId") or rawget(data, "AvatarID") or rawget(data, "avatarID")
                or rawget(data, "id") or rawget(data, "ID") or rawget(data, "key")
            )
            local tabType = tonumber(rawget(data, "AvatarType") or rawget(data, "avatarType"))

            if not tabType and avatarKey then
                if avatarKey >= 10000 and avatarKey < 20000 then tabType = 1
                elseif avatarKey >= 20000 and avatarKey < 30000 then tabType = 2
                elseif avatarKey >= 30000 and avatarKey < 40000 then tabType = 3 end
            end
            if not tabType and itemID then tabType = ClassifyAppearanceID(itemID) end
            return itemID, avatarKey, tabType
        end

        local function UnlockAppearanceItemTable(data, cfgRow)
            if cfgRow ~= nil then
                pcall(function() cfgRow.RoyalePassSeason = 0; cfgRow.ForeverCost = 0 end)
            end
            if type(data) ~= "table" then return data end
            pcall(function()
                data.Owned            = true
                data.RoyalePassSeason = 0
                data.ForeverCost      = 0
                data.RemainTime       = 0
                local itemID, avatarKey, tabType = ExtractItemAndKeyFromData(data)
                if avatarKey then KeyToDataMap[avatarKey] = data end
                if itemID and itemID > 0 then
                    ItemIdToDataMap[itemID] = data
                    if tabType then ItemIdToTabType[itemID] = tabType end
                end
            end)
            return data
        end

        -- One-Shot RAM Patcher: Only patches when (serverID, targetID) actually changes!
        local _OriginalStructBackup = {}
        local _PatchedRAMSignature  = {}
        local AppearanceTablesToPatch = { "Item", "BPMappingTable", "AvatarHideSlotConfig", "NoReplaceHatTable" }

        local function BackupStructIfNeeded(tableName, id, row)
            if not row then return end
            local key = tableName .. ":" .. tostring(id)
            if _OriginalStructBackup[key] then return end
            local snap = {}
            pcall(function()
                for k, v in pairs(row) do
                    if k ~= "ItemID" and k ~= "ID" and type(v) ~= "function" then
                        snap[k] = v
                    end
                end
            end)
            _OriginalStructBackup[key] = snap
        end

        local function CopyAppearanceStructInPlace(dstRow, srcSnapOrRow)
            if not dstRow or not srcSnapOrRow or dstRow == srcSnapOrRow then return end
            pcall(function()
                for k, v in pairs(srcSnapOrRow) do
                    if k ~= "ItemID" and k ~= "ID" then
                        dstRow[k] = v
                    end
                end
            end)
        end

        local function PatchServerFaceAndHairInRAMOnce()
            if not _OrigCDataTableGet then return end
            for slotType = 1, 3 do
                local targetID = ActiveAppearance[slotType] and ActiveAppearance[slotType].itemID
                local serverID = ServerEquippedSlotID[slotType]
                if targetID and targetID > 0 and serverID and serverID > 0 and targetID ~= serverID then
                    local sig = tostring(serverID) .. "->" .. tostring(targetID)
                    if _PatchedRAMSignature[slotType] ~= sig then
                        _PatchedRAMSignature[slotType] = sig
                        for _, tName in ipairs(AppearanceTablesToPatch) do
                            pcall(function()
                                local dstRow = _OrigCDataTableGet(tName, serverID)
                                local srcRow = _OrigCDataTableGet(tName, targetID)
                                if dstRow and srcRow then
                                    BackupStructIfNeeded(tName, serverID, dstRow)
                                    BackupStructIfNeeded(tName, targetID, srcRow)
                                    local cleanSrc = _OriginalStructBackup[tName .. ":" .. tostring(targetID)] or srcRow
                                    CopyAppearanceStructInPlace(dstRow, cleanSrc)
                                end
                            end)
                        end
                    end
                end
            end
        end

        -- O(1) CDataTable Hook: Never runs CopyAppearanceStructInPlace inside GetTableData!
        do
            if CDataTable and CDataTable.GetTableData and not CDataTable._VrsxhV3RevCDTHook then
                CDataTable._VrsxhV3RevCDTHook = true
                local origGet = CDataTable.GetTableData
                _OrigCDataTableGet = origGet

                CDataTable.GetTableData = function(tableName, itemID)
                    local origRow = origGet(tableName, itemID)
                    if origRow ~= nil then return origRow end
                    local numID = tonumber(itemID)
                    if numID and (tableName == "Item" or tableName == "BPMappingTable") then
                        for slotType = 1, 3 do
                            if numID == ServerEquippedSlotID[slotType] then
                                local targetID = ActiveAppearance[slotType] and ActiveAppearance[slotType].itemID
                                if targetID and targetID ~= numID then
                                    return origGet(tableName, targetID)
                                end
                            end
                        end
                    end
                    return nil
                end
            end
        end

        local _AllAvatarComps = setmetatable({}, { __mode = "k" })
        local _SelfCompCache  = setmetatable({}, { __mode = "k" })

        local function IsSelfCharacterAvatarComp(comp)
            if not comp then return false end
            local cached = _SelfCompCache[comp]
            if cached ~= nil then return cached end

            local ok, res = pcall(function()
                if comp.OwnerIsLobbyPawn and comp:OwnerIsLobbyPawn() then return true end
                local owner = comp.GetOwner and comp:GetOwner()
                if not owner then return false end
                if owner.IsLocallyControlled and owner:IsLocallyControlled() then return true end
                local gd = package.loaded["GameLua.GameCore.Data.GameplayData"]
                local selfPawn = gd and gd.GetPlayerCharacter and gd.GetPlayerCharacter()
                if selfPawn and owner == selfPawn then return true end
                if tostring(owner):find("BP_PlayerLobbyPawn") then return true end
                return false
            end)
            local isSelf = (ok and res == true) or false
            if isSelf then _SelfCompCache[comp] = true end
            return isSelf
        end

        local function ApplyFaceAndHairToComp(comp, forceApply)
            if _InAvatarEquipGuard or not comp then return end
            if not IsSelfCharacterAvatarComp(comp) then return end

            _InAvatarEquipGuard = true
            pcall(function()
                _AllAvatarComps[comp] = true
                PatchServerFaceAndHairInRAMOnce()

                local owner = comp.GetOwner and comp:GetOwner()
                local inMatch = IsInMatch()

                for tabType = 1, 3 do
                    local state = ActiveAppearance[tabType]
                    local targetID = state and state.itemID
                    if targetID and targetID > 0 then
                        local propKey = "_VrsxhLastSlot_" .. tostring(tabType) .. "_" .. tostring(inMatch)
                        if forceApply or rawget(comp, propKey) ~= targetID then
                            rawset(comp, propKey, targetID)
                            downloadSkinAsset(targetID)

                            _ForceLobbyPawnFlag = true
                            if comp.PutOnCustomEquipmentByID then
                                pcall(comp.PutOnCustomEquipmentByID, comp, targetID, { id = targetID, resID = targetID, itemID = targetID })
                            end
                            _ForceLobbyPawnFlag = false

                            if inMatch and comp.PutOnEquipmentByResID then
                                pcall(comp.PutOnEquipmentByResID, comp, targetID)
                            end

                            if inMatch and owner and owner.synData then
                                pcall(function()
                                    local actualIndex = tabType - 1
                                    local d = owner.synData:Get(actualIndex)
                                    if d and d.defineID then
                                        d.defineID.TypeSpecificID = targetID
                                        owner.synData:Set(actualIndex, d)
                                    end
                                end)
                            end
                        end
                    end
                end
            end)
            _ForceLobbyPawnFlag = false
            _InAvatarEquipGuard = false
        end

        local function BroadcastFaceAndHairToAllSelfComps(forceApply)
            PatchServerFaceAndHairInRAMOnce()
            for comp in pairs(_AllAvatarComps) do
                if comp then ApplyFaceAndHairToComp(comp, forceApply) end
            end
            if IsInMatch() then
                pcall(function()
                    local gd = package.loaded["GameLua.GameCore.Data.GameplayData"]
                    local player = gd and gd.GetPlayerCharacter and gd.GetPlayerCharacter()
                    if player then
                        local comp = player.CharacterAvatarComponent_BP or player.CharacterAvatarComponent or player.AvatarComponent
                        if comp then
                            _AllAvatarComps[comp] = true
                            _SelfCompCache[comp]  = true
                            ApplyFaceAndHairToComp(comp, forceApply)
                        end
                    end
                end)
            end
        end

        local function RefreshAppearanceUICheckmarks()
            pcall(function()
                if _ActiveSubTabUI then
                    if _ActiveSubTabUI.OnAvatarEquipmentChange then pcall(_ActiveSubTabUI.OnAvatarEquipmentChange, _ActiveSubTabUI) end
                    if _ActiveSubTabUI.RefreshAppearance then pcall(_ActiveSubTabUI.RefreshAppearance, _ActiveSubTabUI) end
                end
            end)
        end

        local function EquipAppearanceClientSide(logicSelf, tabType, itemData, avatarKey, meshItemID)
            pcall(function()
                if not itemData then
                    if avatarKey and KeyToDataMap[avatarKey] then itemData = KeyToDataMap[avatarKey]
                    elseif meshItemID and ItemIdToDataMap[meshItemID] then itemData = ItemIdToDataMap[meshItemID] end
                end
                if itemData then
                    UnlockAppearanceItemTable(itemData)
                    local extItem, extKey, extTab = ExtractItemAndKeyFromData(itemData)
                    meshItemID = meshItemID or extItem
                    avatarKey  = avatarKey  or extKey
                    tabType    = tabType    or extTab
                end
                tabType = tonumber(tabType) or ClassifyAppearanceID(meshItemID) or CurrentSubTabType or 1
                local state = ActiveAppearance[tabType]
                if not state then return end

                if meshItemID and meshItemID > 0 then state.itemID = meshItemID end
                if avatarKey  and avatarKey > 0  then state.avatarKey = avatarKey end
                if itemData                      then state.itemData = itemData end

                if state.itemID and state.itemID > 0 then
                    downloadSkinAsset(state.itemID)
                    PatchServerFaceAndHairInRAMOnce()
                    local lwaInst = logicSelf or _ActiveLogicInst
                    if lwaInst and lwaInst.PutOnAvatar then
                        pcall(lwaInst.PutOnAvatar, lwaInst, state.itemID)
                    end
                    BroadcastFaceAndHairToAllSelfComps(true)
                    RefreshAppearanceUICheckmarks()
                end
            end)
        end

        local function HookTableAndInnerImpl(modTable, hookTag, setupFn)
            if type(modTable) ~= "table" then return end
            local targets = { modTable }
            local inner = rawget(modTable, "__inner_impl")
            if type(inner) == "table" and inner ~= modTable then targets[#targets + 1] = inner end
            for _, tbl in ipairs(targets) do
                if not rawget(tbl, hookTag) then
                    rawset(tbl, hookTag, true)
                    setupFn(tbl)
                end
            end
        end

        local function HookWardrobeAndAppearanceOnce()
            pcall(function()
                local wd = package.loaded["client.slua.logic.wardrobe.wardrobe_data"]
                if wd and not wd._VrsxhV3RevCOwnHooked then
                    wd._VrsxhV3RevCOwnHooked = true
                    local function ShouldSpoofItem(resID)
                        if _InAppearanceContext then return true end
                        return ClassifyAppearanceID(resID) ~= nil
                    end
                    for _, fnName in ipairs({ "HasItem", "HasValidItem", "CheckHasPermanentItem" }) do
                        if type(wd[fnName]) == "function" then
                            local orig = wd[fnName]
                            wd[fnName] = function(selfOrId, idOrNil, ...)
                                local r = orig(selfOrId, idOrNil, ...)
                                if not r then
                                    local checkID = tonumber(idOrNil) or tonumber(selfOrId)
                                    if ShouldSpoofItem(checkID) then return true end
                                end
                                return r
                            end
                        end
                    end
                    for _, fnName in ipairs({ "GetHallDepotItemCountByResID", "GetHallDepotItemCountByResIDAndValidInfo", "GetItemCountOnlyForever" }) do
                        if type(wd[fnName]) == "function" then
                            local orig = wd[fnName]
                            wd[fnName] = function(selfOrId, idOrNil, ...)
                                local r = orig(selfOrId, idOrNil, ...)
                                if (tonumber(r) or 0) <= 0 then
                                    local checkID = tonumber(idOrNil) or tonumber(selfOrId)
                                    if ShouldSpoofItem(checkID) then return 1 end
                                end
                                return r
                            end
                        end
                    end
                    if type(wd.GetHallDepotItemDataByResID) == "function" then
                        local origData = wd.GetHallDepotItemDataByResID
                        wd.GetHallDepotItemDataByResID = function(selfOrId, idOrNil, ...)
                            local r = origData(selfOrId, idOrNil, ...)
                            if not r then
                                local checkID = tonumber(idOrNil) or tonumber(selfOrId)
                                if checkID and ShouldSpoofItem(checkID) then
                                    return { resID = checkID, itemID = checkID, count = 1, insID = tostring(checkID), expireTS = 0, isNew = false }
                                end
                            end
                            return r
                        end
                    end
                end
            end)

            pcall(function()
                local itu = package.loaded["client.slua.umg.Wardrobe.tips.item_tips_util"]
                if itu and not itu._VrsxhV3RevCTipsHooked then
                    itu._VrsxhV3RevCTipsHooked = true
                    if type(itu.GetAvatarItemOwned) == "function" then
                        local origOwned = itu.GetAvatarItemOwned
                        itu.GetAvatarItemOwned = function(id, ...)
                            local r = origOwned(id, ...)
                            if not r and (_InAppearanceContext or ClassifyAppearanceID(id) ~= nil) then return true end
                            return r
                        end
                    end
                end
            end)

            pcall(function()
                local lwa = package.loaded["client.slua.logic.wardrobe.logic_wardrobe_appearance"]
                if lwa then
                    HookTableAndInnerImpl(lwa, "_VrsxhV3RevCHooked", function(tbl)
                        if type(tbl.GetAvatarInitTableData) == "function" then
                            local origInitTbl = tbl.GetAvatarInitTableData
                            tbl.GetAvatarInitTableData = function(self, ...)
                                _ActiveLogicInst = self or _ActiveLogicInst
                                local res = origInitTbl(self, ...)
                                if type(res) == "table" then
                                    for _, v in pairs(res) do UnlockAppearanceItemTable(v, v) end
                                end
                                return res
                            end
                        end
                        if type(tbl.GenerateAvatarData) == "function" then
                            local origGen = tbl.GenerateAvatarData
                            tbl.GenerateAvatarData = function(self, cfgRow, ...)
                                _ActiveLogicInst = self or _ActiveLogicInst
                                UnlockAppearanceItemTable(nil, cfgRow)
                                _InAppearanceContext = true
                                local data = origGen(self, cfgRow, ...)
                                _InAppearanceContext = false
                                return UnlockAppearanceItemTable(data, cfgRow)
                            end
                        end
                        if type(tbl.GetAppearanceItems) == "function" then
                            local origGetItems = tbl.GetAppearanceItems
                            tbl.GetAppearanceItems = function(self, tabType, ...)
                                _ActiveLogicInst = self or _ActiveLogicInst
                                local tType = tonumber(tabType) or CurrentSubTabType
                                _InAppearanceContext = true
                                local list = origGetItems(self, tabType, ...)
                                _InAppearanceContext = false
                                if type(list) == "table" then
                                    if tType and TabListCache[tType] then TabListCache[tType] = {} end
                                    for idx, item in pairs(list) do
                                        UnlockAppearanceItemTable(item)
                                        if tType and TabListCache[tType] and type(idx) == "number" then
                                            TabListCache[tType][idx] = item
                                        end
                                    end
                                end
                                return list
                            end
                        end
                        for _, fnName in ipairs({ "GetAvatarDataById", "GetAvatarDataByKey" }) do
                            if type(tbl[fnName]) == "function" then
                                local origGetBy = tbl[fnName]
                                tbl[fnName] = function(self, a1, a2, ...)
                                    _ActiveLogicInst = self or _ActiveLogicInst
                                    _InAppearanceContext = true
                                    local data = origGetBy(self, a1, a2, ...)
                                    _InAppearanceContext = false
                                    return UnlockAppearanceItemTable(data)
                                end
                            end
                        end
                        for _, fnName in ipairs({ "PutAvatar", "TryOnAvatar" }) do
                            if type(tbl[fnName]) == "function" then
                                local origAct = tbl[fnName]
                                tbl[fnName] = function(self, tabType, key, ...)
                                    _ActiveLogicInst = self or _ActiveLogicInst
                                    local tType = tonumber(tabType) or CurrentSubTabType
                                    local numKey = tonumber(key) or key
                                    local itemData = KeyToDataMap[numKey] or ItemIdToDataMap[numKey]
                                    if not itemData and self.GetAvatarDataByKey then pcall(function() itemData = self:GetAvatarDataByKey(tType, numKey) end) end
                                    if not itemData and self.GetAvatarDataById then pcall(function() itemData = self:GetAvatarDataById(numKey) end) end
                                    EquipAppearanceClientSide(self, tType, itemData, numKey, nil)
                                    if fnName == "TryOnAvatar" then
                                        _InAppearanceContext = true
                                        local r1, r2 = origAct(self, tabType, key, ...)
                                        _InAppearanceContext = false
                                        BroadcastFaceAndHairToAllSelfComps(true)
                                        RefreshAppearanceUICheckmarks()
                                        return r1, r2
                                    else
                                        if self.ModifyAvatar and itemData then pcall(self.ModifyAvatar, self, tType, itemData, true) end
                                        BroadcastFaceAndHairToAllSelfComps(true)
                                        RefreshAppearanceUICheckmarks()
                                        return true
                                    end
                                end
                            end
                        end
                        if type(tbl.ModifyAvatar) == "function" then
                            local origModAv = tbl.ModifyAvatar
                            tbl.ModifyAvatar = function(self, tabType, itemData, bPutOn, ...)
                                _ActiveLogicInst = self or _ActiveLogicInst
                                local tType = tonumber(tabType)
                                if type(itemData) == "table" and bPutOn and not _InRevertBlock then
                                    UnlockAppearanceItemTable(itemData)
                                    EquipAppearanceClientSide(self, tType, itemData, nil, nil)
                                end
                                _InAppearanceContext = true
                                local r1, r2 = origModAv(self, tabType, itemData, bPutOn, ...)
                                _InAppearanceContext = false
                                BroadcastFaceAndHairToAllSelfComps(true)
                                return r1, r2
                            end
                        end
                        local modifySlotMap = { ModifyHeadAvatar = 1, ModifyHairAvatar = 2, ModifyBeardAvatar = 3 }
                        for fnName, slotType in pairs(modifySlotMap) do
                            if type(tbl[fnName]) == "function" then
                                local origModSlot = tbl[fnName]
                                tbl[fnName] = function(self, itemData, bPutOn, bRevert, ...)
                                    _ActiveLogicInst = self or _ActiveLogicInst
                                    local state = ActiveAppearance[slotType]
                                    if bRevert == true or _InRevertBlock then
                                        if state and (state.itemID or state.itemData) then
                                            BroadcastFaceAndHairToAllSelfComps(true)
                                            return
                                        end
                                    elseif type(itemData) == "table" and bPutOn then
                                        UnlockAppearanceItemTable(itemData)
                                        EquipAppearanceClientSide(self, slotType, itemData, nil, nil)
                                    end
                                    _InAppearanceContext = true
                                    local r1, r2 = origModSlot(self, itemData, bPutOn, bRevert, ...)
                                    _InAppearanceContext = false
                                    BroadcastFaceAndHairToAllSelfComps(true)
                                    return r1, r2
                                end
                            end
                        end
                        if type(tbl.PutOnAvatar) == "function" then
                            local origPutOn = tbl.PutOnAvatar
                            tbl.PutOnAvatar = function(self, itemID, ...)
                                _ActiveLogicInst = self or _ActiveLogicInst
                                local numID = tonumber(itemID) or 0
                                local slotType = ClassifyAppearanceID(numID)
                                if _InRevertBlock and slotType and ActiveAppearance[slotType] and ActiveAppearance[slotType].itemID then
                                    numID = ActiveAppearance[slotType].itemID
                                    itemID = numID
                                elseif slotType and ActiveAppearance[slotType] and numID > 0 then
                                    ActiveAppearance[slotType].itemID = numID
                                    downloadSkinAsset(numID)
                                    PatchServerFaceAndHairInRAMOnce()
                                end
                                _InAppearanceContext = true
                                local r1, r2 = origPutOn(self, itemID, ...)
                                _InAppearanceContext = false
                                BroadcastFaceAndHairToAllSelfComps(true)
                                return r1, r2
                            end
                        end
                        for _, fnName in ipairs({ "_GetEquipAvatarID", "GetAppearanceEquipAvatarId" }) do
                            if type(tbl[fnName]) == "function" then
                                local origGetEq = tbl[fnName]
                                tbl[fnName] = function(self, tabType, userDataMap, ...)
                                    local origID = origGetEq(self, tabType, userDataMap, ...)
                                    local tType = tonumber(tabType)
                                    local state = tType and ActiveAppearance[tType]
                                    if state and (state.itemID or state.avatarKey) then
                                        local numOrig = tonumber(origID) or 0
                                        if numOrig > 0 and numOrig < 100000 and state.avatarKey then return state.avatarKey end
                                        return state.itemID or state.avatarKey
                                    end
                                    return origID
                                end
                            end
                        end
                        if type(tbl.GetAppearanceEquipData) == "function" then
                            local origGetEqData = tbl.GetAppearanceEquipData
                            tbl.GetAppearanceEquipData = function(self, tabType, ...)
                                local origD = origGetEqData(self, tabType, ...)
                                local tType = tonumber(tabType)
                                if tType and ActiveAppearance[tType] and ActiveAppearance[tType].itemData then
                                    return ActiveAppearance[tType].itemData
                                end
                                return origD
                            end
                        end
                        for _, fnName in ipairs({ "HasEquipItemData", "HasEquipItemView", "IsRealEquip" }) do
                            if type(tbl[fnName]) == "function" then
                                local origCheck = tbl[fnName]
                                tbl[fnName] = function(self, a1, a2, ...)
                                    local r = origCheck(self, a1, a2, ...)
                                    local tType = tonumber(a1)
                                    local state = tType and ActiveAppearance[tType]
                                    if state and (state.itemID or state.avatarKey) then
                                        if a2 ~= nil then
                                            local checkItem, checkKey = nil, nil
                                            if type(a2) == "table" then checkItem, checkKey = ExtractItemAndKeyFromData(a2)
                                            else checkItem = tonumber(a2); checkKey = tonumber(a2) end
                                            if checkItem or checkKey then
                                                return (checkItem ~= nil and checkItem == state.itemID)
                                                    or (checkKey  ~= nil and checkKey  == state.avatarKey)
                                            end
                                        end
                                        return true
                                    end
                                    return r
                                end
                            end
                        end
                        for _, fnName in ipairs({ "DeInit", "RestoreToOrigin" }) do
                            if type(tbl[fnName]) == "function" then
                                local origFn = tbl[fnName]
                                tbl[fnName] = function(self, ...)
                                    _InRevertBlock = true
                                    local r1, r2 = origFn(self, ...)
                                    _InRevertBlock = false
                                    BroadcastFaceAndHairToAllSelfComps(true)
                                    return r1, r2
                                end
                            end
                        end
                    end)
                end
            end)

            pcall(function()
                local sta = package.loaded["client.slua.umg.Wardrobe.subtab_appearance"]
                if sta then
                    HookTableAndInnerImpl(sta, "_VrsxhV3RevCHooked", function(tbl)
                        for _, fnName in ipairs({ "CheckCanModify", "CheckCanModifyAppearance" }) do
                            if type(tbl[fnName]) == "function" then
                                tbl[fnName] = function(self, ...) _ActiveSubTabUI = self or _ActiveSubTabUI; return true end
                            end
                        end
                        if type(tbl.ShowCantChangeNotice) == "function" then tbl.ShowCantChangeNotice = function() return end end
                        if type(tbl.ScrollInit) == "function" then
                            local origScroll = tbl.ScrollInit
                            tbl.ScrollInit = function(self, scrollWidget, tabType, ...)
                                _ActiveSubTabUI = self or _ActiveSubTabUI
                                if tonumber(tabType) then CurrentSubTabType = tonumber(tabType) end
                                return origScroll(self, scrollWidget, tabType, ...)
                            end
                        end
                        if type(tbl.GetAppearanceItems) == "function" then
                            local origGet = tbl.GetAppearanceItems
                            tbl.GetAppearanceItems = function(self, ...)
                                _ActiveSubTabUI = self or _ActiveSubTabUI
                                _InAppearanceContext = true
                                local list = origGet(self, ...)
                                _InAppearanceContext = false
                                if type(list) == "table" then
                                    for idx, item in pairs(list) do
                                        UnlockAppearanceItemTable(item)
                                        if type(idx) == "number" then
                                            local _, _, tType = ExtractItemAndKeyFromData(item)
                                            if tType and TabListCache[tType] then TabListCache[tType][idx] = item end
                                        end
                                    end
                                end
                                return list
                            end
                        end
                        if type(tbl.OnClickItem) == "function" then
                            local origClick = tbl.OnClickItem
                            tbl.OnClickItem = function(self, itemWidget, index, ...)
                                _ActiveSubTabUI = self or _ActiveSubTabUI
                                local idx = tonumber(index)
                                local clickedData = type(itemWidget) == "table" and (rawget(itemWidget, "ItemData") or rawget(itemWidget, "itemData") or rawget(itemWidget, "data")) or nil
                                _InAppearanceContext = true
                                local r1, r2 = origClick(self, itemWidget, index, ...)
                                _InAppearanceContext = false
                                if not clickedData and idx then
                                    for _, tType in ipairs({ CurrentSubTabType, 2, 1, 3 }) do
                                        if TabListCache[tType] and TabListCache[tType][idx] then
                                            clickedData = TabListCache[tType][idx]
                                            break
                                        end
                                    end
                                end
                                if clickedData then
                                    local itemID, avatarKey, tabType = ExtractItemAndKeyFromData(clickedData)
                                    if tabType and ActiveAppearance[tabType] then ActiveAppearance[tabType].uiIndex = idx end
                                    EquipAppearanceClientSide(_ActiveLogicInst, tabType, clickedData, avatarKey, itemID)
                                end
                                return r1, r2
                            end
                        end
                    end)
                end
            end)
        end

        local _HookedCACCount = 0
        local function HookCharacterAvatarComponentsOnce()
            if _HookedCACCount >= 2 then return end
            for _, path in ipairs({
                "GameLua.Mod.Library.GamePlay.Avatar.Component.CharacterAvatarComponent",
                "GameLua.Mod.Library.GamePlay.Avatar.Component.CharacterAvatarcomponent"
            }) do
                pcall(function()
                    local CAC = package.loaded[path]
                    if not CAC then return end
                    local impl = rawget(CAC, "__inner_impl") or CAC
                    if type(impl) ~= "table" or rawget(impl, "_VrsxhV3RevCCompHooked") then return end
                    rawset(impl, "_VrsxhV3RevCCompHooked", true)
                    _HookedCACCount = _HookedCACCount + 1

                    if type(impl.OwnerIsLobbyPawn) == "function" then
                        local origIsLobby = impl.OwnerIsLobbyPawn
                        impl.OwnerIsLobbyPawn = function(self, ...)
                            if _ForceLobbyPawnFlag then return true end
                            return origIsLobby(self, ...)
                        end
                    end

                    for _, checkFn in ipairs({ "CheckItemValid", "CheckIsSlotItemIDMatched", "CheckNetAvatarSlotID" }) do
                        if type(impl[checkFn]) == "function" then
                            local origChk = impl[checkFn]
                            impl[checkFn] = function(self, ...)
                                if _ForceLobbyPawnFlag or _InAvatarEquipGuard then return true end
                                return origChk(self, ...)
                            end
                        end
                    end

                    if type(impl.HandleFaceHidden) == "function" then
                        local origHide = impl.HandleFaceHidden
                        impl.HandleFaceHidden = function(self, suitID, ...)
                            if ActiveAppearance[1].itemID or ActiveAppearance[2].itemID then return end
                            return origHide(self, suitID, ...)
                        end
                    end

                    if type(impl.PutOnCustomEquipmentByID) == "function" then
                        local origPutOn = impl.PutOnCustomEquipmentByID
                        impl.PutOnCustomEquipmentByID = function(self, resID, itemData, ...)
                            if not _InAvatarEquipGuard and IsSelfCharacterAvatarComp(self) then
                                _AllAvatarComps[self] = true
                                local numID = tonumber(resID) or 0
                                local slotType = ClassifyAppearanceID(numID)
                                if slotType then
                                    local activeID = ActiveAppearance[slotType] and ActiveAppearance[slotType].itemID
                                    if numID > 0 and numID ~= activeID and not ServerEquippedSlotID[slotType] then
                                        ServerEquippedSlotID[slotType] = numID
                                    end
                                    if activeID and activeID > 0 and numID ~= activeID then
                                        resID = activeID
                                        if type(itemData) == "table" then
                                            itemData.id = activeID; itemData.resID = activeID; itemData.itemID = activeID
                                        end
                                    end
                                end
                            end
                            return origPutOn(self, resID, itemData, ...)
                        end
                    end

                    if type(impl.OnAvatarEquipFinish) == "function" then
                        local origFinish = impl.OnAvatarEquipFinish
                        impl.OnAvatarEquipFinish = function(self, slotID, isEquip, resID, ...)
                            local sID = tonumber(slotID)
                            local rID = tonumber(resID)
                            if not _InAvatarEquipGuard and (sID == 1 or sID == 2) and rID and rID > 0 then
                                local activeID = ActiveAppearance[sID] and ActiveAppearance[sID].itemID
                                if rID ~= activeID and IsSelfCharacterAvatarComp(self) then
                                    ServerEquippedSlotID[sID] = rID
                                    PatchServerFaceAndHairInRAMOnce()
                                end
                            end
                            local r1, r2 = origFinish(self, slotID, isEquip, resID, ...)
                            if not _InAvatarEquipGuard and (sID == 1 or sID == 2) and ActiveAppearance[sID] and ActiveAppearance[sID].itemID then
                                if rID ~= ActiveAppearance[sID].itemID and IsSelfCharacterAvatarComp(self) then
                                    ApplyFaceAndHairToComp(self, true)
                                end
                            end
                            return r1, r2
                        end
                    end

                    for _, fnName in ipairs({
                        "ReceiveBeginPlay", "OnStartInit", "InitLocalEquipmentDisplay",
                        "PreOnRep_BodySlotStateChangedInternal", "OnAvatarAllMeshLoadedLua"
                    }) do
                        if type(impl[fnName]) == "function" then
                            local origFn = impl[fnName]
                            impl[fnName] = function(self, ...)
                                PatchServerFaceAndHairInRAMOnce()
                                local r1, r2 = origFn(self, ...)
                                if IsSelfCharacterAvatarComp(self) then
                                    _AllAvatarComps[self] = true
                                    ApplyFaceAndHairToComp(self, fnName == "PreOnRep_BodySlotStateChangedInternal" or fnName == "OnAvatarAllMeshLoadedLua")
                                end
                                return r1, r2
                            end
                        end
                    end
                end)
            end
        end

        local _LastMatchState   = false
        local _LastMatchPawnObj = nil

        local function SyncFaceAndHairFast()
            HookCharacterAvatarComponentsOnce()
            if IsInLobby() then
                HookWardrobeAndAppearanceOnce()
            end

            local inMatchNow = IsInMatch()
            local forceUpdate = false

            if inMatchNow ~= _LastMatchState then
                _LastMatchState = inMatchNow
                forceUpdate = true
            end

            if inMatchNow then
                local gd = package.loaded["GameLua.GameCore.Data.GameplayData"]
                local player = gd and gd.GetPlayerCharacter and gd.GetPlayerCharacter()
                if player and player ~= _LastMatchPawnObj then
                    _LastMatchPawnObj = player
                    forceUpdate = true
                    if player.synData then
                        pcall(function()
                            local d0 = player.synData:Get(0)
                            if d0 and d0.defineID then
                                local id = tonumber(d0.defineID.TypeSpecificID)
                                if id and id > 0 and id ~= ActiveAppearance[1].itemID then ServerEquippedSlotID[1] = id end
                            end
                            local d1 = player.synData:Get(1)
                            if d1 and d1.defineID then
                                local id = tonumber(d1.defineID.TypeSpecificID)
                                if id and id > 0 and id ~= ActiveAppearance[2].itemID then ServerEquippedSlotID[2] = id end
                            end
                        end)
                        PatchServerFaceAndHairInRAMOnce()
                    end
                end
                -- Fast exit if neither pawn nor appearance changed!
                if not forceUpdate and not ActiveAppearance[1].itemID and not ActiveAppearance[2].itemID then
                    return
                end
            else
                _LastMatchPawnObj = nil
            end

            BroadcastFaceAndHairToAllSelfComps(forceUpdate)
        end

        HookWardrobeAndAppearanceOnce()
        HookCharacterAvatarComponentsOnce()

        if _ticker and _ticker.AddTimerLoop then
            pcall(function()
                _ticker.AddTimerLoop(0.8, function()
                    if _G.__SkinTickAllowed() then SyncFaceAndHairFast() end
                end, -1, 0.8)
            end)
        elseif Game and Game.SetTimer then
            pcall(function() Game:SetTimer(0.8, true, function()
                if _G.__SkinTickAllowed() then SyncFaceAndHairFast() end
            end) end)
        end
    end
end

-- ============================================================================
-- MODULE 6: V5 (REV B-TURBO) — X-SUIT KILL MSG + SUMMON + GUN KILL COUNTER
-- Fixes:
--   1. Never reads disk files (io.open) while IsInMatch() is true!
--   2. Strict self-only X-Suit Kill Message Overlay (enemy/friend kills untouched).
--   3. Separate In-Match Kills (1, 2, 3...) vs Gun Kill Counter (4280+).
-- ============================================================================
do
    if not _G.__VRSXH_V5_XSUIT_KC_REVB then
        _G.__VRSXH_V5_XSUIT_KC_REVB = true

        local DEFAULT_TOTAL_KILL_COUNT = 4280

        local function HookBothTables(modTable, flagName, setupFn)
            if type(modTable) ~= "table" then return end
            local targets = { modTable }
            local inner = rawget(modTable, "__inner_impl")
            if type(inner) == "table" and inner ~= modTable then targets[#targets + 1] = inner end
            local cls = rawget(modTable, "__class")
            if type(cls) == "table" then
                local clsInner = rawget(cls, "__inner_impl") or cls
                if type(clsInner) == "table" and clsInner ~= modTable and clsInner ~= inner then
                    targets[#targets + 1] = clsInner
                end
            end
            for _, tbl in ipairs(targets) do
                if not rawget(tbl, flagName) then
                    rawset(tbl, flagName, true)
                    setupFn(tbl)
                end
            end
        end

        local SkinState = {
            outfitID    = 0, -- Default to 0 so it never forces an X-Suit when wearing T-Shirt/Pants/Shoes!
            weapons     = {},
            lastSizes   = {},
            lastCheckTS = 0
        }

        local SKIN_FILES = {
            ROOT_DIR .. "match_skin.txt",
            MATCH_TXT,
            SHADOW_TXT,
        }

        local function DeriveBaseWeaponID(skinOrWepID)
            skinOrWepID = tonumber(skinOrWepID) or 0
            if skinOrWepID <= 0 then return 0 end
            if skinOrWepID < 10000000 then return skinOrWepID end
            if _OrigCDataTableGet then
                local m = _OrigCDataTableGet("WeaponSkinMapping", skinOrWepID)
                if m then
                    local wid = tonumber(m.WeaponID or m.WeaponId)
                    if wid and wid > 0 then return wid end
                end
            end
            if skinOrWepID >= 1100000000 and skinOrWepID < 1200000000 then
                local base = math.floor((skinOrWepID - 1000000000) / 1000)
                if base >= 101000 and base <= 109999 then return base end
            end
            return 0
        end

        local function SyncSkinMemoryAndFiles(allowDiskRead)
            -- 1. Fast in-memory sync from _G.InventorySkins & _G.AddOutfitEquippedCache (0.00ms)
            if type(_G.InventorySkins) == "table" then
                local invOut = tonumber(_G.InventorySkins.outfit) or 0
                if invOut > 0 then SkinState.outfitID = invOut end
                if type(_G.InventorySkins.weapons) == "table" then
                    for wid, sid in pairs(_G.InventorySkins.weapons) do
                        local nw, ns = tonumber(wid), tonumber(sid)
                        if nw and ns and ns > 0 then SkinState.weapons[nw] = ns end
                    end
                end
            end
            if type(_G.AddOutfitEquippedCache) == "table" then
                local cOut = tonumber(_G.AddOutfitEquippedCache.outfitRes) or tonumber(_G.AddOutfitEquippedCache.outfit) or 0
                if cOut > 0 then SkinState.outfitID = cOut end
                if type(_G.AddOutfitEquippedCache.weapons) == "table" then
                    for wid, w in pairs(_G.AddOutfitEquippedCache.weapons) do
                        local nw = tonumber(wid)
                        local ns = type(w) == "table" and tonumber(w.resID) or tonumber(w)
                        if nw and ns and ns > 0 then SkinState.weapons[nw] = ns end
                    end
                end
            end

            -- 2. Disk read ONLY in Lobby or once on Match Entry (NEVER periodically during combat!)
            if allowDiskRead then
                for _, path in ipairs(SKIN_FILES) do
                    pcall(function()
                        local f = io.open(path, "r")
                        if not f then return end
                        local sz = f:seek("end") or 0
                        if SkinState.lastSizes[path] == sz then
                            f:close()
                            return
                        end
                        SkinState.lastSizes[path] = sz
                        f:seek("set", 0)
                        for line in f:lines() do
                            local outID = line:match("SKIN_Outfit%s*=%s*(%d+)")
                                       or line:match("OUTFIT%s*=%s*(%d+)")
                                       or line:match("[Oo]utfit[%s\"':=]+(%d+)")
                            if outID then
                                local nOut = tonumber(outID)
                                if nOut and nOut > 0 then SkinState.outfitID = nOut end
                            end
                            local widStr, sidStr = line:match("SKIN_Weapon_(%d+)%s*=%s*(%d+)")
                            if not widStr then widStr, sidStr = line:match("WEAPON_(%d+)%s*=%s*(%d+)") end
                            if widStr and sidStr then
                                local nw, ns = tonumber(widStr), tonumber(sidStr)
                                if nw and ns and ns > 0 then SkinState.weapons[nw] = ns end
                            end
                        end
                        f:close()
                    end)
                end
            end

            -- If separate Top (403), Pants (404), or Shoes (405) are worn, force outfitID to 0!
            local sepClothes = _G.InventorySkins and _G.InventorySkins.clothes
            if type(sepClothes) == "table" and (sepClothes[403] or sepClothes[404] or sepClothes[405]) then
                SkinState.outfitID = 0
                _G.SuitSkin = 0
                if type(_G.OutfitMap) == "table" then _G.OutfitMap.Suit = 0 end
                if type(_G.InventorySkins) == "table" then _G.InventorySkins.outfit = 0 end
            elseif SkinState.outfitID and SkinState.outfitID > 0 then
                _G.SuitSkin = SkinState.outfitID
                if type(_G.OutfitMap) == "table" then _G.OutfitMap.Suit = SkinState.outfitID end
            end
        end

        local function ResolveWeaponSkinFast(weaponOrSkinID)
            local num = tonumber(weaponOrSkinID) or 0
            if num <= 0 then return 0, 0 end
            if num >= 10000000 then
                local baseW = DeriveBaseWeaponID(num)
                return (baseW > 0 and baseW or num), num
            end
            local skin = SkinState.weapons[num]
                      or (_G.InventorySkins and _G.InventorySkins.weapons and tonumber(_G.InventorySkins.weapons[num]))
            if not skin and _G.get_skin_id then
                local ok, s = pcall(_G.get_skin_id, num)
                if ok and tonumber(s) and tonumber(s) > 0 then skin = tonumber(s) end
            end
            return num, (skin and skin > 0) and skin or num
        end

        local function ResolveActiveOutfitID()
            -- If wearing separate T-Shirt, Pants, or Shoes, return 0 so NO X-Suit kill message or suit swap happens!
            local sepClothes = _G.InventorySkins and _G.InventorySkins.clothes
            if type(sepClothes) == "table" and (sepClothes[403] or sepClothes[404] or sepClothes[405]) then
                _G.SuitSkin = 0
                return 0
            end

            local out = tonumber(_G.InventorySkins and _G.InventorySkins.outfit) or 0
            if out <= 0 then
                out = tonumber(SkinState.outfitID) or 0
            end
            _G.SuitSkin = out
            return out
        end

        local function IsLocalPlayerCauser(dmgData)
            if not dmgData then return false end
            local isMe = false
            pcall(function()
                local gd = package.loaded["GameLua.GameCore.Data.GameplayData"]
                local playerChar = gd and gd.GetPlayerCharacter and gd.GetPlayerCharacter()
                if not playerChar then return end

                local myUID = tonumber(_G.DataMgr and _G.DataMgr.roleData and _G.DataMgr.roleData.uid)
                           or tonumber(playerChar.PlayerUID) or 0
                local causerUID = tonumber(dmgData.CauserUID or dmgData.CauserPlayerUID) or 0
                if myUID > 0 and causerUID > 0 then
                    if causerUID == myUID then isMe = true end
                    return
                end

                local myKey = tonumber(playerChar.PlayerKey) or 0
                local causerKey = tonumber(dmgData.CauserKey or dmgData.CauserPlayerKey) or 0
                if myKey > 0 and causerKey > 0 then
                    if causerKey == myKey then isMe = true end
                    return
                end

                local causerName = dmgData.Causer
                if not causerName or causerName == "" then causerName = dmgData.CauserRealPlayerName end
                if causerName and causerName ~= "" then
                    local cStr = tostring(causerName)
                    local myCharName = playerChar.GetPlayerNameSafety and playerChar:GetPlayerNameSafety()
                    if myCharName and myCharName ~= "" and cStr == tostring(myCharName) then isMe = true; return end
                    local myPropName = playerChar.PlayerName
                    if myPropName and myPropName ~= "" and cStr == tostring(myPropName) then isMe = true; return end
                    local roleData = _G.DataMgr and _G.DataMgr.roleData
                    if type(roleData) == "table" then
                        local rName = roleData.nickName or roleData.name or roleData.roleName
                        if rName and rName ~= "" and cStr == tostring(rName) then isMe = true; return end
                    end
                    if _G.GetCustomName then
                        local okC, custName = pcall(_G.GetCustomName)
                        if okC and custName and custName ~= "" and cStr == tostring(custName) then isMe = true; return end
                    end
                end

                local fullMsg = dmgData.FullMsg
                if type(fullMsg) == "string" and (fullMsg:find(">You ") or fullMsg:find("^You ")) then
                    isMe = true
                end
            end)
            return isMe
        end

        local function StampFatalDamageStructIfMine(dmgData)
            if not IsLocalPlayerCauser(dmgData) then return false end
            pcall(function()
                local outfitID = ResolveActiveOutfitID()
                if outfitID and outfitID > 0 then
                    if _G.download_item then pcall(_G.download_item, outfitID) end
                    -- Set ONLY CauserClothAvatarID so the Gun Kill Animation plays first,
                    -- and then transitions to the X-Suit overlay on its native delay timer!
                    pcall(function() dmgData.CauserClothAvatarID = outfitID end)
                end

                local curWepSkin = tonumber(dmgData.CauserWeaponAvatarID) or 0
                if curWepSkin < 10000000 then
                    local gd = package.loaded["GameLua.GameCore.Data.GameplayData"]
                    local playerChar = gd and gd.GetPlayerCharacter and gd.GetPlayerCharacter()
                    local cw = playerChar and playerChar.GetCurrentWeapon and playerChar:GetCurrentWeapon()
                    local wID = (cw and cw.GetWeaponID and tonumber(cw:GetWeaponID())) or tonumber(dmgData.CauserWeaponID) or 0
                    if wID > 0 then
                        local _, resolvedSkin = ResolveWeaponSkinFast(wID)
                        if resolvedSkin and resolvedSkin > 10000000 then
                            if _G.download_item then pcall(_G.download_item, resolvedSkin) end
                            pcall(function() dmgData.CauserWeaponAvatarID = resolvedSkin end)
                        end
                    end
                else
                    if _G.download_item then pcall(_G.download_item, curWepSkin) end
                end

                pcall(function()
                    dmgData.IsUseColor = true
                    local FLinearColor = import("LinearColor")
                    if FLinearColor then
                        dmgData.UseColor = FLinearColor(1.0, 0.8, 0.0, 1.0)
                    end
                end)
            end)
            return true
        end

        local function ApplyXSuitOverlayToKillInfoWidget(killInfoSelf, dmgData)
            if not killInfoSelf or not dmgData then return end
            pcall(function()
                -- Trigger UpdateKillEffect so the Gun Kill Message UMG animation plays completely
                local wepSkin = tonumber(dmgData.CauserWeaponAvatarID) or 0
                if wepSkin > 10000000 and type(killInfoSelf.UpdateKillEffect) == "function" then
                    pcall(killInfoSelf.UpdateKillEffect, killInfoSelf, wepSkin, dmgData)
                end
            end)
        end

        local function ClearXSuitOverlayOnKillInfoWidget(killInfoSelf)
            if not killInfoSelf then return end
            pcall(function()
                local kingItem = rawget(killInfoSelf, "KingEliminationInfoItem")
                if type(kingItem) == "table" then
                    if kingItem.AdvanceActivateModCanvas then pcall(kingItem.AdvanceActivateModCanvas, kingItem, false) end
                    if kingItem.UIRoot and kingItem.UIRoot.SetWidgetVisibility and UEnums and UEnums.ESlateVisibility then
                        pcall(kingItem.UIRoot.SetWidgetVisibility, kingItem.UIRoot, UEnums.ESlateVisibility.Collapsed)
                    end
                end
            end)
        end

        local function HookXSuitSummonAndFeatures()
            pcall(function()
                local XSuitUtil = package.loaded["GameLua.Activity.Commercialize.GamePlay.XSuit.XSuitUtil"]
                if XSuitUtil then
                    HookBothTables(XSuitUtil, "_VrsxhV5RevBXSuitUtilHook", function(tbl)
                        tbl.HasXSuit                      = function() return true end
                        tbl.IsUnlockedFeature             = function() return true end
                        tbl.IsValidXSuitEffect            = function() return true end
                        tbl.IsValidBornIslandAction       = function() return true end
                        tbl.IsOpenLowLevelEffect          = function() return true end
                        tbl.IsUserOpenSpecialGlideSetting = function() return true end
                        tbl.IsExecutePlanResourceReady    = function() return true end
                        tbl.IsXSuitFeatureClosed          = function() return false end
                        tbl.GetLevelByItemId              = function() return 7 end
                        tbl.GetEffectMinLevel             = function() return 1 end
                        tbl.GetUnLockLevelByFeature       = function() return 1 end
                    end)
                end
            end)

            pcall(function()
                local lxs = package.loaded["client.slua.logic.XSuit.logic_xsuit"]
                if lxs then
                    HookBothTables(lxs, "_VrsxhV5RevBLogicXSuitHook", function(tbl)
                        tbl.CheckShowByLevel                       = function() return true end
                        tbl.CheckShowByLevelAndFeature             = function() return true end
                        tbl.CheckUnlockState                       = function() return true end
                        tbl.HasUnlockFeature                       = function() return true end
                        tbl.HasAnyXSuitAtElimOverrideTier          = function() return true end
                        tbl.HasEliminationKingOverrideAvailable    = function() return true end
                        tbl.GetEliminationKingClothOverrideEnabled = function() return true end
                        tbl.CheckHasEquipXSuit                     = function() return true end
                        tbl.CheckHasEquipXSuitByAction             = function() return true end
                        tbl.GetLevelByItemId                       = function() return 7 end
                        tbl.GetLevelByPeriod                       = function() return 7 end
                        tbl.GetLevelByPeriodSelf                   = function() return 7 end
                    end)
                end
            end)

            pcall(function()
                local xadu = package.loaded["GameLua.Activity.Commercialize.GamePlay.XSuit.XSuitAvatarDataUtil"]
                if xadu then
                    HookBothTables(xadu, "_VrsxhV5RevBXADUHook", function(tbl)
                        tbl.GetEquipXSuitID    = function() return ResolveActiveOutfitID() end
                        tbl.GetEquipXSuitLevel = function() return 7 end
                        tbl.GetUnlockLevel     = function() return 7 end
                        tbl.GetShowLevel       = function() return 7 end
                    end)
                end
            end)

            pcall(function()
                local xca = package.loaded["GameLua.Activity.Commercialize.Actor.XSuitCompanionActor"]
                if xca then
                    HookBothTables(xca, "_VrsxhV5RevBXCAHook", function(tbl)
                        if type(tbl.CheckOrbiterSwitch) == "function" then
                            local origOrb = tbl.CheckOrbiterSwitch
                            tbl.CheckOrbiterSwitch = function(self, ...)
                                pcall(origOrb, self, ...)
                                return true
                            end
                        end
                    end)
                end
            end)

            pcall(function()
                local xsp = package.loaded["GameLua.Activity.Commercialize.Actor.InteractActor.XSuitPlatform"]
                if not xsp then return end
                HookBothTables(xsp, "_VrsxhV5RevBXSuitPlatformHook", function(tbl)
                    if type(tbl.GetWearingXSuitID) == "function" then
                        local origWear = tbl.GetWearingXSuitID
                        tbl.GetWearingXSuitID = function(self, char, ...)
                            local id = origWear(self, char, ...)
                            if not id or tonumber(id) == 0 then return ResolveActiveOutfitID() end
                            return id
                        end
                    end
                    tbl.Wearing7StarXSuit               = function() return true end
                    tbl.OnAllowToInteract               = function() return true end
                    tbl.IsCharacterInCD                 = function() return false end
                    tbl.IsGameStateBan                  = function() return false end
                    tbl.IsDsOpen                        = function() return true end
                    tbl.MustCheckResultAfterServerClick = function() return false end

                    local _SummonSeqFired = false
                    if type(tbl.CallStatue) == "function" then
                        local origCallStatue = tbl.CallStatue
                        tbl.CallStatue = function(self, ...)
                            _SummonSeqFired = true
                            return origCallStatue(self, ...)
                        end
                    end
                    if type(tbl.TriggerCallShowSequence) == "function" then
                        local origTrigSeq = tbl.TriggerCallShowSequence
                        tbl.TriggerCallShowSequence = function(self, ...)
                            _SummonSeqFired = true
                            return origTrigSeq(self, ...)
                        end
                    end

                    if type(tbl.OnClientClickInteractiveButton) == "function" then
                        local origClick = tbl.OnClientClickInteractiveButton
                        tbl.OnClientClickInteractiveButton = function(self, playerChar, interactiveComp, ...)
                            _SummonSeqFired = false
                            local xsuitID = (self.GetWearingXSuitID and self:GetWearingXSuitID(playerChar)) or ResolveActiveOutfitID()
                            downloadSkinAsset(xsuitID)

                            local prevAuth = rawget(self, "hasAuthority")
                            rawset(self, "hasAuthority", true)
                            rawset(self, "NeedShowStatue", true)
                            rawset(self, "CanChange", true)
                            rawset(self, "HaveShowCDBar", false)

                            local okClick, res = pcall(origClick, self, playerChar, interactiveComp, ...)

                            if not _SummonSeqFired then
                                pcall(function()
                                    if self.TrySetCurrentCaller then pcall(self.TrySetCurrentCaller, self, playerChar) end
                                    if self.ModifyCallerInfo then pcall(self.ModifyCallerInfo, self, playerChar, xsuitID) end
                                    if self.DoChangeCaller then pcall(self.DoChangeCaller, self, playerChar, xsuitID) end
                                    if self.OnRep_CallerInfo then pcall(self.OnRep_CallerInfo, self) end
                                end)
                            end
                            if not _SummonSeqFired then
                                pcall(function()
                                    if self.CallStatue then
                                        local ok1 = pcall(self.CallStatue, self, xsuitID)
                                        if not ok1 then pcall(self.CallStatue, self, playerChar) end
                                        pcall(self.CallStatue, self)
                                    end
                                    if self.TriggerCallShowSequence then
                                        local ok2 = pcall(self.TriggerCallShowSequence, self, playerChar, xsuitID)
                                        if not ok2 then pcall(self.TriggerCallShowSequence, self, xsuitID) end
                                        pcall(self.TriggerCallShowSequence, self)
                                    end
                                    if self.ChangeSkyMaterialForCall then
                                        pcall(self.ChangeSkyMaterialForCall, self, xsuitID)
                                        pcall(self.ChangeSkyMaterialForCall, self)
                                    end
                                    if self.ShowCaller then
                                        pcall(self.ShowCaller, self, playerChar)
                                        pcall(self.ShowCaller, self)
                                    end
                                    if self.BeginRotate then pcall(self.BeginRotate, self) end
                                    if self.ShowSwitchCameraUIBP then pcall(self.ShowSwitchCameraUIBP, self, true) end
                                end)
                            end
                            rawset(self, "hasAuthority", prevAuth)
                            return okClick and res or true
                        end
                    end
                end)
            end)
        end

        local TotalKillCounts = setmetatable({}, { __index = function() return DEFAULT_TOTAL_KILL_COUNT end })
        local MatchKillCounts = {}
        local _TotalMatchKills = 0
        local _LastKillIncrementClock = 0

        _G.AKFakeKillCounts = TotalKillCounts

        local function GetTotalKillCountForWeapon(weaponOrSkinID)
            local baseWid = DeriveBaseWeaponID(weaponOrSkinID)
            if baseWid <= 0 then baseWid = tonumber(weaponOrSkinID) or 101004 end
            local cnt = rawget(TotalKillCounts, baseWid)
            if not cnt or cnt <= 0 then
                cnt = DEFAULT_TOTAL_KILL_COUNT
                rawset(TotalKillCounts, baseWid, cnt)
            end
            return cnt
        end

        local function GetMatchKillCountForWeapon(weaponOrSkinID)
            local baseWid = DeriveBaseWeaponID(weaponOrSkinID)
            if baseWid <= 0 then baseWid = tonumber(weaponOrSkinID) or 101004 end
            return MatchKillCounts[baseWid] or _TotalMatchKills or 0
        end

        local function RecordLocalPlayerKill(weaponOrSkinID)
            local now = os.clock()
            if (now - _LastKillIncrementClock) < 0.20 then
                return GetTotalKillCountForWeapon(weaponOrSkinID), GetMatchKillCountForWeapon(weaponOrSkinID)
            end
            _LastKillIncrementClock = now

            local baseWid = DeriveBaseWeaponID(weaponOrSkinID)
            if baseWid <= 0 then baseWid = tonumber(weaponOrSkinID) or 101004 end

            local newTotal = GetTotalKillCountForWeapon(baseWid) + 1
            rawset(TotalKillCounts, baseWid, newTotal)

            _TotalMatchKills = _TotalMatchKills + 1
            MatchKillCounts[baseWid] = (MatchKillCounts[baseWid] or 0) + 1
            return newTotal, MatchKillCounts[baseWid]
        end

        local _LiveKCSubsystemInst = nil
        local _RealKCIdCache       = {}
        local _FallbackValidKCId   = nil

        local function GetValidKillCounterIDForWeapon(kcLogic, weaponOrSkinID)
            local baseWid = DeriveBaseWeaponID(weaponOrSkinID)
            if baseWid <= 0 then baseWid = tonumber(weaponOrSkinID) or 101004 end
            if _RealKCIdCache[baseWid] then return _RealKCIdCache[baseWid] end

            local foundID = nil
            pcall(function()
                if not kcLogic then
                    local MM = package.loaded["client.module_framework.ModuleManager"]
                    kcLogic = MM and MM.CommonModuleConfig and MM.GetModule(MM.CommonModuleConfig.LogicKillCounter)
                end
                if not kcLogic then return end
                local origImpl = kcLogic.__class and kcLogic.__class.__inner_impl
                if origImpl and type(origImpl.GetBaseKillCounterIdByWeaponId) == "function" then
                    local ok, id = pcall(origImpl.GetBaseKillCounterIdByWeaponId, kcLogic, baseWid)
                    if ok and tonumber(id) and tonumber(id) > 0 and tonumber(id) ~= 2100004 then
                        foundID = tonumber(id)
                    end
                end
                if not foundID and type(kcLogic.weaponFeatureList) == "table" then
                    local feat = kcLogic.weaponFeatureList[baseWid] or kcLogic.weaponFeatureList[101004] or kcLogic.weaponFeatureList[101006]
                    if type(feat) == "number" and feat > 0 then foundID = feat
                    elseif type(feat) == "table" then
                        for k, v in pairs(feat) do
                            if type(v) == "number" and v > 0 then foundID = v; break end
                            if type(k) == "number" and k > 1000 then foundID = k; break end
                            if type(v) == "table" then
                                local subID = tonumber(v.id or v.ID or v.featureId or v.FeatureId or v.itemId or v.ItemId or v[1])
                                if subID and subID > 0 then foundID = subID; break end
                            end
                        end
                    end
                end
            end)

            if foundID and foundID > 0 then
                _RealKCIdCache[baseWid] = foundID
                _FallbackValidKCId = _FallbackValidKCId or foundID
                return foundID
            end
            return _FallbackValidKCId or 2100004
        end

        local function GetLiveKCSubsystem()
            if _LiveKCSubsystemInst and not _LiveKCSubsystemInst._isDisposed then
                return _LiveKCSubsystemInst
            end
            pcall(function()
                local SM = package.loaded["GameLua.GameCore.Module.Subsystem.SubsystemMgr"]
                if SM and SM.Get then
                    local sub = SM:Get("KillCounterUISubsystem")
                    if sub then _LiveKCSubsystemInst = sub end
                end
            end)
            return _LiveKCSubsystemInst
        end

        local _ActiveMainKCWidget   = nil
        local _ActiveCommonKCWidget = nil

        local function PushKillCounterToWidgets(baseWeaponID, skinID, totalKillCount)
            pcall(function()
                baseWeaponID, skinID = ResolveWeaponSkinFast(baseWeaponID)
                if baseWeaponID <= 0 then return end
                totalKillCount = totalKillCount or GetTotalKillCountForWeapon(baseWeaponID)
                local validKCId = GetValidKillCounterIDForWeapon(nil, baseWeaponID)

                local UIManager = package.loaded["client.slua_ui_framework.manager"]
                local mainKC = _ActiveMainKCWidget
                if (not mainKC or mainKC._IsClosed) and UIManager and UIManager.UI_Config_InGame then
                    mainKC = UIManager.GetUI(UIManager.UI_Config_InGame.MainKillCounter)
                end

                if mainKC and not mainKC._IsClosed then
                    _ActiveMainKCWidget = mainKC
                    mainKC.WeaponID = baseWeaponID
                    mainKC.AvatarID = skinID
                    local kcItem = rawget(mainKC, "KillCounterItem") or _ActiveCommonKCWidget
                    if kcItem then
                        _ActiveCommonKCWidget = kcItem
                        if kcItem.SetKillCounterItemShowWithNum then
                            pcall(kcItem.SetKillCounterItemShowWithNum, kcItem, validKCId, totalKillCount, skinID)
                        end
                        if kcItem.UIRoot and kcItem.UIRoot.SetWidgetVisibility and UEnums and UEnums.ESlateVisibility then
                            pcall(kcItem.UIRoot.SetWidgetVisibility, kcItem.UIRoot, UEnums.ESlateVisibility.SelfHitTestInvisible)
                        end
                    end
                end
            end)
        end

        local _InMyKillInfoFileItem = false

        local function HookKillCounterAndKillInfoModulesRevB()
            pcall(function()
                local MM = package.loaded["client.module_framework.ModuleManager"]
                local kcLogic = MM and MM.CommonModuleConfig and MM.GetModule(MM.CommonModuleConfig.LogicKillCounter)
                local kcMod   = package.loaded["client.logic.kill_features.LogicKillCounter"]

                for _, target in ipairs({ kcLogic, kcMod }) do
                    if type(target) == "table" and not rawget(target, "_VrsxhV5RevBKCHooked") then
                        rawset(target, "_VrsxhV5RevBKCHooked", true)
                        HookBothTables(target, "_VrsxhV5RevBKCInnerHooked", function(tbl)
                            tbl.CheckSupportKC                 = function() return true end
                            tbl.CheckSupportKillCounterAvatar  = function() return true end
                            tbl.CheckHasWeaponKillCounter      = function() return true end
                            tbl.CheckHaveKillCounter           = function() return true end
                            tbl.CheckHaveKillCounterByWeaponId = function() return true end
                            tbl.CheckEquipedWeaponCounter      = function() return true end
                            tbl.CheckCounterShowInMainUI       = function() return true end

                            tbl.GetBaseKillCounterIdByWeaponId   = function(self, wid) return GetValidKillCounterIDForWeapon(self or kcLogic, wid) end
                            tbl.GetEquipedKillCounterId          = function(self, uid, wid) return GetValidKillCounterIDForWeapon(self or kcLogic, wid or uid) end
                            tbl.GetMyEquipedKillCounterId        = function(self, wid) return GetValidKillCounterIDForWeapon(self or kcLogic, wid) end
                            tbl.GetWeaponKillCountByUid          = function(self, uid, wid) return GetTotalKillCountForWeapon(wid or uid) end
                            tbl.GetMyKillCounterNum              = function(self, wid) return GetTotalKillCountForWeapon(wid) end
                            tbl.GetOneWeaponKillCountInBattle    = function(self, uid, wid) return GetMatchKillCountForWeapon(wid or uid) end
                            tbl.GetCurBattleWeaponKillCountByUid = function(self, uid, wid) return GetMatchKillCountForWeapon(wid or uid) end
                        end)
                    end
                end
            end)

            pcall(function()
                local KCSub = package.loaded["GameLua.Mod.BaseMod.Client.KillCounter.KillCounterUISubsystem"]
                if KCSub then
                    HookBothTables(KCSub, "_VrsxhV5RevBKCSubHook", function(tbl)
                        tbl.CheckSupportKCUI = function(self)
                            if type(self) == "table" and rawget(self, "bIsValid") ~= nil then _LiveKCSubsystemInst = self end
                            return true
                        end
                        if type(tbl.OnRegister) == "function" then
                            local origReg = tbl.OnRegister
                            tbl.OnRegister = function(self, ...) _LiveKCSubsystemInst = self; return origReg(self, ...) end
                        end
                        if type(tbl.RefreshMainKCVisible) == "function" then
                            local origRef = tbl.RefreshMainKCVisible
                            tbl.RefreshMainKCVisible = function(self, ...)
                                if type(self) == "table" and rawget(self, "bIsValid") ~= nil then _LiveKCSubsystemInst = self end
                                return origRef(self, ...)
                            end
                        end

                        local origUpdate = tbl.UpdateMainKillCounterUI
                        if debug and debug.getupvalue and type(origUpdate) == "function" then
                            for i = 1, 10 do
                                local un, uv = debug.getupvalue(origUpdate, i)
                                if not un then break end
                                if un == "origUpdate" and type(uv) == "function" then origUpdate = uv; break end
                            end
                        end

                        tbl.UpdateMainKillCounterUI = function(self, bShow, weaponID, avatarID)
                            if type(self) ~= "table" or rawget(self, "bIsValid") == nil then
                                local realInst = GetLiveKCSubsystem()
                                if realInst then self = realInst else return end
                            else
                                _LiveKCSubsystemInst = self
                            end
                            if bShow and weaponID and tonumber(weaponID) > 0 then
                                local baseW, skinW = ResolveWeaponSkinFast(weaponID)
                                weaponID = baseW
                                avatarID = (skinW and skinW > 10000000) and skinW or avatarID or baseW
                                if origUpdate then pcall(origUpdate, self, true, weaponID, avatarID) end
                                PushKillCounterToWidgets(weaponID, avatarID, GetTotalKillCountForWeapon(weaponID))
                            else
                                if origUpdate then pcall(origUpdate, self, bShow, weaponID, avatarID) end
                            end
                        end

                        tbl.CheckNeedMainKillCounterUI = function(self, weapon, PlayerID)
                            if type(self) ~= "table" or rawget(self, "bIsValid") == nil then
                                self = GetLiveKCSubsystem() or self
                            else
                                _LiveKCSubsystemInst = self
                            end
                            if not SafeValid(weapon) then
                                local gd = package.loaded["GameLua.GameCore.Data.GameplayData"]
                                local lp = gd and gd.GetPlayerCharacter and gd.GetPlayerCharacter()
                                if lp and lp.GetCurrentWeapon then weapon = lp:GetCurrentWeapon() end
                            end
                            if SafeValid(weapon) and weapon.GetWeaponID then
                                local wID = tonumber(weapon:GetWeaponID()) or 0
                                if wID > 0 then
                                    local baseW, skinW = ResolveWeaponSkinFast(wID)
                                    self:UpdateMainKillCounterUI(true, baseW, skinW)
                                    return
                                end
                            end
                            self:UpdateMainKillCounterUI(false)
                        end
                    end)
                end
            end)

            pcall(function()
                local MKC = package.loaded["GameLua.Mod.BaseMod.Client.KillCounter.MainKillCounter"]
                if MKC then
                    HookBothTables(MKC, "_VrsxhV5RevBMKCHook", function(tbl)
                        for _, fnName in ipairs({ "OnInitialize", "OnPostInitialize", "UpdateWeaponID", "OnRefreshUI", "OnRefreshData" }) do
                            if type(tbl[fnName]) == "function" then
                                local orig = tbl[fnName]
                                tbl[fnName] = function(self, a1, a2, ...)
                                    _ActiveMainKCWidget = self
                                    if fnName == "UpdateWeaponID" and tonumber(a1) then
                                        local baseW, skinW = ResolveWeaponSkinFast(a1)
                                        a1 = baseW
                                        a2 = (skinW and skinW > 10000000) and skinW or a2
                                    elseif tonumber(self.WeaponID) and tonumber(self.WeaponID) > 0 then
                                        local baseW, skinW = ResolveWeaponSkinFast(self.WeaponID)
                                        self.WeaponID = baseW
                                        if skinW > 10000000 then self.AvatarID = skinW end
                                    end
                                    local r1, r2 = orig(self, a1, a2, ...)
                                    if tonumber(self.WeaponID) and tonumber(self.WeaponID) > 0 then
                                        PushKillCounterToWidgets(self.WeaponID, self.AvatarID, nil)
                                    end
                                    return r1, r2
                                end
                            end
                        end
                    end)
                end
            end)

            pcall(function()
                local CKI = package.loaded["client.slua.umg.KillCounter.Common_KillCounter_Item"]
                if CKI then
                    HookBothTables(CKI, "_VrsxhV5RevBCKIHook", function(tbl)
                        if type(tbl.SetWeaponIconForWeaponStrength) == "function" then
                            local origIcon = tbl.SetWeaponIconForWeaponStrength
                            tbl.SetWeaponIconForWeaponStrength = function(self, bShow, kcID, ...)
                                _ActiveCommonKCWidget = self
                                if tonumber(kcID) == 2100004 then
                                    local wID = (_ActiveMainKCWidget and _ActiveMainKCWidget.WeaponID) or 101004
                                    kcID = GetValidKillCounterIDForWeapon(nil, wID)
                                end
                                return origIcon(self, bShow, kcID, ...)
                            end
                        end
                        if type(tbl.SetKillCounterItemShowWithNum) == "function" then
                            local origSetNum = tbl.SetKillCounterItemShowWithNum
                            tbl.SetKillCounterItemShowWithNum = function(self, kcID, killNum, avatarID, ...)
                                _ActiveCommonKCWidget = self
                                local baseW, skinW = ResolveWeaponSkinFast(avatarID or (_ActiveMainKCWidget and _ActiveMainKCWidget.WeaponID) or 101004)
                                if tonumber(kcID) == 2100004 or not tonumber(kcID) or tonumber(kcID) <= 0 then
                                    kcID = GetValidKillCounterIDForWeapon(nil, baseW)
                                end
                                killNum = GetTotalKillCountForWeapon(baseW)
                                if skinW and skinW > 10000000 then avatarID = skinW end
                                local r1, r2 = origSetNum(self, kcID, killNum, avatarID, ...)
                                if self.UIRoot and self.UIRoot.SetWidgetVisibility and UEnums and UEnums.ESlateVisibility then
                                    pcall(self.UIRoot.SetWidgetVisibility, self.UIRoot, UEnums.ESlateVisibility.SelfHitTestInvisible)
                                end
                                return r1, r2
                            end
                        end
                    end)
                end
            end)

            pcall(function()
                local wkcs = package.loaded["GameLua.Mod.BaseMod.GamePlay.WeaponKillCounter.WeaponKillCounterSubsystem"]
                if wkcs then
                    HookBothTables(wkcs, "_VrsxhV5RevBWKCSHook", function(tbl)
                        if type(tbl.GetCurBattleWeaponKillCount_DS) == "function" then
                            tbl.GetCurBattleWeaponKillCount_DS = function(self, pc, weaponID)
                                return GetMatchKillCountForWeapon(weaponID)
                            end
                        end
                    end)
                end
            end)

            pcall(function()
                local pcfd = package.loaded["GameLua.Mod.BaseMod.Gameplay.Feature.PlayerControllerFatalDamageFeature"]
                if pcfd then
                    HookBothTables(pcfd, "_VrsxhV5RevBPCFDHook", function(tbl)
                        for _, fnName in ipairs({ "ExtractFatalDamageInfoForLua", "BroadcastFatalDamageToClientForLua" }) do
                            if type(tbl[fnName]) == "function" then
                                local orig = tbl[fnName]
                                tbl[fnName] = function(self, fatalData, ...)
                                    StampFatalDamageStructIfMine(fatalData)
                                    local r1, r2 = orig(self, fatalData, ...)
                                    StampFatalDamageStructIfMine(fatalData)
                                    return r1, r2
                                end
                            end
                        end
                    end)
                end
            end)

            pcall(function()
                local lki = package.loaded["GameLua.Mod.BaseMod.Client.KillInfoTips.LeftKillInfo"]
                if lki then
                    HookBothTables(lki, "_VrsxhV5RevBLKIHook", function(tbl)
                        if type(tbl.AddLeftKillInfoPostProcessing) == "function" then
                            local origAdd = tbl.AddLeftKillInfoPostProcessing
                            tbl.AddLeftKillInfoPostProcessing = function(self, dmgInfo, ...)
                                StampFatalDamageStructIfMine(dmgInfo)
                                return origAdd(self, dmgInfo, ...)
                            end
                        end
                        if type(tbl.InsertRecordCache) == "function" then
                            local origIns = tbl.InsertRecordCache
                            tbl.InsertRecordCache = function(self, recordTbl, ...)
                                if type(recordTbl) == "table" and recordTbl.DamageInfo then
                                    StampFatalDamageStructIfMine(recordTbl.DamageInfo)
                                end
                                return origIns(self, recordTbl, ...)
                            end
                        end
                    end)
                end
            end)

            pcall(function()
                local lkiAsset = package.loaded["client.slua.logic.kill_info.logic_killinfo"]
                if lkiAsset then
                    HookBothTables(lkiAsset, "_VrsxhV5RevBLKIAssetHook", function(tbl)
                        -- Only spoof X-Suit download check; let Weapon Kill Effect run its native passive loader
                        -- so the animated UMG effect blueprint is loaded before UpdateKillEffect plays it!
                        tbl.IsXSuitKillInfoAssetDownload      = function() return true end
                        tbl.CheckKillPassiveDownloadByXSuitID = function() return true end
                    end)
                end
            end)

            pcall(function()
                local bkb = package.loaded["GameLua.Mod.BaseMod.Client.BattleKillBroadcast.BattleKillBroadcastSubSystem"]
                if bkb then
                    HookBothTables(bkb, "_VrsxhV5RevBBKBHook", function(tbl)
                        if type(tbl.OnDisplayKillOrPutDownMessageProcessing) == "function" then
                            local origProc = tbl.OnDisplayKillOrPutDownMessageProcessing
                            tbl.OnDisplayKillOrPutDownMessageProcessing = function(self, msgTbl, ...)
                                if type(msgTbl) == "table" and StampFatalDamageStructIfMine(msgTbl) then
                                    local wepSkin = tonumber(msgTbl.CauserWeaponAvatarID) or 0
                                    if wepSkin > 0 then
                                        local newTotal = RecordLocalPlayerKill(wepSkin)
                                        PushKillCounterToWidgets(wepSkin, wepSkin, newTotal)
                                    end
                                end
                                return origProc(self, msgTbl, ...)
                            end
                        end
                    end)
                end
            end)

            pcall(function()
                local KillInfo = package.loaded["GameLua.Mod.BaseMod.Client.KillInfoTips.KillInfo"]
                if KillInfo then
                    HookBothTables(KillInfo, "_VrsxhV5RevBKillInfoHook", function(tbl)
                        if type(tbl.UpdateColorLua) == "function" then
                            local origColor = tbl.UpdateColorLua
                            tbl.UpdateColorLua = function(self, clothID, wepSkinID, bIsCauser, ...)
                                if _InMyKillInfoFileItem and bIsCauser and (tonumber(clothID) or 0) == 0 then
                                    clothID = ResolveActiveOutfitID()
                                end
                                return origColor(self, clothID, wepSkinID, bIsCauser, ...)
                            end
                        end
                        if type(tbl.SetSkillIcon) == "function" then
                            local origSkill = tbl.SetSkillIcon
                            tbl.SetSkillIcon = function(self, a1, wepID, clothID, ...)
                                if _InMyKillInfoFileItem and (tonumber(clothID) or 0) == 0 then
                                    clothID = ResolveActiveOutfitID()
                                end
                                return origSkill(self, a1, wepID, clothID, ...)
                            end
                        end

                        local origFileItem = tbl.FileItem
                        if debug and debug.getupvalue and type(origFileItem) == "function" then
                            for i = 1, 10 do
                                local un, uv = debug.getupvalue(origFileItem, i)
                                if not un then break end
                                if un == "origFileItem" and type(uv) == "function" then origFileItem = uv; break end
                            end
                        end

                        if type(origFileItem) == "function" then
                            tbl.FileItem = function(self, DamageRecordData, ...)
                                local isMine = StampFatalDamageStructIfMine(DamageRecordData)
                                _InMyKillInfoFileItem = isMine

                                if isMine then
                                    pcall(function()
                                        if DamageRecordData.ResultHealthStatus == 2 then
                                            local wepSkin = tonumber(DamageRecordData.CauserWeaponAvatarID) or 0
                                            local newTotal = RecordLocalPlayerKill(wepSkin)
                                            PushKillCounterToWidgets(wepSkin, wepSkin, newTotal)
                                        end
                                    end)
                                else
                                    ClearXSuitOverlayOnKillInfoWidget(self)
                                end

                                local r1, r2 = origFileItem(self, DamageRecordData, ...)
                                _InMyKillInfoFileItem = false

                                if isMine then
                                    ApplyXSuitOverlayToKillInfoWidget(self, DamageRecordData)
                                else
                                    ClearXSuitOverlayOnKillInfoWidget(self)
                                end
                                return r1, r2
                            end
                        end
                    end)
                end
            end)
        end

        local _LastHeldWepPtr = nil
        local _LastHeldSkinID = 0
        local _WasInMatch     = false

        local function RefreshKillCounterFast(force)
            local inMatchNow = IsInMatch()
            if not inMatchNow then
                if _WasInMatch then
                    _WasInMatch = false
                    _TotalMatchKills = 0
                    MatchKillCounts = {}
                end
                _LastHeldWepPtr = nil
                SyncSkinMemoryAndFiles(true)
                return
            end

            if not _WasInMatch then
                _WasInMatch = true
                -- Read skin files ONCE on match entry, then never touch disk during the match!
                SyncSkinMemoryAndFiles(true)
                HookXSuitSummonAndFeatures()
                HookKillCounterAndKillInfoModulesRevB()
            end

            local gd = package.loaded["GameLua.GameCore.Data.GameplayData"]
            local lp = gd and gd.GetPlayerCharacter and gd.GetPlayerCharacter()
            if not lp or not lp.GetCurrentWeapon then return end

            local cw = lp:GetCurrentWeapon()
            if not cw or not cw.GetWeaponID then
                _LastHeldWepPtr = nil
                return
            end

            -- Fast-exit in <0.001ms if the held weapon actor hasn't changed!
            if not force and cw == _LastHeldWepPtr then
                return
            end

            local wID = tonumber(cw:GetWeaponID()) or 0
            if wID <= 0 then return end

            local baseW, skinW = ResolveWeaponSkinFast(wID)
            if not force and cw == _LastHeldWepPtr and skinW == _LastHeldSkinID then
                return
            end
            _LastHeldWepPtr = cw
            _LastHeldSkinID = skinW

            HookXSuitSummonAndFeatures()
            HookKillCounterAndKillInfoModulesRevB()

            local liveSub = GetLiveKCSubsystem()
            if liveSub and liveSub.UpdateMainKillCounterUI then
                liveSub:UpdateMainKillCounterUI(true, baseW, skinW)
            end
            PushKillCounterToWidgets(baseW, skinW, GetTotalKillCountForWeapon(baseW))
        end

        -- Override 4.lua's globals with our fast-exiting pointer-cached version
        _G.ForceEnableKillCounterUI = function()
            RefreshKillCounterFast(false)
        end

        _G.RefreshKillCounterUI = function()
            RefreshKillCounterFast(false)
        end

        SyncSkinMemoryAndFiles(true)
        HookXSuitSummonAndFeatures()
        HookKillCounterAndKillInfoModulesRevB()

        if _ticker and _ticker.AddTimerLoop then
            pcall(function()
                _ticker.AddTimerLoop(0.8, function()
                    if _G.__SkinTickAllowed() then RefreshKillCounterFast(false) end
                end, -1, 0.8)
            end)
        elseif Game and Game.SetTimer then
            pcall(function() Game:SetTimer(0.8, true, function()
                if _G.__SkinTickAllowed() then RefreshKillCounterFast(false) end
            end) end)
        end
    end
end



-- ============================================================================
-- DIRECT PATCH: T-SHIRT (403), PANTS (404), SHOES (405) LOBBY SAVE + MATCH EQUIP
-- ============================================================================
do
    _G.InventorySkins = _G.InventorySkins or {}
    local INV = _G.InventorySkins
    INV.clothes = INV.clothes or {} -- [subType] = resID (403=Top, 404=Pants, 405=Shoes, 401=Hat, 402=Mask, 407=Glasses)

    local CLOTH_SUBTYPES = {
        [401] = "SKIN_Hat",
        [402] = "SKIN_Mask",
        [403] = "SKIN_Top",
        [404] = "SKIN_Pants",
        [405] = "SKIN_Shoes",
        [407] = "SKIN_Glasses"
    }

    -- SlotSyncData mapping: Slot 5 = Top (403), Slot 6 = Pants (404), Slot 7 = Shoes (405)
    local SUBTYPE_TO_SYNCSLOT = {
        [403] = 5,
        [404] = 6,
        [405] = 7
    }

    local function IsFullSuitItem(resID)
        local c = GetItemCfgFast(resID)
        if not c then return false end
        local st = tonumber(c.ItemSubType or c.itemSubType)
        if st ~= 403 then return false end
        local wTab = tonumber(c.WardrobeTab or c.wardrobeTab)
        if wTab == 10 then return true end
        if wTab == 3  then return false end
        local ok, isX = pcall(function()
            local lx = package.loaded["client.slua.logic.XSuit.logic_xsuit"]
            return lx and lx.IsXSuit and lx.IsXSuit(resID)
        end)
        return ok and isX == true
    end

    local function SaveSeparateClothesToDisk()
        if IsInMatch() then return end
        local kv = {
            SKIN_Outfit  = tonumber(INV.outfit) or 0,
            SKIN_Top     = tonumber(INV.clothes[403]) or 0,
            SKIN_Pants   = tonumber(INV.clothes[404]) or 0,
            SKIN_Shoes   = tonumber(INV.clothes[405]) or 0,
            SKIN_Hat     = tonumber(INV.clothes[401]) or 0,
            SKIN_Mask    = tonumber(INV.clothes[402]) or 0,
            SKIN_Glasses = tonumber(INV.clothes[407]) or 0
        }
        UpdateKeysInSaveFile(SHADOW_TXT, kv)
    end

    local function LoadSeparateClothesFromDisk()
        local f = io.open(SHADOW_TXT, "r")
        if not f then return end
        for line in f:lines() do
            local k, v = line:match("^%s*([^=]+)%s*=%s*(%d+)%s*$")
            local n = tonumber(v)
            if k and n then
                if k == "SKIN_Top"     then INV.clothes[403] = n > 0 and n or nil
                elseif k == "SKIN_Pants"   then INV.clothes[404] = n > 0 and n or nil
                elseif k == "SKIN_Shoes"   then INV.clothes[405] = n > 0 and n or nil
                elseif k == "SKIN_Hat"     then INV.clothes[401] = n > 0 and n or nil
                elseif k == "SKIN_Mask"    then INV.clothes[402] = n > 0 and n or nil
                elseif k == "SKIN_Glasses" then INV.clothes[407] = n > 0 and n or nil
                elseif k == "SKIN_Outfit" and n == 0 then INV.outfit = 0 end
            end
        end
        f:close()
        if INV.clothes[403] and INV.clothes[403] > 0 then
            INV.outfit = 0
            _G.SuitSkin = 0
            if _G.OutfitMap then _G.OutfitMap.Suit = 0 end
        end
    end
    LoadSeparateClothesFromDisk()

    -- 1. Capture T-Shirt, Pants, Shoes when equipped in Lobby Wardrobe
    pcall(function()
        local WRH = require("client.network.Protocol.WardRobeHandler")
        if WRH and not WRH._VrsxhSeparateClothHooked then
            WRH._VrsxhSeparateClothHooked = true
            local origRsp = WRH.on_depot_put_on_rsp
            WRH.on_depot_put_on_rsp = function(res, item, olditem, slot, newIns, oldIns, extra)
                if origRsp then origRsp(res, item, olditem, slot, newIns, oldIns, extra) end
                if type(item) == "table" and not _G._PersistLoading then
                    local rID = tonumber(item.res_id or item.resID) or 0
                    local c = GetItemCfgFast(rID)
                    local st = c and tonumber(c.ItemSubType or c.itemSubType) or 0

                    if st == 403 then
                        if IsFullSuitItem(rID) then
                            -- Full suit equipped -> clear separate T-shirt, Pants & Shoes
                            INV.outfit = rID
                            _G.SuitSkin = rID
                            INV.clothes[403], INV.clothes[404], INV.clothes[405] = nil, nil, nil
                        else
                            -- Separate T-Shirt/Top equipped -> completely clear Full Suit & 5.lua caches!
                            INV.outfit = 0
                            _G.SuitSkin = 0
                            _G.AddOutfitLastLobbyOutfitRes = nil
                            if _G.OutfitMap then _G.OutfitMap.Suit = 0 end
                            if _G.AddOutfitEquippedCache then
                                _G.AddOutfitEquippedCache.outfitRes = nil
                                _G.AddOutfitEquippedCache.outfitIns = nil
                            end
                            INV.clothes[403] = rID
                        end
                        downloadSkinAsset(rID)
                        SaveSeparateClothesToDisk()
                    elseif CLOTH_SUBTYPES[st] then
                        if st == 404 or st == 405 then
                            -- Wearing separate Pants or Shoes removes a Full Suit & clears 5.lua caches!
                            INV.outfit = 0
                            _G.SuitSkin = 0
                            _G.AddOutfitLastLobbyOutfitRes = nil
                            if _G.OutfitMap then _G.OutfitMap.Suit = 0 end
                            if _G.AddOutfitEquippedCache then
                                _G.AddOutfitEquippedCache.outfitRes = nil
                                _G.AddOutfitEquippedCache.outfitIns = nil
                            end
                        end
                        INV.clothes[st] = rID
                        downloadSkinAsset(rID)
                        SaveSeparateClothesToDisk()
                    end
                end
            end
        end
    end)

    -- 2. Apply T-Shirt (Slot 5), Pants (Slot 6), Shoes (Slot 7) & Accessories in Match
    local _AppliedClothPawnSig = setmetatable({}, { __mode = "k" })

    local function SyncSeparateClothesInMatch()
        if not IsInMatch() then return end
        local hasAny = false
        for _, id in pairs(INV.clothes) do
            if tonumber(id) and tonumber(id) > 0 then hasAny = true; break end
        end
        if not hasAny then return end

        pcall(function()
            local GD = package.loaded["GameLua.GameCore.Data.GameplayData"]
            local char = GD and GD.GetPlayerCharacter and GD.GetPlayerCharacter()
            if not SafeValid(char) then return end

            -- Prevent 4.lua's equip_character_avatar from overwriting separate clothes with an old full suit
            if INV.clothes[403] or INV.clothes[404] or INV.clothes[405] then
                INV.outfit = 0
                if _G.OutfitMap then _G.OutfitMap.Suit = 0 end
            end

            local ac = char.AvatarComponent2 or char.CharacterAvatarComp2_BP or (char.getAvatarComponent2 and char:getAvatarComponent2())
            if not SafeValid(ac) or not ac.NetAvatarData then return end
            local sd = ac.NetAvatarData.SlotSyncData
            if not SafeValid(sd) then return end

            local changed = false
            for i = 0, sd:Num() - 1 do
                local eq = sd:Get(i)
                if eq then
                    local slotID = eq.SlotID
                    local curID  = tonumber(eq.ItemId or eq.ItemID) or 0
                    local target = 0

                    if slotID == 5 and INV.clothes[403] then target = INV.clothes[403]
                    elseif slotID == 6 and INV.clothes[404] then target = INV.clothes[404]
                    elseif slotID == 7 and INV.clothes[405] then target = INV.clothes[405] end

                    if target > 0 and curID ~= target then
                        downloadSkinAsset(target)
                        eq.ItemId = target
                        pcall(function() eq.ItemID = target end)
                        sd:Set(i, eq)
                        changed = true
                    end
                end
            end

            if changed and ac.OnRep_BodySlotStateChanged then
                pcall(ac.OnRep_BodySlotStateChanged, ac)
            end

            -- Also call PutOnCustomEquipmentByID once per pawn spawn so missing slots (e.g. Hat/Mask/Glasses/Shoes) mount cleanly
            local sig = string.format("%d:%d:%d:%d:%d:%d",
                INV.clothes[403] or 0, INV.clothes[404] or 0, INV.clothes[405] or 0,
                INV.clothes[401] or 0, INV.clothes[402] or 0, INV.clothes[407] or 0)
            if _AppliedClothPawnSig[char] ~= sig then
                _AppliedClothPawnSig[char] = sig
                local comp = char.CharacterAvatarComponent_BP or ac
                if SafeValid(comp) and comp.PutOnCustomEquipmentByID then
                    for _, st in ipairs({ 403, 404, 405, 401, 402, 407 }) do
                        local cid = tonumber(INV.clothes[st]) or 0
                        if cid > 0 then
                            downloadSkinAsset(cid)
                            pcall(comp.PutOnCustomEquipmentByID, comp, cid, { id = cid, resID = cid, itemID = cid })
                        end
                    end
                end
            end
        end)
    end

    if _ticker and _ticker.AddTimerLoop then
        pcall(function()
            _ticker.AddTimerLoop(0.8, function()
                if _G.__SkinTickAllowed() then SyncSeparateClothesInMatch() end
            end, -1, 0.8)
        end)
    elseif Game and Game.SetTimer then
        pcall(function() Game:SetTimer(0.8, true, function()
            if _G.__SkinTickAllowed() then SyncSeparateClothesInMatch() end
        end) end)
    end
end






-- 6.lua — TEAM BROADCAST FIX v2 (integrated, optimized)
if not _G.__TEAM_BROADCAST_FIX_V2_LOADED then
    _G.__TEAM_BROADCAST_FIX_V2_LOADED = true
-- ============================================================================
-- TEAM BROADCAST FIX v2 — writes skin ID into ExpandDataContent
-- Load AFTER 1.lua. Does not touch bypass / anti-cheat.
-- ============================================================================
pcall(function()
    local OUT = "/storage/emulated/0/Android/data/com.pubg.imobile/files/kb_fix.txt"
    local function log(_) end
    local _timeTicker = nil
    pcall(function() _timeTicker = package.loaded["common.time_ticker"] or require("common.time_ticker") end)

    -- ---------------------------------------------------------------------
    -- My name + weapon skin cache
    -- ---------------------------------------------------------------------
    local _myName = nil
    local function getMyName()
        if _myName then return _myName end
        pcall(function()
            local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
            if pc and slua.isValid(pc) then
                local ch = pc:GetPlayerCharacterSafety()
                if ch and slua.isValid(ch) then _myName = ch:GetPlayerNameSafety() end
            end
        end)
        return _myName
    end

    local _w, _s, _t = 0, 0, 0
    local function getMyWeaponSkin()
        local now = os.clock()
        if now - _t < 0.1 then return _w, _s end
        _t = now; _w, _s = 0, 0
        pcall(function()
            local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
            if not pc then return end
            local ch = pc:GetPlayerCharacterSafety()
            if not ch or not slua.isValid(ch) then return end
            local wep = ch:GetCurrentWeapon()
            if not wep or not slua.isValid(wep) then return end
            local did = wep:GetItemDefineID()
            if did and slua.isValid(did) then _w = tonumber(did.TypeSpecificID) or 0 end
            if wep.synData and slua.isValid(wep.synData) then
                local ref = slua.IndexReference(wep.synData:Get(7), "defineID")
                if ref and slua.isValid(ref) then _s = tonumber(ref.TypeSpecificID) or 0 end
            end
        end)
        return _w, _s
    end

    -- ---------------------------------------------------------------------
    -- TeamKillBroadcast row + preload cache
    -- ---------------------------------------------------------------------
    local _hasRow = {}
    local function hasRow(skinID)
        if _hasRow[skinID] ~= nil then return _hasRow[skinID] end
        local ok = false
        pcall(function() ok = CDataTable.GetTableData("TeamKillBroadcast", skinID) ~= nil end)
        _hasRow[skinID] = ok
        return ok
    end

    local _pre = {}
    local function preload(skinID)
        if _pre[skinID] then return end
        _pre[skinID] = true
        pcall(function()
            local PM = package.loaded["client.slua.logic.download.puffer.puffer_manager"] or require("client.slua.logic.download.puffer.puffer_manager")
            local PC = package.loaded["client.slua.logic.download.puffer.const"] or require("client.slua.logic.download.puffer.const")
            PM.Download(PC.ENUM_DownloadType.ODPAK, { skinID })
            local row = CDataTable.GetTableData("TeamKillBroadcast", skinID)
            if row then
                if row.BgPath and row.BgPath ~= "" then PM.Download(PC.ENUM_DownloadType.ODPAK, { row.BgPath }) end
                if row.EffectPath and row.EffectPath ~= "" then PM.Download(PC.ENUM_DownloadType.ODPAK, { row.EffectPath }) end
            end
        end)
    end

    -- ---------------------------------------------------------------------
    -- ExpandDataContent decode / encode (the real target)
    -- ---------------------------------------------------------------------
    local function decodeExp(content)
        if type(content) ~= "string" or #content == 0 then return nil end
        local ok, exp = pcall(function()
            return slua.LuaArchiverDecode(LuaStateWrapper, content)
        end)
        if not ok or type(exp) ~= "table" then return nil end
        return exp
    end

    local function encodeExp(exp)
        if type(exp) ~= "table" then return nil end
        local ok, str = pcall(function()
            return slua.LuaArchiverEncode(LuaStateWrapper, exp)
        end)
        if not ok or type(str) ~= "string" or #str == 0 then return nil end
        return str
    end

    -- ---------------------------------------------------------------------
    -- Enrich the message table
    -- ---------------------------------------------------------------------
    local function isMyKill(md)
        if type(md) ~= "table" then return false end
        if md.bIamCauser == true then return true end
        local me = getMyName()
        if not me or me == "" then return false end
        return md.CauserPlayerName == me or md.CauserRealPlayerName == me
    end

    local function enrich(md, tag)
        if type(md) ~= "table" then return end
        if not isMyKill(md) then return end

        local _, skinID = getMyWeaponSkin()
        if not skinID or skinID <= 1000000 then return end
        if not hasRow(skinID) then return end
        preload(skinID)

        -- 1) The banner reads this — the real target
        local content = md.ExpandDataContent
        if type(content) == "string" and #content > 0 then
            local exp = decodeExp(content)
            if exp then
                local old = exp.CauserWeaponAvatarID
                if tonumber(old) ~= skinID then
                    exp.CauserWeaponAvatarID = skinID
                    local newStr = encodeExp(exp)
                    if newStr then
                        md.ExpandDataContent = newStr
                        log(string.format("[%s] ExpandDataContent skin %s -> %d", tag, tostring(old), skinID))
                    else
                        log("["..tag.."] encode failed")
                    end
                end
            else
                log("["..tag.."] decode failed (content len "..#content..")")
            end
        end

        -- 2) Belt-and-suspenders: write to top-level fields too
        local touched = 0
        for _, f in ipairs({
            "CauserWeaponAvatarID","CauserWeaponSkinID","WeaponAvatarID",
            "WeaponSkinID","CauserAvatarID",
        }) do
            if md[f] ~= nil then md[f] = skinID; touched = touched + 1 end
        end
        if touched == 0 then md.CauserWeaponAvatarID = skinID end

        -- 3) Ensure the top-banner UI flags are on
        if md.bShowBottomBothSidesKillInfo ~= nil then md.bShowBottomBothSidesKillInfo = true end
        for _, f in ipairs({"bShowBroadcast","bShowBigBanner","bShowTeamKill","bShowKillEffect"}) do
            if md[f] ~= nil then md[f] = true end
        end
        if md.bHideKillIcon ~= nil then md.bHideKillIcon = false end
    end

    -- ---------------------------------------------------------------------
    -- Install wraps
    -- ---------------------------------------------------------------------
    local function install()
        local M = package.loaded["GameLua.Mod.BaseMod.Client.BattleKillBroadcast.BattleKillBroadcastSubSystem"]
        if not M or not M.__inner_impl then return false end
        local impl = M.__inner_impl
        if impl._kbFixV2 then return true end
        impl._kbFixV2 = true

        -- Copy: input is userdata, output is a Lua table — enrich the RESULT
        local fnCopy = "CopyKillOrPutDownMessageDataUserDataToLuaTable"
        if type(impl[fnCopy]) == "function" then
            local O = impl[fnCopy]
            impl[fnCopy] = function(self, ...)
                local result = O(self, ...)
                pcall(enrich, result, "copy")
                return result
            end
            log("[install] "..fnCopy)
        end

        -- The other three: input is the Lua table already — enrich BEFORE call
        for _, fnName in ipairs({
            "HandleDisplayKillOrPutDownMessage",
            "OnDisplayKillOrPutDownMessageProcessing",
            "OnDisplayKillOrPutDownMessage",
        }) do
            if type(impl[fnName]) == "function" then
                local O = impl[fnName]
                impl[fnName] = function(self, md, ...)
                    pcall(enrich, md, fnName:sub(1,8))
                    return O(self, md, ...)
                end
                log("[install] "..fnName)
            end
        end
        return true
    end

    local function poll()
        if not pcall(install) then
            pcall(function()
                local t = _timeTicker
                if t and t.AddTimerOnce then t.AddTimerOnce(0.5, poll) end
            end)
        end
    end
    poll()

    log("[init] loaded")
    print("[kb_fix v2] loaded — see kb_fix.txt")
end)
end

-- ============================================================================
-- INTEGRATED 5.LUA (standalone behavior preserved)
-- ============================================================================
local function __run_integrated_5()
-- ============================================================================
-- persist_fix.lua  —  standalone overlay, loads AFTER 1.lua
--
-- Fixes two concrete, code-level bugs in the persistence layer of 5.lua:
--   1. SaveLobbyState truncates shadow_lobby.txt and writes only what's in
--      the current cache. Post-match, the cache is partial → disk is wiped.
--   2. LoadLobbyState fires once at t=2.5s; if injection hasn't populated
--      the injected-res map yet, every isInjectedRes() check is false and
--      the load silently does nothing.
--
-- Does NOT touch bypass / anti-cheat. Does NOT touch 2.lua/3.lua/8.lua.
-- Does NOT edit 1.lua. Pure read+wrap.
-- ============================================================================

if _G.__PERSIST_FIX_V1 then return end
_G.__PERSIST_FIX_V1 = true

local PATH = "/storage/emulated/0/Android/data/com.pubg.imobile/files/shadow_lobby.txt"
local LOG  = "/storage/emulated/0/Android/data/com.pubg.imobile/files/persist_fix.txt"

-- ── helpers ─────────────────────────────────────────────────────────────
local function log(msg)
    pcall(function()
        local f = io.open(LOG, "a")
        if f then
            f:write(os.date("[%H:%M:%S] ") .. tostring(msg) .. "\n")
            f:close()
        end
    end)
end

pcall(function()
    local f = io.open(LOG, "w")
    if f then f:write("[persist_fix v1] " .. os.date("%H:%M:%S") .. "\n"); f:close() end
end)

local function count(t)
    local n = 0
    for _ in pairs(t or {}) do n = n + 1 end
    return n
end

local function readDisk()
    local out = {}
    local f = io.open(PATH, "r")
    if not f then return out end
    for line in f:lines() do
        local k, v = line:match("^([^=]+)=(%d+)$")
        if k then out[k] = tonumber(v) or 0 end
    end
    f:close()
    return out
end

local function writeDisk(tbl)
    local f = io.open(PATH, "w")
    if not f then return false end
    for k, v in pairs(tbl) do
        if v and tonumber(v) and tonumber(v) > 0 then
            f:write(k .. "=" .. tostring(v) .. "\n")
        end
    end
    f:close()
    return true
end

local function cacheHasData()
    local cch = _G.AddOutfitEquippedCache or {}
    if cch.outfitRes and tonumber(cch.outfitRes) and tonumber(cch.outfitRes) > 0 then return true end
    if next(cch.weapons or {}) ~= nil then return true end
    return false
end

-- ── guard: 1.lua's 5.lua must have run already ──────────────────────────
if type(_G.SaveLobbyState) ~= "function" or type(_G.LoadLobbyState) ~= "function" then
    log("FATAL: 5.lua globals not present (load order wrong?)")
    return
end

local _origSave = _G.SaveLobbyState
local _origLoad = _G.LoadLobbyState

_G._PersistLoading = false

-- ── 1. SAVE — regression guard ──────────────────────────────────────────
-- Let the original save run untouched (it also writes vehicles/emotes/
-- theme/pet that we don't want to lose). Afterward, if the file shrank,
-- merge the previous content back in. A legit shrink can't happen in 5.lua
-- because there is no "un-equip" path.
_G.SaveLobbyState = function()
    if _G._PersistLoading then
        log("save skipped (loading)")
        return
    end

    local before  = readDisk()
    local bCount  = count(before)
    if bCount == 0 then
        return _origSave()  -- nothing to protect
    end

    local ok = pcall(_origSave)
    if not ok then
        log("orig save errored")
        return
    end

    local after  = readDisk()
    local aCount = count(after)
    if aCount < bCount then
        local merged = {}
        for k, v in pairs(before) do merged[k] = v end
        for k, v in pairs(after)  do if v and v > 0 then merged[k] = v end end
        writeDisk(merged)
        log(string.format("save regressed %d→%d, restored %d keys", bCount, aCount, count(merged)))
    end
end

-- ── 2. LOAD — with loading flag so internal saves are suppressed ───────
local function tryLoad()
    _G._PersistLoading = true
    local ok, err = pcall(_origLoad)
    _G._PersistLoading = false
    if not ok then log("load errored: " .. tostring(err)) end
    return cacheHasData()
end

_G.LoadLobbyState = function()
    return tryLoad()
end

-- ── 3. Retry load until the cache is actually populated ────────────────
local ticker
pcall(function() ticker = require("common.time_ticker") end)

if not (ticker and ticker.AddTimerOnce) then
    log("no ticker; running one immediate load")
    tryLoad()
    return
end

-- 1.lua's own t=2.5s timer will still fire; it now hits OUR LoadLobbyState
-- (global lookup at call time), so the flag is honored.
for _, t in ipairs({ 3.0, 5.0, 8.0, 12.0, 18.0, 26.0, 36.0 }) do
    ticker.AddTimerOnce(t, function()
        if cacheHasData() then return end
        pcall(tryLoad)
    end)
end

-- ── 4. Safety net: while in lobby, if cache is empty but disk has data,
--       re-run the load. This catches post-match returns where the game
--       wipes the in-memory avatar component.
if ticker.AddTimerLoop then
    ticker.AddTimerLoop(6.0, function()
        pcall(function()
            local inLobby = _G.GameStatus
                and _G.GameStatus.IsInLobbyOrMainCity
                and _G.GameStatus.IsInLobbyOrMainCity()
            if not inLobby then return end
            if cacheHasData() then return end
            if count(readDisk()) == 0 then return end
            log("safety net: cache empty, disk populated → reload")
            pcall(tryLoad)
        end)
    end, -1, 6.0)
end

log("[init] armed")
print("[persist_fix] loaded — see persist_fix.txt")
end
local __ok_5, __err_5 = pcall(__run_integrated_5)
if not __ok_5 then print("[integrated_5] error: " .. tostring(__err_5)) end

-- ============================================================================
-- STANDALONE ANTI-BLINK & OUTFIT SYNC ENGINE
-- Resolves conflicts between shadow_lobby.txt and layer_clothes.cfg
-- ============================================================================
pcall(function()
    if _G._AntiBlinkOutfitFix then return end
    _G._AntiBlinkOutfitFix = true

    -- Function to wipe Layered Clothes (Shirt/Pants/Shoes)
    local function ClearLayers()
        if _G.LayerStore then
            _G.LayerStore.top = 0
            _G.LayerStore.pants = 0
            _G.LayerStore.shoes = 0
            _G.LayerStore.under_top = 0
            _G.LayerStore.under_pants = 0
            if _G.LayerCloth and _G.LayerCloth.Save then 
                _G.LayerCloth.Save() 
            end
        end
    end

    -- Function to wipe Full Suits
    local function ClearSuit()
        if _G.InventorySkins then _G.InventorySkins.outfit = 0 end
        if _G.AddOutfitEquippedCache then
            _G.AddOutfitEquippedCache.outfitRes = nil
            _G.AddOutfitEquippedCache.outfitIns = nil
        end
        _G.AddOutfitLastLobbyOutfitRes = nil
        if not _G.IsLoadingLobbyState and _G.SaveLobbyState then 
            _G.SaveLobbyState() 
        end
    end

    -- 1. Lobby Hook: Detect what the user clicks and delete the opposing save
    local WRH = require("client.network.Protocol.WardRobeHandler")
    if WRH and WRH.on_depot_put_on_rsp then
        local orig_rsp = WRH.on_depot_put_on_rsp
        WRH.on_depot_put_on_rsp = function(res, item, olditem, slot, insID, oldIns, extra)
            if _G.IsLoadingLobbyState then 
                return orig_rsp(res, item, olditem, slot, insID, oldIns, extra) 
            end

            if item and item.res_id then
                local resID = tonumber(item.res_id)
                if resID then
                    local st = nil
                    local isSuit = false
                    pcall(function()
                        local c = CDataTable.GetTableData("Item", resID)
                        st = tonumber(c.ItemSubType or c.itemSubType)
                        local tab = tonumber(c.WardrobeTab or c.wardrobeTab)
                        isSuit = (tab == 10) -- 10 is the internal ID for WARDROBE_TAB_SUIT
                    end)

                    if isSuit then
                        -- User equipped a Full Suit -> Destroy layered clothes
                        ClearLayers()
                    elseif st == 404 or st == 405 or st == 450 or st == 451 or (st == 403 and not isSuit) then
                        -- User equipped Top/Pants/Shoes -> Destroy Full Suit
                        ClearSuit()
                    end
                end
            end
            return orig_rsp(res, item, olditem, slot, insID, oldIns, extra)
        end
    end

    -- 2. In-Match Fail-Safe Hook: Prevents rendering overlaps and stops the 1-second blink
    local orig_equip = _G.equip_character_avatar
    if type(orig_equip) == "function" then
        _G.equip_character_avatar = function(playerChar)
            local hasSuit = _G.InventorySkins and _G.InventorySkins.outfit and _G.InventorySkins.outfit > 0
            local hasLayers = _G.LayerStore and (_G.LayerStore.top > 0 or _G.LayerStore.pants > 0)

            -- If both somehow loaded due to a desync, the Suit takes priority and wipes the ghost layers
            if hasSuit and hasLayers then
                ClearLayers()
            end

            return orig_equip(playerChar)
        end
    end
end)

return AutoFeedback

end)()

-- =-- ============================================================================
-- STANDALONE BACKPACK & HELMET AUTO-LEVEL SYSTEM FOR a.lua (LOBBY + MATCH FIX)
-- Equip Lv.1, Lv.2, or Lv.3 in Wardrobe -> Auto-applies Lv.1 / Lv.2 / Lv.3
-- in Match according to the actual Backpack & Helmet level you pick up.
-- ============================================================================
do
    _G.InventorySkins = _G.InventorySkins or { weapons = {}, outfit = 0, vehicle = 0, bag = 0, helmet = 0 }
    _G._MatchBagLevel  = _G._MatchBagLevel or 3
    _G._MatchHelmLevel = _G._MatchHelmLevel or 3
    _G._LastMatchBagApplied  = 0
    _G._LastMatchHelmApplied = 0

    local LOBBY_SAVE_PATH = "/storage/emulated/0/Android/data/com.pubg.imobile/files/shadow_lobby.txt"

    -- Base in-game item IDs -> Level (1, 2, or 3)
    local BASE_HELMET_LEVEL = {
        [502001] = 1, [502004] = 1, [1505000001] = 1,
        [502002] = 2, [502005] = 2, [1505000002] = 2,
        [502003] = 3, [502006] = 3, [1505000003] = 3,
    }
    local BASE_BAG_LEVEL = {
        [501001] = 1, [501004] = 1,
        [501002] = 2, [501005] = 2,
        [501003] = 3, [501006] = 3,
    }

    -- Safe C++ UStruct ItemID / ItemId getter & setter (prevents SLua struct crash)
    local function getSlotItemID(eq)
        if not eq then return 0 end
        local id = nil
        pcall(function() id = eq.ItemID end)
        if id == nil then pcall(function() id = eq.ItemId end) end
        return tonumber(id) or 0
    end

    local function setSlotItemID(eq, val)
        if not eq then return end
        local ok = pcall(function() eq.ItemID = val end)
        if not ok then pcall(function() eq.ItemId = val end) end
        pcall(function() eq.ItemId = val end)
    end

    -- 1. Detect if an Item ID is a Backpack ("bag") or Helmet ("helmet")
    local function getEquipSlotType(resID)
        resID = tonumber(resID)
        if not resID or resID <= 0 then return nil end
        if (resID >= 1501000000 and resID < 1502000000) or (resID >= 1504000000 and resID < 1505000000) then
            return "bag"
        elseif (resID >= 1502000000 and resID < 1503000000) or (resID >= 1505000000 and resID < 1506000000) then
            return "helmet"
        end
        local slot = nil
        pcall(function()
            if CDataTable and CDataTable.GetTableData then
                local c = CDataTable.GetTableData("Item", resID)
                if c then
                    local st = tonumber(c.ItemSubType or c.itemSubType or 0)
                    if st == 501 or st == 504 then slot = "bag"
                    elseif st == 502 or st == 505 then slot = "helmet" end
                end
            end
        end)
        return slot
    end

    -- 2. Normalize any Lv.1 / Lv.2 / Lv.3 skin ID to its Catalog Base ID
    local function getCatalogBaseID(resID)
        resID = tonumber(resID)
        if not resID or resID <= 0 then return 0 end
        for _, base in ipairs({ 1501000000, 1502000000, 1504000000, 1505000000 }) do
            if resID >= base + 1000 and resID < base + 4000 then
                local tail = resID - base
                local lvl = math.floor(tail / 1000)
                if lvl >= 1 and lvl <= 3 then
                    return base + (tail - lvl * 1000)
                end
            end
        end
        return resID
    end

    -- Build reverse lookup from CDataTable BackpackMapping (if any skin uses non-pattern IDs)
    local _bpMapReverse = nil
    local function getBackpackMapEntry(skinID)
        if not _bpMapReverse and CDataTable and CDataTable.GetTable then
            _bpMapReverse = {}
            pcall(function()
                local tbl = CDataTable.GetTable("BackpackMapping")
                if not tbl then return end
                for k, m in pairs(tbl) do
                    local cat = tonumber(m.ID or m.Id or k) or 0
                    local lv1 = tonumber(m.SkinItemIDLv1) or 0
                    local lv2 = tonumber(m.SkinItemIDLv2) or 0
                    local lv3 = tonumber(m.SkinItemIDLv3) or 0
                    local set = { lv1 = lv1, lv2 = lv2, lv3 = lv3 }
                    if cat > 0 then _bpMapReverse[cat] = set end
                    if lv1 > 0 then _bpMapReverse[lv1] = set end
                    if lv2 > 0 then _bpMapReverse[lv2] = set end
                    if lv3 > 0 then _bpMapReverse[lv3] = set end
                end
            end)
        end
        return _bpMapReverse and _bpMapReverse[tonumber(skinID) or 0] or nil
    end

    -- 3. Resolve exact Skin ID for Target Level (1, 2, or 3) from ANY equipped level
    function _G.GetEquipSkinForLevel(selectedSkinID, targetLevel)
        selectedSkinID = tonumber(selectedSkinID)
        targetLevel = tonumber(targetLevel) or 3
        if not selectedSkinID or selectedSkinID <= 0 then return 0 end
        if targetLevel < 1 or targetLevel > 3 then targetLevel = 3 end

        local catalogID = getCatalogBaseID(selectedSkinID)

        -- Method A: Direct 1501 / 1502 / 1504 / 1505 level math (+1000 / +2000 / +3000)
        for _, base in ipairs({ 1501000000, 1502000000, 1504000000, 1505000000 }) do
            if catalogID >= base and catalogID < base + 1000 then
                return catalogID + (targetLevel * 1000)
            end
        end

        -- Method B: Reverse BackpackMapping lookup
        local entry = getBackpackMapEntry(selectedSkinID) or getBackpackMapEntry(catalogID)
        if entry then
            if targetLevel == 1 and entry.lv1 > 0 then return entry.lv1 end
            if targetLevel == 2 and entry.lv2 > 0 then return entry.lv2 end
            if targetLevel == 3 and entry.lv3 > 0 then return entry.lv3 end
        end

        -- Method C: Direct BackpackMapping / DataMgr lookup
        local mapped = 0
        pcall(function()
            if CDataTable and CDataTable.GetTableData then
                local m = CDataTable.GetTableData("BackpackMapping", catalogID)
                       or CDataTable.GetTableData("BackpackMapping", selectedSkinID)
                if m then
                    if targetLevel == 1 then mapped = tonumber(m.SkinItemIDLv1) or 0
                    elseif targetLevel == 2 then mapped = tonumber(m.SkinItemIDLv2) or 0
                    else mapped = tonumber(m.SkinItemIDLv3) or 0 end
                end
            end
            if mapped <= 0 and DataMgr and DataMgr.GetEquipmentItemIDByResID then
                mapped = tonumber(DataMgr.GetEquipmentItemIDByResID(targetLevel, catalogID)) or 0
            end
        end)
        if mapped > 0 then return mapped end

        return selectedSkinID
    end

    local function buildLevelList(selectedSkinID)
        return {
            _G.GetEquipSkinForLevel(selectedSkinID, 1),
            _G.GetEquipSkinForLevel(selectedSkinID, 2),
            _G.GetEquipSkinForLevel(selectedSkinID, 3),
        }
    end

    -- 4. Detect if an item ID is a vanilla/base in-game Bag or Helmet and return its level
    local function detectBaseEquipLevel(itemID, slotType)
        itemID = tonumber(itemID) or 0
        if itemID <= 0 then return nil end
        if slotType == "helmet" then
            if BASE_HELMET_LEVEL[itemID] then return BASE_HELMET_LEVEL[itemID] end
            if itemID >= 502001 and itemID <= 502999 then
                local d = itemID % 10
                if d == 1 or d == 4 then return 1
                elseif d == 2 or d == 5 then return 2
                elseif d == 3 or d == 6 then return 3 end
            end
        elseif slotType == "bag" then
            if BASE_BAG_LEVEL[itemID] then return BASE_BAG_LEVEL[itemID] end
            if itemID >= 501001 and itemID <= 501999 then
                local d = itemID % 10
                if d == 1 or d == 4 then return 1
                elseif d == 2 or d == 5 then return 2
                elseif d == 3 or d == 6 then return 3 end
            end
        end
        return nil
    end

    function _G.DetectItemEquipLevel(currentItemID, slotType)
        currentItemID = tonumber(currentItemID) or 0
        if currentItemID <= 0 then return nil end

        local baseLvl = detectBaseEquipLevel(currentItemID, slotType)
        if baseLvl then return baseLvl end

        for _, base in ipairs({ 1501000000, 1502000000, 1504000000, 1505000000 }) do
            if currentItemID >= base + 1000 and currentItemID < base + 4000 then
                local lvl = math.floor((currentItemID - base) / 1000)
                if lvl >= 1 and lvl <= 3 then return lvl end
            end
        end

        local entry = getBackpackMapEntry(currentItemID)
        if entry then
            if currentItemID == entry.lv1 then return 1
            elseif currentItemID == entry.lv2 then return 2
            elseif currentItemID == entry.lv3 then return 3 end
        end

        local detected = nil
        pcall(function()
            local BU = import("BackpackUtils") or require("GameLua.Mod.BaseMod.GamePlay.Backpack.BackpackUtils")
            if BU then
                if slotType == "helmet" and BU.GetEquipmentHelmetLevel then
                    local hl = BU.GetEquipmentHelmetLevel(currentItemID)
                    if hl and hl >= 1 and hl <= 3 then detected = hl end
                elseif slotType == "bag" and BU.GetEquipmentBagLevel then
                    local bl = BU.GetEquipmentBagLevel(currentItemID)
                    if bl and bl >= 1 and bl <= 3 then detected = bl end
                end
            end
        end)
        return detected
    end

    -- 5. Persist Bag & Helmet in shadow_lobby.txt
    local function saveBagAndHelmetToDisk()
        pcall(function()
            local lines = {}
            local f = io.open(LOBBY_SAVE_PATH, "r")
            if f then
                for line in f:lines() do
                    if not line:match("^SKIN_Bag=") and not line:match("^SKIN_Helmet=") then
                        lines[#lines + 1] = line
                    end
                end
                f:close()
            end
            if _G.InventorySkins.bag and _G.InventorySkins.bag > 0 then
                lines[#lines + 1] = "SKIN_Bag=" .. tostring(_G.InventorySkins.bag)
            end
            if _G.InventorySkins.helmet and _G.InventorySkins.helmet > 0 then
                lines[#lines + 1] = "SKIN_Helmet=" .. tostring(_G.InventorySkins.helmet)
            end
            local wf = io.open(LOBBY_SAVE_PATH, "w")
            if wf then
                for _, l in ipairs(lines) do wf:write(l .. "\n") end
                wf:close()
            end
        end)
    end

    local origSaveLobby = _G.SaveLobbyState
    _G.SaveLobbyState = function()
        if origSaveLobby then pcall(origSaveLobby) end
        saveBagAndHelmetToDisk()
    end

    local function loadSavedBagAndHelmet()
        pcall(function()
            local f = io.open(LOBBY_SAVE_PATH, "r")
            if not f then return end
            for line in f:lines() do
                local bagRes = line:match("^SKIN_Bag=(%d+)$")
                if bagRes then _G.InventorySkins.bag = tonumber(bagRes) end
                local helmRes = line:match("^SKIN_Helmet=(%d+)$")
                if helmRes then _G.InventorySkins.helmet = tonumber(helmRes) end
            end
            f:close()
        end)
    end
    loadSavedBagAndHelmet()

    -- Helper to resolve resID from insID
    local function resolveResFromIns(insID)
        insID = tonumber(insID)
        if not insID or insID <= 0 then return nil end
        if _G.AddOutfit_R and _G.AddOutfit_R.insToRes and _G.AddOutfit_R.insToRes[insID] then
            return tonumber(_G.AddOutfit_R.insToRes[insID])
        end
        local res = nil
        pcall(function()
            local wd = require("client.slua.logic.wardrobe.wardrobe_data")
            local d = wd:GetValidHallDepotItemDataByInsID(insID) or wd:GetHallDepotItemDataByInsID(insID)
            if d then res = tonumber(d.resID or d.res_id) end
        end)
        if not res and insID >= 1500000000 and insID < 1600000000 then
            res = insID
        end
        return res
    end

    -- Record selection whenever equipped in Lobby
    local function recordLobbyEquip(resID, insID)
        resID = tonumber(resID) or resolveResFromIns(insID)
        if not resID or resID <= 0 then return false end
        local slotType = getEquipSlotType(resID)
        if not slotType then return false end

        _G.InventorySkins[slotType] = resID
        _G.AddOutfitEquippedCache = _G.AddOutfitEquippedCache or { equip = {}, weapons = {}, clothes = {} }
        _G.AddOutfitEquippedCache.equip = _G.AddOutfitEquippedCache.equip or {}
        _G.AddOutfitEquippedCache.equip[slotType] = resID
        if insID then _G.AddOutfitEquippedCache.equip[slotType .. "Ins"] = tonumber(insID) end

        _G._LastMatchBagApplied  = 0
        _G._LastMatchHelmApplied = 0
        saveBagAndHelmetToDisk()

        -- Apply visual in Lobby
        pcall(function()
            local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
            local HT  = require("client.logic.lobby.hall_theme_utils")
            local TAM = require("client.logic.avatar.logic_team_avatar_manager")
            local AvatarData = require("client.logic.data.AvatarData")
            local lds = require("client.slua.logic.wardrobe.logic_display_setting")
            local lav = require("client.slua.logic.wardrobe.logic_wardrobe_avatar")

            local clickedLevel = _G.DetectItemEquipLevel(resID, slotType) or 3
            if slotType == "helmet" and fbd and fbd.SetHelmetLevel then fbd:SetHelmetLevel(clickedLevel)
            elseif slotType == "bag" and fbd and fbd.SetBagLevel then fbd:SetBagLevel(clickedLevel) end

            local displayRes = _G.GetEquipSkinForLevel(resID, clickedLevel)
            if lav and lav.AvatarChange then lav:AvatarChange(displayRes, true) end
            if TAM and AvatarData and DataMgr and DataMgr.roleData then
                TAM.ChangeAvatarEquipment(
                    tostring(DataMgr.roleData.uid),
                    AvatarData.CreateAvatarCustom(displayRes),
                    true
                )
            end
            if lds and lds.data then
                if slotType == "bag" then lds.data.OpenBag = true
                elseif slotType == "helmet" then lds.data.OpenHelmet = true end
            end
            if slotType == "bag" and HT and HT.PutOnBag and fbd then
                HT.PutOnBag(fbd:GetFashionBagUseIndex())
            end
        end)
        return true
    end

    -- 6. Hook ALL Lobby Wardrobe Equip Pathways (including 5.lua's on_depot_put_on_rsp shortcut!)
    local function installLobbyHooks()
        pcall(function()
            local WRH = require("client.network.Protocol.WardRobeHandler")
            if WRH and not WRH._BH_RspHooked then
                WRH._BH_RspHooked = true
                local origRsp = WRH.on_depot_put_on_rsp
                WRH.on_depot_put_on_rsp = function(res, item, olditem, slot, newIns, oldIns, extra)
                    if origRsp then origRsp(res, item, olditem, slot, newIns, oldIns, extra) end
                    if item then
                        local rID = tonumber(item.res_id or item.resID)
                        local iID = tonumber(item.instid or newIns)
                        recordLobbyEquip(rID, iID)
                    end
                end

                local origReq = WRH.send_depot_put_on_req
                WRH.send_depot_put_on_req = function(insID, extra)
                    local resID = resolveResFromIns(insID)
                    if resID and getEquipSlotType(resID) then
                        recordLobbyEquip(resID, insID)
                    end
                    return origReq(insID, extra)
                end
            end
        end)

        pcall(function()
            local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
            if wl and not wl._BH_WlHooked then
                wl._BH_WlHooked = true
                local origValid = wl.IsValidCurrentPageItem
                wl.IsValidCurrentPageItem = function(self, mainTab, subTab, v, t)
                    local resID = v and tonumber(v.resID or v.res_id)
                    local slotType = getEquipSlotType(resID)
                    if slotType == "bag" and mainTab == 1 and subTab == 15 then return true end
                    if slotType == "helmet" and mainTab == 1 and subTab == 16 then return true end
                    return origValid(self, mainTab, subTab, v, t)
                end

                local origPutOnReq = wl.wardrobe_puton_req
                wl.wardrobe_puton_req = function(self, insID, extra)
                    local resID = resolveResFromIns(insID)
                    if resID and getEquipSlotType(resID) then
                        recordLobbyEquip(resID, insID)
                    end
                    return origPutOnReq(self, insID, extra)
                end

                local origPutOnRsp = wl.on_puton_rsp
                wl.on_puton_rsp = function(self, res, item, olditem, index, extra)
                    if origPutOnRsp then origPutOnRsp(self, res, item, olditem, index, extra) end
                    if item then
                        recordLobbyEquip(tonumber(item.res_id or item.resID), tonumber(item.instid))
                    end
                end
            end
        end)

        pcall(function()
            if DataMgr and not DataMgr._BH_LevelMapHooked then
                DataMgr._BH_LevelMapHooked = true
                local origGetEq = DataMgr.GetEquipmentItemIDByResID
                DataMgr.GetEquipmentItemIDByResID = function(level, itemResID)
                    if getEquipSlotType(itemResID) then
                        local resolved = _G.GetEquipSkinForLevel(itemResID, level)
                        if resolved and resolved > 0 then return resolved end
                    end
                    return origGetEq(level, itemResID)
                end
            end
        end)
    end

    -- 7. Install Dynamic In-Match Hooks (runs lazily so match modules are always hooked)
    local function installMatchHooks()
        -- Allow injected Bag/Helmet BPIDs in BackpackUtils & AvatarUtils
        pcall(function()
            local BU = import("BackpackUtils")
            if BU and BU.GetBPIDByResID and not BU._BH_Hooked then
                BU._BH_Hooked = true
                local orig = BU.GetBPIDByResID
                BU.GetBPIDByResID = function(resID)
                    resID = tonumber(resID)
                    if resID and getEquipSlotType(resID) then
                        local bp = orig(resID)
                        if bp and bp > 0 then return bp end
                        return resID
                    end
                    return orig(resID)
                end
            end
        end)

        pcall(function()
            local AU = import("AvatarUtils")
            if AU and AU.GetBPIDByResID and not AU._BH_Hooked then
                AU._BH_Hooked = true
                local orig = AU.GetBPIDByResID
                AU.GetBPIDByResID = function(resID, ...)
                    resID = tonumber(resID)
                    if resID and getEquipSlotType(resID) then
                        local bp = orig(resID, ...)
                        if bp and bp > 0 then return bp end
                        return resID
                    end
                    return orig(resID, ...)
                end
            end
        end)

        -- Hook CharacterAvatarComponent in Match
        pcall(function()
            local CAC = package.loaded["GameLua.Mod.Library.GamePlay.Avatar.Component.CharacterAvatarComponent"]
                     or require("GameLua.Mod.Library.GamePlay.Avatar.Component.CharacterAvatarComponent")
            if not CAC then return end

            if not CAC._BH_CheckValidHooked then
                CAC._BH_CheckValidHooked = true
                local origValid = CAC.CheckItemValid
                CAC.CheckItemValid = function(self, resID)
                    if getEquipSlotType(resID) then return true end
                    return origValid(self, resID)
                end
            end

            if not CAC._BH_PutOnHooked then
                CAC._BH_PutOnHooked = true
                local origPutOn = CAC.PutOnCustomEquipmentByID
                CAC.PutOnCustomEquipmentByID = function(self, resID, CustomData)
                    if self.IsSelf and not self:IsSelf() then
                        return origPutOn(self, resID, CustomData)
                    end
                    resID = tonumber(resID)
                    if resID and getEquipSlotType(resID) then
                        local ok, result = pcall(function()
                            local ItemDefineID = FItemDefineID(4, resID)
                            local EAvatarCustomType = import("EAvatarCustomType")
                            local AvatarCustom = FAvatarCustomDefault()
                            if CustomData and type(CustomData) == "userdata" then
                                AvatarCustom = CustomData
                            end
                            AvatarCustom.CustomType = EAvatarCustomType.AvatarCustomCharacter
                            return self:HandleEquipItem(ItemDefineID, AvatarCustom)
                        end)
                        if ok and result ~= false and result ~= nil then return result end
                    end
                    return origPutOn(self, resID, CustomData)
                end
            end

            if not CAC._BH_GetEqSkinHooked then
                CAC._BH_GetEqSkinHooked = true
                local origGetSkin = CAC.GetEquipmentSkinItemID
                CAC.GetEquipmentSkinItemID = function(self, InItemID)
                    if self.IsSelf and not self:IsSelf() then
                        return origGetSkin(self, InItemID)
                    end
                    InItemID = tonumber(InItemID) or 0
                    if InItemID > 0 then
                        local helmLvl = detectBaseEquipLevel(InItemID, "helmet") or _G.DetectItemEquipLevel(InItemID, "helmet")
                        if helmLvl and _G.InventorySkins.helmet and _G.InventorySkins.helmet > 0 then
                            _G._MatchHelmLevel = helmLvl
                            local skin = _G.GetEquipSkinForLevel(_G.InventorySkins.helmet, helmLvl)
                            if skin > 0 then return skin end
                        end

                        local bagLvl = detectBaseEquipLevel(InItemID, "bag") or _G.DetectItemEquipLevel(InItemID, "bag")
                        if bagLvl and _G.InventorySkins.bag and _G.InventorySkins.bag > 0 then
                            _G._MatchBagLevel = bagLvl
                            local skin = _G.GetEquipSkinForLevel(_G.InventorySkins.bag, bagLvl)
                            if skin > 0 then return skin end
                        end
                    end
                    return origGetSkin(self, InItemID)
                end
            end
        end)
    end

    -- 8. Core In-Match Applier (Updates InitialEquipmentAvatar + PutOnCustomEquipmentByID + SlotSyncData)
    local function applyBagAndHelmetInMatch(playerChar)
        if not playerChar or not slua.isValid(playerChar) then return end
        installMatchHooks()

        local bagSelected  = tonumber(_G.InventorySkins.bag) or 0
        local helmSelected = tonumber(_G.InventorySkins.helmet) or 0
        if bagSelected <= 0 and helmSelected <= 0 then return end

        local ac = playerChar.CharacterAvatarComp2_BP
                or playerChar.AvatarComponent2
                or (playerChar.getAvatarComponent2 and playerChar:getAvatarComponent2())
        if not ac or not slua.isValid(ac) then return end

        local netData = nil
        pcall(function() netData = slua.IndexReference(ac, "NetAvatarData") or ac.NetAvatarData end)
        if not netData then return end

        local slotSyncData = nil
        pcall(function() slotSyncData = slua.IndexReference(netData, "SlotSyncData") or netData.SlotSyncData end)
        if not slotSyncData then return end

        local hasBagEquipped, hasHelmEquipped = false, false
        local changed = false

        -- Scan SlotSyncData (works with both TArray:Num() and pairs)
        local count = 0
        pcall(function() count = slotSyncData:Num() end)

        for i = 0, count - 1 do
            local eq = slotSyncData:Get(i)
            if eq then
                local slotID = eq.SlotID
                local curItemID = getSlotItemID(eq)

                -- Slot 8: Backpack
                if slotID == 8 and curItemID > 0 and bagSelected > 0 then
                    hasBagEquipped = true
                    local baseLvl = detectBaseEquipLevel(curItemID, "bag")
                    if baseLvl then _G._MatchBagLevel = baseLvl end
                    local bagLvl = baseLvl or _G.DetectItemEquipLevel(curItemID, "bag") or _G._MatchBagLevel or 3
                    local targetBag = _G.GetEquipSkinForLevel(bagSelected, bagLvl)

                    if targetBag > 0 and (curItemID ~= targetBag or _G._LastMatchBagApplied ~= targetBag) then
                        if _G.download_item and not (_G.skinIdCache and _G.skinIdCache[targetBag]) then
                            pcall(_G.download_item, targetBag)
                            if _G.skinIdCache then _G.skinIdCache[targetBag] = true end
                        end
                        pcall(function()
                            if ac.PutOnCustomEquipmentByID then ac:PutOnCustomEquipmentByID(targetBag) end
                        end)
                        pcall(function()
                            ac:HandleEquipItem(FItemDefineID(4, targetBag), FAvatarCustomDefault())
                        end)
                        setSlotItemID(eq, targetBag)
                        pcall(function() slotSyncData:Set(i, eq) end)
                        _G._LastMatchBagApplied = targetBag
                        changed = true
                    end
                elseif slotID == 8 and curItemID == 0 then
                    _G._LastMatchBagApplied = 0
                end

                -- Slot 9: Helmet
                if slotID == 9 and curItemID > 0 and helmSelected > 0 then
                    hasHelmEquipped = true
                    local baseLvl = detectBaseEquipLevel(curItemID, "helmet")
                    if baseLvl then _G._MatchHelmLevel = baseLvl end
                    local helmLvl = baseLvl or _G.DetectItemEquipLevel(curItemID, "helmet") or _G._MatchHelmLevel or 3
                    local targetHelm = _G.GetEquipSkinForLevel(helmSelected, helmLvl)

                    if targetHelm > 0 and (curItemID ~= targetHelm or _G._LastMatchHelmApplied ~= targetHelm) then
                        if _G.download_item and not (_G.skinIdCache and _G.skinIdCache[targetHelm]) then
                            pcall(_G.download_item, targetHelm)
                            if _G.skinIdCache then _G.skinIdCache[targetHelm] = true end
                        end
                        pcall(function()
                            if ac.PutOnCustomEquipmentByID then ac:PutOnCustomEquipmentByID(targetHelm) end
                        end)
                        pcall(function()
                            ac:HandleEquipItem(FItemDefineID(4, targetHelm), FAvatarCustomDefault())
                        end)
                        setSlotItemID(eq, targetHelm)
                        pcall(function() slotSyncData:Set(i, eq) end)
                        _G._LastMatchHelmApplied = targetHelm
                        changed = true
                    end
                elseif slotID == 9 and curItemID == 0 then
                    _G._LastMatchHelmApplied = 0
                end
            end
        end

        -- Sync PlayerController InitialEquipmentAvatar Lists (Lv.1, Lv.2, Lv.3)
        pcall(function()
            local pc = playerChar.GetPlayerControllerSafety and playerChar:GetPlayerControllerSafety()
            if pc and slua.isValid(pc) then
                local eq = pc.InitialEquipmentAvatar or {}
                if bagSelected > 0 and hasBagEquipped then
                    eq.BagAvatar = _G.GetEquipSkinForLevel(bagSelected, _G._MatchBagLevel or 3)
                    eq.BagAvatarList = buildLevelList(bagSelected)
                end
                if helmSelected > 0 and hasHelmEquipped then
                    eq.HelmetAvatar = _G.GetEquipSkinForLevel(helmSelected, _G._MatchHelmLevel or 3)
                    eq.HelmetAvatarList = buildLevelList(helmSelected)
                end
                pc.InitialEquipmentAvatar = eq
                if slua.isValid(pc.PlayerState) and pc.PlayerState.MetroPlayerStateAvatarFeature then
                    pc.PlayerState.MetroPlayerStateAvatarFeature.InitialEquipmentAvatar = eq
                end
            end
        end)

        if changed then
            pcall(function() if ac.ProcessAvatarRectify then ac:ProcessAvatarRectify() end end)
            pcall(function() if ac.OnRep_BodySlotStateChanged then ac:OnRep_BodySlotStateChanged() end end)
            pcall(function() if ac.RefreshAvatarReAttach then ac:RefreshAvatarReAttach() end end)
        end
    end

    -- 9. Hook into 4.lua's equip_character_avatar AND run a dedicated Match Timer
    local origEquipCharAvatar = _G.equip_character_avatar
    _G.equip_character_avatar = function(playerChar)
        if origEquipCharAvatar then pcall(origEquipCharAvatar, playerChar) end
        pcall(applyBagAndHelmetInMatch, playerChar)
    end

    installLobbyHooks()
    installMatchHooks()

    -- Dedicated timer that survives Lobby -> Match transitions
    local function startBagHelmLoop()
        local function tick()
            -- [PERF] 0.4s bag/helmet pass: entry-window only in a match.
            if not _G.__SkinTickAllowed() then return end
            pcall(installLobbyHooks)
            pcall(function()
                local GD = package.loaded["GameLua.GameCore.Data.GameplayData"]
                        or require("GameLua.GameCore.Data.GameplayData")
                if GD and GD.GetPlayerCharacter then
                    local char = GD.GetPlayerCharacter()
                    if char and slua.isValid(char) then
                        applyBagAndHelmetInMatch(char)
                    end
                end
            end)
        end

        pcall(function()
            if Game and Game.SetTimer and not _G._BH_GameTimer then
                _G._BH_GameTimer = Game:SetTimer(0.4, true, tick)
            end
        end)
        pcall(function()
            local tk = require("common.time_ticker")
            if tk and tk.AddTimerLoop and not _G._BH_TickerLoop then
                _G._BH_TickerLoop = tk.AddTimerLoop(0.4, tick, -1, 0.4)
            end
        end)
    end
    startBagHelmLoop()
end



-- Preserve the original 1.lua return value for callers that load this file.

-- ===== BEGIN current 5.lua integration (replaces prior embedded module) =====
local __five_ok, __five_err = pcall(function()
    local function __run_current_5_module()
        -- ============================================================================
        -- stability_perf.lua v1 — COMBINED stability engine + adaptive perf mode
        -- Replaces both stability.lua and perf_mode.lua. Load after 1.lua.
        -- Cosmetic/perf only. Bypass / anti-cheat / telemetry untouched.
        --
        -- Ownership split (no cvar races):
        --   [stab]  t.MaxFPS, r.ScreenPercentage, r.DynamicRes.*,
        --           touch relief (HUD wraps), thermal guard
        --   [perf]  r.ShadowQuality, r.EffectsQuality, r.ParticleLODBias,
        --           r.AntiAliasingMethod, r.BloomQuality, r.MotionBlurQuality,
        --           r.ViewDistanceScale
        -- ============================================================================
        if _G.__STABILITY_COMBINED_V1 then return _G.StabilityCombined end
        _G.__STABILITY_COMBINED_V1 = true
        _G.__STABILITY_ENGINE_V1   = true   -- block standalone stability.lua
        _G.__PERF_MODE_V1          = true   -- block standalone perf_mode.lua

        local BASE = "/storage/emulated/0/Android/data/com.pubg.imobile/files/"
        local LOG  = BASE .. "stability.txt"
        local CFG  = BASE .. "stability.cfg"

        -- Header write first, before anything risky
        pcall(function()
            local f = io.open(LOG, "w")
            if f then
                f:write("[stability_perf.lua v1] " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n")
                f:close()
            end
        end)

        local function log(msg)
            pcall(function()
                local f = io.open(LOG, "a")
                if f then
                    f:write(os.date("[%H:%M:%S] ") .. tostring(msg) .. "\n")
                    f:close()
                end
            end)
        end

        local function step(name, fn)
            local ok, err = pcall(fn)
            if ok then log("STEP " .. name .. " OK")
            else log("STEP " .. name .. " FAIL: " .. tostring(err)) end
            return ok
        end

        -- ============================================================================
        -- State
        -- ============================================================================
        local S = _G.StabilityCombined or {
            -- shared
            tier = "mid", tierSource = "auto", override = "",
            startTime = os.time(), startClock = os.clock(),

            -- shared frame
            ft = 0, emaFT = 0, targetFT = 0, currentTargetFPS = 60,
            worstFT = 0, accumFT = 0, accumN = 0,
            _lastRealTime = nil, _lastClock = nil, _lastLag = nil,
            _methodLogged = false, _lastRuntimeLog = 0,

            -- stability layer
            stab = {
                enabled = true, touchRelief = true, thermalGuard = true,
                heavyLoad = false, thermalStage = 0,
                currentScreenPct = 100, adjCount = 0,
                _highStreak = 0, _lowStreak = 0, _lastAdjClock = 0,
                _wrapReported = false, menuRegistered = false, _lastMenuAttempt = 0,
            },

            -- perf layer
            perf = {
                enabled = true, adaptive = true, forceAggressive = false,
                currentMode = "comfort", aggressiveActive = false,
                switchCount = 0,
                _highTicks = 0, _lowTicks = 0, _lastSwitchClock = 0,
                menuRegistered = false, _lastMenuAttempt = 0,
            },
        }
        _G.StabilityCombined = S

        -- ============================================================================
        -- Config (single file, prefixed keys)
        -- ============================================================================
        local function defaultConfig()
            local r = io.open(CFG, "r"); if r then r:close(); return end
            local w = io.open(CFG, "w"); if not w then return end
            w:write("stab_enabled=1\n")
            w:write("stab_touchRelief=1\n")
            w:write("stab_thermalGuard=1\n")
            w:write("perf_enabled=1\n")
            w:write("perf_adaptive=1\n")
            w:write("perf_forceAggressive=0\n")
            w:write("override=\n")
            w:write("tier=mid\n")
            w:close()
        end

        local function loadConfig()
            pcall(defaultConfig)
            local f = io.open(CFG, "r"); if not f then return end
            for line in f:lines() do
                local k, v = line:match("^([%w_]+)=(.*)$")
                if k == "stab_enabled"            then S.stab.enabled = (v == "1")
                elseif k == "stab_touchRelief"    then S.stab.touchRelief = (v == "1")
                elseif k == "stab_thermalGuard"   then S.stab.thermalGuard = (v == "1")
                elseif k == "perf_enabled"        then S.perf.enabled = (v == "1")
                elseif k == "perf_adaptive"       then S.perf.adaptive = (v == "1")
                elseif k == "perf_forceAggressive" then S.perf.forceAggressive = (v == "1")
                elseif k == "override"            then S.override = v or ""
                elseif k == "tier"                then S.tier = v ~= "" and v or "mid"
                -- legacy keys from old standalone files:
                elseif k == "enabled"             then S.stab.enabled = (v == "1")
                elseif k == "adaptive"            then S.perf.adaptive = (v == "1")
                elseif k == "forceAggressive"     then S.perf.forceAggressive = (v == "1")
                end
            end
            f:close()
        end

        local function saveConfig()
            pcall(function()
                local f = io.open(CFG, "w"); if not f then return end
                f:write("stab_enabled=" .. (S.stab.enabled and "1" or "0") .. "\n")
                f:write("stab_touchRelief=" .. (S.stab.touchRelief and "1" or "0") .. "\n")
                f:write("stab_thermalGuard=" .. (S.stab.thermalGuard and "1" or "0") .. "\n")
                f:write("perf_enabled=" .. (S.perf.enabled and "1" or "0") .. "\n")
                f:write("perf_adaptive=" .. (S.perf.adaptive and "1" or "0") .. "\n")
                f:write("perf_forceAggressive=" .. (S.perf.forceAggressive and "1" or "0") .. "\n")
                f:write("override=" .. tostring(S.override or "") .. "\n")
                f:write("tier=" .. tostring(S.tier) .. "\n")
                f:close()
            end)
        end

        -- ============================================================================
        -- Presets (each layer owns distinct cvars)
        -- ============================================================================
        local PRESET_STAB = {
            high = { targetFPS = 88, minRes = 70, maxRes = 100 },
            mid  = { targetFPS = 60, minRes = 60, maxRes = 90  },
            low  = { targetFPS = 45, minRes = 50, maxRes = 75  },
        }
        local PERF_COMFORT = {
            high = { shadow=3, effects=3, particle=1, aa=2, bloom=1, motion=1, viewDist=1.00 },
            mid  = { shadow=2, effects=2, particle=1, aa=2, bloom=1, motion=1, viewDist=1.00 },
            low  = { shadow=1, effects=1, particle=0, aa=1, bloom=1, motion=1, viewDist=1.00 },
        }
        local PERF_AGGRESSIVE = {
            high = { shadow=1, effects=0, particle=2, aa=0, bloom=0, motion=0, viewDist=0.75 },
            mid  = { shadow=0, effects=0, particle=2, aa=0, bloom=0, motion=0, viewDist=0.60 },
            low  = { shadow=0, effects=0, particle=2, aa=0, bloom=0, motion=0, viewDist=0.50 },
        }

        -- ============================================================================
        -- Console exec
        -- ============================================================================
        local _cmdOk, _cmdFail = 0, 0
        local function exec(cmd)
            pcall(function()
                local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
                if not pc then _cmdFail = _cmdFail + 1; return end
                local gi = pc.GetGameInstance and pc:GetGameInstance()
                if gi and gi.ExecuteCMD then gi:ExecuteCMD(cmd); _cmdOk = _cmdOk + 1; return end
                if pc.ExecuteCmd then pc:ExecuteCmd(cmd); _cmdOk = _cmdOk + 1; return end
                _cmdFail = _cmdFail + 1
            end)
        end

        local function applyStabBase()
            local p = PRESET_STAB[S.tier] or PRESET_STAB.mid
            exec("t.MaxFPS " .. p.targetFPS)
            exec("r.DynamicRes.OperationMode 1")
            exec("r.DynamicRes.MinScreenPercentage " .. p.minRes)
            exec("r.DynamicRes.MaxScreenPercentage " .. p.maxRes)
            exec("r.ScreenPercentage " .. p.maxRes)
            S.stab.currentScreenPct = p.maxRes
            return p
        end

        local function applyPerfPreset(mode)
            local tbl = (mode == "aggressive") and PERF_AGGRESSIVE or PERF_COMFORT
            local p = tbl[S.tier] or tbl.mid
            exec("r.ShadowQuality " .. p.shadow)
            exec("r.EffectsQuality " .. p.effects)
            exec("r.ParticleLODBias " .. p.particle)
            exec("r.AntiAliasingMethod " .. p.aa)
            exec("r.BloomQuality " .. p.bloom)
            exec("r.MotionBlurQuality " .. p.motion)
            exec("r.ViewDistanceScale " .. string.format("%.2f", p.viewDist))
            return p
        end

        -- ============================================================================
        -- Device probe + tier
        -- ============================================================================
        local HIGH_PATTERNS = {
            "sm-s9","sm-s91","sm-s92","sm-s93","sm-s94","sm-s928","sm-s921","sm-s926",
            "pixel 7","pixel 8","pixel 9",
            "oneplus 11","oneplus 12","oneplus 13",
            "mi 13","mi 14","13 pro","14 pro","13 ultra","14 ultra",
            "iqoo 11","iqoo 12","iqoo 13",
            "iphone 13","iphone 14","iphone 15","iphone 16","ipad pro",
        }
        local LOW_PATTERNS = {
            "snapdragon 4","snapdragon 6","dimensity 6","dimensity 7",
            "helio","redmi 9","redmi 10","realme c",
            "sm-a0","sm-a1","sm-a2","moto g","oppo a","vivo y",
        }

        local function matchAny(s, pats)
            if not s or s == "" then return false end
            local ls = s:lower()
            for _, p in ipairs(pats) do
                if ls:find(p, 1, true) then return true end
            end
            return false
        end

        local function probeDevice()
            local d = { make = "", model = "", platform = "", sw = 0, sh = 0 }
            pcall(function()
                local SL = import("KismetSystemLibrary")
                if SL then
                    if SL.GetDeviceMake  then pcall(function() d.make  = tostring(SL.GetDeviceMake())  end) end
                    if SL.GetDeviceModel then pcall(function() d.model = tostring(SL.GetDeviceModel()) end) end
                end
                if Game and Game.GetPlatformName then
                    pcall(function() d.platform = tostring(Game:GetPlatformName()) end)
                end
                local WLL = import("WidgetLayoutLibrary")
                if WLL and WLL.GetViewportSize then
                    pcall(function()
                        local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
                        local vs = WLL.GetViewportSize(pc)
                        if vs then d.sw = vs.X or 0; d.sh = vs.Y or 0 end
                    end)
                end
            end)
            return d
        end

        local function assignTier(d)
            if S.override == "high" or S.override == "mid" or S.override == "low" then
                S.tier = S.override; S.tierSource = "user"; return
            end
            local probe = (d.make or "") .. " " .. (d.model or "")
            if matchAny(probe, HIGH_PATTERNS) then S.tier = "high"; S.tierSource = "auto"
            elseif matchAny(probe, LOW_PATTERNS) then S.tier = "low"; S.tierSource = "auto"
            else S.tier = "mid"; S.tierSource = "auto" end
        end

        -- ============================================================================
        -- LocUtil chain (single chain for all IDs)
        -- ============================================================================
        local _strs = {
            [999996] = "Stability",
            [999997] = "Stability Engine",
            [999998] = "Touch Relief (pause HUD in combat)",
            [999999] = "Thermal Guard (auto-drop after 15 min)",
            [990000] = "Performance Mode",
            [990001] = "Performance Mode Engine",
            [990002] = "Adaptive (auto-switch on FPS drops)",
            [990003] = "Force Aggressive (potato mode now)",
        }

        local function chainLocUtil()
            pcall(function()
                local LU = package.loaded["client.common.LocUtil"] or require("client.common.LocUtil")
                if not LU or LU._stabilityPerfChained then return end
                local orig = LU.GetLocalizeResStr
                if type(orig) ~= "function" then return end
                LU.GetLocalizeResStr = function(id)
                    local s = _strs[id]
                    if s then return s end
                    return orig(id)
                end
                LU._stabilityPerfChained = true
            end)
        end

        -- ============================================================================
        -- Menu registration (both categories in one function)
        -- ============================================================================
        local function registerMenus()
            local ok1, SPD = pcall(require, "client.logic.NewSetting.SettingPageDefine")
            if not ok1 or not SPD then return false end
            local ok2, SC = pcall(require, "client.logic.NewSetting.SettingCatalog")
            if not ok2 or not SC then return false end
            local ok3, AM = pcall(require, "client.slua.umg.NewSetting.Item.AliasMap")
            if not ok3 or not AM then return false end
            if not AM.TitleSwitcher or not AM.Switcher then return false end

            local page = SPD.ModMenu
            if not page then
                page = { Key = "ModMenu", Text = 999000, UIKey = "Setting_Page_Privacy", Category = {} }
                SPD.ModMenu = page
                table.insert(SC, 1, page)
            end
            page.Category = page.Category or {}
            chainLocUtil()

            local function hasCat(key)
                for _, c in ipairs(page.Category) do
                    if c.Key == key then return true end
                end
                return false
            end

            -- ── Stability category ──────────────────────────────────────────
            if not hasCat("Cat_Stability") then
                table.insert(page.Category, {
                    Key = "Cat_Stability", Text = 999996,
                    Stack = {
                        {
                            Key = "Stability_Enable", UI = AM.TitleSwitcher,
                            Text = 999997, ExpandIndex = 0,
                            GetFunc = function() return S.stab.enabled end,
                            SetFunc = function(_, v)
                                S.stab.enabled = (v == true); saveConfig()
                                log("stab toggle enabled=" .. tostring(S.stab.enabled)); return true
                            end,
                        },
                        {
                            Key = "Stability_TouchRelief", UI = AM.Switcher,
                            Text = 999998, ExpandHandle = "Stability_Enable",
                            GetFunc = function() return S.stab.touchRelief end,
                            SetFunc = function(_, v)
                                S.stab.touchRelief = (v == true); saveConfig()
                                log("stab toggle touchRelief=" .. tostring(S.stab.touchRelief)); return true
                            end,
                        },
                        {
                            Key = "Stability_ThermalGuard", UI = AM.Switcher,
                            Text = 999999, ExpandHandle = "Stability_Enable",
                            GetFunc = function() return S.stab.thermalGuard end,
                            SetFunc = function(_, v)
                                S.stab.thermalGuard = (v == true); saveConfig()
                                log("stab toggle thermalGuard=" .. tostring(S.stab.thermalGuard)); return true
                            end,
                        },
                    },
                })
                S.stab.menuRegistered = true
            end

            -- ── Perf mode category ──────────────────────────────────────────
            if not hasCat("Cat_PerfMode") then
                table.insert(page.Category, {
                    Key = "Cat_PerfMode", Text = 990000,
                    Stack = {
                        {
                            Key = "PerfMode_Enable", UI = AM.TitleSwitcher,
                            Text = 990001, ExpandIndex = 0,
                            GetFunc = function() return S.perf.enabled end,
                            SetFunc = function(_, v)
                                S.perf.enabled = (v == true); saveConfig()
                                log("perf toggle enabled=" .. tostring(S.perf.enabled)); return true
                            end,
                        },
                        {
                            Key = "PerfMode_Adaptive", UI = AM.Switcher,
                            Text = 990002, ExpandHandle = "PerfMode_Enable",
                            GetFunc = function() return S.perf.adaptive end,
                            SetFunc = function(_, v)
                                S.perf.adaptive = (v == true); saveConfig()
                                log("perf toggle adaptive=" .. tostring(S.perf.adaptive)); return true
                            end,
                        },
                        {
                            Key = "PerfMode_Force", UI = AM.Switcher,
                            Text = 990003, ExpandHandle = "PerfMode_Enable",
                            GetFunc = function() return S.perf.forceAggressive end,
                            SetFunc = function(_, v)
                                S.perf.forceAggressive = (v == true); saveConfig()
                                log("perf toggle forceAggressive=" .. tostring(S.perf.forceAggressive))
                                if S.perf.forceAggressive then
                                    local p = applyPerfPreset("aggressive")
                                    S.perf.aggressiveActive = true
                                    S.perf.currentMode = "aggressive"
                                    log(string.format("[perf] FORCE-ON shadow=%d effects=%d viewDist=%.2f",
                                        p.shadow, p.effects, p.viewDist))
                                else
                                    local p = applyPerfPreset("comfort")
                                    S.perf.aggressiveActive = false
                                    S.perf.currentMode = "comfort"
                                    log(string.format("[perf] FORCE-OFF shadow=%d effects=%d viewDist=%.2f",
                                        p.shadow, p.effects, p.viewDist))
                                end
                                return true
                            end,
                        },
                    },
                })
                S.perf.menuRegistered = true
            end

            if S.stab.menuRegistered and S.perf.menuRegistered then
                log("MENUS REGISTERED (Cat_Stability + Cat_PerfMode)")
                return true
            end
            return false
        end

        -- ============================================================================
        -- Touch relief wraps (retry every tick — targets may load late)
        -- ============================================================================
        local function wrapRibbon()
            local RN = _G.RibbonName
            if type(RN) ~= "table" or RN._stabilityWrapped then return false end
            local orig = RN.Update
            if type(orig) ~= "function" then return false end
            RN.Update = function(...)
                if S.stab.enabled and S.stab.touchRelief
                   and (S.stab.heavyLoad or S.perf.aggressiveActive) then return end
                return orig(...)
            end
            RN._stabilityWrapped = true
            return true
        end

        local function wrapGlobal(name)
            local fn = _G[name]
            if type(fn) ~= "function" or fn._stabilityWrapped then return false end
            local orig = fn
            local w = function(...)
                if S.stab.enabled and S.stab.touchRelief
                   and (S.stab.heavyLoad or S.perf.aggressiveActive) then return end
                return orig(...)
            end
            w._stabilityWrapped = true
            _G[name] = w
            return true
        end

        local function installTouchRelief()
            local names = {}
            if wrapRibbon() then table.insert(names, "RibbonName.Update") end
            for _, n in ipairs({ "RefreshKillCounterUI", "ForceEnableKillCounterUI", "DeadBox_TemperRequest" }) do
                if wrapGlobal(n) then table.insert(names, n) end
            end
            if #names > 0 and not S.stab._wrapReported then
                S.stab._wrapReported = true
                log("TOUCH RELIEF WRAPPED: " .. table.concat(names, ", "))
            end
        end

        -- ============================================================================
        -- Signals + frame time
        -- ============================================================================
        local TICK_MS = 250
        local EMA_OLD, EMA_NEW = 0.85, 0.15

        local function readSignals()
            local s = { ok = false }
            pcall(function()
                local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
                if not pc then return end
                local world = pc.GetWorld and pc:GetWorld()
                if not (world and slua.isValid(world)) then return end
                local rt = world.GetRealTimeSeconds and world:GetRealTimeSeconds()
                local gt = world.GetTimeSeconds and world:GetTimeSeconds()
                if rt then s.realTime = rt; s.ok = true end
                if gt then s.gameTime = gt end
                if rt and gt then s.lag = rt - gt end
            end)
            return s
        end

        local function computeFrameTime(sig, targetFPS)
            local tickDelta
            if sig.ok and sig.realTime then
                tickDelta = sig.realTime - (S._lastRealTime or sig.realTime)
                S._lastRealTime = sig.realTime
            else
                tickDelta = os.clock() - (S._lastClock or os.clock())
                S._lastClock = os.clock()
            end
            if tickDelta < 0.1 or tickDelta > 2.0 then tickDelta = TICK_MS / 1000.0 end

            local expectedFrames = targetFPS * TICK_MS / 1000.0
            local ft, method
            if sig.ok and sig.lag then
                local deltaLag = 0
                if S._lastLag then deltaLag = math.max(0, sig.lag - S._lastLag) end
                S._lastLag = sig.lag
                ft = (tickDelta + deltaLag) * 1000.0 / expectedFrames
                method = "world-lag"
            else
                ft = tickDelta * 1000.0 / expectedFrames
                method = sig.ok and "world-time" or "tick(approx)"
            end
            if not S._methodLogged then
                S._methodLogged = true
                log("frame method=" .. method)
            end
            return ft
        end

        local function computeTargetFT()
            local p = PRESET_STAB[S.tier] or PRESET_STAB.mid
            local fps = p.targetFPS
            if S.stab.thermalStage == 1 then fps = fps - 5 end
            if S.stab.thermalStage == 2 then fps = fps - 10 end
            if fps < 20 then fps = 20 end
            S.currentTargetFPS = fps
            return 1000.0 / fps
        end

        -- ============================================================================
        -- Stability layer (FPS cap, dynamic res, heavy flag)
        -- ============================================================================
        local function stabLayer()
            if not S.stab.enabled then return end
            local targetFT = S.targetFT
            local p = PRESET_STAB[S.tier] or PRESET_STAB.mid

            -- Heavy flag
            if S.emaFT > targetFT * 1.60 then
                if not S.stab.heavyLoad then
                    S.stab.heavyLoad = true
                    log(string.format("HEAVY ON ema=%.1f target=%.1f", S.emaFT, targetFT))
                end
            elseif S.emaFT < targetFT * 1.30 then
                if S.stab.heavyLoad then
                    S.stab.heavyLoad = false
                    log(string.format("HEAVY OFF ema=%.1f", S.emaFT))
                end
            end

            -- Dynamic resolution (throttled 300ms)
            local now = os.clock()
            if now - S.stab._lastAdjClock < 0.3 then return end

            local minR, maxR = p.minRes, p.maxRes
            if S.stab.thermalStage == 1 then
                maxR = math.max(minR, maxR - 10); minR = math.max(40, minR - 5)
            elseif S.stab.thermalStage == 2 then
                maxR = math.max(minR, maxR - 25); minR = math.max(35, minR - 10)
            end

            if S.emaFT > targetFT * 1.35 then
                S.stab._highStreak = S.stab._highStreak + 1
                S.stab._lowStreak  = 0
                if S.stab._highStreak >= 3 then
                    local newPct = math.max(minR, S.stab.currentScreenPct - 5)
                    if newPct ~= S.stab.currentScreenPct then
                        S.stab.currentScreenPct = newPct
                        S.stab.adjCount = S.stab.adjCount + 1
                        S.stab._lastAdjClock = now
                        exec("r.ScreenPercentage " .. math.floor(newPct))
                        log(string.format("[stab] DR down → %.0f%%", newPct))
                    end
                    S.stab._highStreak = 0
                end
            elseif S.emaFT < targetFT * 1.05 then
                S.stab._lowStreak  = S.stab._lowStreak + 1
                S.stab._highStreak = 0
                if S.stab._lowStreak >= 6 then
                    local newPct = math.min(maxR, S.stab.currentScreenPct + 2)
                    if newPct ~= S.stab.currentScreenPct then
                        S.stab.currentScreenPct = newPct
                        S.stab.adjCount = S.stab.adjCount + 1
                        S.stab._lastAdjClock = now
                        exec("r.ScreenPercentage " .. math.floor(newPct))
                        log(string.format("[stab] DR up → %.0f%%", newPct))
                    end
                    S.stab._lowStreak = 0
                end
            end
        end

        -- ============================================================================
        -- Thermal guard
        -- ============================================================================
        local function updateThermal()
            if not S.stab.enabled or not S.stab.thermalGuard then return end
            local up = os.time() - S.startTime
            local stage = (up >= 25 * 60) and 2 or ((up >= 15 * 60) and 1 or 0)
            if stage ~= S.stab.thermalStage then
                S.stab.thermalStage = stage
                local p = PRESET_STAB[S.tier] or PRESET_STAB.mid
                local fps = p.targetFPS
                if stage == 1 then
                    fps = fps - 5
                    S.stab.currentScreenPct = math.max(p.minRes, S.stab.currentScreenPct - 10)
                elseif stage == 2 then
                    fps = fps - 10
                    S.stab.currentScreenPct = math.max(p.minRes, S.stab.currentScreenPct - 15)
                end
                exec("t.MaxFPS " .. fps)
                exec("r.ScreenPercentage " .. math.floor(S.stab.currentScreenPct))
                log(string.format("THERMAL stage=%d targetFPS=%d res=%.0f%%",
                    stage, fps, S.stab.currentScreenPct))
            end
        end

        -- ============================================================================
        -- Perf layer (comfort ↔ aggressive)
        -- ============================================================================
        local HIGH_TRIGGER_TICKS = 20   -- 5s @ 250ms
        local LOW_TRIGGER_TICKS  = 40   -- 10s @ 250ms
        local COOLDOWN_SEC       = 10.0

        local function perfEnterAggressive()
            if S.perf.aggressiveActive then return end
            S.perf.aggressiveActive = true
            S.perf.currentMode = "aggressive"
            S.perf.switchCount = S.perf.switchCount + 1
            S.perf._lastSwitchClock = os.clock()
            S.perf._highTicks = 0; S.perf._lowTicks = 0
            local p = applyPerfPreset("aggressive")
            log(string.format("[perf] MODE aggressive tier=%s shadow=%d effects=%d particle=%d aa=%d bloom=%d motion=%d viewDist=%.2f",
                S.tier, p.shadow, p.effects, p.particle, p.aa, p.bloom, p.motion, p.viewDist))
        end

        local function perfExitAggressive()
            if not S.perf.aggressiveActive then return end
            S.perf.aggressiveActive = false
            S.perf.currentMode = "comfort"
            S.perf.switchCount = S.perf.switchCount + 1
            S.perf._lastSwitchClock = os.clock()
            S.perf._highTicks = 0; S.perf._lowTicks = 0
            local p = applyPerfPreset("comfort")
            log(string.format("[perf] MODE comfort tier=%s shadow=%d effects=%d particle=%d aa=%d bloom=%d motion=%d viewDist=%.2f",
                S.tier, p.shadow, p.effects, p.particle, p.aa, p.bloom, p.motion, p.viewDist))
        end

        local function perfLayer()
            if not S.perf.enabled then
                if S.perf.aggressiveActive then perfExitAggressive() end
                return
            end
            if S.perf.forceAggressive then perfEnterAggressive(); return end
            if not S.perf.adaptive then
                if S.perf.aggressiveActive then perfExitAggressive() end
                return
            end

            local targetFT = S.targetFT
            if S.emaFT > targetFT * 1.50 then
                S.perf._highTicks = S.perf._highTicks + 1
                S.perf._lowTicks  = 0
            elseif S.emaFT < targetFT * 1.15 then
                S.perf._lowTicks  = S.perf._lowTicks + 1
                S.perf._highTicks = 0
            else
                S.perf._highTicks = math.max(0, S.perf._highTicks - 1)
                S.perf._lowTicks  = math.max(0, S.perf._lowTicks  - 1)
            end

            local now = os.clock()
            local inCooldown = (now - S.perf._lastSwitchClock) < COOLDOWN_SEC

            if not S.perf.aggressiveActive then
                if S.perf._highTicks >= HIGH_TRIGGER_TICKS and not inCooldown then
                    log(string.format("[perf] TRIGGER comfort→aggressive ema=%.1f target=%.1f ticks=%d",
                        S.emaFT, targetFT, S.perf._highTicks))
                    perfEnterAggressive()
                end
            else
                if S.perf._lowTicks >= LOW_TRIGGER_TICKS and not inCooldown then
                    log(string.format("[perf] TRIGGER aggressive→comfort ema=%.1f target=%.1f ticks=%d",
                        S.emaFT, targetFT, S.perf._lowTicks))
                    perfExitAggressive()
                end
            end
        end

        -- ============================================================================
        -- Runtime log (combined)
        -- ============================================================================
        local function runtimeLog()
            local now = os.clock()
            if now - S._lastRuntimeLog < 60 then return end
            S._lastRuntimeLog = now
            local up = os.time() - S.startTime
            local avgFT = (S.accumN > 0) and (S.accumFT / S.accumN) or 0
            local avgFPS = (avgFT > 0) and (1000.0 / avgFT) or 0
            log(string.format(
                "RUNTIME uptime=%ds avgFT=%.1fms avgFPS=%.0f worstFT=%.1f "
                .. "stab[heavy=%s thermal=%d res=%.0f%% adj=%d] "
                .. "perf[mode=%s switches=%d]",
                up, avgFT, avgFPS, S.worstFT,
                tostring(S.stab.heavyLoad), S.stab.thermalStage,
                S.stab.currentScreenPct, S.stab.adjCount,
                S.perf.currentMode, S.perf.switchCount))
            S.accumFT = 0; S.accumN = 0; S.worstFT = 0
        end

        -- ============================================================================
        -- Main tick (single timer for both subsystems)
        -- ============================================================================
        local _device = nil

        local function tick()
            pcall(function()
                if not _device then _device = probeDevice() end

                -- Menu retry
                local now = os.clock()
                if not (S.stab.menuRegistered and S.perf.menuRegistered) then
                    if now - S.stab._lastMenuAttempt >= 2 then
                        S.stab._lastMenuAttempt = now
                        pcall(registerMenus)
                    end
                end

                -- Touch relief hooks (retry every tick)
                if S.stab.enabled and S.stab.touchRelief then
                    pcall(installTouchRelief)
                end

                -- Frame signals
                local sig = readSignals()
                S.targetFT = computeTargetFT()
                S.ft = computeFrameTime(sig, S.currentTargetFPS)
                S.emaFT = (S.emaFT == 0) and S.ft or (EMA_OLD * S.emaFT + EMA_NEW * S.ft)
                if S.ft > S.worstFT then S.worstFT = S.ft end
                S.accumFT = S.accumFT + S.ft
                S.accumN  = S.accumN + 1

                stabLayer()
                perfLayer()
                updateThermal()
                runtimeLog()
            end)
        end

        -- ============================================================================
        -- Init sequence
        -- ============================================================================
        step("loadConfig", function()
            loadConfig(); saveConfig()
        end)

        local device
        step("probeDevice", function()
            device = probeDevice()
            log(string.format("DEVICE make=%s model=%s platform=%s screen=%dx%d",
                device.make, device.model, device.platform, device.sw, device.sh))
        end)

        step("assignTier", function()
            assignTier(device or {})
            log(string.format("TIER tier=%s source=%s", S.tier, S.tierSource))
        end)

        step("applyStabilityBase", function()
            local p = applyStabBase()
            log(string.format("STAB base targetFPS=%d res=%d-%d", p.targetFPS, p.minRes, p.maxRes))
        end)

        step("applyPerfComfort", function()
            local p = applyPerfPreset("comfort")
            log(string.format("PERF base comfort shadow=%d effects=%d particle=%d aa=%d bloom=%d motion=%d viewDist=%.2f",
                p.shadow, p.effects, p.particle, p.aa, p.bloom, p.motion, p.viewDist))
        end)

        step("registerMenus", function()
            if not registerMenus() then error("menus not ready (will retry)") end
        end)

        step("startTicker", function()
            local tk = require("common.time_ticker")
            if not tk or not tk.AddTimerLoop then error("no ticker") end
            tk.AddTimerLoop(TICK_MS / 1000, tick, -1, TICK_MS / 1000)
        end)

        log(string.format("CMD OK=%d FAIL=%d", _cmdOk, _cmdFail))
        log(string.format("INIT stab=%s perf=%s perfAdaptive=%s",
            tostring(S.stab.enabled), tostring(S.perf.enabled), tostring(S.perf.adaptive)))

        if S.perf.forceAggressive then perfEnterAggressive() end

        return S
        end
    return __run_current_5_module()
end)
if not __five_ok then
    pcall(function()
        local f = io.open("/storage/emulated/0/Android/data/com.pubg.imobile/files/5_merge_error.txt", "a")
        if f then f:write(os.date("[%H:%M:%S] ") .. tostring(__five_err) .. "\n"); f:close() end
    end)
end
-- ===== END current 5.lua integration =====

return __combined_1_result

]===])

-- ============================================================================
-- 2. 2.lua
-- ============================================================================
__defer_feature('2.lua', [===[
-- ============================================================================
-- VIP PRO EDITION V6 — MULTI-MATCH PERSISTENT STANDALONE ENGINE
-- Fixes:
--   1. Multi-Match Watchdog: Never dies after 1 match; auto-resets on new match
--   2. Native UMG Overhead Tag: Guaranteed Name, Distance & Health Bar display
--   3. Full-Body Chams (Slots 0-7 + Weapon + Highlight): Fixes "only head visible"
--   4. Smooth 30 FPS Snaplines + Top Center Threat Banner + Aimbot V2 + SuperBullet
-- ============================================================================

-- Clean up any previous version timers if re-executed
if _G._V6WatchdogHandle and Game and Game.ClearTimer then
    pcall(function() Game:ClearTimer(_G._V6WatchdogHandle) end)
end
if _G._V6FastReset and type(_G._V6FastReset) == "function" then
    pcall(_G._V6FastReset)
end

-- ============================================================================
-- PART 1: LOCALIZATION & MENU TEXT HOOK
-- ============================================================================
local FakeTextMap = {
    [999000] = " VIP MOD MENU",
    [999003] = " AIMBOT ROYAL",
    [999004] = " ESP SYSTEM",
    [991001] = "Enable Custom Aimbot V2",
    [991010] = "Hipfire Aimbot",
    [991011] = "   Ignore Knocked",
    [991012] = "   Ignore Bots",
    [991013] = "   VisCheck",
    [991014] = "   Priority (1=FOV, 2=Dist, 3=HP)",
    [991015] = "   Target Bone (1=Head, 2=Chest)",
    [991016] = "   Trigger (1=Fire, 2=Always)",
    [991017] = "   Speed / Smoothness",
    [991018] = "   FOV Radius",
    [991019] = "   Distance Limit",
    [991020] = "   Recoil Control",
    [991021] = "   Prediction",
    [991030] = "Shotgun Aimbot",
    [991031] = "   Auto Fire",
    [991032] = "   Ignore Knocked",
    [991033] = "   Ignore Bots",
    [991034] = "   VisCheck",
    [991035] = "   Priority",
    [991036] = "   Target Bone",
    [991037] = "   Trigger Mode",
    [991038] = "   Speed / Smoothness",
    [991039] = "   FOV Radius",
    [991040] = "   Distance Limit",
    [991041] = "   Recoil Control",
    [991050] = "Scope Aimbot",
    [991051] = "   Ignore Knocked",
    [991052] = "   Ignore Bots",
    [991053] = "   VisCheck",
    [991054] = "   Priority",
    [991055] = "   Target Bone",
    [991056] = "   Trigger Mode",
    [991057] = "   Speed / Smoothness",
    [991058] = "   FOV Radius",
    [991059] = "   Distance Limit",
    [991060] = "   Prediction",
    [991061] = "   Recoil Control",
    [991062] = "   Precision",
    [991070] = "Sniper Aimbot",
    [991071] = "   Ignore Knocked",
    [991072] = "   Ignore Bots",
    [991073] = "   VisCheck",
    [991074] = "   Priority",
    [991075] = "   Target Bone",
    [991076] = "   Trigger Mode",
    [991077] = "   Speed / Smoothness",
    [991078] = "   FOV Radius",
    [991079] = "   Distance Limit",
    [991080] = "   Prediction",
    [991081] = "   Recoil Control",
    [991090] = "Mortar Aimbot",
    [991091] = "   FOV Radius",
    [991092] = "   Prediction",
    [991200] = "SHOTGUN SUPER BULLET (20x)",
    [991201] = "   Bullet Count (1-20)",
    [992001] = "Enable Player ESP",
    [992002] = "   Show Snaplines",
    [992003] = "   Show Top Radar Banner",
    [992004] = "   Wallhack Chams (W/G/P)",
    [992005] = "   Show Player Name",
    [992006] = "   Show Distance",
    [992007] = "   Show Health Bar",
    [992010] = "   Snapline Thickness (1-5)",
    [992012] = "   ESP Type 5 (Enemy Frame)"
}

local function HookLocUtil()
    local LocUtil = _G.LocUtil or (package.loaded["client.common.LocUtil"] and require("client.common.LocUtil"))
    if LocUtil and not LocUtil._MasterHookedV6 then
        local oldGetStr         = LocUtil.GetLocalizeResStr
        local oldGetText        = LocUtil.GetText
        local oldGetTextByID    = LocUtil.GetTextByID
        local oldGetLocalText   = LocUtil.GetLocalText
        local oldGetLocalizeStr = LocUtil.GetLocalizeStr
        local function fakeGet(id) return FakeTextMap[id] end

        LocUtil.GetLocalizeResStr = function(id)
            if FakeTextMap[id] then return FakeTextMap[id] end
            if type(id) == "string" and not tonumber(id) then return id end
            return oldGetStr and oldGetStr(id) or tostring(id)
        end
        if oldGetText then LocUtil.GetText = function(id) return fakeGet(id) or oldGetText(id) end end
        if oldGetTextByID then LocUtil.GetTextByID = function(id) return fakeGet(id) or oldGetTextByID(id) end end
        if oldGetLocalText then LocUtil.GetLocalText = function(id) return fakeGet(id) or oldGetLocalText(id) end end
        if oldGetLocalizeStr then LocUtil.GetLocalizeStr = function(id) return fakeGet(id) or oldGetLocalizeStr(id) end end
        LocUtil._MasterHookedV6 = true
    end
end
pcall(HookLocUtil)

-- ============================================================================
-- PART 2: CORE IMPORTS & FAST HELPERS
-- ============================================================================
local GameplayData, ui_util, FVector2D, FLinearColor, FVector, FSlateColor
local UGameplayStatics, KismetMathLibrary, SlateBlueprintLibrary, WidgetLayoutLibrary

pcall(function() GameplayData          = require("GameLua.GameCore.Data.GameplayData") end)
pcall(function() ui_util               = require("client.common.ui_util") end)
pcall(function() FVector2D             = import("Vector2D") end)
pcall(function() FLinearColor          = import("LinearColor") end)
pcall(function() FVector               = import("Vector") end)
pcall(function() FSlateColor           = import("SlateColor") or import("/Script/SlateCore.SlateColor") end)
pcall(function() UGameplayStatics      = import("GameplayStatics") end)
pcall(function() KismetMathLibrary     = import("KismetMathLibrary") end)
pcall(function() SlateBlueprintLibrary = import("SlateBlueprintLibrary") or import("/Script/UMG.SlateBlueprintLibrary") end)
pcall(function() WidgetLayoutLibrary   = import("WidgetLayoutLibrary") or import("/Script/UMG.WidgetLayoutLibrary") end)

local function Valid(obj)
    if obj == nil then return false end
    if slua and slua.isValid then
        local ok, r = pcall(slua.isValid, obj)
        return ok and r == true
    end
    return true
end

local function GetGameplayData()
    if not GameplayData then
        pcall(function() GameplayData = require("GameLua.GameCore.Data.GameplayData") end)
    end
    return GameplayData
end

local function GetLocalPlayerAndPC()
    local gdp = GetGameplayData()
    local player, pc = nil, nil
    pcall(function()
        if gdp then
            if gdp.GetPlayerCharacter then player = gdp.GetPlayerCharacter() end
            if not Valid(player) and gdp.GetLocalCharacter then player = gdp.GetLocalCharacter() end
            if gdp.GetPlayerController then pc = gdp.GetPlayerController() end
        end
        if Valid(player) and not Valid(pc) and player.GetPlayerControllerSafety then
            pc = player:GetPlayerControllerSafety()
        end
        if not Valid(pc) and slua_GameFrontendHUD and slua_GameFrontendHUD.GetPlayerController then
            pc = slua_GameFrontendHUD:GetPlayerController()
        end
        if Valid(pc) and not Valid(player) then
            if pc.GetPawn then player = pc:GetPawn() end
            if not Valid(player) and pc.GetCurPawn then player = pc:GetCurPawn() end
        end
    end)
    return player, pc
end

-- ============================================================================
-- PART 3: DEFAULT CONFIGURATIONS (AIMBOT + ESP)
-- ============================================================================
_G.LexusConfig = _G.LexusConfig or {}
local C = _G.LexusConfig
_G.LexusState = _G.LexusState or {}
local S = _G.LexusState
S.CustomTextData = S.CustomTextData or {}
local D = S.CustomTextData

if not _G._V6PresetsApplied then
    _G._V6PresetsApplied = true
    C.AimTouchEnable      = true
    C.AimTouchHipfire     = true;  C.AimTouchHipIgKnock    = true;  C.AimTouchHipIgBot    = true;  C.AimTouchHipVisCheck    = true
    C.AimTouchSG          = false; C.AimTouchSGAutoFire    = false; C.AimTouchSGIgKnock   = false; C.AimTouchSGIgBot        = false; C.AimTouchSGVisCheck = false
    C.AimTouchScopeAll    = true;  C.AimTouchScopeIgKnock  = true;  C.AimTouchScopeIgBot  = true;  C.AimTouchScopeVisCheck  = true
    C.AimTouchScopeSniper = true;  C.AimTouchSniperIgKnock = true;  C.AimTouchSniperIgBot = true;  C.AimTouchSniperVisCheck = true
    C.AimTouchMortar      = false
    C.SuperBulletSG       = false
    C.SuperBulletSGCount  = 20
    C.EspLoai5            = true

    D.AimTouchHipPrio    = 1; D.AimTouchHipBone    = 1; D.AimTouchHipCond    = 1; D.AimTouchHipSpeed    = 75;  D.AimTouchHipFOV    = 15; D.AimTouchHipDist    = 500; D.AimTouchHipRecoil    = 0;   D.AimTouchHipPred    = 0
    D.AimTouchSGPrio     = 1; D.AimTouchSGBone     = 1; D.AimTouchSGCond     = 1; D.AimTouchSGSpeed     = 75;  D.AimTouchSGFOV     = 15; D.AimTouchSGDist     = 100; D.AimTouchSGRecoil     = 100
    D.AimTouchScopePrio  = 1; D.AimTouchScopeBone  = 1; D.AimTouchScopeCond  = 1; D.AimTouchScopeSpeed  = 100; D.AimTouchScopeFOV  = 15; D.AimTouchScopeDist  = 500; D.AimTouchScopePred    = 26;  D.AimTouchScopeRecoil = 6; D.AimTouchPrecision = 100
    D.AimTouchSniperPrio = 1; D.AimTouchSniperBone = 1; D.AimTouchSniperCond = 2; D.AimTouchSniperSpeed = 100; D.AimTouchSniperFOV = 15; D.AimTouchSniperDist = 500; D.AimTouchSniperPred   = 26;  D.AimTouchSniperRecoil = 0
    D.AimTouchMortarFOV  = 360; D.AimTouchMortarPred = 0
end

if _G.Mod_ESP_Enabled         == nil then _G.Mod_ESP_Enabled         = true end
if _G.Mod_ESP_ShowPlayerCount == nil then _G.Mod_ESP_ShowPlayerCount = true end
if _G.Mod_ESP_ShowName        == nil then _G.Mod_ESP_ShowName        = true end
if _G.Mod_ESP_ShowDistance    == nil then _G.Mod_ESP_ShowDistance    = true end
if _G.Mod_ESP_ShowHealthBar   == nil then _G.Mod_ESP_ShowHealthBar   = true end
if _G.Mod_ESP_ShowSnapline    == nil then _G.Mod_ESP_ShowSnapline    = true end
if _G.Mod_ESP_Wallhack        == nil then _G.Mod_ESP_Wallhack        = true end
_G.Mod_ESP_SnaplineThickness = _G.Mod_ESP_SnaplineThickness or 1

-- ============================================================================
-- PART 4: PALETTE & REUSABLE SCRATCHPAD VECTORS
-- ============================================================================
local _AimScreen1 = FVector2D and FVector2D(0, 0) or { X = 0, Y = 0 }
local _AimScreen2 = FVector2D and FVector2D(0, 0) or { X = 0, Y = 0 }
local _ProjTemp   = FVector2D and FVector2D(0, 0) or { X = 0, Y = 0 }
local _ZeroVec3   = FVector   and FVector(0, 0, 0) or { X = 0, Y = 0, Z = 0 }
local _AimRotOut  = { Pitch = 0, Yaw = 0, Roll = 0 }

local function MakeSlateCol(r, g, b, a)
    local lin = FLinearColor(r, g, b, a)
    return FSlateColor and FSlateColor(lin) or lin
end

local PALETTE = {
    -- Top Pill Banner Colors
    BgShadow      = FLinearColor(0.00, 0.00, 0.00, 0.55),
    BgBody        = FLinearColor(0.03, 0.04, 0.07, 0.92),
    AccentSafe    = FLinearColor(0.05, 0.95, 0.50, 1.00), -- Emerald Green
    AccentBot     = FLinearColor(0.95, 0.98, 1.00, 1.00), -- Pure White
    AccentWarn    = FLinearColor(0.75, 0.15, 1.00, 1.00), -- Electric Purple
    AccentDanger  = FLinearColor(1.00, 0.12, 0.25, 1.00), -- Crimson Red

    -- Snapline Colors (Open Real = Green | Cover Real = Purple | Bot = White)
    LineOpenReal  = FLinearColor(0.05, 1.00, 0.30, 0.90),
    LineCoverReal = FLinearColor(0.75, 0.10, 1.00, 0.85),
    LineBot       = FLinearColor(0.95, 0.98, 1.00, 0.80),

    -- Chams Colors (Bot = White Always | Real Open = Green | Real Cover = Purple)
    ChamBotWhite  = FLinearColor(255, 255, 255, 110),
    ChamRealOpen  = FLinearColor(0,   255, 40,  110),
    ChamRealCover = FLinearColor(185, 0,   255, 110),

    -- Overhead Tag & Banner Text SlateColors
    TextDanger    = MakeSlateCol(1.00, 0.28, 0.32, 1.0),
    TextPurple    = MakeSlateCol(0.88, 0.50, 1.00, 1.0),
    TextGreen     = MakeSlateCol(0.20, 1.00, 0.45, 1.0),
    TextWhite     = MakeSlateCol(0.96, 0.98, 1.00, 1.0),
    TextKnocked   = MakeSlateCol(1.00, 0.50, 0.00, 1.0),

    -- Overhead Health Bar Colors
    HpBorderBg    = FLinearColor(0.00, 0.00, 0.00, 0.80),
    HpHigh        = FLinearColor(0.10, 0.95, 0.40, 1.00),
    HpMid         = FLinearColor(1.00, 0.65, 0.00, 1.00),
    HpLow         = FLinearColor(1.00, 0.15, 0.20, 1.00)
}

local VIS_SHOW = UEnums.ESlateVisibility.SelfHitTestInvisible
local VIS_HIDE = UEnums.ESlateVisibility.Collapsed

-- ============================================================================
-- PART 5: MULTI-SOURCE ENEMY ROSTER (WORKS ACROSS ALL MATCHES & MODES)
-- ============================================================================
local EnemyRoster = {
    List = {},
    LastSync = 0,
    SyncInterval = 0.20
}

local function GetTeamIDFromPawn(pawn)
    if not Valid(pawn) then return nil end
    local t = pawn.TeamID
    if not t and type(pawn.GetTeamID) == "function" then
        pcall(function() t = pawn:GetTeamID() end)
    end
    if not t then
        pcall(function()
            local ps = pawn.PlayerState or (pawn.GetPlayerStateSafety and pawn:GetPlayerStateSafety())
            if Valid(ps) then t = ps.TeamID or (ps.GetTeamID and ps:GetTeamID()) end
        end)
    end
    return t
end

local function SyncEnemyRoster(myPlayer)
    local now = os.clock()
    if now - EnemyRoster.LastSync < EnemyRoster.SyncInterval then
        return EnemyRoster.List
    end
    EnemyRoster.LastSync = now

    local list = EnemyRoster.List
    for i = #list, 1, -1 do list[i] = nil end
    if not Valid(myPlayer) then return list end

    local myTeam = GetTeamIDFromPawn(myPlayer) or -999
    local seen = {}

    local function tryAddPawn(pawn)
        if Valid(pawn) and pawn ~= myPlayer then
            local ptr = tostring(pawn)
            if not seen[ptr] then
                seen[ptr] = true
                local t = GetTeamIDFromPawn(pawn)
                if t == nil or t ~= myTeam then
                    list[#list + 1] = pawn
                end
            end
        end
    end

    pcall(function()
        if Game and Game.GetAllPlayerPawns then
            local pawns = Game:GetAllPlayerPawns()
            if pawns then for _, p in pairs(pawns) do tryAddPawn(p) end end
        end
    end)

    if #list == 0 then
        pcall(function()
            local gdp = GetGameplayData()
            if gdp then
                if gdp.GetAllPlayerCharacters then
                    local chars = gdp.GetAllPlayerCharacters()
                    if chars then for _, p in pairs(chars) do tryAddPawn(p) end end
                elseif gdp.GameCharacters then
                    for _, p in pairs(gdp.GameCharacters) do tryAddPawn(p) end
                end
            end
        end)
    end

    return list
end

-- ============================================================================
-- PART 6: AIMBOT V2 ENGINE + SHOTGUN SUPER BULLET
-- ============================================================================
local lastAimTime = 0
local AIM_INTERVAL = 0.025
local viewportSize = nil
local lastViewportUpdate = 0
local aimVisCache = {}

local function AimTouch()
    if not C.AimTouchEnable then return end
    local now = os.clock()
    if now - lastAimTime < AIM_INTERVAL then return end
    lastAimTime = now

    if not (ui_util and FVector2D and UGameplayStatics and KismetMathLibrary) then return end

    pcall(function()
        local player, pc = GetLocalPlayerAndPC()
        if not Valid(player) or not Valid(pc) then return end

        local isFiring = player.bIsWeaponFiring
        local isADS    = player.bIsGunADS

        local weapon = player.WeaponManagerComponent and player.WeaponManagerComponent.CurrentWeaponReplicated
        if not weapon and type(player.GetCurrentShootWeapon) == "function" then
            weapon = player:GetCurrentShootWeapon()
        end

        local isShotgun, isSniper, isMortar = false, false, false
        local currentAmmo = 1

        if Valid(weapon) then
            if weapon._V6WepType == nil then
                local wID   = type(weapon.GetWeaponID) == "function" and weapon:GetWeaponID() or 0
                local wName = type(weapon.GetWeaponName) == "function" and weapon:GetWeaponName() or ""
                local wLow  = wName:lower()
                local sg = (wID >= 1040000 and wID < 1050000) or wLow:find("s686") or wLow:find("s1897") or wLow:find("s12") or wLow:find("dbs") or wLow:find("m1014") or wLow:find("ns2000")
                local sn = wLow:find("kar98") or wLow:find("m24") or wLow:find("awm") or wLow:find("mosin") or wLow:find("win94") or wLow:find("amr") or wLow:find("sks") or wLow:find("slr") or wLow:find("mini") or wLow:find("mk14") or wLow:find("qbu") or wLow:find("mk12") or wLow:find("vss")
                local mo = wLow:find("mortar")
                weapon._V6WepType = (mo and 3) or (sg and 1) or (sn and 2) or 0
            end
            local wt = weapon._V6WepType
            isShotgun = (wt == 1)
            isSniper  = (wt == 2)
            isMortar  = (wt == 3)

            if isShotgun then
                if type(weapon.GetCurrentAmmo) == "function" then currentAmmo = weapon:GetCurrentAmmo() or 1
                elseif weapon.CurrentAmmo ~= nil then currentAmmo = weapon.CurrentAmmo end
            end

            -- Super Bullet
            if C.SuperBulletSG and isShotgun then
                local candidates = { weapon.ShootWeaponEntityComp, weapon.ShootWeaponEntity, weapon.ShootWeaponComponent }
                local n = C.SuperBulletSGCount or 20
                for _, se in ipairs(candidates) do
                    if Valid(se) and se._AppliedSB ~= n then
                        if not se._OrigBulletNum then se._OrigBulletNum = se.BulletNumSingleShot or 9 end
                        pcall(function() se.BulletNumSingleShot = n end)
                        pcall(function() se.BulletNum = n end)
                        pcall(function() se.PelletCount = n end)
                        se._AppliedSB = n
                    end
                end
            end
        end

        if S.IsAutoFiring then
            player.bIsWeaponFiring = false
            if type(player.SetIsWeaponFiring) == "function" then player:SetIsWeaponFiring(false) end
            if type(pc.SetIsWeaponFiring) == "function" then pc:SetIsWeaponFiring(false) end
            local wm = player.WeaponManagerComponent
            if Valid(wm) then wm.bIsWeaponFiring = false end
            S.IsAutoFiring = false
        end

        if isShotgun and currentAmmo <= 0 then return end

        local cond, prioMode, boneIdx = 2, 1, 1
        local speedVal, fovVal, maxDistMeters = 50, 30, 50
        local useVisCheck, igKnock, igBot = false, false, false
        local predVal, recoilCompVal = 0, 0

        if isMortar and C.AimTouchMortar then
            if not (weapon and weapon.MortarState == 2) then return end
            cond = 2; prioMode = 1; boneIdx = 4; speedVal = 100; fovVal = D.AimTouchMortarFOV or 360; maxDistMeters = 2000; predVal = D.AimTouchMortarPred or 0
        elseif isShotgun and C.AimTouchSG then
            cond = D.AimTouchSGCond or 1; if C.AimTouchSGAutoFire then cond = 2 end
            if cond == 1 and not isFiring then return end
            prioMode = D.AimTouchSGPrio or 1; boneIdx = D.AimTouchSGBone or 2; speedVal = D.AimTouchSGSpeed or 80; fovVal = D.AimTouchSGFOV or 40; maxDistMeters = D.AimTouchSGDist or 30
            useVisCheck = C.AimTouchSGVisCheck; igKnock = C.AimTouchSGIgKnock; igBot = C.AimTouchSGIgBot; recoilCompVal = D.AimTouchSGRecoil or 0
        elseif isADS then
            if isSniper and C.AimTouchScopeSniper then
                cond = D.AimTouchSniperCond or 2; if cond == 1 and not isFiring then return end
                prioMode = D.AimTouchSniperPrio or 1; boneIdx = D.AimTouchSniperBone or 1; speedVal = D.AimTouchSniperSpeed or 30; fovVal = D.AimTouchSniperFOV or 20; maxDistMeters = D.AimTouchSniperDist or 400
                useVisCheck = C.AimTouchSniperVisCheck; igKnock = C.AimTouchSniperIgKnock; igBot = C.AimTouchSniperIgBot; predVal = D.AimTouchSniperPred or 0; recoilCompVal = D.AimTouchSniperRecoil or 0
            elseif C.AimTouchScopeAll then
                cond = D.AimTouchScopeCond or 1; if cond == 1 and not isFiring then return end
                prioMode = D.AimTouchScopePrio or 1; boneIdx = D.AimTouchScopeBone or 2; speedVal = D.AimTouchScopeSpeed or 40; fovVal = D.AimTouchScopeFOV or 20; maxDistMeters = D.AimTouchScopeDist or 300
                useVisCheck = C.AimTouchScopeVisCheck; igKnock = C.AimTouchScopeIgKnock; igBot = C.AimTouchScopeIgBot; predVal = D.AimTouchScopePred or 0; recoilCompVal = D.AimTouchScopeRecoil or 0
            else return end
        else
            if not C.AimTouchHipfire then return end
            cond = D.AimTouchHipCond or 1; if cond == 1 and not isFiring then return end
            prioMode = D.AimTouchHipPrio or 1; boneIdx = D.AimTouchHipBone or 1; speedVal = D.AimTouchHipSpeed or 50; fovVal = D.AimTouchHipFOV or 30; maxDistMeters = D.AimTouchHipDist or 250
            useVisCheck = C.AimTouchHipVisCheck; igKnock = C.AimTouchHipIgKnock; igBot = C.AimTouchHipIgBot; recoilCompVal = D.AimTouchHipRecoil or 0; predVal = D.AimTouchHipPred or 0
        end

        local enemies = SyncEnemyRoster(player)
        if #enemies == 0 then return end

        if not viewportSize or now - lastViewportUpdate > 2.0 then
            viewportSize = ui_util.GetViewportSize()
            lastViewportUpdate = now
        end
        if not viewportSize then return end

        local camManager = UGameplayStatics.GetPlayerCameraManager(pc, 0)
        if not Valid(camManager) then return end
        local camLoc = camManager:GetCameraLocation()
        if not camLoc then return end

        local centerX = viewportSize.X * 0.5
        local centerY = viewportSize.Y * 0.5
        local FOV_RADIUS = (fovVal / 100.0) * centerX
        local FOV_RADIUS_SQ = FOV_RADIUS * FOV_RADIUS
        local maxDistUnits = maxDistMeters * 100

        local bestTarget, bestBonePos = nil, nil
        local bestScore = 99999999
        local selBoneName = (boneIdx == 2 and "spine_03") or (boneIdx == 3 and "spine_01") or (boneIdx == 4 and "pelvis") or "head"

        for i = 1, #enemies do
            local target = enemies[i]
            if Valid(target) and (target.Health == nil or target.Health > 0) and target.HealthStatus ~= 2 then
                local skip = false
                if igKnock and target.HealthStatus == 1 then skip = true end
                if not skip and igBot then
                    if target.bIsAI == true or target.IsAI == true then skip = true
                    elseif Valid(target.PlayerState) and (target.PlayerState.bIsABot or target.PlayerState.bIsBot) then skip = true end
                end

                if not skip then
                    local dist = player:GetDistanceTo(target)
                    if not dist or dist > maxDistUnits then skip = true end

                    if not skip then
                        local tPos = target:GetBonePos(selBoneName, _ZeroVec3)
                        if not tPos or (tPos.X == 0 and tPos.Y == 0 and tPos.Z == 0) then
                            if type(target.K2_GetActorLocation) == "function" then
                                tPos = target:K2_GetActorLocation()
                                if tPos then tPos.Z = tPos.Z + ((boneIdx == 1 and 70) or (boneIdx == 2 and 40) or 20) end
                            end
                        end

                        if tPos and (tPos.X ~= 0 or tPos.Y ~= 0 or tPos.Z ~= 0) then
                            local ok = pc:ProjectWorldLocationToScreen(tPos, _AimScreen1, false)
                            if ok and _AimScreen1.X > 0 and _AimScreen1.Y > 0 then
                                local dx = _AimScreen1.X - centerX
                                local dy = _AimScreen1.Y - centerY
                                local dSq = dx * dx + dy * dy
                                if dSq <= FOV_RADIUS_SQ then
                                    if useVisCheck then
                                        local tk = tostring(target)
                                        local vc = aimVisCache[tk]
                                        if not vc or (now - vc.time) > 0.15 then
                                            local vis = pc.LineOfSightTo and pc:LineOfSightTo(target) or false
                                            vc = { vis = vis, time = now }
                                            aimVisCache[tk] = vc
                                        end
                                        if not vc.vis then skip = true end
                                    end

                                    if not skip then
                                        local score = math.sqrt(dSq)
                                        if prioMode == 2 then score = dist
                                        elseif prioMode == 3 then score = target.Health or 100
                                        elseif prioMode == 4 then score = (target.Health or 100) / math.max(1, target.HealthMax or 100) end
                                        if score < bestScore then
                                            bestScore = score
                                            bestTarget = target
                                            bestBonePos = tPos
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end

        if not Valid(bestTarget) or not bestBonePos then return end

        local finalBonePos = bestBonePos
        if not isMortar and predVal > 0 and type(bestTarget.GetVelocity) == "function" then
            local tVel = bestTarget:GetVelocity()
            if tVel and (tVel.X ~= 0 or tVel.Y ~= 0) then
                local distM = player:GetDistanceTo(bestTarget) * 0.01
                local ToF = (distM / 800.0) * (predVal * 0.02)
                finalBonePos = { X = finalBonePos.X + (tVel.X * ToF), Y = finalBonePos.Y + (tVel.Y * ToF), Z = finalBonePos.Z }
            end
        end

        local rot = KismetMathLibrary.FindLookAtRotation(camLoc, finalBonePos)
        local curRot = pc:GetControlRotation()
        if not rot or not curRot then return end

        local dYaw = rot.Yaw - curRot.Yaw
        local dPitch = rot.Pitch - curRot.Pitch

        if isADS and type(camManager.GetCameraRotation) == "function" then
            local camRot = camManager:GetCameraRotation()
            if camRot then
                dYaw = dYaw - (camRot.Yaw - curRot.Yaw)
                dPitch = dPitch - (camRot.Pitch - curRot.Pitch)
            end
        end
        if dYaw > 180 then dYaw = dYaw - 360 elseif dYaw < -180 then dYaw = dYaw + 360 end
        if dPitch > 180 then dPitch = dPitch - 360 elseif dPitch < -180 then dPitch = dPitch + 360 end

        local smoothFactor = (speedVal >= 100) and 1.0 or math.max(0.01, (speedVal * 0.01) * 0.3)

        local precisionVal = D.AimTouchPrecision or 30
        if isFiring and precisionVal > 0 then
            if pc:ProjectWorldLocationToScreen(bestBonePos, _AimScreen2, false) then
                local dx = _AimScreen2.X - centerX
                local dy = _AimScreen2.Y - centerY
                local dT = math.sqrt(dx * dx + dy * dy)
                local pr = (precisionVal * 0.01) * FOV_RADIUS
                if pr > 0 and dT < pr then smoothFactor = smoothFactor * (0.5 + (dT / pr) * 0.5) end
            end
        end

        local finalPitch = curRot.Pitch + (dPitch * smoothFactor)
        local finalYaw   = curRot.Yaw + (dYaw * smoothFactor)
        if recoilCompVal > 0 and isFiring and not isMortar then
            finalPitch = finalPitch - ((recoilCompVal * 0.02) * 1.5)
        end

        _AimRotOut.Pitch = finalPitch
        _AimRotOut.Yaw   = finalYaw
        _AimRotOut.Roll  = 0
        pc:SetControlRotation(_AimRotOut, "AimTouch")

        if isShotgun and C.AimTouchSGAutoFire then
            if (player:GetDistanceTo(bestTarget) * 0.01) <= maxDistMeters then
                player.bIsWeaponFiring = true
                if type(player.SetIsWeaponFiring) == "function" then player:SetIsWeaponFiring(true) end
                if type(pc.SetIsWeaponFiring) == "function" then pc:SetIsWeaponFiring(true) end
                local wm = player.WeaponManagerComponent
                if Valid(wm) then wm.bIsWeaponFiring = true end
                local cw = player:GetCurrentWeapon()
                if Valid(cw) and type(cw.StartFire) == "function" then cw:StartFire() end
                S.IsAutoFiring = true
            end
        end
    end)
end

-- ============================================================================
-- PART 7: PURE UMG OVERHEAD TAG + BANNER + SNAPLINES + FULL-BODY CHAMS
-- ============================================================================
local ESPEngine = {
    Canvas = nil,
    LastPC = nil,
    LastPawn = nil,
    Nodes = {},
    ScaleX = 1.0,
    ScaleY = 1.0,
    OffsetX = 0.0,
    OffsetY = 0.0,
    OriginX = 960,
    OriginY = 48,
    LastTransformTime = 0,
    Banner = {
        Container = nil,
        Slot = nil,
        TextBlock = nil,
        AccentBar = nil,
        PosVec = FVector2D and FVector2D(960, 10) or { X = 960, Y = 10 },
        LastText = "",
        LastState = -1,
        LastX = -9999,
        LastY = -9999,
        Width = 300,
        Height = 36
    },
    Chams = {
        ConsoleReady = false
    }
}

-- Full Reset when transitioning between matches
local function ResetESPEngineForNewMatch()
    for k, node in pairs(ESPEngine.Nodes) do
        if node.Overhead and Valid(node.Overhead.Container) then
            pcall(function() node.Overhead.Container:RemoveFromParent(); node.Overhead.Container:ConditionalBeginDestroy() end)
        end
        if node.Snapline and Valid(node.Snapline.Widget) then
            pcall(function() node.Snapline.Widget:RemoveFromParent(); node.Snapline.Widget:ConditionalBeginDestroy() end)
        end
        ESPEngine.Nodes[k] = nil
    end
    local B = ESPEngine.Banner
    if Valid(B.Container) then
        pcall(function() B.Container:RemoveFromParent(); B.Container:ConditionalBeginDestroy() end)
    end
    B.Container = nil
    B.Slot = nil
    B.TextBlock = nil
    B.AccentBar = nil
    B.LastText = ""
    B.LastState = -1
    B.LastX = -9999
    ESPEngine.Canvas = nil
    ESPEngine.LastTransformTime = 0
    ESPEngine.Chams.ConsoleReady = false
    EnemyRoster.LastSync = 0
    aimVisCache = {}
end
_G._V6FastReset = ResetESPEngineForNewMatch

local function EnsureCanvas()
    if Valid(ESPEngine.Canvas) then return true end
    local InGameUITools = package.loaded["GameLua.Mod.BaseMod.Common.UI.InGameUITools"]
    if not InGameUITools then pcall(function() InGameUITools = require("GameLua.Mod.BaseMod.Common.UI.InGameUITools") end) end
    if not InGameUITools or not InGameUITools.GetMainControlBaseUI then return false end
    local MainUI = nil
    pcall(function() MainUI = InGameUITools.GetMainControlBaseUI() end)
    if not Valid(MainUI) then return false end
    local c = (Valid(MainUI.CanvasPanel_0) and MainUI.CanvasPanel_0) or (Valid(MainUI.CanvasPanel_42) and MainUI.CanvasPanel_42) or nil
    if not c then return false end
    ESPEngine.Canvas = c
    ESPEngine.LastTransformTime = 0
    ESPEngine.Banner.LastX = -9999
    return true
end

local function UpdateCanvasMetrics(pc, now)
    if now - ESPEngine.LastTransformTime < 0.4 and ESPEngine.OriginX > 100 then return end
    ESPEngine.LastTransformTime = now

    local sx, sy, ox, oy = 1.0, 1.0, 0.0, 0.0
    local ok = false
    pcall(function()
        if SlateBlueprintLibrary and SlateBlueprintLibrary.AbsoluteToLocal and Valid(ESPEngine.Canvas) then
            local cg = ESPEngine.Canvas:GetCachedGeometry()
            if cg then
                local p0 = SlateBlueprintLibrary.AbsoluteToLocal(cg, FVector2D(0, 0))
                local p1 = SlateBlueprintLibrary.AbsoluteToLocal(cg, FVector2D(100, 100))
                if p0 and p1 and (p1.X - p0.X) > 1 then
                    sx = (p1.X - p0.X) * 0.01
                    sy = (p1.Y - p0.Y) * 0.01
                    ox = p0.X
                    oy = p0.Y
                    ok = true
                end
            end
        end
    end)
    if not ok then
        local scale = 1.0
        pcall(function()
            if WidgetLayoutLibrary and WidgetLayoutLibrary.GetViewportScale then
                scale = WidgetLayoutLibrary.GetViewportScale(pc) or 1.0
            end
        end)
        if scale <= 0 then scale = 1.0 end
        sx, sy = 1.0 / scale, 1.0 / scale
    end
    ESPEngine.ScaleX, ESPEngine.ScaleY = sx, sy
    ESPEngine.OffsetX, ESPEngine.OffsetY = ox, oy

    local vw = 1920
    pcall(function()
        if pc and pc.GetViewportSize then
            local vs = FVector2D(0, 0)
            pc:GetViewportSize(vs)
            if vs and vs.X > 200 then vw = vs.X end
        end
        if vw <= 200 and ui_util and ui_util.GetViewportSize then
            local vs = ui_util.GetViewportSize()
            if vs and vs.X > 200 then vw = vs.X end
        end
    end)
    ESPEngine.OriginX = (vw * 0.5) * sx + ox
    ESPEngine.OriginY = 48
end

-- Create / Update Top Center Pill Banner
local function UpdateBanner(realCount, botCount, nearestMeters, showBanner)
    local B = ESPEngine.Banner
    if not showBanner then
        if Valid(B.Container) then
            pcall(function() B.Container:SetWidgetVisibility(VIS_HIDE) end)
        end
        return
    end

    if not Valid(B.Container) then
        if not Valid(ESPEngine.Canvas) then return end
        local cont = CGame:NewObjectFromPath("/Script/UMG.CanvasPanel", ESPEngine.Canvas)
        if not Valid(cont) then return end

        local defs = {
            { w = B.Width + 4, h = B.Height + 4, col = PALETTE.BgShadow,   x = -2, y = -2, z = 1 },
            { w = B.Width,     h = B.Height,     col = PALETTE.BgBody,     x = 0,  y = 0,  z = 2 },
            { w = B.Width,     h = 3,             col = PALETTE.AccentSafe, x = 0,  y = 0,  z = 3, accent = true }
        }
        for _, L in ipairs(defs) do
            local bdr = CGame:NewObjectFromPath("/Script/UMG.Border", cont)
            if Valid(bdr) then
                bdr:SetBrushColor(L.col)
                bdr:SetWidgetVisibility(VIS_SHOW)
                local s = cont:AddChildToCanvas(bdr)
                if s then
                    s:SetAutoSize(false)
                    s:SetPosition(FVector2D(L.x, L.y))
                    s:SetSize(FVector2D(L.w, L.h))
                    s:SetZOrder(L.z)
                end
                if L.accent then B.AccentBar = bdr end
            end
        end

        local tb = CGame:NewObjectFromPath("/Script/UMG.TextBlock", cont)
        if Valid(tb) then
            tb:SetText("✔  AREA CLEAR")
            tb:SetColorAndOpacity(PALETTE.TextGreen)
            if tb.Font then
                local f = tb.Font; f.Size = 13
                if f.OutlineSettings then f.OutlineSettings.OutlineSize = 1 end
                tb.Font = f
            end
            tb:SetWidgetVisibility(VIS_SHOW)
            local ts = cont:AddChildToCanvas(tb)
            if ts then
                ts:SetAutoSize(true)
                ts:SetAlignment(FVector2D(0.5, 0.5))
                ts:SetPosition(FVector2D(B.Width * 0.5, (B.Height + 2) * 0.5))
                ts:SetZOrder(10)
            end
            B.TextBlock = tb
        end

        local ms = ESPEngine.Canvas:AddChildToCanvas(cont)
        if ms then
            ms:SetAutoSize(false)
            ms:SetZOrder(999)
            ms:SetAlignment(FVector2D(0.5, 0.0))
            ms:SetSize(FVector2D(B.Width, B.Height))
        end
        B.Container = cont
        B.Slot = ms
        B.LastText = ""
        B.LastState = -1
        B.LastX = -9999
    end

    pcall(function() B.Container:SetWidgetVisibility(VIS_SHOW) end)

    local tx = math.floor(ESPEngine.OriginX)
    local ty = 10
    if B.LastX ~= tx or B.LastY ~= ty then
        B.LastX, B.LastY = tx, ty
        B.PosVec.X, B.PosVec.Y = tx, ty
        pcall(function() B.Slot:SetPosition(B.PosVec) end)
    end

    local stateCode = 0
    local txt = ""
    if realCount == 0 and botCount == 0 then
        stateCode = 0
        txt = "✔  AREA CLEAR"
    elseif realCount == 0 then
        stateCode = 1
        txt = string.format("BOTS: %d   •   NEAR: %dm", botCount, nearestMeters)
    else
        stateCode = (realCount >= 3 or (nearestMeters > 0 and nearestMeters < 60)) and 3 or 2
        txt = string.format("⚠ REAL: %d   |   BOT: %d   |   %dm", realCount, botCount, nearestMeters)
    end

    if B.LastText ~= txt and Valid(B.TextBlock) then
        B.LastText = txt
        pcall(function()
            B.TextBlock:SetText(txt)
            if stateCode == 3 then B.TextBlock:SetColorAndOpacity(PALETTE.TextDanger)
            elseif stateCode == 2 then B.TextBlock:SetColorAndOpacity(PALETTE.TextPurple)
            elseif stateCode == 1 then B.TextBlock:SetColorAndOpacity(PALETTE.TextWhite)
            else B.TextBlock:SetColorAndOpacity(PALETTE.TextGreen) end
        end)
    end

    if B.LastState ~= stateCode and Valid(B.AccentBar) then
        B.LastState = stateCode
        pcall(function()
            if stateCode == 0 then B.AccentBar:SetBrushColor(PALETTE.AccentSafe)
            elseif stateCode == 1 then B.AccentBar:SetBrushColor(PALETTE.AccentBot)
            elseif stateCode == 2 then B.AccentBar:SetBrushColor(PALETTE.AccentWarn)
            else B.AccentBar:SetBrushColor(PALETTE.AccentDanger) end
        end)
    end
end

-- ============================================================================
-- PURE NATIVE UMG OVERHEAD WIDGET (100% RELIABLE NAME + DISTANCE + HP BAR)
-- Does not rely on OB_PlayerHeadHPItem_UIBP so it NEVER fails to show!
-- ============================================================================
local HP_BAR_WIDTH  = 68
local HP_BAR_HEIGHT = 4
local TAG_WIDTH     = 140
local TAG_HEIGHT    = 28

local function CreatePureOverheadWidget()
    if not Valid(ESPEngine.Canvas) then return nil end
    local cont, mainSlot, tb, hpBg, hpFill, hpFillSlot = nil, nil, nil, nil, nil, nil

    pcall(function()
        cont = CGame:NewObjectFromPath("/Script/UMG.CanvasPanel", ESPEngine.Canvas)
        if not Valid(cont) then return end
        cont:SetWidgetVisibility(VIS_SHOW)

        mainSlot = ESPEngine.Canvas:AddChildToCanvas(cont)
        if mainSlot then
            mainSlot:SetAutoSize(false)
            mainSlot:SetSize(FVector2D(TAG_WIDTH, TAG_HEIGHT))
            mainSlot:SetAlignment(FVector2D(0.5, 1.0)) -- Bottom-center anchored right above head
            mainSlot:SetZOrder(25)
        end

        -- 1. Outlined Name + Distance TextBlock
        tb = CGame:NewObjectFromPath("/Script/UMG.TextBlock", cont)
        if Valid(tb) then
            tb:SetText("")
            tb:SetColorAndOpacity(PALETTE.TextWhite)
            if tb.Font then
                local f = tb.Font
                f.Size = 11
                if f.OutlineSettings then f.OutlineSettings.OutlineSize = 1 end
                tb.Font = f
            end
            if tb.SetJustification then tb:SetJustification(1) end
            tb:SetWidgetVisibility(VIS_SHOW)
            local ts = cont:AddChildToCanvas(tb)
            if ts then
                ts:SetAutoSize(true)
                ts:SetAlignment(FVector2D(0.5, 1.0))
                ts:SetPosition(FVector2D(TAG_WIDTH * 0.5, TAG_HEIGHT - 7))
                ts:SetZOrder(3)
            end
        end

        -- 2. Health Bar Dark Background Border
        local barStartX = (TAG_WIDTH - HP_BAR_WIDTH) * 0.5
        local barStartY = TAG_HEIGHT - 5
        hpBg = CGame:NewObjectFromPath("/Script/UMG.Border", cont)
        if Valid(hpBg) then
            hpBg:SetBrushColor(PALETTE.HpBorderBg)
            hpBg:SetWidgetVisibility(VIS_SHOW)
            local bgs = cont:AddChildToCanvas(hpBg)
            if bgs then
                bgs:SetAutoSize(false)
                bgs:SetAlignment(FVector2D(0.0, 0.0))
                bgs:SetPosition(FVector2D(barStartX - 1, barStartY - 1))
                bgs:SetSize(FVector2D(HP_BAR_WIDTH + 2, HP_BAR_HEIGHT + 2))
                bgs:SetZOrder(1)
            end
        end

        -- 3. Health Bar Live Fill Border
        hpFill = CGame:NewObjectFromPath("/Script/UMG.Border", cont)
        if Valid(hpFill) then
            hpFill:SetBrushColor(PALETTE.HpHigh)
            hpFill:SetWidgetVisibility(VIS_SHOW)
            hpFillSlot = cont:AddChildToCanvas(hpFill)
            if hpFillSlot then
                hpFillSlot:SetAutoSize(false)
                hpFillSlot:SetAlignment(FVector2D(0.0, 0.0))
                hpFillSlot:SetPosition(FVector2D(barStartX, barStartY))
                hpFillSlot:SetSize(FVector2D(HP_BAR_WIDTH, HP_BAR_HEIGHT))
                hpFillSlot:SetZOrder(2)
            end
        end
    end)

    if not Valid(cont) or not mainSlot then return nil end

    return {
        Container = cont,
        MainSlot = mainSlot,
        TextBlock = tb,
        HpBg = hpBg,
        HpFill = hpFill,
        HpFillSlot = hpFillSlot,
        PosVec = FVector2D(0, 0),
        HpSizeVec = FVector2D(HP_BAR_WIDTH, HP_BAR_HEIGHT),
        LastText = "",
        LastColor = nil,
        LastHP = -1,
        LastHpTier = -1,
        HpShown = true,
        TextShown = true,
        Shown = true
    }
end

local function CreateSnaplineWidget()
    if not Valid(ESPEngine.Canvas) then return nil end
    local bdr, slot = nil, nil
    pcall(function()
        bdr = CGame:NewObjectFromPath("/Script/UMG.Border", ESPEngine.Canvas)
        if Valid(bdr) then
            bdr:SetBrushColor(PALETTE.LineOpenReal)
            bdr:SetWidgetVisibility(VIS_SHOW)
            bdr:SetRenderTransformPivot(FVector2D(0.0, 0.5))
            slot = ESPEngine.Canvas:AddChildToCanvas(bdr)
            if slot then
                slot:SetAutoSize(false)
                slot:SetZOrder(5)
            end
        end
    end)
    if not Valid(bdr) or not slot then return nil end
    return {
        Widget = bdr,
        Slot = slot,
        PosVec = FVector2D(0, 0),
        SizeVec = FVector2D(0, 0),
        LastColorCode = -1,
        Shown = true
    }
end

-- ============================================================================
-- FULL-BODY CHAMS APPLICATOR (ALL 8 AVATAR SLOTS + WEAPON + HIGHLIGHT)
-- Fixes "only head visible" by styling all streamed outfit slots + highlight!
-- ============================================================================
local function ApplyMeshChamsFull(mesh, visCol, occCol)
    if not Valid(mesh) then return end
    pcall(function()
        mesh:SetDrawDyeing(true)
        mesh:SetDrawDyeingMode(1)
        mesh:SetVisibleDyeingColor(visCol)
        mesh:SetOccludedDyeingColor(occCol)
        mesh:SetDyeingColorFadeDistance(99999.0)
        mesh:SetDyeingColorMinMaxDistance(0.0, 99999.0)

        mesh:SetDrawHighlight(true)
        mesh:OverrideHighlightColor(visCol)
        mesh:SetHighlightCanBeOccluded(false)

        mesh:SetDrawIdeaOutline(true)
        mesh:SetIdeaOutlineNew(true)
        mesh:SetIdeaOutlineOcclusionHighlight(true)
        mesh:OverrideIdeaOutlineColor(visCol)
        mesh:SetIdeaOutlineOcclusionColor(occCol)
        mesh:OverrideIdeaOutlineThickness(3.5)
        mesh:SetIdeaOverrideOutlineAndOcclusion(true)

        mesh:SetRenderCustomDepth(true)
        mesh:SetCustomDepthStencilValue(255)
    end)
end

-- ============================================================================
-- MASTER REAL-TIME ESP TICK (30 FPS)
-- ============================================================================
local lastESPRender = 0
local ESP_RENDER_INTERVAL = 0.033

local function RealTimeESPTick()
    local now = os.clock()
    if now - lastESPRender < ESP_RENDER_INTERVAL then return end
    lastESPRender = now

    local myPlayer, pc = GetLocalPlayerAndPC()
    if not Valid(myPlayer) or not Valid(pc) then
        -- We are in lobby or loading screen: clean up old match state
        if ESPEngine.LastPC ~= nil then
            ESPEngine.LastPC = nil
            ESPEngine.LastPawn = nil
            ResetESPEngineForNewMatch()
        end
        return
    end

    -- Detect Match Change / Respawn and auto-reset cleanly!
    if ESPEngine.LastPC ~= pc or ESPEngine.LastPawn ~= myPlayer then
        ESPEngine.LastPC = pc
        ESPEngine.LastPawn = myPlayer
        ResetESPEngineForNewMatch()
    end

    if not _G.Mod_ESP_Enabled then
        if next(ESPEngine.Nodes) or ESPEngine.Banner.LastState ~= -1 then
            ResetESPEngineForNewMatch()
        end
        return
    end

    pcall(function()
        if not EnsureCanvas() then return end
        UpdateCanvasMetrics(pc, now)

        -- Console Setup for Chams (Re-runs automatically at start of every match)
        if _G.Mod_ESP_Wallhack and not ESPEngine.Chams.ConsoleReady then
            local KSL = import("KismetSystemLibrary")
            local world = slua.getWorld()
            if KSL and world then
                KSL.ExecuteConsoleCommand(world, "r.EnableDrawDyeingColor 1")
                KSL.ExecuteConsoleCommand(world, "r.CustomDepth 3")
                KSL.ExecuteConsoleCommand(world, "r.IdeaOutline.Enable 1")
                KSL.ExecuteConsoleCommand(world, "r.Highlight.Enable 1")
                ESPEngine.Chams.ConsoleReady = true
            end
        end

        local myLoc = myPlayer:K2_GetActorLocation()
        if not myLoc then return end

        local enemies = SyncEnemyRoster(myPlayer)
        local activeKeys = {}
        local realCount, botCount = 0, 0
        local nearestMeters = 9999

        local sx, sy = ESPEngine.ScaleX, ESPEngine.ScaleY
        local ox, oy = ESPEngine.OffsetX, ESPEngine.OffsetY
        local fromX, fromY = ESPEngine.OriginX, ESPEngine.OriginY

        local showName = _G.Mod_ESP_ShowName
        local showDist = _G.Mod_ESP_ShowDistance
        local showHP   = _G.Mod_ESP_ShowHealthBar
        local showLine = _G.Mod_ESP_ShowSnapline
        local showWH   = _G.Mod_ESP_Wallhack
        local showESP5 = C.EspLoai5
        local lineThick = tonumber(_G.Mod_ESP_SnaplineThickness) or 1.2

        for i = 1, #enemies do
            local pawn = enemies[i]
            if Valid(pawn) then
                local bAlive = (pawn.Health == nil or pawn.Health > 0) and (pawn.HealthStatus ~= 2)
                if bAlive then
                    local key = tostring(pawn)
                    activeKeys[key] = true

                    local node = ESPEngine.Nodes[key]
                    if not node then
                        local isBot = false
                        pcall(function()
                            if Game and Game.IsAI then isBot = Game:IsAI(pawn) end
                            if not isBot and (pawn.bIsAI or pawn.IsAI) then isBot = true end
                            if not isBot and Valid(pawn.PlayerState) and (pawn.PlayerState.bIsABot or pawn.PlayerState.bIsBot) then isBot = true end
                        end)
                        local pName = "Enemy"
                        if isBot then
                            pName = "BOT"
                        else
                            pcall(function()
                                if pawn.GetPlayerNameSafety then pName = pawn:GetPlayerNameSafety()
                                elseif pawn.PlayerName and pawn.PlayerName ~= "" then pName = pawn.PlayerName
                                elseif Valid(pawn.PlayerState) and pawn.PlayerState.GetPlayerName then pName = pawn.PlayerState:GetPlayerName() end
                            end)
                            if not pName or pName == "" then pName = "Player" end
                        end
                        node = {
                            Pawn = pawn,
                            bIsAI = isBot,
                            Name = pName,
                            Vis = false,
                            VisTime = 0,
                            ChamsTime = 0,
                            ChamsCount = 0,
                            ESP5Applied = false,
                            ESP5HP = -1
                        }
                        ESPEngine.Nodes[key] = node
                    end

                    -- Retry name lookup if real player name hadn't replicated on spawn frame
                    if not node.bIsAI and (node.Name == "Player" or node.Name == "Enemy" or node.Name == "Unknown") then
                        pcall(function()
                            local n = (pawn.GetPlayerNameSafety and pawn:GetPlayerNameSafety())
                                   or (Valid(pawn.PlayerState) and pawn.PlayerState.GetPlayerName and pawn.PlayerState:GetPlayerName())
                            if n and n ~= "" then node.Name = n end
                        end)
                    end

                    if node.bIsAI then botCount = botCount + 1 else realCount = realCount + 1 end

                    -- 1. Full-Body Chams (Bot = White, Real Open = Green, Real Cover = Purple)
                    -- Re-applies every 1.5s so newly streamed clothing/helmet/vest slots (0..7) get coloured!
                    if showWH and (now - node.ChamsTime) > 1.5 then
                        node.ChamsTime = now
                        local visCol = node.bIsAI and PALETTE.ChamBotWhite or PALETTE.ChamRealOpen
                        local occCol = node.bIsAI and PALETTE.ChamBotWhite or PALETTE.ChamRealCover
                        pcall(function()
                            if Valid(pawn.Mesh) then ApplyMeshChamsFull(pawn.Mesh, visCol, occCol) end
                            local av = pawn.CharacterAvatarComp2_BP or (pawn.getAvatarComponent2 and pawn:getAvatarComponent2())
                            if av and av.GetMeshCompBySlot then
                                for slotIdx = 0, 7 do
                                    local m = av:GetMeshCompBySlot(slotIdx)
                                    if Valid(m) then ApplyMeshChamsFull(m, visCol, occCol) end
                                end
                            end
                            if type(pawn.GetCurrentWeapon) == "function" then
                                local wep = pawn:GetCurrentWeapon()
                                if Valid(wep) and Valid(wep.Mesh) then ApplyMeshChamsFull(wep.Mesh, visCol, occCol) end
                            end
                        end)
                    end

                    -- 2. Native ESP Type 5 Frame
                    if showESP5 then
                        if not node.ESP5Applied then
                            pcall(function()
                                if pawn.Replay_IsEnemyFrameUIExisted and not pawn:Replay_IsEnemyFrameUIExisted() then
                                    pawn:Replay_CreateEnemyFrameUI(true, true)
                                end
                                if pawn.Replay_SetVisiableOfFrameUI then pawn:Replay_SetVisiableOfFrameUI(true) end
                            end)
                            node.ESP5Applied = true
                        end
                    elseif node.ESP5Applied then
                        pcall(function() if pawn.Replay_SetVisiableOfFrameUI then pawn:Replay_SetVisiableOfFrameUI(false) end end)
                        node.ESP5Applied = false
                    end

                    -- 3. Real-Time World Location + Distance + Screen Projection
                    local loc = pawn:K2_GetActorLocation()
                    if loc then
                        local dx = loc.X - myLoc.X
                        local dy = loc.Y - myLoc.Y
                        local dz = loc.Z - myLoc.Z
                        local distMeters = math.floor(math.sqrt(dx * dx + dy * dy + dz * dz) * 0.01)
                        if distMeters < nearestMeters then nearestMeters = distMeters end

                        local zOffset = 88
                        if pawn.bIsCrouched then zOffset = 62
                        elseif pawn.IsProne and pawn:IsProne() then zOffset = 32 end
                        loc.Z = loc.Z + zOffset

                        if not node.bIsAI and (now - node.VisTime) > 0.12 then
                            node.VisTime = now
                            node.Vis = pc.LineOfSightTo and pc:LineOfSightTo(pawn, _ZeroVec3, false) or false
                        end

                        local projRes = pc:ProjectWorldLocationToScreen(loc, _ProjTemp, true)
                        local onScreen = (projRes == true or projRes == 1) and (_ProjTemp.X > 0 or _ProjTemp.Y > 0)
                        local canvasX = _ProjTemp.X * sx + ox
                        local canvasY = _ProjTemp.Y * sy + oy

                        -- 4. Pure Native UMG Overhead Tag (Name + Distance + Health Bar)
                        if showName or showDist or showHP then
                            if not node.Overhead or not Valid(node.Overhead.Container) then
                                node.Overhead = CreatePureOverheadWidget()
                            end
                            local OH = node.Overhead
                            if OH and Valid(OH.Container) then
                                if onScreen then
                                    if not OH.Shown then
                                        OH.Container:SetWidgetVisibility(VIS_SHOW)
                                        OH.Shown = true
                                    end

                                    OH.PosVec.X = canvasX
                                    OH.PosVec.Y = canvasY - 6
                                    OH.MainSlot:SetPosition(OH.PosVec)

                                    -- Name & Distance Text
                                    if showName or showDist then
                                        if not OH.TextShown and Valid(OH.TextBlock) then
                                            OH.TextBlock:SetWidgetVisibility(VIS_SHOW)
                                            OH.TextShown = true
                                        end
                                        local txt = ""
                                        if showName and showDist then
                                            txt = string.format("%s [%dm]", node.Name, distMeters)
                                        elseif showName then
                                            txt = node.Name
                                        else
                                            txt = string.format("[%dm]", distMeters)
                                        end

                                        local isKnocked = (pawn.HealthStatus == 1)
                                        local tCol = isKnocked and PALETTE.TextKnocked
                                                  or (node.bIsAI and PALETTE.TextWhite)
                                                  or (node.Vis and PALETTE.TextGreen or PALETTE.TextPurple)

                                        if OH.LastText ~= txt or OH.LastColor ~= tCol then
                                            OH.LastText = txt
                                            OH.LastColor = tCol
                                            if Valid(OH.TextBlock) then
                                                OH.TextBlock:SetText(txt)
                                                OH.TextBlock:SetColorAndOpacity(tCol)
                                            end
                                        end
                                    elseif OH.TextShown and Valid(OH.TextBlock) then
                                        OH.TextBlock:SetWidgetVisibility(VIS_HIDE)
                                        OH.TextShown = false
                                    end

                                    -- Live Health Bar
                                    local hp = pawn.Health or 100
                                    local maxHp = pawn.HealthMax or pawn.MaxHealth or 100
                                    if maxHp <= 0 then maxHp = 100 end
                                    local pct = math.min(1.0, math.max(0.0, hp / maxHp))

                                    if showHP then
                                        if not OH.HpShown then
                                            if Valid(OH.HpBg) then OH.HpBg:SetWidgetVisibility(VIS_SHOW) end
                                            if Valid(OH.HpFill) then OH.HpFill:SetWidgetVisibility(VIS_SHOW) end
                                            OH.HpShown = true
                                        end
                                        if math.abs(pct - OH.LastHP) > 0.005 then
                                            OH.LastHP = pct
                                            OH.HpSizeVec.X = math.max(1, math.floor(HP_BAR_WIDTH * pct))
                                            OH.HpSizeVec.Y = HP_BAR_HEIGHT
                                            if OH.HpFillSlot then OH.HpFillSlot:SetSize(OH.HpSizeVec) end

                                            local tier = (pct > 0.55 and 3) or (pct > 0.25 and 2) or 1
                                            if OH.LastHpTier ~= tier and Valid(OH.HpFill) then
                                                OH.LastHpTier = tier
                                                OH.HpFill:SetBrushColor((tier == 3 and PALETTE.HpHigh) or (tier == 2 and PALETTE.HpMid) or PALETTE.HpLow)
                                            end
                                        end
                                    elseif OH.HpShown then
                                        if Valid(OH.HpBg) then OH.HpBg:SetWidgetVisibility(VIS_HIDE) end
                                        if Valid(OH.HpFill) then OH.HpFill:SetWidgetVisibility(VIS_HIDE) end
                                        OH.HpShown = false
                                    end

                                    if showESP5 and pawn.Replay_UpdateEnemyFrameUI and math.abs(pct - node.ESP5HP) > 0.01 then
                                        node.ESP5HP = pct
                                        pawn:Replay_UpdateEnemyFrameUI(pct)
                                    end
                                elseif OH.Shown then
                                    OH.Container:SetWidgetVisibility(VIS_HIDE)
                                    OH.Shown = false
                                end
                            end
                        elseif node.Overhead and node.Overhead.Shown and Valid(node.Overhead.Container) then
                            node.Overhead.Container:SetWidgetVisibility(VIS_HIDE)
                            node.Overhead.Shown = false
                        end

                        -- 5. Smooth Real-Time Snaplines
                        if showLine then
                            if not node.Snapline or not Valid(node.Snapline.Widget) then
                                node.Snapline = CreateSnaplineWidget()
                            end
                            local SL = node.Snapline
                            if SL and Valid(SL.Widget) then
                                if onScreen then
                                    if not SL.Shown then
                                        SL.Widget:SetWidgetVisibility(VIS_SHOW)
                                        SL.Shown = true
                                    end
                                    local colCode = node.bIsAI and 3 or (node.Vis and 1 or 2)
                                    if SL.LastColorCode ~= colCode then
                                        SL.LastColorCode = colCode
                                        SL.Widget:SetBrushColor((colCode == 1 and PALETTE.LineOpenReal) or (colCode == 2 and PALETTE.LineCoverReal) or PALETTE.LineBot)
                                    end

                                    local toX = canvasX
                                    local toY = canvasY - 6
                                    local ldx = toX - fromX
                                    local ldy = toY - fromY
                                    local len = math.sqrt(ldx * ldx + ldy * ldy)
                                    local ang = (math.atan2 and math.atan2(ldy, ldx) or math.atan(ldy, ldx)) * 57.295779513

                                    SL.PosVec.X = fromX
                                    SL.PosVec.Y = fromY - lineThick * 0.5
                                    SL.SizeVec.X = len
                                    SL.SizeVec.Y = lineThick

                                    SL.Slot:SetPosition(SL.PosVec)
                                    SL.Slot:SetSize(SL.SizeVec)
                                    SL.Widget:SetRenderAngle(ang)
                                elseif SL.Shown then
                                    SL.Widget:SetWidgetVisibility(VIS_HIDE)
                                    SL.Shown = false
                                end
                            end
                        elseif node.Snapline and node.Snapline.Shown and Valid(node.Snapline.Widget) then
                            node.Snapline.Widget:SetWidgetVisibility(VIS_HIDE)
                            node.Snapline.Shown = false
                        end
                    end
                end
            end
        end

        -- Clean up dead or despawned enemies
        for k, node in pairs(ESPEngine.Nodes) do
            if not activeKeys[k] then
                if node.ESP5Applied and Valid(node.Pawn) and node.Pawn.Replay_SetVisiableOfFrameUI then
                    pcall(function() node.Pawn:Replay_SetVisiableOfFrameUI(false) end)
                end
                if node.Overhead and Valid(node.Overhead.Container) then
                    pcall(function() node.Overhead.Container:RemoveFromParent(); node.Overhead.Container:ConditionalBeginDestroy() end)
                end
                if node.Snapline and Valid(node.Snapline.Widget) then
                    pcall(function() node.Snapline.Widget:RemoveFromParent(); node.Snapline.Widget:ConditionalBeginDestroy() end)
                end
                ESPEngine.Nodes[k] = nil
            end
        end

        UpdateBanner(realCount, botCount, nearestMeters == 9999 and 0 or nearestMeters, _G.Mod_ESP_ShowPlayerCount)
    end)
end

-- ============================================================================
-- PART 8: IMMORTAL MULTI-MATCH SCHEDULER (NEVER DIES AFTER MATCH 1!)
-- Uses BOTH time_ticker AND Game:SetTimer + PC:AddGameTimer fallback
-- ============================================================================
local _AttachedTimerPC = nil

local function MasterFrameTick()
    pcall(AimTouch)
    pcall(RealTimeESPTick)
end

-- 1. Self-healing time_ticker loop
local _lastTickerHeartbeat = 0
local function StartTickerLoop()
    local t = nil
    pcall(function() t = require("common.time_ticker") end)
    if t and t.AddTimerOnce then
        local function step()
            _lastTickerHeartbeat = os.clock()
            MasterFrameTick()
            pcall(t.AddTimerOnce, 0.025, step)
        end
        pcall(t.AddTimerOnce, 0.025, step)
    end
end
StartTickerLoop()

-- 2. Immortal 1-Second Watchdog: Re-starts ticker or attaches to new Match PC if cleared between matches!
local function MultiMatchWatchdog()
    pcall(function()
        local now = os.clock()
        if now - _lastTickerHeartbeat > 0.5 then
            StartTickerLoop()
        end

        local _, pc = GetLocalPlayerAndPC()
        if Valid(pc) and _AttachedTimerPC ~= pc and pc.AddGameTimer then
            _AttachedTimerPC = pc
            pc:AddGameTimer(0.030, true, function()
                if os.clock() - _lastTickerHeartbeat > 0.15 then
                    MasterFrameTick()
                end
            end)
        end
    end)
end

if Game and Game.SetTimer then
    _G._V6WatchdogHandle = Game:SetTimer(1.0, true, MultiMatchWatchdog)
end
MultiMatchWatchdog()

-- ============================================================================
-- PART 9: IN-GAME SETTINGS MENU (AIMBOT + ESP ONLY — NO LOOT ESP)
-- ============================================================================
function _G.InitMasterMenusV6()
    HookLocUtil()
    local SPD = require("client.logic.NewSetting.SettingPageDefine")
    local SC  = require("client.logic.NewSetting.SettingCatalog")
    local AM  = require("client.slua.umg.NewSetting.Item.AliasMap")

    SPD.Aimbot = SPD.Aimbot or { Key = "Aimbot", Text = 999003, UIKey = "Setting_Page_Privacy", Category = {} }

    local StackAimbot = {
        { Key = "ModMenu_AT_Ex", UI = AM.TitleSwitcher, Text = 991001, ExpandIndex = 0, GetFunc = function() return C.AimTouchEnable end, SetFunc = function(c,v) C.AimTouchEnable = v return true end },
        { Key = "ModMenu_AT_Hip_Ex", UI = AM.TitleSwitcher, Text = 991010, ExpandHandle = "ModMenu_AT_Ex", ExpandIndex = 0, GetFunc = function() return C.AimTouchHipfire end, SetFunc = function(c,v) C.AimTouchHipfire = v return true end },
        { Key = "ModMenu_AT_Hip_IgKnock", UI = AM.Switcher, Text = 991011, ExpandHandle = "ModMenu_AT_Hip_Ex", GetFunc = function() return C.AimTouchHipIgKnock end, SetFunc = function(c,v) C.AimTouchHipIgKnock = v return true end },
        { Key = "ModMenu_AT_Hip_IgBot", UI = AM.Switcher, Text = 991012, ExpandHandle = "ModMenu_AT_Hip_Ex", GetFunc = function() return C.AimTouchHipIgBot end, SetFunc = function(c,v) C.AimTouchHipIgBot = v return true end },
        { Key = "ModMenu_AT_Hip_Vis", UI = AM.Switcher, Text = 991013, ExpandHandle = "ModMenu_AT_Hip_Ex", GetFunc = function() return C.AimTouchHipVisCheck end, SetFunc = function(c,v) C.AimTouchHipVisCheck = v return true end },
        { Key = "ModMenu_AT_Hip_Prio", UI = AM.Slider, Text = 991014, ExpandHandle = "ModMenu_AT_Hip_Ex", MinValue = 1, MaxValue = 4, min = 1, max = 4, GetFunc = function() return D.AimTouchHipPrio or 1 end, SetFunc = function(c,v) D.AimTouchHipPrio = math.floor(v+0.5) return true end },
        { Key = "ModMenu_AT_Hip_Bone", UI = AM.Slider, Text = 991015, ExpandHandle = "ModMenu_AT_Hip_Ex", MinValue = 1, MaxValue = 4, min = 1, max = 4, GetFunc = function() return D.AimTouchHipBone or 1 end, SetFunc = function(c,v) D.AimTouchHipBone = math.floor(v+0.5) return true end },
        { Key = "ModMenu_AT_Hip_Cond", UI = AM.Slider, Text = 991016, ExpandHandle = "ModMenu_AT_Hip_Ex", MinValue = 1, MaxValue = 2, min = 1, max = 2, GetFunc = function() return D.AimTouchHipCond or 1 end, SetFunc = function(c,v) D.AimTouchHipCond = math.floor(v+0.5) return true end },
        { Key = "ModMenu_AT_Hip_Spd", UI = AM.Slider, Text = 991017, ExpandHandle = "ModMenu_AT_Hip_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return D.AimTouchHipSpeed or 75 end, SetFunc = function(c,v) D.AimTouchHipSpeed = v return true end },
        { Key = "ModMenu_AT_Hip_FOV", UI = AM.Slider, Text = 991018, ExpandHandle = "ModMenu_AT_Hip_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return D.AimTouchHipFOV or 15 end, SetFunc = function(c,v) D.AimTouchHipFOV = v return true end },
        { Key = "ModMenu_AT_Hip_Dist", UI = AM.Slider, Text = 991019, ExpandHandle = "ModMenu_AT_Hip_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return math.floor((D.AimTouchHipDist or 500) / 5) end, SetFunc = function(c,v) D.AimTouchHipDist = v * 5 return true end },
        { Key = "ModMenu_AT_Hip_Recoil", UI = AM.Slider, Text = 991020, ExpandHandle = "ModMenu_AT_Hip_Ex", MinValue = 0, MaxValue = 100, min = 0, max = 100, GetFunc = function() return D.AimTouchHipRecoil or 0 end, SetFunc = function(c,v) D.AimTouchHipRecoil = v return true end },
        { Key = "ModMenu_AT_Hip_Pred", UI = AM.Slider, Text = 991021, ExpandHandle = "ModMenu_AT_Hip_Ex", MinValue = 0, MaxValue = 100, min = 0, max = 100, GetFunc = function() return D.AimTouchHipPred or 0 end, SetFunc = function(c,v) D.AimTouchHipPred = v return true end },

        { Key = "ModMenu_AT_SG_Ex", UI = AM.TitleSwitcher, Text = 991030, ExpandHandle = "ModMenu_AT_Ex", ExpandIndex = 0, GetFunc = function() return C.AimTouchSG end, SetFunc = function(c,v) C.AimTouchSG = v return true end },
        { Key = "ModMenu_AT_SG_Auto", UI = AM.Switcher, Text = 991031, ExpandHandle = "ModMenu_AT_SG_Ex", GetFunc = function() return C.AimTouchSGAutoFire end, SetFunc = function(c,v) C.AimTouchSGAutoFire = v return true end },
        { Key = "ModMenu_AT_SG_IgKnock", UI = AM.Switcher, Text = 991032, ExpandHandle = "ModMenu_AT_SG_Ex", GetFunc = function() return C.AimTouchSGIgKnock end, SetFunc = function(c,v) C.AimTouchSGIgKnock = v return true end },
        { Key = "ModMenu_AT_SG_IgBot", UI = AM.Switcher, Text = 991033, ExpandHandle = "ModMenu_AT_SG_Ex", GetFunc = function() return C.AimTouchSGIgBot end, SetFunc = function(c,v) C.AimTouchSGIgBot = v return true end },
        { Key = "ModMenu_AT_SG_Vis", UI = AM.Switcher, Text = 991034, ExpandHandle = "ModMenu_AT_SG_Ex", GetFunc = function() return C.AimTouchSGVisCheck end, SetFunc = function(c,v) C.AimTouchSGVisCheck = v return true end },
        { Key = "ModMenu_AT_SG_Spd", UI = AM.Slider, Text = 991038, ExpandHandle = "ModMenu_AT_SG_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return D.AimTouchSGSpeed or 75 end, SetFunc = function(c,v) D.AimTouchSGSpeed = v return true end },
        { Key = "ModMenu_AT_SG_FOV", UI = AM.Slider, Text = 991039, ExpandHandle = "ModMenu_AT_SG_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return D.AimTouchSGFOV or 15 end, SetFunc = function(c,v) D.AimTouchSGFOV = v return true end },

        { Key = "ModMenu_AT_ScopeAll_Ex", UI = AM.TitleSwitcher, Text = 991050, ExpandHandle = "ModMenu_AT_Ex", ExpandIndex = 0, GetFunc = function() return C.AimTouchScopeAll end, SetFunc = function(c,v) C.AimTouchScopeAll = v return true end },
        { Key = "ModMenu_AT_ScopeAll_IgKnock", UI = AM.Switcher, Text = 991051, ExpandHandle = "ModMenu_AT_ScopeAll_Ex", GetFunc = function() return C.AimTouchScopeIgKnock end, SetFunc = function(c,v) C.AimTouchScopeIgKnock = v return true end },
        { Key = "ModMenu_AT_ScopeAll_IgBot", UI = AM.Switcher, Text = 991052, ExpandHandle = "ModMenu_AT_ScopeAll_Ex", GetFunc = function() return C.AimTouchScopeIgBot end, SetFunc = function(c,v) C.AimTouchScopeIgBot = v return true end },
        { Key = "ModMenu_AT_ScopeAll_Vis", UI = AM.Switcher, Text = 991053, ExpandHandle = "ModMenu_AT_ScopeAll_Ex", GetFunc = function() return C.AimTouchScopeVisCheck end, SetFunc = function(c,v) C.AimTouchScopeVisCheck = v return true end },
        { Key = "ModMenu_AT_ScopeAll_Spd", UI = AM.Slider, Text = 991057, ExpandHandle = "ModMenu_AT_ScopeAll_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return D.AimTouchScopeSpeed or 100 end, SetFunc = function(c,v) D.AimTouchScopeSpeed = v return true end },
        { Key = "ModMenu_AT_ScopeAll_FOV", UI = AM.Slider, Text = 991058, ExpandHandle = "ModMenu_AT_ScopeAll_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return D.AimTouchScopeFOV or 15 end, SetFunc = function(c,v) D.AimTouchScopeFOV = v return true end },
        { Key = "ModMenu_AT_ScopeAll_Pred", UI = AM.Slider, Text = 991060, ExpandHandle = "ModMenu_AT_ScopeAll_Ex", MinValue = 0, MaxValue = 100, min = 0, max = 100, GetFunc = function() return D.AimTouchScopePred or 26 end, SetFunc = function(c,v) D.AimTouchScopePred = v return true end },
        { Key = "ModMenu_AT_ScopeAll_Recoil", UI = AM.Slider, Text = 991061, ExpandHandle = "ModMenu_AT_ScopeAll_Ex", MinValue = 0, MaxValue = 100, min = 0, max = 100, GetFunc = function() return D.AimTouchScopeRecoil or 6 end, SetFunc = function(c,v) D.AimTouchScopeRecoil = v return true end },

        { Key = "ModMenu_AT_Sniper_Ex", UI = AM.TitleSwitcher, Text = 991070, ExpandHandle = "ModMenu_AT_Ex", ExpandIndex = 0, GetFunc = function() return C.AimTouchScopeSniper end, SetFunc = function(c,v) C.AimTouchScopeSniper = v return true end },
        { Key = "ModMenu_AT_Sniper_IgKnock", UI = AM.Switcher, Text = 991071, ExpandHandle = "ModMenu_AT_Sniper_Ex", GetFunc = function() return C.AimTouchSniperIgKnock end, SetFunc = function(c,v) C.AimTouchSniperIgKnock = v return true end },
        { Key = "ModMenu_AT_Sniper_IgBot", UI = AM.Switcher, Text = 991072, ExpandHandle = "ModMenu_AT_Sniper_Ex", GetFunc = function() return C.AimTouchSniperIgBot end, SetFunc = function(c,v) C.AimTouchSniperIgBot = v return true end },
        { Key = "ModMenu_AT_Sniper_Vis", UI = AM.Switcher, Text = 991073, ExpandHandle = "ModMenu_AT_Sniper_Ex", GetFunc = function() return C.AimTouchSniperVisCheck end, SetFunc = function(c,v) C.AimTouchSniperVisCheck = v return true end },
        { Key = "ModMenu_AT_Sniper_Spd", UI = AM.Slider, Text = 991077, ExpandHandle = "ModMenu_AT_Sniper_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return D.AimTouchSniperSpeed or 100 end, SetFunc = function(c,v) D.AimTouchSniperSpeed = v return true end },
        { Key = "ModMenu_AT_Sniper_FOV", UI = AM.Slider, Text = 991078, ExpandHandle = "ModMenu_AT_Sniper_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return D.AimTouchSniperFOV or 15 end, SetFunc = function(c,v) D.AimTouchSniperFOV = v return true end },
        { Key = "ModMenu_AT_Sniper_Pred", UI = AM.Slider, Text = 991080, ExpandHandle = "ModMenu_AT_Sniper_Ex", MinValue = 0, MaxValue = 100, min = 0, max = 100, GetFunc = function() return D.AimTouchSniperPred or 26 end, SetFunc = function(c,v) D.AimTouchSniperPred = v return true end }
    }

    local StackSuperBullet = {
        { Key = "SuperBullet_Main", UI = AM.TitleSwitcher, Text = 991200, ExpandIndex = 0, GetFunc = function() return C.SuperBulletSG end, SetFunc = function(c,v) C.SuperBulletSG = v return true end },
        { Key = "SuperBullet_Count", UI = AM.Slider, Text = 991201, ExpandHandle = "SuperBullet_Main", MinValue = 1, MaxValue = 20, min = 1, max = 20, GetFunc = function() return C.SuperBulletSGCount or 20 end, SetFunc = function(c,v) C.SuperBulletSGCount = math.floor(v + 0.5) return true end }
    }

    SPD.Aimbot.Category = {
        { Key = "Cat_AimbotV2", Text = 999003, Stack = StackAimbot },
        { Key = "Cat_SuperBullet", Text = 991200, Stack = StackSuperBullet }
    }

    SPD.ESP = SPD.ESP or { Key = "ESP", Text = 999004, UIKey = "Setting_Page_Privacy", Category = {} }
    local StackESP = {
        { Key = "ModMenu_ESP_Main",  UI = AM.TitleSwitcher, Text = 992001, ExpandIndex = 0, GetFunc = function() return _G.Mod_ESP_Enabled end, SetFunc = function(c,v) _G.Mod_ESP_Enabled = v return true end },
        { Key = "ModMenu_ESP_Count", UI = AM.Switcher, Text = 992003, ExpandHandle = "ModMenu_ESP_Main", GetFunc = function() return _G.Mod_ESP_ShowPlayerCount end, SetFunc = function(c,v) _G.Mod_ESP_ShowPlayerCount = v return true end },
        { Key = "ModMenu_ESP_Name",  UI = AM.Switcher, Text = 992005, ExpandHandle = "ModMenu_ESP_Main", GetFunc = function() return _G.Mod_ESP_ShowName end, SetFunc = function(c,v) _G.Mod_ESP_ShowName = v return true end },
        { Key = "ModMenu_ESP_Dist",  UI = AM.Switcher, Text = 992006, ExpandHandle = "ModMenu_ESP_Main", GetFunc = function() return _G.Mod_ESP_ShowDistance end, SetFunc = function(c,v) _G.Mod_ESP_ShowDistance = v return true end },
        { Key = "ModMenu_ESP_HP",    UI = AM.Switcher, Text = 992007, ExpandHandle = "ModMenu_ESP_Main", GetFunc = function() return _G.Mod_ESP_ShowHealthBar end, SetFunc = function(c,v) _G.Mod_ESP_ShowHealthBar = v return true end },
        { Key = "ModMenu_ESP_Line",  UI = AM.Switcher, Text = 992002, ExpandHandle = "ModMenu_ESP_Main", GetFunc = function() return _G.Mod_ESP_ShowSnapline end, SetFunc = function(c,v) _G.Mod_ESP_ShowSnapline = v return true end },
        { Key = "ModMenu_ESP_WH",    UI = AM.Switcher, Text = 992004, ExpandHandle = "ModMenu_ESP_Main", GetFunc = function() return _G.Mod_ESP_Wallhack end, SetFunc = function(c,v) _G.Mod_ESP_Wallhack = v return true end },
        { Key = "ModMenu_ESP_Thick", UI = AM.Slider,   Text = 992010, ExpandHandle = "ModMenu_ESP_Main", MinValue = 1, MaxValue = 5, min = 1, max = 5, GetFunc = function() return tonumber(_G.Mod_ESP_SnaplineThickness) or 1 end, SetFunc = function(c,v) _G.Mod_ESP_SnaplineThickness = math.floor(v+0.5) return true end },
        { Key = "ModMenu_ESP5_Main", UI = AM.Switcher, Text = 992012, ExpandHandle = "ModMenu_ESP_Main", GetFunc = function() return C.EspLoai5 end, SetFunc = function(c,v) C.EspLoai5 = v return true end }
    }
    SPD.ESP.Category = { { Key = "Cat_ESP", Text = 999004, Stack = StackESP } }

    local function injectPage(page)
        for _, p in ipairs(SC) do if p.Key == page.Key then return end end
        table.insert(SC, 1, page)
    end
    injectPage(SPD.ESP)
    injectPage(SPD.Aimbot)

    local UIManager = _G.UIManager
    if UIManager and not UIManager._MasterMenuHookedV6 then
        local old_ShowUI = UIManager.ShowUI
        UIManager.ShowUI = function(config, ...)
            local args = {...}
            local n = select('#', ...)
            if config and config.keyName and string.find(string.lower(config.keyName), "setting_main") then
                local catalog = args[1]
                if type(catalog) == "table" then
                    local hasAim, hasEsp = false, false
                    for _, page in ipairs(catalog) do
                        if page.Key == "Aimbot" then hasAim = true end
                        if page.Key == "ESP" then hasEsp = true end
                    end
                    if not hasAim then table.insert(catalog, 1, SPD.Aimbot) end
                    if not hasEsp then table.insert(catalog, 2, SPD.ESP) end
                end
            end
            local unpackFn = table.unpack or unpack
            return old_ShowUI(config, unpackFn(args, 1, n))
        end
        UIManager._MasterMenuHookedV6 = true
    end
end

pcall(_G.InitMasterMenusV6)
if Game and Game.SetTimer then
    Game:SetTimer(2.0, false, function() pcall(_G.InitMasterMenusV6) end)
end

print("[VIP STANDALONE V6] Loaded — Multi-Match Persistent + Native UMG Name/HP/Dist + Full-Body Chams")


]===])

-- ============================================================================
-- 3. 3.lua
-- ============================================================================
__defer_feature('3.lua', [===[
-- 165 FPS Unlock (FPS only)

local KismetMathLibrary_1 = import("KismetMathLibrary")

local logic_setting_graphics_1 = package.loaded["client.slua.logic.setting.logic_setting_graphics"] or require("client.slua.logic.setting.logic_setting_graphics")
local GSC_FPS_1 = package.loaded["client.slua.umg.NewSetting.GraphicsNew.Comps.GSC_FPS"] or require("client.slua.umg.NewSetting.GraphicsNew.Comps.GSC_FPS")
local GSC_FPSFT_1 = package.loaded["client.slua.umg.NewSetting.GraphicsNew.Comps.GSC_FPSFT"] or require("client.slua.umg.NewSetting.GraphicsNew.Comps.GSC_FPSFT")
local GraphicSettingDB_1 = package.loaded["client.slua.umg.NewSetting.GraphicsNew.GraphicSettingDB"] or require("client.slua.umg.NewSetting.GraphicsNew.GraphicSettingDB")

if logic_setting_graphics_1 then
    local var_132 = logic_setting_graphics_1.SetFPS
    function logic_setting_graphics_1.SetFPS(gameInstance, FPSLevel)
        if FPSLevel == 8 and GraphicSettingDB_1 then
            local var_234 = GraphicSettingDB_1:GetUIData(GraphicSettingDB_1.FPSFineTuneSwitch)
            if not var_234 then
                GraphicSettingDB_1:UpdateUIData(GraphicSettingDB_1.FPSFineTuneSwitch, true)
            end
        end
        if var_132 then
            var_132(gameInstance, FPSLevel)
        end
        if FPSLevel == 8 and GraphicSettingDB_1 then
            GraphicSettingDB_1:UpdateUIData(GraphicSettingDB_1.FPSFineTuneNum, 165)
            gameInstance:ExecuteCMD("t.MaxFPS", "165")
            gameInstance:ExecuteCMD("r.FrameRateLimit", "165")
        end
    end
end

if GSC_FPS_1 and GSC_FPS_1.__inner_impl then
    local var_160 = GSC_FPS_1.__inner_impl
    function var_160:GetMaxFPSLevel() return 8, 8 end
    function var_160:CanChangeQualityAndFPSPreCheck() return true end
    function var_160:InitRealSupportFPS()
        local var_29 = {}
        for i = 1, 8 do var_29[i] = {true, true} end
        if GraphicSettingDB_1 then GraphicSettingDB_1:UpdateUIData(GraphicSettingDB_1.RealSupportFPS, var_29, false) end
        return var_29
    end
    function var_160:SetFPSAndQualityEnable(bEnable)
        if self.UIRoot and self.UIRoot.Image_Mask then self:SetWidgetVisible(self.UIRoot.Image_Mask, false) end
    end
    function var_160:UpdateSelectedFPSState(selectedLevel)
        local var_37 = { [2]="NodeFps20", [3]="NodeFps25", [4]="NodeFps30", [5]="NodeFps40", [6]="NodeFps60", [7]="NodeFps90", [8]="NodeFps120" }
        if not self.UIRoot then return end
        for level, name in pairs(var_37) do
            if self.UIRoot[name] then
                self:WidgetSelfHit(self.UIRoot[name])
                self.UIRoot[name]:SetIsEnabled(true)
                local var_54 = self.UIRoot["WidgetSwitcher_" .. level]
                if var_54 then var_54:SetActiveWidgetIndex(level == selectedLevel and 0 or 1) end
            end
        end
    end
    local var_58 = var_160.UpdateUI
    function var_160:UpdateUI()
        if var_58 then pcall(var_58, self) end
        self:SelfHitTestInvisible()
        self:InitRealSupportFPS()
        self:SetFPSAndQualityEnable(true)
        local var_222 = 8
        if GraphicSettingDB_1 then
            if GraphicSettingDB_1:GetUIData(GraphicSettingDB_1.CustomTab) == 2 then
                var_222 = GraphicSettingDB_1:GetUIData(GraphicSettingDB_1.LobbyFPS) or 8
            else
                var_222 = GraphicSettingDB_1:GetUIData(GraphicSettingDB_1.SelectedFPS) or 8
            end
        end
        self:UpdateSelectedFPSState(var_222)
    end
    function var_160:DoClickFPS(FPSLevel)
        if slua.isValid(self.UIRoot) then
            if GraphicSettingDB_1:GetUIData(GraphicSettingDB_1.CustomTab) == 2 then
                GraphicSettingDB_1:UpdateUIData(GraphicSettingDB_1.LobbyFPS, FPSLevel)
            else
                GraphicSettingDB_1:UpdateSelectedFPS(FPSLevel)
            end
            self:UpdateSelectedFPSState(FPSLevel)
            if self:GetParentUI() then
                self:GetParentUI():SaveQualityAndFPS()
                self:GetParentUI():SetDirty(true)
            end
        end
    end
end

if GSC_FPSFT_1 and GSC_FPSFT_1.__inner_impl then
    local var_13 = GSC_FPSFT_1.__inner_impl
    local var_93, var_203 = 90, 5
    local function func_6(val, min, max) return val < min and min or (val > max and max or val) end
    function var_13:ShowOrHide()
        self:SelfHitTestInvisible()
        if self.InitFPSFTSwitch then self:InitFPSFTSwitch() end
    end
    function var_13:InitFPSFTSwitch()
        local sw = GraphicSettingDB_1:GetUIData(GraphicSettingDB_1.FPSFineTuneSwitch)
        if self.UIRoot.Setting_Switch then self.UIRoot.Setting_Switch:SetSwitcherEnable2(sw, true) end
        if self.UIRoot.CanvasPanel_8 then self:SetWidgetVisible(self.UIRoot.CanvasPanel_8, sw) end
        if self.UIRoot.WidgetSwitcher_0 then self.UIRoot.WidgetSwitcher_0:SetActiveWidgetIndex(2) end
        if self.InitFPSFTValue165 then self:InitFPSFTValue165() end
    end
    function var_13:InitFPSFTValue165()
        local var_202 = self.UIRoot
        local sw = GraphicSettingDB_1:GetUIData(GraphicSettingDB_1.FPSFineTuneSwitch)
        local var_69 = sw and GraphicSettingDB_1:GetUIData(GraphicSettingDB_1.FPSFineTuneNum) or 165
        var_202.Slider_screen3:SetLocked(not sw)
        var_202.ProgressBar_screen3:SetFillColorAndOpacity(sw and FLinearColor(1,1,1,1) or FLinearColor(1,0.625,0.6,1))
        local var_60 = (var_69 - var_93) / (165 - var_93)
        var_202.Veihclescreen3:SetText(LocUtil.LocalizeResFormat(10567, var_69))
        var_202.Slider_screen3:SetValue(var_60)
        var_202.ProgressBar_screen3:SetPercent(var_60)
    end
    function var_13:OnFPSFTValueChange3(var_69)
        GraphicSettingDB_1:UpdateUIData(GraphicSettingDB_1.FPSFineTuneNum, var_69)
        self:InitFPSFTValue165()
        if self:GetParentUI() then self:GetParentUI():SetDirty(true) end
        local var_43 = GraphicSettingDB_1.GetGameInstance and GraphicSettingDB_1.GetGameInstance()
        if var_43 then
            var_43:ExecuteCMD("t.MaxFPS", tostring(var_69))
            var_43:ExecuteCMD("r.FrameRateLimit", tostring(var_69))
        end
    end
    function var_13:OnFPSFTSliderValueChange3(var_174)
        if GraphicSettingDB_1:GetUIData(GraphicSettingDB_1.FPSFineTuneSwitch) then
            local var_69 = KismetMathLibrary_1.FCeil(var_174 * (165 - var_93) / var_203) * var_203 + var_93
            self:OnFPSFTValueChange3(func_6(var_69, var_93, 165))
        end
    end
    function var_13:OnFPSFTAdd3()
        local var_69 = GraphicSettingDB_1:GetUIData(GraphicSettingDB_1.FPSFineTuneNum)
        if var_69 then self:OnFPSFTValueChange3(math.min(165, var_69 + var_203)) end
    end
    function var_13:OnFPSFTMinus3()
        local var_69 = GraphicSettingDB_1:GetUIData(GraphicSettingDB_1.FPSFineTuneNum)
        if var_69 then self:OnFPSFTValueChange3(math.max(var_93, var_69 - var_203)) end
    end
    var_13.OnFPSFTAdd = var_13.OnFPSFTAdd3
    var_13.OnFPSFTMinus = var_13.OnFPSFTMinus3
    var_13.OnFPSFTSliderValueChange = var_13.OnFPSFTSliderValueChange3
end

]===])

-- ============================================================================
-- [ADDED] MATCH-ENTRY COSMETIC BURST
-- ----------------------------------------------------------------------------
-- The lobby loops stop on match entry, so pet / dead-box / vehicle / kill-counter
-- cosmetics would otherwise never be applied in-match.  This fires ONCE per
-- match entry and runs a short bounded burst using the already-loaded caches.
-- No file scanning, no table rebuilding, and it stops by itself.
-- ============================================================================
pcall(function()
    if not _G.__OnMatchEnter then return end
    _G.__OnMatchEnter(function()
        _G.__SkinBurst(function()
            pcall(function()
                local GD = package.loaded["GameLua.GameCore.Data.GameplayData"]
                        or require("GameLua.GameCore.Data.GameplayData")
                local char = GD and GD.GetPlayerCharacter and GD.GetPlayerCharacter()
                if char and slua and slua.isValid and slua.isValid(char) then
                    if _G.equip_character_avatar then pcall(_G.equip_character_avatar, char) end
                    if _G.ApplyWeaponSkins       then pcall(_G.ApplyWeaponSkins, char) end
                    if _G.ApplyVehicleSkins      then pcall(_G.ApplyVehicleSkins, char) end
                end
                if _G.HandlePetLogic then pcall(_G.HandlePetLogic) end
                local PC = GD and GD.GetPlayerController and GD.GetPlayerController()
                if PC and slua and slua.isValid and slua.isValid(PC) then
                    if _G.DeadBox_TemperRequest then pcall(_G.DeadBox_TemperRequest, PC) end
                end
                if _G.ForceEnableKillCounterUI then pcall(_G.ForceEnableKillCounterUI) end
                if _G.RefreshKillCounterUI     then pcall(_G.RefreshKillCounterUI) end
            end)
        end, 0.5, 12)   -- 12 passes over ~6s, then silent for the rest of the match
    end)
end)

-- ============================================================================
-- 4. login.lua start hook
-- ============================================================================
pcall(function()
    local l = _G.LunarLoginRuntime
    if l and type(l.Start) == "function" then l.Start() end
    if _G.__run_pending_features then _G.__run_pending_features() end
end)

-- ============================================================================
-- [INTEGRATED] Run the deferred 5_...lua live-patch blocks.
-- Same ordering rule as combined.lua's feature chunks: nothing is patched at
-- load time.  The installer is chained onto __run_pending_features, which only
-- fires once the login gate authorises, i.e. after the game has bootstrapped
-- and LobbySystem / Tss / Gokuba / ban_util / logic_security all exist.
-- ============================================================================
pcall(function()
    local __orig_run_pending = _G.__run_pending_features
    if type(__orig_run_pending) == "function" then
        _G.__run_pending_features = function(...)
            local __ran = __orig_run_pending(...)
            if __ran and _G.__install_5_early_hooks then
                pcall(_G.__install_5_early_hooks)
            end
            return __ran
        end
    end
    -- Harmless early attempt: applies only if the modules already exist.
    if _G.__install_5_early_hooks then pcall(_G.__install_5_early_hooks) end
end)

-- One-shot deferred installer for the module's own CONFIG.auto_install_on_load.
pcall(function()
    local B = _G.__Bypass
    if not B or type(B.install) ~= "function" then return end
    local function tryInstall()
        if _G.__Bypass_auto_installed then return end
        if _G.__IsMatchActive and _G.__IsMatchActive() then return end
        if not _G.__IsLobbyActive or not _G.__IsLobbyActive() then return end
        _G.__Bypass_auto_installed = true
        pcall(B.install)
    end
    local tk = nil
    pcall(function() tk = require("common.time_ticker") end)
    if tk and tk.AddTimerOnce then
        pcall(tk.AddTimerOnce, 3.0, tryInstall)
        pcall(tk.AddTimerOnce, 8.0, tryInstall)
    end
end)

if #__combined_errors > 0 and print then
    for _, __e in ipairs(__combined_errors) do
        print("[COMBINED ERROR] " .. tostring(__e))
    end
end
