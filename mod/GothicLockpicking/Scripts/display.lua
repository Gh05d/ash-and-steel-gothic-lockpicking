-- Text in the combination minigame's UI: how many lockpicks are left (the combination minigame does not show
-- it, the game's normal one does) and, with the Master Lockpicker perk, the correct directions of the best
-- attempt at this lock.
local M = {}

local ARROW = { [0] = "\u{2190}", [1] = "\u{2192}" } -- left, right
local LETTER = { [0] = "L", [1] = "R" }

local text = nil -- the TextBlock this module added to the current minigame UI

local function valid(o)
    return o ~= nil and o:IsValid()
end

local function rootPanel(keylock)
    local ui = keylock.PickLockUI
    if not valid(ui) then return nil end
    local root = ui.WidgetTree.RootWidget
    return valid(root) and root or nil
end

-- "← ← → ←" (or "L L R L" with useArrows = false)
function M.directions(seq, useArrows)
    local marks = useArrows and ARROW or LETTER
    local parts = {}
    for i, d in ipairs(seq) do parts[i] = marks[d] end
    return table.concat(parts, " ")
end

local function create(keylock, cfg)
    local root = rootPanel(keylock)
    if not root then return nil end
    local tb = StaticConstructObject(StaticFindObject("/Script/UMG.TextBlock"), root)
    if not valid(tb) then return nil end
    local slot = root:AddChildToCanvas(tb)
    if valid(slot) then
        slot:SetPosition({ X = cfg.textX, Y = cfg.textY })
        slot:SetAutoSize(true)
    end
    pcall(function() tb.Font.Size = cfg.textSize end)
    return tb
end

function M.show(keylock, lines, cfg)
    if not valid(text) then text = create(keylock, cfg) end
    if valid(text) then text:SetText(FText(table.concat(lines, "\n"))) end
end

function M.clear()
    if valid(text) then pcall(function() text:RemoveFromParent() end) end
    text = nil
end

return M
