local Social = {}

local PRESENCE_TIMEOUT = 5
local ROSTER_TIMEOUT = 3
local NO_ACCOUNT_ID = "no_account_id"
local BOARD_VIEW = "another_scoreboard_view"
local SOCIAL_VIEW = "social_menu_view"
local ROSTER_VIEW = "social_menu_roster_view"

local _generation = 0
local _phase = nil
local _account_id = nil
local _player_info = nil
local _promise = nil
local _timer = 0

function Social.account_id_for_player(player)
    if not player or type(player.is_human_controlled) ~= "function" or not player:is_human_controlled() then
        return nil
    end

    local account_id = type(player.account_id) == "function" and player:account_id() or nil
    if account_id == nil or tostring(account_id) == "" or tostring(account_id) == NO_ACCOUNT_ID then
        return nil
    end

    return account_id
end

local function _social_service()
    local data_service = Managers.data_service

    return data_service and data_service.social
end

local function _social_navigation_open(ui)
    return ui:view_active(SOCIAL_VIEW) or ui:is_view_closing(SOCIAL_VIEW)
        or ui:view_active(ROSTER_VIEW) or ui:is_view_closing(ROSTER_VIEW)
end

local function _board_open(ui)
    return ui:view_active(BOARD_VIEW) and not ui:is_view_closing(BOARD_VIEW)
end

function Social.reset()
    _generation = _generation + 1
    if _promise then
        _promise:cancel()
        _promise = nil
    end
    _phase = nil
    _account_id = nil
    _player_info = nil
    _timer = 0
end

function Social.request(account_id)
    local account_id_type = type(account_id)
    if (account_id_type ~= "string" and account_id_type ~= "number") or tostring(account_id) == ""
        or tostring(account_id) == NO_ACCOUNT_ID then
        return false
    end

    Social.reset()
    _account_id = account_id
    _phase = "queued"
    _timer = PRESENCE_TIMEOUT

    return true
end

local function _begin_resolving()
    local social_service = _social_service()
    if not social_service or not Managers.presence then
        Social.reset()

        return
    end

    local player_info = social_service:get_player_info_by_account_id(_account_id)
    if not player_info or type(player_info.first_update_promise) ~= "function" then
        Social.reset()

        return
    end

    _account_id = nil
    _player_info = player_info
    _phase = "resolving"
    _timer = PRESENCE_TIMEOUT

    local generation = _generation
    local ok, promise = pcall(player_info.first_update_promise, player_info)
    if not ok or not promise then
        Social.reset()

        return
    end

    _promise = promise
    promise:next(function(updated_player_info)
        if generation ~= _generation or _phase ~= "resolving" then
            return
        end

        _promise = nil
        _player_info = updated_player_info or player_info
        _phase = "ready"
    end):catch(function()
        if generation ~= _generation then
            return
        end

        Social.reset()
    end)
end

local function _open_social_view(ui)
    if not _board_open(ui) or _social_navigation_open(ui) then
        Social.reset()

        return
    end

    ui:close_view(BOARD_VIEW, true)

    if not ui:open_view(SOCIAL_VIEW, nil, nil, nil, nil, { can_exit = true }) then
        Social.reset()

        return
    end

    _phase = "opening"
    _timer = ROSTER_TIMEOUT
end

local function _show_popup(ui)
    local roster = ui:view_instance(ROSTER_VIEW)
    if not roster or not ui:view_active(ROSTER_VIEW) or ui:is_view_closing(ROSTER_VIEW) or not roster:entered() then
        return false
    end

    local player_info = _player_info
    _phase = nil
    _account_id = nil
    _player_info = nil
    _timer = 0
    roster:cb_show_popup_menu_for_player(player_info)

    return true
end

function Social.update(dt)
    if not _phase then
        return
    end

    local ui = Managers.ui
    if not ui then
        Social.reset()

        return
    end

    if _phase == "queued" then
        _begin_resolving()

        if not _phase then
            return
        end
    end

    if _phase == "resolving" then
        if not _board_open(ui) then
            Social.reset()

            return
        end

        _timer = _timer - (dt or 0)
        if _timer <= 0 then
            Social.reset()
        end

        return
    end

    if _phase == "ready" then
        _open_social_view(ui)

        if not _phase then
            return
        end
    end

    if _phase == "opening" then
        if not ui:view_active(SOCIAL_VIEW) or ui:is_view_closing(SOCIAL_VIEW) then
            Social.reset()

            return
        end

        if _show_popup(ui) then
            return
        end

        _timer = _timer - (dt or 0)
        if _timer <= 0 then
            Social.reset()
        end
    end
end

return Social
