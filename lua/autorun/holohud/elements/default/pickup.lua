--[[------------------------------------------------------------------
  PICKUP HISTORY
  Displays the items, weapons and ammunition last picked up
]]--------------------------------------------------------------------

if CLIENT then

  -- Namespace
  HOLOHUD.ELEMENTS.PICKUP = {};

  -- Parameters
  HOLOHUD.ELEMENTS.PICKUP.PickupType = {
    WEAPON = 1,
    ITEM = 2,
    AMMO = 3
  }
  HOLOHUD.ELEMENTS.PICKUP.PANEL_SUBFIX = "pickup_";
  HOLOHUD.ELEMENTS.PICKUP.TIME = 5.66;

  -- Variables
  HOLOHUD.ELEMENTS.PICKUP.pickups = {};
  HOLOHUD.ELEMENTS.PICKUP.ammoPickups = {}; -- Cache to locate ammunition pickups for cumulative purposes

  -- Include pickup panels
  --[[include("pickup/ammo.lua");
  include("pickup/weapon.lua");
  include("pickup/item.lua");
  include("pickup/health.lua");]]

end

HOLOHUD:IncludeFile("pickup/ammo.lua");
HOLOHUD:IncludeFile("pickup/weapon.lua");
HOLOHUD:IncludeFile("pickup/item.lua");
HOLOHUD:IncludeFile("pickup/health.lua");

