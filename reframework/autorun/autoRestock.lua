----------- Font ---------------------------
FONT_NAME = 'NotoSansSC-Regular.otf'
FONT_SIZE = 18
CJK_GLYPH_RANGES = {
    0x0020, 0x00FF, -- Basic Latin + Latin Supplement
    0x2000, 0x206F, -- General Punctuation
    0x3000, 0x30FF, -- CJK Symbols and Punctuations, Hiragana, Katakana
    0x31F0, 0x31FF, -- Katakana Phonetic Extensions
    0xFF00, 0xFFEF, -- Half-width characters
    0x4e00, 0x9FAF, -- CJK Ideograms
    0,
}

local font = imgui.load_font(FONT_NAME, FONT_SIZE, CJK_GLYPH_RANGES)

----------- Helper Functions ----------------
local ChatManager = sdk.get_managed_singleton("snow.gui.ChatManager")

local function FindIndex(table, value)
    for i = 1, #table do
        if table[i] == value then
            return i;
        end
    end

    return nil;
end

local function GetEnumMap(enumTypeName)
    local t = sdk.find_type_definition(enumTypeName)
    if not t then return {} end

    local fields = t:get_fields()
    local enum = {}

    for i, field in ipairs(fields) do
        if field:is_static() then
            local name = field:get_name()
            local raw_value = field:get_data(nil)
            enum[raw_value] = name
        end
    end

    return enum
end

local CycleTypeMap = GetEnumMap("snow.data.CustomShortcutSystem.SycleTypes")


------------- Config Management --------------
local Languages = {"en-US", "zh-CN"}

local config = json.load_file("AutoRestock.json") or {}
if config.Enabled == nil then
    config.Enabled = true
end
if config.EnableNotification == nil then
    config.EnableNotification = true
end
config.DefaultSet = config.DefaultSet or 1

if config.WeaponTypeConfig == nil then
    config.WeaponTypeConfig = {}
end
for i = 1, 14, 1 do
    if config.WeaponTypeConfig[i] == nil then
        config.WeaponTypeConfig[i] = -1
    end
end

if config.EquipLoadoutConfig == nil then
    config.EquipLoadoutConfig = {}
end
for i = 1, 112, 1 do
    if config.EquipLoadoutConfig[i] == nil then
        config.EquipLoadoutConfig[i] = -1
    end
end

if config.Language == nil or FindIndex(Languages, config.Language) == nil then
    config.Language = "en-US"
end

if config.MaxItemLoadoutIndex == nil then
    config.MaxItemLoadoutIndex = 0
end

re.on_config_save(function()
    json.dump_file("AutoRestock.json", config)
end)

local function SendMessage(text)
    if not config.EnableNotification then return end
    if ChatManager == nil then
        ChatManager = sdk.get_managed_singleton("snow.gui.ChatManager")
    end
    ChatManager:call("reqAddChatInfomation", text, 2289944406)
end

----------- Item Loadout Management ----------
local SystemDataManager = sdk.get_managed_singleton("snow.data.SystemDataManager")
local ShortcutManager = nil
if SystemDataManager then
    ShortcutManager = SystemDataManager:call("getCustomShortcutSystem")
end
local DataManager = sdk.get_managed_singleton("snow.data.DataManager")

-- itemSetIndex starts from 0
local function GetItemLoadout(loadoutIndex)
    if DataManager == nil then DataManager = sdk.get_managed_singleton("snow.data.DataManager") end
    -- snow.data.ItemMySet, snow.data.PlItemPouchMySetData
    return DataManager:call("get_ItemMySet"):call("getData", loadoutIndex)

    -- get_DangoMySet, snow.facility.DangoMySet
end

-- itemSetIndex starts from 0
local function ApplyItemLoadout(loadoutIndex)
    if DataManager == nil then DataManager = sdk.get_managed_singleton("snow.data.DataManager") end
    -- snow.data.ItemMySet, snow.data.PlItemPouchMySetData
    return DataManager:call("get_ItemMySet"):call("applyItemMySet", loadoutIndex)

    -- get_DangoMySet, snow.facility.DangoMySet
end

local function GetItemLoadoutName(loadoutIndex)
    if DataManager == nil then DataManager = sdk.get_managed_singleton("snow.data.DataManager") end
    return GetItemLoadout(loadoutIndex):call("get_Name")
end

----------- Equipment Loadout Managementt ----
local PlayerManager = sdk.get_managed_singleton("snow.player.PlayerManager")

