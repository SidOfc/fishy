local Fishy = {
  state = { initialized = false, entries = {} },
  frames = { event = CreateFrame('Frame') },
  commands = {},
  events = { global = {}, player = {} },
  icons = {
    plus = {
      normal = 'Interface/Buttons/UI-PlusButton-Up',
      highlight = 'Interface/Buttons/UI-PlusButton-Hilight',
    },
    minus = {
      normal = 'Interface/Buttons/UI-MinusButton-Up',
      highlight = 'Interface/Buttons/UI-MinusButton-Hilight',
    },
  },
  setting_details = {
    auto_loot = {
      label = 'Auto Loot',
      tooltip = 'Automatically loot while fishing.',
    },
    auto_hide = {
      label = 'Auto Hide',
      tooltip = 'Automatically hide the fishing information panel.',
    },
    auto_hide_delay = {
      label = 'Auto Hide Delay',
      tooltip = 'Delay in seconds after which the fishing information panel will be hidden.',
    },
  },
  lures = {
    items = {
      { id = 67404, bonus = 15 }, -- Glass Fishing Bobber
      { id = 6529, bonus = 25 }, -- Shiny Bauble
      { id = 6530, bonus = 50 }, -- Nightcrawlers
      { id = 6811, bonus = 50 }, -- Aquadynamic Fish Lens
      { id = 6532, bonus = 75 }, -- Bright Baubles
      { id = 7307, bonus = 75 }, -- Flesh Eating Worm
      { id = 6533, bonus = 100 }, -- Aquadynamic Fish Attractor
      { id = 62673, bonus = 100 }, -- Feathered Lure
      { id = 34861, bonus = 100 }, -- Sharpened Fish Hook
      { id = 46006, bonus = 100 }, -- Glow Worm
      { id = 68049, bonus = 150 }, -- Heat-Treated Spinning Lure
    },
    hats = {
      { id = 19972, bonus = 5 }, -- Lucky Fishing Hat
      { id = 33820, bonus = 75 }, -- Weather-Beaten Fishing Hat
    },
  },
  character = {
    data = {},
    data_defaults = {
      entries = {},
      settings = {
        auto_loot = false,
        auto_hide = true,
        auto_hide_delay = 10,
      },
    },
  },
  debug = {},
}

setmetatable(Fishy.events.global, Fishy.events.global)
setmetatable(Fishy.events.player, Fishy.events.player)

function Fishy.IsFishingSpell(spell_id)
  return spell_id == 7620
    or spell_id == 7731
    or spell_id == 7732
    or spell_id == 18248
    or spell_id == 33095
    or spell_id == 51294
    or spell_id == 88868
end

function Fishy.Dump(...)
  return DevTools_Dump(...)
end