if CLIENT then

  -- Parameters
  local SCREEN_MAX = 0.5; -- The maximum amount of screen space to take
  local PICKUP_PANEL_ALIGN = TEXT_ALIGN_RIGHT; -- The flash panel animation alignment
  local MARGIN = 5; -- Margin between panels

  -- Variables
  local curSize = 0; -- Current screen occupied

  --[[
    Removes a pickup history entry
    @param {number} position
    @void
  ]]
  local function RemovePickup(pos)
    curSize = curSize - HOLOHUD.ELEMENTS.PICKUP.pickups[pos].h;

    -- Remove from ammoPickup if required
    if (HOLOHUD.ELEMENTS.PICKUP.pickups[pos].category == HOLOHUD.ELEMENTS.PICKUP.PickupType.AMMO) then
      local ammoPickup = table.KeyFromValue(HOLOHUD.ELEMENTS.PICKUP.ammoPickups, pos);
      if (ammoPickup ~= nil) then
        HOLOHUD:RemoveHighlight(HOLOHUD.ELEMENTS.PICKUP.PANEL_SUBFIX .. ammoPickup);
        HOLOHUD.ELEMENTS.PICKUP.ammoPickups[ammoPickup] = nil;
      end
    end

    -- Remove the entry
    table.remove(HOLOHUD.ELEMENTS.PICKUP.pickups, pos);
    HOLOHUD:RemovePanel(HOLOHUD.ELEMENTS.PICKUP.PANEL_SUBFIX .. pos);

    if (table.Count(HOLOHUD.ELEMENTS.PICKUP.pickups) > 0) then
      -- Rename all active panels to fit the new order
      for i=pos + 1, table.Count(HOLOHUD.ELEMENTS.PICKUP.pickups) + 1 do
        HOLOHUD:RenamePanel(HOLOHUD.ELEMENTS.PICKUP.PANEL_SUBFIX .. i, HOLOHUD.ELEMENTS.PICKUP.PANEL_SUBFIX .. (i - 1));

        -- Ammo pickup
        if (HOLOHUD.ELEMENTS.PICKUP.pickups[i - 1].category ~= HOLOHUD.ELEMENTS.PICKUP.PickupType.AMMO) then continue; end

        -- Relocate already existing
        local ammoPickup = table.KeyFromValue(HOLOHUD.ELEMENTS.PICKUP.ammoPickups, i);
        if (ammoPickup ~= nil) then
          HOLOHUD.ELEMENTS.PICKUP.ammoPickups[ammoPickup] = i - 1;
        end
      end
    end
  end

  --[[
    Adds a new pickup history entry, generating the required panel in the way
    @param {1|2|3} pickup category
    @param {table} data
    @param {number} panel width
    @param {number} panel height
    @void
  ]]
  function HOLOHUD.ELEMENTS.PICKUP:AddPickup(category, data, w, h)
    -- Add new pickup
    table.insert(HOLOHUD.ELEMENTS.PICKUP.pickups, {pos = count, category = category, time = CurTime() + HOLOHUD.ELEMENTS.PICKUP.TIME, w = w, h = h, data = data});
    HOLOHUD:AddFlashPanel(HOLOHUD.ELEMENTS.PICKUP.PANEL_SUBFIX .. table.Count(HOLOHUD.ELEMENTS.PICKUP.pickups));
    curSize = curSize + h;
  end

  --[[
    Draws a pickup history entry
    @param {number} x
    @param {number} y
    @param {number} position
    @param {Color} colour
    @param {Color} missing weapon colour
    @void
  ]]
  local function DrawPickup(x, y, i, alpha, animate, colour, critColour)
    colour = colour or Color(255, 255, 255);
    local pickup = HOLOHUD.ELEMENTS.PICKUP.pickups[i];

    if (pickup.category == HOLOHUD.ELEMENTS.PICKUP.PickupType.WEAPON and IsValid(pickup.data.weapon)) then
      local bgCol = HOLOHUD:GetBackgroundColour();
      if (not LocalPlayer():HasWeapon(pickup.data.weapon:GetClass())) then
        bgCol = Color(critColour.r * 0.65, critColour.g * 0.65, critColour.b * 0.65);
      end

      HOLOHUD.ELEMENTS.PICKUP:WeaponAnimation(i, animate);
      HOLOHUD:DrawFragmentAlign(x - pickup.w, y, pickup.w, pickup.h, HOLOHUD.ELEMENTS.PICKUP.WeaponPickup, HOLOHUD.ELEMENTS.PICKUP.PANEL_SUBFIX .. i, PICKUP_PANEL_ALIGN, bgCol, alpha, 1, pickup.data.weapon, pickup.data.margin, pickup.data.anim1, pickup.data.anim2, pickup.data.displayTitle, pickup.data.displayWeapon, colour, critColour);
    elseif (pickup.category == HOLOHUD.ELEMENTS.PICKUP.PickupType.ITEM) then
      HOLOHUD.ELEMENTS.PICKUP:PickupAnimation(i, animate);
      HOLOHUD:DrawFragmentAlign(x - pickup.w, y, pickup.w, pickup.h, HOLOHUD.ELEMENTS.PICKUP.ItemPickup, HOLOHUD.ELEMENTS.PICKUP.PANEL_SUBFIX .. i, PICKUP_PANEL_ALIGN, nil, alpha, 1, pickup.data.item, pickup.data.anim1, pickup.data.anim2, pickup.data.displayTitle, colour);
    elseif (pickup.category == HOLOHUD.ELEMENTS.PICKUP.PickupType.AMMO) then
      HOLOHUD.ELEMENTS.PICKUP:AmmoAnimation(i, animate);
      HOLOHUD:DrawFragmentAlign(x - pickup.w, y, pickup.w, pickup.h, HOLOHUD.ELEMENTS.PICKUP.AmmoPickup, HOLOHUD.ELEMENTS.PICKUP.PANEL_SUBFIX .. i, PICKUP_PANEL_ALIGN, nil, alpha, 1, pickup.data.ammoType, pickup.data.lerp, pickup.data.anim1, pickup.data.anim2, pickup.data.displayTitle, pickup.data.displayAmmo, colour);
    end
  end

  --[[
    Draws the item history pickup element
    @param {function} config
    @void
  ]]
  local function DrawPanel(config)
    local x, y = ScrW() - 20, ScrH() * 0.26;

    local h = 0;
    for i, pickup in pairs(HOLOHUD.ELEMENTS.PICKUP.pickups) do
      local inRange = h < ScrH() * SCREEN_MAX;

      -- Draw the panel
      DrawPickup(x, y + h, i, config("alpha"), config("animate"), config("colour"), config("crit_colour"));

      -- Extend lifetime if it hasn't shown
      if (not inRange) then
        HOLOHUD.ELEMENTS.PICKUP.pickups[i].time = CurTime() + HOLOHUD.ELEMENTS.PICKUP.TIME;
      end

      -- Control lifetime
      HOLOHUD:SetPanelActive(HOLOHUD.ELEMENTS.PICKUP.PANEL_SUBFIX .. i, pickup.time > CurTime() and inRange);
      if (not LocalPlayer():Alive() or (not HOLOHUD:IsPanelActive(HOLOHUD.ELEMENTS.PICKUP.PANEL_SUBFIX .. i) and pickup.time < CurTime())) then
        RemovePickup(i);
      end

      h = h + pickup.h + MARGIN;
    end
    HOLOHUD.ELEMENTS.PICKUP:DrawHealthPickupTray(config("alpha"));
  end

  -- Add element
  HOLOHUD.ELEMENTS:AddElement("item_history",
    "Item pickup history",
    "Informs the player about picked up items",
    {"CHudHistoryResource"},
    {
      alpha = { name = "Background opacity", value = 0.25, minValue = 0, maxValue = 1 },
      animate = { name = "Toggle animation", value = true },
      displayAmmo = { name = "Display known ammo names", desc = "Display the name of ammo types which have icons registered", value = false },
      displayTitle = { name = "Show pickup title", value = true },
      displayWeapon = { name = "Display weapon name", value = true },
      colour = { name = "Colour", value = Color(255, 255, 255) },
      crit_colour = { name = "Missing weapon colour", value = Color(255, 0, 0) }
    },
    DrawPanel
  );

  -- Item pickup hooks
  hook.Add("HUDWeaponPickedUp", "holohud_pickup_weapon", function(weapon)
    if (HOLOHUD:IsHUDEnabled() and HOLOHUD.ELEMENTS:IsElementEnabled("item_history")) then
      local showName = HOLOHUD.ELEMENTS:ConfigValue("item_history", "displayWeapon");
      local showTitle = HOLOHUD.ELEMENTS:ConfigValue("item_history", "displayTitle");

      HOLOHUD.ELEMENTS.PICKUP:AddWeaponPickup(weapon, showTitle, showName);
      return true;
    end
  end);

  hook.Add("HUDAmmoPickedUp", "holohud_pickup_ammo", function(ammo, amount)
    if (HOLOHUD:IsHUDEnabled() and HOLOHUD.ELEMENTS:IsElementEnabled("item_history")) then
      local showName = HOLOHUD.ELEMENTS:ConfigValue("item_history", "displayAmmo");
      local showTitle = HOLOHUD.ELEMENTS:ConfigValue("item_history", "displayTitle");

      HOLOHUD.ELEMENTS.PICKUP:AddAmmoPickup(ammo, amount, showTitle, showName);
      return true;
    end
  end);

  hook.Add("HUDItemPickedUp", "holohud_pickup_item", function(item)
    if (HOLOHUD:IsHUDEnabled() and HOLOHUD.ELEMENTS:IsElementEnabled("item_history")) then
      if (HOLOHUD.ELEMENTS.PICKUP:IsHealthItem(item)) then
        HOLOHUD.ELEMENTS.PICKUP:AddHealthPickup(item);
      else
        HOLOHUD.ELEMENTS.PICKUP:AddItemPickup(item, HOLOHUD.ELEMENTS:ConfigValue("item_history", "displayTitle"));
      end
      return true;
    end
  end);

end