local function GetCurrentWeaponType()
    if PlayerManager == nil then PlayerManager = sdk.get_managed_singleton("snow.player.PlayerManager") end
    if PlayerManager == nil then return end
    local MasterPlayer = PlayerManager:call("findMasterPlayer")
    if MasterPlayer == nil then return end

    local weaponType = MasterPlayer:get_field("_playerWeaponType")
    return weaponType
end

local EquipDataManager = sdk.get_managed_singleton("snow.data.EquipDataManager")

local function GetEquipmentLoadout(loadoutIndex)
    if EquipDataManager == nil then EquipDataManager = sdk.get_managed_singleton("snow.data.EquipDataManager") end
    local data = EquipDataManager:call("get_PlEquipMySetList"):call("get_Item", loadoutIndex) -- snow.equip.PlEquipMySetData
    return data
end

local function GetEquipmentLoadoutWeaponType(loadoutIndex)
    return GetEquipmentLoadout(loadoutIndex):call("getWeaponData"):call("get_PlWeaponType")
end

local function GetEquipmentLoadoutName(loadoutIndex)
    return GetEquipmentLoadout(loadoutIndex):call("get_Name")
end

local function EquipmentLoadoutIsNotEmpty(loadoutIndex)
    return GetEquipmentLoadout(loadoutIndex):call("get_IsUsing")
end

local function EquipmentLoadoutIsEquipped(loadoutIndex)
    return GetEquipmentLoadout(loadoutIndex):call("isSamePlEquipPack")
end

--------------- Temporary Data ----------------
local lastHitLoadout = -1 -- Cached loadout, avoid unnecessary search

---------------  Localization  ----------------

local LocalizedStrings = {
    ["en-US"] = {
        WeaponNames = {
            [0] = "大剣",
            [1] = "スラッシュアックス",
            [2] = "太刀",
            [3] = "ライトボウガン",
            [4] = "ヘビィボウガン",
            [5] = "ハンマー",
            [6] = "ガンランス",
            [7] = "ランス",
            [8] = "片手剣",
            [9] = "双剣",
            [10] = "狩猟笛",
            [11] = "チャージアックス",
            [12] = "操虫棍",
            [13] = "弓",
        },
        UseDefaultItemSet = "デフォルト設定を適用します。",
        WeaponTypeNotSetUseDefault = "%s は設定されていません。デフォルト設定を適用します。%s",
        UseWeaponTypeItemSet = "%sの設定を適用します。%s",

        FromLoadout = "マイセット [<COL YEL>%s</COL>] に対応するアイテムマイセット [<COL YEL>%s</COL>] を適用しました。",
        MismatchLoadout = "現在の武器種にマッチしたアイテムマイセットが見つかりませんでした。\n",
        FromWeaponType = "[<COL YEL>%s</COL>] に対応するアイテムマイセット [<COL YEL>%s</COL>] を適用しました。",
        MismatchWeaponType = "[<COL YEL>%s</COL>] に対応するアイテムマイセットが見つかりませんでした。\n",
        FromDefault = "デフォルトのマイセット [<COL YEL>%s</COL>] を適用しました。",
        OutOfStock = "<COL RED>在庫不足</COL>のため、マイセット [<COL YEL>%s</COL>] の適用をキャンセルしました。",

        PaletteNilError = "<COL RED>エラー</COL>。パレットセットが設定されていません。",
        PaletteApplied = "パレットセット [<COL YEL>%s</COL>] を適用しました。",
        PaletteListEmpty = "パレットセットが空のため、スキップしました。",
    }
}

local function Localized()
    return LocalizedStrings[config.Language]
end

local function GetWeaponName(weaponType)
    if weaponType == nil then return "<ERROR>:GetWeaponName failed" end
    return Localized().WeaponNames[weaponType]
end

local function UseDefaultItemSet()
    return Localized().UseDefaultItemSet
end

local function WeaponTypeNotSetUseDefault(weaponName, itemName)
    return string.format(Localized().WeaponTypeNotSetUseDefault, weaponName, itemName)
end

local function UseWeaponTypeItemSet(weaponName, itemName)
    return string.format(Localized().UseWeaponTypeItemSet, weaponName, itemName)
end

local function FromLoadout(equipName, itemName)
    return string.format(Localized().FromLoadout, equipName, itemName)
end

local function FromWeaponType(equipName, itemName, mismatch)
    local msg = ""
    if mismatch then
        msg = Localized().MismatchLoadout
    end
    return msg .. string.format(Localized().FromWeaponType, equipName, itemName)
