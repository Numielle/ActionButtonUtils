local function debug(msg) DEFAULT_CHAT_FRAME:AddMessage("[ABI] " .. tostring(msg), 1, 1, 0); end

local ABI_ActionButtons = ABD_Profile("DEFAULT_UI");

local ABI_StanceSlots = {
	["Battle"] = {73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84},
	["Defensive"] = {85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95, 96},
	["Berserker"] = {97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108},
};

local function ABI_ButtonFromID(slotId) 
	local slotNumber = ABD_SlotNumber(slotId);

	for barName, bar in ABI_ActionButtons do
		if ActionButton_GetPagedID(bar[slotNumber]) == slotId then
			return bar[slotNumber];
		end
	end

	return nil; -- TODO this should never happen!
end

local ABI_Index = {};
local _, ABI_Class = UnitClass("player"); -- english class uppercase, e.g. "WARRIOR"
local ABI_TraceLength = 3;

local function ABI_tremove(t, value)
	for n = table.getn(t), 1, -1 do
		if (t[n] == value) then
			local v = tremove(t, n);
		end
	end
end

local function ABI_CheckAndAdd(bar, spellTexture)
	for _, button in bar do
		local texture = GetActionTexture(ActionButton_GetPagedID(button));

		-- spellTexture is optional hence disregard any textures that don't match if argument is provided
		if spellTexture and texture and spellTexture ~= texture then
			texture = nil;
		end

		if ABI_Index[texture] and not GetActionText(ActionButton_GetPagedID(button)) then
			tinsert(ABI_Index[texture]["buttons"], button);

			for _, handler in ABI_Index[texture]["add"] do
				handler(button);
			end
		-- else not registered or a macro
		end
	end
end

local function ABI_InitTexture(spellTexture)
	-- full scan required
	for _, bar in ABI_ActionButtons do
		ABI_CheckAndAdd(bar, spellTexture);
	end
end

local function ABI_PurgeFromIndex(prefix)
	local pattern = "^"..prefix;

	for texture, spellArray in ABI_Index do
		for n = table.getn(spellArray["buttons"]), 1, -1 do
			if string.find(spellArray["buttons"][n]:GetName(), pattern) then
				local b = tremove(spellArray["buttons"], n);
				
				-- call all remove handlers
				for _, handler in spellArray["remove"] do
					handler(b);
				end
			end
		end
	end
end

local function ABI_UpdatePage()
	ABI_PurgeFromIndex("BonusAction");
	ABI_CheckAndAdd(ABI_ActionButtons["BonusActionBarFrame"]);
end

local function ABI_UpdateButton(button)
	ABI_PurgeFromIndex(button:GetName());
	ABI_CheckAndAdd({button});
end

local function ABI_UpdateIndex(newStance)
	-- remove all BonusActionButtons 
	ABI_PurgeFromIndex("BonusAction");

	-- only scan BonusAction bar
	if CURRENT_ACTIONBAR_PAGE == 1 then
		for index, id in ABI_StanceSlots[newStance] do
			local texture = GetActionTexture(id);
	
			if ABI_Index[texture] and not GetActionText(id) then
				local button = ABI_ActionButtons["BonusActionBarFrame"][index];
	
				tinsert(ABI_Index[texture]["buttons"], button);
				for _, handler in ABI_Index[texture]["add"] do
					handler(button);
				end
			-- else not registred or a macro
			end
		end
	else
		ABI_CheckAndAdd(ABI_ActionButtons["BonusActionBarFrame"]);
	end
end

