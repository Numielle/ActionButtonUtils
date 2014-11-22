local function debug(msg) DEFAULT_CHAT_FRAME:AddMessage("[ABI] " .. tostring(msg), 1, 1, 0); end

local ABI_ActionButtons = {
	["BonusActionBarFrame"] = { 
		BonusActionButton1,
		BonusActionButton2,
		BonusActionButton3,
		BonusActionButton4,
		BonusActionButton5,
		BonusActionButton6,
		BonusActionButton7,
		BonusActionButton8,
		BonusActionButton9,
		BonusActionButton10,
		BonusActionButton11,
		BonusActionButton12 
	},
	["MultiBarLeft"] = { 
		MultiBarLeftButton1,
		MultiBarLeftButton2,
		MultiBarLeftButton3,
		MultiBarLeftButton4,
		MultiBarLeftButton5,
		MultiBarLeftButton6,
		MultiBarLeftButton7,
		MultiBarLeftButton8,
		MultiBarLeftButton9,
		MultiBarLeftButton10,
		MultiBarLeftButton11,
		MultiBarLeftButton12 
	},
	["MultiBarRight"] = { 
		MultiBarRightButton1,
		MultiBarRightButton2,
		MultiBarRightButton3,
		MultiBarRightButton4,
		MultiBarRightButton5,
		MultiBarRightButton6,
		MultiBarRightButton7,
		MultiBarRightButton8,
		MultiBarRightButton9,
		MultiBarRightButton10,
		MultiBarRightButton11,
		MultiBarRightButton12 
	},
	["MultiBarBottomLeft"] = { 
		MultiBarBottomLeftButton1,
		MultiBarBottomLeftButton2,
		MultiBarBottomLeftButton3,
		MultiBarBottomLeftButton4,
		MultiBarBottomLeftButton5,
		MultiBarBottomLeftButton6,
		MultiBarBottomLeftButton7,
		MultiBarBottomLeftButton8,
		MultiBarBottomLeftButton9,
		MultiBarBottomLeftButton10,
		MultiBarBottomLeftButton11,
		MultiBarBottomLeftButton12 
	},
	["MultiBarBottomRight"] = {
		MultiBarBottomRightButton1,
		MultiBarBottomRightButton2,
		MultiBarBottomRightButton3,
		MultiBarBottomRightButton4,
		MultiBarBottomRightButton5,
		MultiBarBottomRightButton6,
		MultiBarBottomRightButton7,
		MultiBarBottomRightButton8,
		MultiBarBottomRightButton9,
		MultiBarBottomRightButton10,
		MultiBarBottomRightButton11,
		MultiBarBottomRightButton12 
	}
};

local ABI_StanceSlots = {
	["Battle"] = {73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84},
	["Defensive"] = {85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95, 96},
	["Berserker"] = {97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108},
};

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

local function ABI_InitTexture(spellTexture)
	-- full scan required
	for _, bar in ABI_ActionButtons do
		for _, button in bar do
			local texture = GetActionTexture(ActionButton_GetPagedID(button));

			if ABI_Index[texture] and not GetActionText(ActionButton_GetPagedID(button)) then
				tinsert(ABI_Index[texture]["buttons"], button);
			-- else not registered or a macro
			end
		end
	end
end

local function ABI_UpdateIndex(newStance)
	-- remove all BonusActionButtons http://stackoverflow.com/a/12397571
	for texture, spellArray in ABI_Index do
		for n = table.getn(spellArray["buttons"]), 1, -1 do
			if string.find(spellArray["buttons"][n]:GetName(), "BonusAction") then
				local b = tremove(spellArray["buttons"], n);
				
				-- call all remove handlers
				for _, handler in spellArray["remove"] do
					handler(b);
				end
			end
		end
	end

	-- only scan BonusAction bar
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
		debug("TODO " .. event);

	elseif event == "ACTIONBAR_SLOT_CHANGED" then
		-- action button changed by dragging ability in or out
		-- arg1 == id
		debug("TODO " .. event .. " " .. arg1);
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