end

local function FromDefault(itemName, mismatch)
    local msg = ""
    if mismatch then
        msg = string.format(Localized().MismatchWeaponType, GetWeaponName(GetCurrentWeaponType()))
    end
    return msg .. string.format(Localized().FromDefault, itemName)
end

local function OutOfStock(itemName)
    return string.format(Localized().FromDefault, itemName)
end

local function PaletteNilError()
    return Localized().PaletteNilError
end

local function PaletteApplied(paletteName)
    return string.format(Localized().PaletteApplied, paletteName)
end

local function PaletteListEmpty()
    return Localized().PaletteListEmpty
end

local function EquipmentChanged()
    return "Equipment changed since last apply equipment loadout."
end

---------------      CORE      ----------------
-- weaponType starts from 0
local function GetWeaponTypeItemLoadoutName(weaponType)
    local got = config.WeaponTypeConfig[weaponType + 1]
    if (got == nil) or (got == -1) then
        return UseDefaultItemSet()
    end
    return GetItemLoadoutName(got)
end

-- loadoutIndex starts from 0
local function GetLoadoutItemLoadoutIndex(loadoutIndex)
    local got = config.EquipLoadoutConfig[loadoutIndex + 1]
    if (got == nil) or (got == -1) then
        local weaponType = GetEquipmentLoadoutWeaponType(loadoutIndex)

        local got = config.WeaponTypeConfig[weaponType+1]
        if (got == nil) or (got == -1) then
            return WeaponTypeNotSetUseDefault(GetWeaponName(weaponType), GetItemLoadoutName(config.DefaultSet))
        end

        return UseWeaponTypeItemSet(GetWeaponName(weaponType), GetItemLoadoutName(got))
    end
    return GetItemLoadoutName(got)
end

-- arg loadoutIndex is set when player applying equipment loadout
-- If loadOutIndex == nil, use cached loadout. if cache missed, search all loadouts.
-- If no loadout matched, use weapon type.
-- If no weapon type setting, use default.
local function AutoChooseItemLoadout(loadoutIndex)
    local cacheHit = false
    local loadoutMismatch = false
    if loadoutIndex then
        -- player is applying loadout
        cacheHit = true
        -- Please note that the function is hooked in pre-function, so the player's current equipments haven't changed yet
        -- So here we do not determine whether the loadout is really equipped or not
        lastHitLoadout = loadoutIndex
        local got = config.EquipLoadoutConfig[loadoutIndex + 1]
        if (got ~= nil) and (got ~= -1) then
            return got, "Loadout", GetEquipmentLoadoutName(loadoutIndex)
        end
    else
        -- player is accepting quest
        if lastHitLoadout ~= -1 then
            -- check the cached loadout first
            local cachedLoadoutIndex = lastHitLoadout
            if EquipmentLoadoutIsEquipped(cachedLoadoutIndex) then
                lastHitLoadout = cachedLoadoutIndex
                cacheHit = true
                local got = config.EquipLoadoutConfig[cachedLoadoutIndex + 1]
                if (got ~= nil) and (got ~= -1) then
                    return got, "Loadout", GetEquipmentLoadoutName(cachedLoadoutIndex)
                end
            else
                -- SendMessage(EquipmentChanged())
            end
        end

        if not cacheHit then
            -- SendMessage("searching Loadout")
            local found = false
            for i = 1, 112, 1 do
                local loadoutIndex = i - 1
                if EquipmentLoadoutIsEquipped(loadoutIndex) then
                    found = true
                    lastHitLoadout = i
                    local got = config.EquipLoadoutConfig[i]
                    if (got ~= nil) and (got ~= -1) then
                        return got, "Loadout", GetEquipmentLoadoutName(loadoutIndex)
                    end
                    break
                end
            end
            if not found then
                loadoutMismatch = true
            end
        end
    end

    local weaponType
    if loadoutIndex then
        weaponType = GetEquipmentLoadoutWeaponType(loadoutIndex)
    else
        weaponType = GetCurrentWeaponType()
    end
    local got = config.WeaponTypeConfig[weaponType+1]
    if (got ~= nil) and (got ~= -1) then
        return got, "WeaponType", GetWeaponName(weaponType), loadoutMismatch
    end

    return config.DefaultSet, "Default", "", loadoutMismatch
end

------------------------

