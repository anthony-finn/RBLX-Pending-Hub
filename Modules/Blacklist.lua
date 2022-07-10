-- Dependencies
local RetryFunction = require(script.Parent:WaitForChild("RetryFunction"))
local Settings = _G.PENDING_HUB_SETTINGS

-- Services
local MessagingService = game:GetService("MessagingService")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

-- DataStores
local BlacklistStore = DataStoreService:GetDataStore("Blacklist")

-- Constants
local PERMAMENT_BANS_KEY = "PermamentBans"
local TEMPORARY_BANS_KEY = "TemporaryBans"

-- Module
local Blacklist = {}
Blacklist.__index = Blacklist
Blacklist.PERMAMENT_BANS_KEY = PERMAMENT_BANS_KEY
Blacklist.TEMPORARY_BANS_KEY = TEMPORARY_BANS_KEY

-- Private Functions
local function UpdateBlacklistUser(UserId, BanType, Modifier)
	local Budget = DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.UpdateAsync)
	
	if Budget > 0 then
		local Success, Message = RetryFunction(BlacklistStore.UpdateAsync, BlacklistStore, BanType, function(CurrentBans)
			CurrentBans = CurrentBans or {}
			local Index = table.find(CurrentBans, UserId)
			if Modifier == 0 and not Index then
				table.insert(CurrentBans, UserId)
			elseif Modifier == 1 then
				table.remove(CurrentBans, Index)
			end
			
			return CurrentBans
		end)
		
		if Success then
			RetryFunction(MessagingService.PublishAsync, MessagingService, "BlacklistUpdate", {BanType = BanType})
		end
		
		return Success, Message
	else
		task.delay(60, function()
			UpdateBlacklistUser(UserId, BanType, Modifier)
		end)
	end
end

-- Public Functions
function Blacklist.Load()
	local self = {}
	setmetatable(self, Blacklist)
	
	if not (self:UpdateBans(PERMAMENT_BANS_KEY) and self:UpdateBans(TEMPORARY_BANS_KEY)) then
		return
	end
	
	-- Connections
	MessagingService:SubscribeAsync("BlacklistUpdate", function(Message) 
		self:UpdateBans(Message.Data.BanType) 
	end)
	
	Players.PlayerAdded:Connect(function(Player)
		local UserId = Player.UserId
		if self:IsUserIdBanned(Player.UserId) then
			Player:Kick("You have been banned.")
		end
	end)
	
	return self
end

function Blacklist:PermanentlyBanByUserId(UserId)
	local UpdateSuccess, Bans = UpdateBlacklistUser(UserId, PERMAMENT_BANS_KEY, 0)
	
	if UpdateSuccess then
		self[PERMAMENT_BANS_KEY] = Bans
	end
end

function Blacklist:TemporarilyBanByUserId(UserId)
	local UpdateSuccess, Bans = UpdateBlacklistUser(UserId, TEMPORARY_BANS_KEY, 0)

	if UpdateSuccess then
		self[TEMPORARY_BANS_KEY] = Bans
	end
end

function Blacklist:UnPermanentBanByUserId(UserId)
	local UpdateSuccess, Bans = UpdateBlacklistUser(UserId, PERMAMENT_BANS_KEY, 1)

	if UpdateSuccess then
		self[PERMAMENT_BANS_KEY] = Bans
	end
end

function Blacklist:UnTemporaryBanByUserId(UserId)
	local UpdateSuccess, Bans = UpdateBlacklistUser(UserId, TEMPORARY_BANS_KEY, 1)

	if UpdateSuccess then
		self[TEMPORARY_BANS_KEY] = Bans
	end
end

function Blacklist:ClearTemporaryBanlist()
	RetryFunction(BlacklistStore.RemoveAsync, BlacklistStore, TEMPORARY_BANS_KEY)
end

function Blacklist:IsUserIdBanned(UserId)
	if table.find(Settings.ACCESS.BLACKLISTED, UserId) then
		return true
	end
	
	if not self[PERMAMENT_BANS_KEY] or not self[TEMPORARY_BANS_KEY] then
		self:GetBans()
	end
	
	return table.find(self[PERMAMENT_BANS_KEY], UserId) or table.find(self[TEMPORARY_BANS_KEY], UserId)
end

function Blacklist:GetBans()
	return Blacklist:UpdateBans(PERMAMENT_BANS_KEY), Blacklist:UpdateBans(TEMPORARY_BANS_KEY)
end

function Blacklist:UpdateBans(BanType)
	if not BanType then
		return Blacklist:GetBans()
	end
	
	local Budget = DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.GetAsync)
	if Budget > 0 then
		local GetSuccess, Bans = RetryFunction(BlacklistStore.GetAsync, BlacklistStore, BanType)
		if not GetSuccess or (GetSuccess and not Bans) then
			Bans = {}
			local SetSuccess, Message = RetryFunction(BlacklistStore.SetAsync, BlacklistStore, BanType, Bans)
			if not SetSuccess then
				return
			end
		end

		self[BanType] = Bans
		
		local Players = Players:GetPlayers()
		for _, Player in next, Players do
			if table.find(self[BanType], Player.UserId) then
				if BanType == TEMPORARY_BANS_KEY then
					Player:Kick("You have been temporarily banned.")
				else
					Player:Kick("You have been permanently banned.")
				end
			end
		end

		return Bans
	else
		return {}
	end
end

return Blacklist