local ABI_Frame = CreateFrame("Frame", nil, UIParent);
ABI_Frame:RegisterEvent("PLAYER_LOGIN");
ABI_Frame:RegisterEvent("ACTIONBAR_PAGE_CHANGED");
ABI_Frame:RegisterEvent("ACTIONBAR_SLOT_CHANGED");
ABI_Frame:RegisterEvent("UPDATE_SHAPESHIFT_FORM");
ABI_Frame:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS");
ABI_Frame:SetScript("OnEvent", function() 

	if event == "PLAYER_LOGIN" then
		-- in case ABI_Register gets called before spell information is available to the UI
		for texture, _ in ABI_Index do
			ABI_InitTexture(texture);
		end
		
	elseif event == "ACTIONBAR_PAGE_CHANGED" then
		-- primary action bar changed via page up/down
		ABI_UpdatePage();

	elseif event == "ACTIONBAR_SLOT_CHANGED" then
		-- action button changed by dragging ability in or out
		-- arg1 == Action Slot ID (http://www.wowwiki.com/ActionSlot)
		local button = ABI_ButtonFromID(arg1);
		ABI_UpdateButton(button);

	elseif event == "CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS" then
		if ABI_Class == "WARRIOR" then
			local found, _, stance = string.find(arg1, "You gain (.*)% Stance.");

			if found then
				-- "Battle" or "Defensive" or "Berserker"
				ABI_UpdateIndex(stance);
			end
		end
	elseif event == "UPDATE_SHAPESHIFT_FORM" then
		if UnitClass("player") == "DRUID" then
			-- TBD: Cat, Bear, Dire Bear, Moonkin, Prowl
			-- TODO maybe this can be done via specific event

		elseif UnitClass("player") == "ROGUE" then
			-- check for stealth
			-- TODO maybe this can be done via specific event

		end
	end
end);

function ABI_Register(spellTexture, addHandler, removeHandler)
	if not spellTexture then
		error("ABI_Register called with nil texture.", ABI_TraceLength);
	elseif not addHandler or type(addHandler) ~= 'function' then
		error("ABI_Register expecting argument addHandler of type 'function' but received '" .. type(addHandler) .. "' instead.", ABI_TraceLength);
	elseif not removeHandler or type(removeHandler) ~= 'function' then
		error("ABI_Register expecting argument removeHandler of type 'function' but received '" .. type(removeHandler) .. "' instead.", ABI_TraceLength);
	end

	if not ABI_Index[spellTexture] then
		ABI_Index[spellTexture] = {};
		ABI_Index[spellTexture]["add"] = {};
		ABI_Index[spellTexture]["remove"] = {};
		ABI_Index[spellTexture]["buttons"] = {};

		ABI_InitTexture(spellTexture);
	end

	tinsert(ABI_Index[spellTexture]["add"], addHandler);
	tinsert(ABI_Index[spellTexture]["remove"], removeHandler);

	ABI_Trigger(spellTexture, addHandler);
end

function ABI_Unregister(spellTexture, addHandler, removeHandler)
	if not spellTexture then
		error("ABI_Unregister called with nil texture.", ABI_TraceLength);
	elseif not addHandler or type(addHandler) ~= 'function' then
		error("ABI_Unregister expecting argument addHandler of type 'function' but received '" .. type(addHandler) .. "' instead.", ABI_TraceLength);
	elseif not removeHandler or type(removeHandler) ~= 'function' then
		error("ABI_Unregister expecting argument removeHandler of type 'function' but received '" .. type(removeHandler) .. "' instead.", ABI_TraceLength);
	end

	if ABI_Index[spellTexture] then
		ABI_tremove(ABI_Index[spellTexture]["add"], addHandler);
		ABI_tremove(ABI_Index[spellTexture]["remove"], removeHandler);

		if table.getn(ABI_Index[spellTexture]["add"]) == 0 then
			ABI_Index[spellTexture] = nil; -- TODO waste of memory?
		end
	end
end

function ABI_Trigger(spellTexture, handler)
	if not spellTexture then
		error("ABI_Trigger called with nil texture.", ABI_TraceLength);
	elseif not handler or type(handler) ~= "function" then
		error("ABI_Trigger expecting handler of type 'function' but received '" .. type(handler) .. "' instead.", ABI_TraceLength);
	elseif not ABI_Index[spellTexture] then
		error("ABI_Trigger never called for texture '" .. spellTexture .. "'.", ABI_TraceLength);
	end

	for _, button in ABI_Index[spellTexture]["buttons"] do
		handler(button);
	end
end

local ABI_OP_Texture = "Interface\\Icons\\Ability_MeleeDamage";
SlashCmdList["ACTION_BUTTON_INDEX_DEV"] = function(Flag)
	flag = string.lower(Flag)
	if (flag == "add") then
		ABI_Register(ABI_OP_Texture, ABG_AddOverlay, ABG_RemoveOverlay);
	elseif (flag == "remove") then
		ABI_Unregister(ABI_OP_Texture, ABG_AddOverlay, ABG_RemoveOverlay);
	elseif flag == "print" then
		for texture, data in ABI_Index do
			debug(texture);
			debug("  buttons:");
			for _, button in data["buttons"] do
				debug("    " .. button:GetName());
			end
			debug("  add handlers: "  .. table.getn(data["add"]));
			for k, v in pairs(data["add"]) do
				debug("    " .. k);
			end
		end
	else
		debug("/abi add - Adds Overpower glowing.");
		debug("/abi remove - Removes Overpower glowing.");
		debug("/abi print - debugs Index.");
	end
end
SLASH_ACTION_BUTTON_INDEX_DEV1 = "/abi";