local function Restock(loadoutIndex)
    if config.Enabled == false then return end

    local itemLoadoutIndex, matchedType, matchedName, loadoutMismatch = AutoChooseItemLoadout(loadoutIndex)
    local loadout = GetItemLoadout(itemLoadoutIndex)
    local itemLoadoutName = loadout:call("get_Name")

    local msg = ""
    if loadout:call("isEnoughItem") then
        -- loadout:call("exportToPouch", false)
        ApplyItemLoadout(itemLoadoutIndex)
        if matchedType == "Loadout" then
            msg = FromLoadout(matchedName, itemLoadoutName)
        elseif matchedType == "WeaponType" then
            msg = FromWeaponType(matchedName, itemLoadoutName, loadoutMismatch)
        else
            msg = FromDefault(itemLoadoutName, loadoutMismatch)
        end

        -- Apply Radial Menu
        local paletteIndex = loadout:call("get_PaletteSetIndex") -- Nullable type so we call GetValueOrDefault later
        if paletteIndex == nil then
            msg = msg .. "\n" .. PaletteNilError()
        else
            local radialSetIndex = paletteIndex:call("GetValueOrDefault")
            -- SendMessage(CycleTypeMap[0] .. " Palette: " .. radialSetIndex)
            local paletteList = ShortcutManager:call("getPaletteSetList", 0) -- 0 is Quest
            if paletteList then
                local palette = paletteList:call("get_Item", radialSetIndex)
                if palette then
                    msg = msg .. "\n" .. PaletteApplied(palette:call("get_Name"))
                end
            else
                msg = msg .. "\n" .. PaletteListEmpty()
            end
            ShortcutManager:call("setUsingPaletteIndex", 0, radialSetIndex)
        end
    else
        msg = OutOfStock(itemLoadoutName)
    end
    SendMessage(msg)
end

----------------- Hook ------------------
-- On apply equipment loadout
sdk.hook(
    sdk.find_type_definition("snow.data.EquipDataManager"):get_method("applyEquipMySet(System.Int32)"),
    --snow.equip.PlEquipMySetData
    function(args)
        local idx = sdk.to_int64(args[3])
        Restock(idx)
    end
)

-- On accept quest
sdk.hook(
    sdk.find_type_definition("snow.QuestManager"):get_method("questActivate(snow.LobbyManager.QuestIdentifier)"),
    function(args)
        Restock()
    end
)

-- On back to village
-- This does not seem to work when the game is first loaded, most likely because the EquipDataManager cannot be obtained correctly.
-- It also causes restock every time you teleport, perhaps requiring a flag to mark (which needs to be reset when you return from a qeust).
-- sdk.hook(
--     sdk.find_type_definition("snow.gui.GuiManager"):get_method("notifyReturnInVillage"),
--     function(args)
--         Restock()
--     end
-- )

re.on_frame(function()
    if ChatManager == nil then ChatManager = sdk.get_managed_singleton("snow.gui.ChatManager") end
    if DataManager == nil then DataManager = sdk.get_managed_singleton("snow.data.DataManager") end
    if EquipDataManager == nil then EquipDataManager = sdk.get_managed_singleton("snow.data.EquipDataManager") end
    if ShortcutManager == nil then ShortcutManager = sdk.get_managed_singleton("snow.data.CustomShortcutSystem") end
    if PlayerManager == nil then PlayerManager = sdk.get_managed_singleton("snow.player.PlayerManager") end

    if SystemDataManager == nil then SystemDataManager = sdk.get_managed_singleton("snow.data.SystemDataManager") end
    if ShortcutManager == nil and SystemDataManager ~= nil then
        ShortcutManager = SystemDataManager:call("getCustomShortcutSystem")
    end
end)

