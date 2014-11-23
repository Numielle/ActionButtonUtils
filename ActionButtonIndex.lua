local function debug(msg) DEFAULT_CHAT_FRAME:AddMessage("[ABI] " .. tostring(msg), 1, 1, 0); end

local ABI_ActionButtons = ABD_Profile("DEFAULT_UI");
local ABI_StanceSlots = ABD_ClassValues();

local function ABI_ButtonFromID(slotId) 
	local slotNumber = ABD_SlotNumber(slotId);

	for barName, bar in ABI_ActionButtons do
		if ActionButton_GetPagedID(bar[slotNumber]) == slotId then
			return bar[slotNumber];
		end
	end

	error("[ABI] cannot determine ActionButton for ActionSlot ID " .. slotId); -- should never happen
end

local ABI_Index = {};
local _, ABI_Class = UnitClass("player"); -- english class uppercase, e.g. "WARRIOR"
local ABI_TraceLength = 3;

local function ABI_tremove(t, value, handler)
	for n = table.getn(t), 1, -1 do
		if (t[n] == value) then
			local v = tremove(t, n);

			if handler then
				handler(v);
			end
		end
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

-- this function either takes the name of an action bar as returned by ABD_Profile or a list of action buttons.
local function ABI_UpdateIndex(actionBar, spellTexture)
	
	if type(actionBar) == 'string' then
		ABI_PurgeFromIndex(actionBar);
		actionBar = ABI_ActionButtons[actionBar];
	elseif type(actionBar) == 'table' then 
		for _, button in actionBar do
			ABI_PurgeFromIndex(button:GetName());
		end
	else 
		error("ABI_Update expecting argument of type 'string' or 'table' but received '" .. type(actionBar) .. "' instead.", ABI_TraceLength);
	end

	for _, button in actionBar do
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
	for actionBarName, _ in ABI_ActionButtons do
		ABI_UpdateIndex(actionBarName, spellTexture);
	end
end

local function ABI_UpdatePage()
	-- for all classes update primary action bar
	ABI_UpdateIndex("Action");

	if ABI_Class == "DRUID" or ABI_Class == "WARRIOR" then
		-- for druid and warrior also update stance-specific bar
		ABI_UpdateIndex("BonusAction");
	end
end

local function ABI_UpdateButton(button)
	ABI_UpdateIndex({button});
end

local function ABI_StanceChange(newStance)
	-- only scan BonusAction bar
	if CURRENT_ACTIONBAR_PAGE == 1 then
		ABI_PurgeFromIndex("BonusAction");

		for index, id in ABI_StanceSlots[newStance] do
			local texture = GetActionTexture(id);
	
			if ABI_Index[texture] and not GetActionText(id) then
				local button = ABI_ActionButtons["BonusAction"][index];
	
				tinsert(ABI_Index[texture]["buttons"], button);
				for _, handler in ABI_Index[texture]["add"] do
					handler(button);
				end
			-- else not registred or a macro
			end
		end
	else
		ABI_UpdateIndex("BonusAction");
	end
end

local ABI_Frame = CreateFrame("Frame", nil, UIParent);
ABI_Frame:RegisterEvent("PLAYER_LOGIN");
ABI_Frame:RegisterEvent("ACTIONBAR_PAGE_CHANGED");
ABI_Frame:RegisterEvent("ACTIONBAR_SLOT_CHANGED");
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
		ABI_UpdateButton(ABI_ButtonFromID(arg1));

	elseif event == "CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS" then
		if ABI_Class == "WARRIOR" then
			local found, _, stance = string.find(arg1, "You gain (.*)% Stance.");

			if found then
				-- "Battle" or "Defensive" or "Berserker"
				ABI_StanceChange(stance);
			end
		elseif ABI_Class == "DRUID" then
			local found, _, stance = string.find(arg1, "You gain (.*)% Form.");

			if found and ABI_StanceSlots[stance] then
				-- perform update for "Cat", "Bear" and "Dire Bear" but ignore "Aquatic", "Moonkin" and "Travel"
				ABI_StanceChange(stance);
			end
		end
		-- Rogues and Priests don't have BonusAction bar in 1.12
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
		-- perform cleanup to unregister
		ABI_Trigger(spellTexture, removeHandler);

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