function Fishy.FindElement(frame, path)
  local current = path[1]
  local next_path = {}

  for idx = 2, #path do
    next_path[#next_path + 1] = path[idx]
  end

  for _, child in ipairs({ frame:GetChildren() }) do
    if child.fishy_data_id == current then
      if #next_path == 0 then
        return child
      else
        return Fishy.FindElement(child, next_path)
      end
    end
  end
end

function Fishy.GetCaughtPercentages(caught)
  local total = 0
  local result = {}

  for _, catch in ipairs(caught) do
    total = total + catch.count
  end

  for _, catch in ipairs(caught) do
    result[catch.id] = catch.count / total * 100
  end

  return result
end

function Fishy.GetSettingLabel(setting)
  return Fishy.setting_details[setting] and Fishy.setting_details[setting].label
end

function Fishy.GetSettingTooltip(setting)
  return Fishy.setting_details[setting] and Fishy.setting_details[setting].tooltip
end

function Fishy.Color(text, r, g, b, a)
  return string.format('|c%02x%02x%02x%02x%s|r', 255 * (a or 1), 255 * r, 255 * g, 255 * b, text)
end

function Fishy.Print(...)
  local addon = Fishy.Color('Fishy', 0, 1, 1)
  local items = { ... }

  for idx = 1, #items do
    items[idx] = tostring(items[idx])
  end

  local text = table.concat(items, ' ')
  local msg = Fishy.Color(text, 0.2, 0.8, 0.2)

  print(string.format('%s %s', addon, msg))
end

function Fishy.character.SortCaught(entry)
  if entry and entry.caught then
    table.sort(entry.caught, function(a, b)
      if a.count > b.count then
        return true
      elseif a.count < b.count then
        return false
      else
        return string.lower(a.name) < string.lower(b.name)
      end
    end)
  end
end

function Fishy.frames.Texture(frame, r, g, b, a)
  local texture = frame:CreateTexture(nil, 'BACKGROUND')

  texture:SetAllPoints(true)
  texture:SetColorTexture(r, g, b, a)

  return texture
end

function Fishy.frames.EnableMovement(frame)
  frame:EnableMouse(true)
  frame:SetMovable(true)

  frame:SetScript('OnMouseDown', function(self)
    self:StartMoving()
  end)

  frame:SetScript('OnMouseUp', function(self)
    self:StopMovingOrSizing()
  end)
end

function Fishy.character.FishingSkillInfo()
  local _, _, _, fishing_idx = GetProfessions()

  if fishing_idx then
    local _, _, level, max_level, _, _, _, modifier = GetProfessionInfo(fishing_idx)

    return { level = level, max_level = max_level, modifier = modifier, total_level = level + modifier }
  end
end

function Fishy.frames.CreateFishingPanelTab(parent, text, padding)
  local Container = CreateFrame('Button', nil, parent)
  local Label = Container:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')

  Label:SetText(text)
  Container:SetSize(Label:GetStringWidth() + padding * 2, Label:GetStringHeight() + padding * 2)
  Label:SetPoint('CENTER', Container, 'CENTER')

  function Container.SetSelected(value)
    local modifier = value and 1.5 or 1
    local alpha = value and 1 or 0.5

    Container:SetSize(Label:GetStringWidth() + padding * 2, Label:GetStringHeight() + padding * modifier * 2)
    Container:SetAlpha(alpha)
  end

  return Container
end

function Fishy.frames.CreateFishingPanel()
  local FishingPanel = CreateFrame('Frame', 'FishyFishingPanel', UIParent)
  local GlobalTab = Fishy.frames.CreateFishingPanelTab(FishingPanel, 'All Time', 6)
  local CurrentTab = Fishy.frames.CreateFishingPanelTab(FishingPanel, 'Current', 6)
  local entries = Fishy.character.data.entries

  GlobalTab:SetPoint('BOTTOMLEFT', FishingPanel, 'TOPLEFT')
  CurrentTab:SetPoint('BOTTOMLEFT', GlobalTab, 'BOTTOMRIGHT', 5, 0)
  Fishy.frames.Texture(GlobalTab, 0, 0, 0, 0.6)
  Fishy.frames.Texture(CurrentTab, 0, 0, 0, 0.6)

  GlobalTab:SetScript('OnClick', function()
    entries = Fishy.character.data.entries

    GlobalTab.SetSelected(true)
    CurrentTab.SetSelected(false)
    FishingPanel.Update()
  end)

  CurrentTab:SetScript('OnClick', function()
    entries = Fishy.state.entries

    GlobalTab.SetSelected(false)
    CurrentTab.SetSelected(true)
    FishingPanel.Update()
  end)

  GlobalTab.SetSelected(true)
  CurrentTab.SetSelected(false)

  FishingPanel.Name = FishingPanel:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
  FishingPanel.Name:SetPoint('TOPLEFT', 5, -5)

  FishingPanel.Skill = FishingPanel:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
  FishingPanel.Skill:SetPoint('TOPLEFT', FishingPanel.Name, 0, -13)

  FishingPanel.ContentContainer = CreateFrame('Frame', nil, FishingPanel)
  FishingPanel.ContentContainer:SetPoint('TOPLEFT', FishingPanel, 'TOPLEFT', 2, -35)
  FishingPanel.ContentContainer:SetPoint('TOPRIGHT', FishingPanel, 'TOPRIGHT', -2, -35)

  FishingPanel.Content = Fishy.frames.CreateScrollableContent(FishingPanel, FishingPanel.ContentContainer)
  FishingPanel.Content.Caught = CreateFrame('Frame', nil, FishingPanel.Content)
  FishingPanel.Content.Caught:SetPoint('TOPLEFT', FishingPanel.Content, 'TOPLEFT', 0, 0)
  FishingPanel.Content.Caught:SetPoint('TOPRIGHT', FishingPanel.Content, 'TOPRIGHT', -26, 0)

  function FishingPanel.Resize()
    local height = 0

    for _, child in ipairs({ FishingPanel.Content.Caught:GetChildren() }) do
      height = height + child:GetHeight()
    end

    local clamped_height = math.max(57, math.min(200, height))

    if math.floor(clamped_height) < math.floor(height) then
      FishingPanel.Content.ShowScrollBar()
      FishingPanel.Content.Caught:SetPoint('TOPRIGHT', FishingPanel.Content, 'TOPRIGHT', -26, 0)
    else
      FishingPanel.Content.HideScrollBar()
      FishingPanel.Content.Caught:SetPoint('TOPRIGHT', FishingPanel.Content, 'TOPRIGHT', -8, 0)
    end

    FishingPanel.ContentContainer:SetHeight(5 + clamped_height)
    FishingPanel.Content:SetHeight(clamped_height)
    FishingPanel.Content:SetWidth(FishingPanel.ContentContainer:GetWidth())
    FishingPanel.Content.Caught:SetHeight(height)
    FishingPanel:SetHeight(42 + clamped_height)
  end

  function FishingPanel.Clear()
    for _, child in ipairs({ FishingPanel.Content.Caught:GetChildren() }) do
      child:ClearAllPoints()
      child:SetParent(nil)
      wipe(child)
    end

    FishingPanel.Resize()
  end

  function FishingPanel.Update()
    FishingPanel.Clear()

    if Fishy.state.location then
      local map_name = Fishy.state.location.map_name
      local zone_name = Fishy.state.location.zone_name
      local name = map_name
      local entry = Fishy.FindEntryData(name, entries)
      local fishing = Fishy.character.FishingSkillInfo()

      if fishing then
        local current_skill = Fishy.Color(tostring(fishing.total_level), 0, 1, 0)
        local base_skill = Fishy.Color(tostring(fishing.level), 0, 1, 0)
        local modifier_skill = Fishy.Color(tostring(fishing.modifier), 0, 1, 0)
        local skill_text = string.format('Fishing Level %s + %s = %s', base_skill, modifier_skill, current_skill)

        FishingPanel.Skill:SetText(skill_text)
      end

      if zone_name then
        name = zone_name
        entry = entry and Fishy.FindEntryData(zone_name, entry.entries)
      end

      if name then
        if entry then
          local PreviousCatchAnchor
          local percentages = Fishy.GetCaughtPercentages(entry.caught)

          for _, catch in ipairs(entry.caught) do
            local ItemRow = Fishy.frames.CreateCatchRow(FishingPanel.Content.Caught, catch, percentages[catch.id])

            if PreviousCatchAnchor then
              ItemRow:SetPoint('TOPLEFT', PreviousCatchAnchor, 'BOTTOMLEFT')
              ItemRow:SetPoint('TOPRIGHT', PreviousCatchAnchor, 'BOTTOMRIGHT')
            else
              ItemRow:SetPoint('TOPLEFT', FishingPanel.Content.Caught, 'TOPLEFT')
              ItemRow:SetPoint('TOPRIGHT', FishingPanel.Content.Caught, 'TOPRIGHT')
            end

            PreviousCatchAnchor = ItemRow
          end
        end

        FishingPanel.Name:SetText(name)
      end
    end

    FishingPanel.Resize()
  end

  -- FishingPanel:Hide()
  FishingPanel:SetSize(320, 57)
  FishingPanel:SetPoint('CENTER')
  FishingPanel.Content.HideScrollBar()

  Fishy.frames.EnableMovement(FishingPanel)
  Fishy.frames.Texture(FishingPanel, 0, 0, 0, 0.6)

  return FishingPanel
end

function Fishy.frames.CreateMainPanel()
  local MainPanel = CreateFrame('Frame', 'FishyMainPanel', UIParent, 'UIPanelDialogTemplate')

  MainPanel.Close = FishyMainPanelClose
  MainPanel.ContentContainer = FishyMainPanelDialogBG

  MainPanel:SetSize(360, 360)
  MainPanel:SetPoint('CENTER')

  MainPanel.Close:ClearAllPoints()
  MainPanel.Close:SetPoint('TOPRIGHT', 2, 1)

  MainPanel.Title:SetText('Fishy')
  MainPanel.Title:ClearAllPoints()
  MainPanel.Title:SetPoint('TOPLEFT', 14, -9)

  MainPanel.Content = Fishy.frames.CreateScrollableContent(MainPanel, MainPanel.ContentContainer)
  MainPanel.Content.Entries = Fishy.frames.CreateMainPanelEntries(MainPanel)
  MainPanel.Content.Settings = Fishy.frames.CreateMainPanelSettings(MainPanel)

  Fishy.frames.EnableMovement(MainPanel)
  Fishy.frames.CreateMainPanelTabs(MainPanel, {
    { name = 'Stats', container = MainPanel.Content.Entries },
    { name = 'Settings', container = MainPanel.Content.Settings },
  })

  function MainPanel.Update(map_entry, zone_entry)
    local entries_container = Fishy.frames.main.Content.Entries
    local map_container = map_entry and MainPanel.UpdateEntryCaught(map_entry, entries_container)
    local map_entries = map_container and map_container.Content.Entries
    local zone_container = zone_entry and map_container and MainPanel.UpdateEntryCaught(zone_entry, map_entries)

    return map_container, zone_container
  end

  function MainPanel.SortEntryCaught(entry, Entry)
    local PreviousAnchor
    local sorted_catches = {}

    for _, catch in ipairs(entry.caught) do
      local ItemRow = Fishy.FindElement(Entry.Content.Caught, { catch.id })

      if ItemRow then
        sorted_catches[#sorted_catches + 1] = ItemRow

        ItemRow:ClearAllPoints()

        if PreviousAnchor then
          ItemRow:SetPoint('TOPLEFT', PreviousAnchor, 'BOTTOMLEFT')
          ItemRow:SetPoint('TOPRIGHT', PreviousAnchor, 'BOTTOMRIGHT')
        else
          ItemRow:SetPoint('TOPLEFT', Entry.Content.Caught, 'TOPLEFT')
          ItemRow:SetPoint('TOPRIGHT', Entry.Content.Caught, 'TOPRIGHT')
        end

        PreviousAnchor = ItemRow
      end
    end
  end

  function MainPanel.UpdateEntryCaught(entry, parent)
    local percentages = Fishy.GetCaughtPercentages(entry.caught)
    local Entry = Fishy.FindElement(parent, { entry.id })

    if Entry then
      for _, catch in ipairs(entry.caught) do
        local children = { Entry.Content.Caught:GetChildren() }
        local element = Fishy.FindElement(Entry.Content.Caught, { catch.id })
        local PreviousAnchor = children[#children]

        if element then
          if element.Percent then
            element.Percent:SetText(string.format('%2.2f%%', percentages[catch.id]))
          end

          if element.Count then
            element.Count:SetText(catch.count)
          end
        else
          local ItemRow = Fishy.frames.CreateCatchRow(Entry.Content.Caught, catch, percentages[catch.id])

          if PreviousAnchor then
            ItemRow:SetPoint('TOPLEFT', PreviousAnchor, 'BOTTOMLEFT')
            ItemRow:SetPoint('TOPRIGHT', PreviousAnchor, 'BOTTOMRIGHT')
          else
            ItemRow:SetPoint('TOPLEFT', Entry.Content.Caught, 'TOPLEFT')
            ItemRow:SetPoint('TOPRIGHT', Entry.Content.Caught, 'TOPRIGHT')
          end
        end
      end

      MainPanel.SortEntryCaught(entry, Entry)
      Entry.Resize()

      return Entry
    else
      local children = { parent:GetChildren() }
      local NewEntry = Fishy.frames.CreateEntry(parent, entry)
      local PreviousAnchor = children[#children]

      if PreviousAnchor then
        NewEntry:SetPoint('TOPLEFT', PreviousAnchor, 'BOTTOMLEFT', 0, -3)
        NewEntry:SetPoint('TOPRIGHT', PreviousAnchor, 'BOTTOMRIGHT', 0, -3)
      else
        NewEntry:SetPoint('TOPLEFT', parent, 'TOPLEFT')
        NewEntry:SetPoint('TOPRIGHT', parent, 'TOPRIGHT')
      end

      return NewEntry
    end
  end

  function MainPanel.IsCurrentTabContainer(Container)
    local id = PanelTemplates_GetSelectedTab(MainPanel)
    local Tab = MainPanel.Tabs and MainPanel.Tabs[id]

    return Tab and Tab.Content == Container
  end

  function MainPanel.Clear()
    for _, child in ipairs({ MainPanel.Content.Entries:GetChildren() }) do
      child:ClearAllPoints()
      child:SetParent(nil)
      wipe(child)
    end

    pcall(MainPanel.Content.Entries.Resize)
  end

  Fishy.frames.SetSelectedTab(MainPanel, 1)

  MainPanel:Hide()

  return MainPanel
end

function Fishy.frames.CreateScrollableContent(Parent, ContentParent)
  local Container = CreateFrame('ScrollFrame', nil, Parent, 'UIPanelScrollFrameTemplate')
  local Content = CreateFrame('Frame', nil, Container)

  Content.Scroll = Container
  Content.fishy_data_id = 'content'
  Content:SetWidth(ContentParent:GetWidth() - 24)

  Container:SetScrollChild(Content)
  Container:SetClipsChildren(true)
  Container:SetPoint('TOPLEFT', ContentParent, 'TOPLEFT', 4, -4)
  Container:SetPoint('BOTTOMRIGHT', ContentParent, 'BOTTOMRIGHT', -1, 1)

  Container.ScrollBar:ClearAllPoints()
  Container.ScrollBar:SetPoint('TOPLEFT', Container, 'TOPRIGHT', -12, -17)
  Container.ScrollBar:SetPoint('BOTTOMRIGHT', Container, 'BOTTOMRIGHT', -4, 16)

  function Content.ShowScrollBar()
    Container.ScrollBar:SetPoint('TOPLEFT', Container, 'TOPRIGHT', -12, -17)
    Container.ScrollBar:SetPoint('BOTTOMRIGHT', Container, 'BOTTOMRIGHT', -4, 16)
  end

  function Content.HideScrollBar()
    Container.ScrollBar:SetPoint('TOPLEFT', Container, 'TOPRIGHT', 24, -17)
    Container.ScrollBar:SetPoint('BOTTOMRIGHT', Container, 'BOTTOMRIGHT', 16, 16)
  end

  return Content
end

function Fishy.character.GetSetting(name)
  return Fishy.character.data.settings[name]
end

function Fishy.character.SetSetting(name, value)
  Fishy.character.data.settings[name] = value

  return value
end

function Fishy.frames.CreateTooltip(Container, label, description)
  Container:SetScript('OnEnter', function()
    GameTooltip:SetOwner(Container, 'ANCHOR_TOPLEFT')
    GameTooltip:SetText(label, 1, 1, 1)
    GameTooltip:AddLine(description, nil, nil, nil, true)
    GameTooltip:Show()
  end)

  Container:SetScript('OnLeave', function()
    GameTooltip:Hide()
  end)
end

function Fishy.frames.AddDisabledHandler(Container)
  function Container.SetDisabled(value)
    if value then
      Container:EnableMouse(false)
      Container:SetAlpha(0.5)
    else
      Container:EnableMouse(true)
      Container:SetAlpha(1)
    end
  end
end

function Fishy.frames.Slider(parent, setting, options, on_update)
  local Slider = CreateFrame('Slider', setting, parent, 'OptionsSliderTemplate')
  local value = Fishy.character.GetSetting(setting)
  local min = math.min(value, options.min or 0)
  local max = math.max(value, options.max or 100)
  local label = Fishy.GetSettingLabel(setting)
  local tooltip = Fishy.GetSettingTooltip(setting)

  if label then
    local Label = Slider:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')

    Label:SetPoint('BOTTOMLEFT', Slider, 'TOPLEFT', 0, 3)
    Label:SetText(label)

    if tooltip then
      Fishy.frames.CreateTooltip(Label, label, tooltip)
    end
  end

  Slider:SetSize(options.width or 100, options.height or 20)
  Slider:SetMinMaxValues(min, max)
  Slider:SetValue(value)
  Slider:SetValueStep(1)

  local Min = Slider:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
  Min:SetPoint('TOPLEFT', Slider, 'BOTTOMLEFT', 0, -2)
  Min:SetText(min)

  local Max = Slider:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
  Max:SetPoint('TOPRIGHT', Slider, 'BOTTOMRIGHT', 0, -2)
  Max:SetText(max)

  local Current = Slider:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
  Current:SetPoint('TOP', Slider, 'BOTTOM', 0, -2)
  Current:SetText(value)

  Slider:SetScript('OnValueChanged', function(_, next_value)
    Fishy.character.SetSetting(setting, math.floor(next_value))
    Current:SetText(math.floor(next_value))
    pcall(on_update, math.floor(next_value))
  end)

  _G[string.format('%sText', setting)]:Hide()
  _G[string.format('%sHigh', setting)]:Hide()
  _G[string.format('%sLow', setting)]:Hide()

  Fishy.frames.AddDisabledHandler(Slider)

  return Slider
end

function Fishy.frames.Checkbox(parent, setting, on_update)
  local Checkbox = CreateFrame('CheckButton', nil, parent, 'ChatConfigCheckButtonTemplate')
  local label = Fishy.GetSettingLabel(setting)
  local tooltip = Fishy.GetSettingTooltip(setting)

  if label then
    local Label = Checkbox:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')

    Label:SetPoint('LEFT', Checkbox, 'RIGHT', 5, 0)
    Label:SetText(label)

    if tooltip then
      Fishy.frames.CreateTooltip(Label, label, tooltip)
    end
  end

  Checkbox:SetChecked(Fishy.character.GetSetting(setting))
  Checkbox:SetScript('OnClick', function(self)
    Fishy.character.SetSetting(setting, self:GetChecked())
    pcall(on_update, self:GetChecked())
  end)

  Fishy.frames.AddDisabledHandler(Checkbox)

  return Checkbox
end

function Fishy.frames.CreateMainPanelSettings(MainPanel)
  local Container = CreateFrame('Frame', nil, MainPanel.Content)

  Container:SetPoint('TOPLEFT', MainPanel.Content, 'TOPLEFT')
  Container:SetPoint('TOPRIGHT', MainPanel.Content, 'TOPRIGHT')
  Container:SetHeight(200)
  Container.fishy_data_id = 'settings'

  Container.AutoLootCheckBox = Fishy.frames.Checkbox(Container, 'auto_loot')
  Container.AutoLootCheckBox:SetPoint('TOPLEFT', Container, 'TOPLEFT', 10, -10)
  Container.AutoHideCheckBox = Fishy.frames.Checkbox(Container, 'auto_hide', function(checked)
    Container.AutoHideSlider.SetDisabled(not checked)
  end)
  Container.AutoHideCheckBox:SetPoint('TOPLEFT', Container.AutoLootCheckBox, 'BOTTOMLEFT', 0, -10)
  Container.AutoHideSlider = Fishy.frames.Slider(Container, 'auto_hide_delay', { min = 3, max = 120, width = 200 })
  Container.AutoHideSlider:SetPoint('TOPLEFT', Container.AutoHideCheckBox, 'BOTTOMLEFT', 5, -30)
  Container.AutoHideSlider.SetDisabled(not Fishy.character.GetSetting('auto_hide'))

  function Container.Resize()
    if MainPanel.IsCurrentTabContainer(Container) then
      MainPanel.Content:SetHeight(Container:GetHeight())
    end
  end

  function Container.Update()
    Container.AutoLootCheckBox:SetChecked(Fishy.character.GetSetting('auto_loot'))
    Container.AutoHideCheckBox:SetChecked(Fishy.character.GetSetting('auto_hide'))
    Container.AutoHideSlider:SetValue(Fishy.character.GetSetting('auto_hide_delay'))
    Container.AutoHideSlider.SetDisabled(not Fishy.character.GetSetting('auto_hide'))
  end

  return Container
end

function Fishy.frames.CreateMainPanelEntries(MainPanel)
  local PreviousAnchor
  local Container = CreateFrame('Frame', nil, MainPanel.Content)

  Container:SetPoint('TOPLEFT', MainPanel.Content, 'TOPLEFT')
  Container:SetPoint('TOPRIGHT', MainPanel.Content, 'TOPRIGHT')
  Container.fishy_data_id = 'entries'

  function Container.Resize()
    if MainPanel.IsCurrentTabContainer(Container) then
      local height = 0

      for _, child in ipairs({ Container:GetChildren() }) do
        height = height + child:GetHeight()
      end

      MainPanel.Content:SetHeight(height)
      Container:SetHeight(height)
    end
  end

  for _, entry in ipairs(Fishy.character.data.entries) do
    Entry = Fishy.frames.CreateEntry(Container, entry)

    if PreviousAnchor then
      Entry:SetPoint('TOPLEFT', PreviousAnchor, 'BOTTOMLEFT', 0, -3)
      Entry:SetPoint('TOPRIGHT', PreviousAnchor, 'BOTTOMRIGHT', 0, -3)
    else
      Entry:SetPoint('TOPLEFT', Container, 'TOPLEFT')
      Entry:SetPoint('TOPRIGHT', Container, 'TOPRIGHT')
    end

    PreviousAnchor = Entry
  end

  return Container
end

function Fishy.frames.SetSelectedTab(frame, id)
  local SelectedTab = frame.Tabs[id]

  PanelTemplates_SetTab(frame, id)

  for _, Tab in ipairs(frame.Tabs) do
    Tab.Content:Hide()
  end

  SelectedTab.Content:Show()
  pcall(SelectedTab.Content.Resize)
end

function Fishy.frames.CreateMainPanelTabs(frame, tabs)
  frame.numTabs = #tabs
  frame.Tabs = {}
  PanelTemplates_SetNumTabs(frame, #tabs)

  for idx, tab_data in ipairs(tabs) do
    local Tab = CreateFrame('Button', tab_data.name, frame, 'CharacterFrameTabButtonTemplate')

    Tab.Content = tab_data.container

    Tab:SetID(idx)
    Tab:SetText(tab_data.name)
    Tab:SetScript('OnClick', function()
      Fishy.frames.SetSelectedTab(frame, idx)
    end)
    Tab.Content:Hide()

    if idx == 1 then
      Tab:SetPoint('TOPLEFT', frame, 'BOTTOMLEFT', 15, 7)
    else
      local PreviousTabAnchor = frame.Tabs[idx - 1]
      Tab:SetPoint('TOPLEFT', PreviousTabAnchor, 'TOPRIGHT', -15, 0)
    end

    frame.Tabs[#frame.Tabs + 1] = Tab
  end
end

function Fishy.frames.CreateEntry(parent, entry)
  local Entry = CreateFrame('Frame', nil, parent)

  Entry.fishy_data_id = entry.id
  Entry:SetHeight(16)

  function Entry.Resize()
    local caught_height = 0
    local entries_height = 0

    for _, child in ipairs({ Entry.Content.Caught:GetChildren() }) do
      caught_height = caught_height + child:GetHeight()
    end

    for _, child in ipairs({ Entry.Content.Entries:GetChildren() }) do
      entries_height = entries_height + child:GetHeight()
    end

    Entry.Content:SetHeight(caught_height + entries_height)
    Entry.Content.Caught:SetHeight(caught_height)
    Entry.Content.Entries:SetHeight(entries_height)

    if Entry.Content:IsShown() then
      Entry:SetHeight(16 + Entry.Content:GetHeight())
    else
      Entry:SetHeight(16)
    end

    pcall(parent.Resize)
  end

  Entry.Toggle = CreateFrame('Button', nil, Entry)
  Entry.Content = CreateFrame('Frame', nil, Entry)
  Entry.Name = Entry.Toggle:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')

  Entry.Toggle:SetSize(16, 16)
  Entry.Toggle:SetPoint('TOPLEFT', 0, 0)
  Entry.Toggle:SetNormalTexture(Fishy.icons.plus.normal)
  Entry.Toggle:SetHighlightTexture(Fishy.icons.plus.highlight)

  Entry.Toggle:SetScript('OnClick', function()
    if Entry.Content:IsShown() then
      Entry.Toggle:SetNormalTexture(Fishy.icons.plus.normal)
      Entry.Toggle:SetHighlightTexture(Fishy.icons.plus.highlight)
      Entry.Content:Hide()
    else
      Entry.Toggle:SetNormalTexture(Fishy.icons.minus.normal)
      Entry.Toggle:SetHighlightTexture(Fishy.icons.minus.highlight)
      Entry.Content:Show()
    end

    Entry.Resize()
  end)

  Entry.Name:SetText(entry.name)
  Entry.Name:SetPoint('TOPLEFT', Entry.Toggle, 'TOPRIGHT', 4, -2)

  Entry.Content.fishy_data_id = 'content'
  Entry.Content:SetPoint('TOPLEFT', Entry.Toggle, 'BOTTOMRIGHT', 4, 0)
  Entry.Content:SetPoint('TOPRIGHT', Entry, 'TOPRIGHT')
  Entry.Content:Hide()
  Entry.Content.Resize = Entry.Resize

  Entry.Content.Caught = CreateFrame('Frame', nil, Entry.Content)
  Entry.Content.Caught:SetPoint('TOPLEFT', Entry.Content, 'TOPLEFT')
  Entry.Content.Caught:SetPoint('TOPRIGHT', Entry.Content, 'TOPRIGHT')
  Entry.Content.Caught.fishy_data_id = 'caught'
  Entry.Content.Caught.Resize = Entry.Content.Resize

  Entry.Content.Entries = CreateFrame('Frame', nil, Entry.Content)
  Entry.Content.Entries:SetPoint('TOPLEFT', Entry.Content.Caught, 'BOTTOMLEFT')
  Entry.Content.Entries:SetPoint('TOPRIGHT', Entry.Content.Caught, 'BOTTOMRIGHT')
  Entry.Content.Entries.fishy_data_id = 'entries'
  Entry.Content.Entries.Resize = Entry.Content.Resize

  local PreviousCatchAnchor
  local PreviousEntryAnchor
  local percentages = Fishy.GetCaughtPercentages(entry.caught)

  for _, catch in ipairs(entry.caught) do
    local ItemRow = Fishy.frames.CreateCatchRow(Entry.Content.Caught, catch, percentages[catch.id])

    if PreviousCatchAnchor then
      ItemRow:SetPoint('TOPLEFT', PreviousCatchAnchor, 'BOTTOMLEFT')
      ItemRow:SetPoint('TOPRIGHT', PreviousCatchAnchor, 'BOTTOMRIGHT')
    else
      ItemRow:SetPoint('TOPLEFT', Entry.Content.Caught, 'TOPLEFT')
      ItemRow:SetPoint('TOPRIGHT', Entry.Content.Caught, 'TOPRIGHT')
    end

    PreviousCatchAnchor = ItemRow
  end

  for _, child in ipairs(entry.entries) do
    ChildEntry = Fishy.frames.CreateEntry(Entry.Content.Entries, child)

    if PreviousEntryAnchor then
      ChildEntry:SetPoint('TOPLEFT', PreviousEntryAnchor, 'BOTTOMLEFT')
      ChildEntry:SetPoint('TOPRIGHT', PreviousEntryAnchor, 'BOTTOMRIGHT')
    else
      ChildEntry:SetPoint('TOPLEFT', Entry.Content.Entries, 'TOPLEFT')
      ChildEntry:SetPoint('TOPRIGHT', Entry.Content.Entries, 'TOPRIGHT')
    end

    PreviousEntryAnchor = ChildEntry
  end

  Fishy.character.SortCaught(entry, Entry)
  Entry.Resize()

  return Entry
end

function Fishy.frames.CreateCatchRow(parent, catch, percentage)
  local ItemRow = CreateFrame('Frame', nil, parent)

  ItemRow.Name = ItemRow:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
  ItemRow.Count = ItemRow:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
  ItemRow.Percent = ItemRow:CreateFontString(nil, 'OVERLAY', 'GameFontGreenSmall')

  ItemRow.Name:SetText(catch.name)
  ItemRow.Name:SetPoint('LEFT', ItemRow, 'LEFT')

  ItemRow.Count:SetText(catch.count)
  ItemRow.Count:SetPoint('RIGHT', ItemRow, 'RIGHT', -50, 0)

  ItemRow.Percent:SetText(string.format('%2.2f%%', percentage))
  ItemRow.Percent:SetPoint('RIGHT', ItemRow, 'RIGHT')

  ItemRow.fishy_data_id = catch.id
  ItemRow:SetHeight(
    16,
    math.max(ItemRow.Name:GetStringHeight(), ItemRow.Count:GetStringHeight(), ItemRow.Percent:GetStringHeight())
  )

  return ItemRow
end

function Fishy.Merge(tbl1, tbl2)
  for key, value in pairs(tbl2) do
    if tbl1[key] == nil then
      tbl1[key] = value
    end
  end

  return tbl1
end

function Fishy.character.GetData()
  FishyCharacterData = FishyCharacterData or {}

  Fishy.Merge(FishyCharacterData, Fishy.character.data_defaults)
  Fishy.Merge(FishyCharacterData.settings, Fishy.character.data_defaults.settings)

  return FishyCharacterData
end

function Fishy.character.LocationInfo()
  local map_id = C_Map.GetBestMapForUnit('player')
  local map_info = C_Map.GetMapInfo(map_id)
  local zone_name = GetSubZoneText()

  if zone_name == '' then
    zone_name = nil
  end

  return { map_id = map_id, map_name = map_info.name, zone_name = zone_name }
end

function Fishy.NormalizeString(name)
  return string.gsub(string.lower(name), '%s+', '_')
end

function Fishy.FindEntryData(name, entries)
  if name then
    local id = Fishy.NormalizeString(name)

    for _, entry in ipairs(entries) do
      if entry.id == id then
        return entry
      end
    end
  end
end

function Fishy.CreateEntryData(name, entries)
  if name then
    entries[#entries + 1] = {
      id = Fishy.NormalizeString(name),
      name = name,
      caught = {},
      entries = {},
    }

    return entries[#entries]
  end
end

function Fishy.FindCatchData(item, caught)
  if item then
    for _, catch in ipairs(caught) do
      if catch.id == item.id then
        return catch
      end
    end
  end
end

function Fishy.CreateCatchData(item, caught)
  if item then
    caught[#caught + 1] = {
      id = item.id,
      name = item.name,
      count = 0,
    }

    return caught[#caught]
  end
end

function Fishy.UpdateEntryCaughtData(name, entries, loot)
  if name then
    local entry = Fishy.FindEntryData(name, entries) or Fishy.CreateEntryData(name, entries)

    if entry then
      local catch = Fishy.FindCatchData(loot.item, entry.caught) or Fishy.CreateCatchData(loot.item, entry.caught)

      if catch then
        catch.count = catch.count + loot.quantity
      end

      return entry
    end
  end
end

function Fishy.state.UpdateCaught(loot, location)
  local entries = Fishy.state.entries

  if loot and location then
    local map_name = location.map_name
    local zone_name = location.zone_name
    local map_entry = map_name and Fishy.UpdateEntryCaughtData(map_name, entries, loot)
    local zone_entry = map_entry and Fishy.UpdateEntryCaughtData(zone_name, map_entry.entries, loot)

    Fishy.character.SortCaught(map_entry)
    Fishy.character.SortCaught(zone_entry)
    Fishy.frames.fishing.Update()
  end
end

function Fishy.character.UpdateCaught(loot, location)
  local entries = Fishy.character.data.entries

  if loot and location then
    local map_name = location.map_name
    local zone_name = location.zone_name
    local map_entry = map_name and Fishy.UpdateEntryCaughtData(map_name, entries, loot)
    local zone_entry = map_entry and Fishy.UpdateEntryCaughtData(zone_name, map_entry.entries, loot)

    Fishy.character.SortCaught(map_entry)
    Fishy.character.SortCaught(zone_entry)
    Fishy.frames.main.Update(map_entry, zone_entry)
  end
end

function Fishy.character.HandleLoot()
  hooksecurefunc(LootFrame, 'Show', function(self)
    if C_CVar.GetCVarBool('autoLootDefault') or (Fishy.character.GetSetting('auto_loot') and IsFishingLoot()) then
      self:Hide()
    end
  end)
end

function Fishy.events.WrapHandler(event, handler)
  return function(...)
    if Fishy.state.initialized or event == 'ADDON_LOADED' then
      return handler(...)
    end
  end
end

function Fishy.events.global.__newindex(self, event, handler)
  rawset(self, event, Fishy.events.WrapHandler(event, handler))
  Fishy.frames.event:RegisterEvent(event)
end

function Fishy.events.player.__newindex(self, event, handler)
  rawset(self, event, Fishy.events.WrapHandler(event, handler))
  Fishy.frames.event:RegisterUnitEvent(event, 'player')
end

Fishy.frames.event:SetScript('OnEvent', function(_, event, ...)
  local handler = Fishy.events.global[event] or Fishy.events.player[event]

  handler(...)
end)

function Fishy.events.global.ADDON_LOADED(name)
  if name == 'Fishy' then
    Fishy.character.HandleLoot()

    Fishy.character.data = Fishy.character.GetData()
    Fishy.frames.main = Fishy.frames.CreateMainPanel()
    Fishy.frames.fishing = Fishy.frames.CreateFishingPanel()
    Fishy.state.initialized = true
  end
end

function Fishy.events.global.LOOT_OPENED()
  if IsFishingLoot() then
    local location = Fishy.character.LocationInfo()
    local auto_loot = Fishy.character.GetSetting('auto_loot') and not C_CVar.GetCVarBool('autoLootDefault')

    for idx, loot in ipairs(GetLootInfo()) do
      local link = GetLootSlotLink(idx)
      local bind_type = link and select(14, C_Item.GetItemInfo(link))
      local id = link and tonumber(string.match(link, 'item:(%d+)'))

      if LootSlotHasItem(idx) then
        if id then
          local catch = { quantity = loot.quantity, item = { id = id, name = loot.item } }

          Fishy.state.UpdateCaught(catch, location)
          Fishy.character.UpdateCaught(catch, location)
        end
      end

      if auto_loot then
        LootSlot(idx)

        if bind_type == 1 then
          ConfirmLootSlot(idx)
          Fishy.Print('AUTO_CONFIRM_LOOT', loot.item)
        end
      end
    end
  end
end

function Fishy.events.global.BAG_UPDATE()
  C_Timer.After(0.25, Fishy.frames.fishing.Update)
end

function Fishy.events.global.PLAYER_EQUIPMENT_CHANGED()
  C_Timer.After(0.25, Fishy.frames.fishing.Update)
end

function Fishy.events.player.UNIT_AURA()
  C_Timer.After(0.25, Fishy.frames.fishing.Update)
end

function Fishy.events.player.UNIT_SPELLCAST_CHANNEL_START(_, _, spell_id)
  if Fishy.IsFishingSpell(spell_id) then
    if Fishy.state.hide_fishing_timer then
      Fishy.state.hide_fishing_timer:Cancel()

      Fishy.state.hide_fishing_timer = nil
    end

    Fishy.state.location = Fishy.character.LocationInfo()
    Fishy.frames.fishing.Update()
    Fishy.frames.fishing:Show()
  end
end

function Fishy.events.player.UNIT_SPELLCAST_CHANNEL_STOP(_, _, spell_id)
  if Fishy.IsFishingSpell(spell_id) and Fishy.character.GetSetting('auto_hide') then
    Fishy.state.hide_fishing_timer = C_Timer.NewTimer(Fishy.character.GetSetting('auto_hide_delay'), function()
      Fishy.frames.fishing:Hide()

      Fishy.state.hide_fishing_timer = nil
    end)
  end
end

function Fishy.commands.hide()
  Fishy.frames.main:Hide()
end

function Fishy.commands.show()
  Fishy.frames.main:Show()
end

function Fishy.commands.help()
  local function cmd(name)
    return Fishy.Color(name, 1, 0.8, 0)
  end

  local function arg(name)
    return Fishy.Color(name, 0.8, 0, 1)
  end

  Fishy.Print('Commands:')
  Fishy.Print('/fs - Show help')
  Fishy.Print(string.format('/fs %s - Show help', cmd('help')))
  Fishy.Print(string.format('/fs %s - Show main panel', cmd('show')))
  Fishy.Print(string.format('/fs %s - Hide main panel', cmd('hide')))
  Fishy.Print(
    string.format('/fs %s %s - Clear all caught fish and reset settings to default', cmd('reset'), arg('all'))
  )
  Fishy.Print(string.format('/fs %s %s - Clear all caught fish', cmd('reset'), arg('fish')))
  Fishy.Print(string.format('/fs %s %s - Reset settings to default', cmd('reset'), arg('settings')))
end

function Fishy.commands.reset(what)
  if what == 'all' or what == 'fish' then
    Fishy.character.data.entries = {}

    Fishy.frames.main.Clear()
    Fishy.frames.fishing.Clear()
  end

  if what == 'all' or what == 'settings' then
    Fishy.character.data.settings = Fishy.character.data_defaults.settings

    Fishy.frames.main.Content.Settings.Update()
  end
end

SLASH_FISHY1 = '/fishy'
SLASH_FISHY2 = '/fs'

function SlashCmdList.FISHY(msg)
  local cmd, argstr = strsplit(' ', msg, 2)

  if Fishy.commands[cmd] then
    Fishy.commands[cmd](strsplit(' ', argstr or ''))
  elseif #cmd > 0 then
    Fishy.Print(string.format('Command not found "%s". Type /fs help for a list of commands', cmd))
  else
    Fishy.commands.help()
  end
end