----------------------------------------------
re.on_draw_ui(function()
    local configChanged = false
    imgui.push_font(font)
    if imgui.tree_node("AutoRestock") then
        if ChatManager ~= nil and DataManager ~= nil and EquipDataManager ~= nil then
            _, config.Enabled = imgui.checkbox("Enabled", config.Enabled)
            _, config.EnableNotification = imgui.checkbox("EnableNotification", config.EnableNotification)

            local langIdx = FindIndex(Languages, config.Language)
            configChanged, langIdx = imgui.combo("Language", langIdx, Languages)
            config.Language = Languages[langIdx]

            _, config.DefaultSet = imgui.slider_int("Default ItemSet", config.DefaultSet, 0, 39,
                GetItemLoadoutName(config.DefaultSet))

            if imgui.tree_node("WeaponType") then
                for i = 1, 14, 1 do
                    local weaponType = i - 1
                    _, config.WeaponTypeConfig[i] = imgui.slider_int(GetWeaponName(weaponType),
                        config.WeaponTypeConfig[i], -1, 39, GetWeaponTypeItemLoadoutName(weaponType))
                end
                imgui.tree_pop()
            end

            if imgui.tree_node("Loadout") then
                for i = 1, 112, 1 do
                    local loadoutIndex = i - 1
                    local name = GetEquipmentLoadoutName(loadoutIndex)
                    local isUsing = EquipmentLoadoutIsNotEmpty(loadoutIndex)
                    if name and isUsing then
                        local same = EquipmentLoadoutIsEquipped(loadoutIndex)
                        local msg = ""
                        if same then msg = " (Current)" end
                        _, config.EquipLoadoutConfig[i] = imgui.slider_int(name .. msg,
                            config.EquipLoadoutConfig[i], -1, 39, GetLoadoutItemLoadoutIndex(loadoutIndex))
                    end
                end
                imgui.tree_pop();
            end
        else
            imgui.text("Loading...")
        end
        imgui.tree_pop();
    end
    imgui.pop_font();

    if configChanged then
        json.dump_file("AutoRestock.json", config)
    end
end)

-------------------------Custom Mod UI COOLNESS----------------------------------

--no idea how this works but google to the rescue
--can use this to check if the api is available and do an alternative to avoid complaints from users
function IsModuleAvailable(name)
  if package.loaded[name] then
    return true
  else
    for _, searcher in ipairs(package.searchers or package.loaders) do
      local loader = searcher(name)
      if type(loader) == 'function' then
        package.preload[name] = loader
        return true
      end
    end
    return false
  end
end

local apiPackageName = "ModOptionsMenu.ModMenuApi";
local modUI = nil;
local DrawSlider;

if IsModuleAvailable(apiPackageName) then
	modUI = require(apiPackageName);
end

if modUI then
	local name = "AutoRestock";
	local description = "It does what it says on the tin.";
	modUI.OnMenu(name, description, function()
            local changed = false
	    local configChanged = false

            modUI.Header("メイン設定");
            changed, config.Enabled = modUI.Toggle("有効無効", config.Enabled, "有効かどうか")
            configChanged = configChanged or changed

            local itemLoadoutName = GetItemLoadoutName(config.MaxItemLoadoutIndex)
            changed, config.MaxItemLoadoutIndex = modUI.Slider(itemLoadoutName, config.MaxItemLoadoutIndex, -1, 39, "アイテムマイセット終端")
            configChanged = configChanged or changed

            modUI.Header("武器種デフォルトマイセット");
            for i = 1, 14, 1 do
                local weaponType = i - 1
                local weaponName = GetWeaponName(weaponType)
                local itemLoadoutName = ""
                if config.WeaponTypeConfig[i] > -1 then
                    local itemloadout = GetItemLoadout(config.WeaponTypeConfig[i])
                    itemLoadoutName = "／" .. itemloadout:call("get_Name")
                end
                changed, config.WeaponTypeConfig[i] = modUI.Slider(weaponName .. itemLoadoutName, config.WeaponTypeConfig[i], -1, config.MaxItemLoadoutIndex, GetWeaponTypeItemLoadoutName(weaponType))
                configChanged = configChanged or changed
            end

            modUI.Header("装備マイセット");
            for i = 1, 112, 1 do
                local loadoutIndex = i - 1
                local name = GetEquipmentLoadoutName(loadoutIndex)

                local isUsing = EquipmentLoadoutIsNotEmpty(loadoutIndex)
                if name and isUsing then
                    local same = EquipmentLoadoutIsEquipped(loadoutIndex)
                    local msg = ""
                    if same then msg = " (装備中)" end
                    local itemLoadoutName = ""
                    if config.EquipLoadoutConfig[i] > -1 then
                        local itemloadout = GetItemLoadout(config.EquipLoadoutConfig[i])
                        itemLoadoutName = "／" .. itemloadout:call("get_Name")
                    end

                    changed, config.EquipLoadoutConfig[i] = modUI.Slider(name .. msg .. itemLoadoutName, config.EquipLoadoutConfig[i], -1, config.MaxItemLoadoutIndex, GetLoadoutItemLoadoutIndex(loadoutIndex))
                    configChanged = configChanged or changed
                end
            end

	    if configChanged then
	        json.dump_file("AutoRestock.json", config)
	    end
	end);
end
