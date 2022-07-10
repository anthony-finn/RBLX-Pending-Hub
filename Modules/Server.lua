-- Dependencies
local RetryFunction = require(script.Parent:WaitForChild("RetryFunction"))
local SpeakerService = require(script.Parent:WaitForChild("SpeakerService"))
local UsersGroup = require(script.Parent:WaitForChild("UsersGroup"))
local Settings = _G.PENDING_HUB_SETTINGS
local Blacklist = require(script.Parent:WaitForChild("Blacklist"))
local TimezoneService = require(script:WaitForChild("TimezoneService").Value)

-- Module Initialization
local Speaker = SpeakerService.Get("HUB")

-- Services
local DataStoreService = game:GetService("DataStoreService")
local TeleportService = game:GetService("TeleportService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")

-- Datastores
local ServersStore = DataStoreService:GetDataStore("PrivateServers")

-- Private Functions
local function OnJoinRequest(Message)
	local UserId = tonumber(Message.Data)
	if UserId then
		if not Blacklist:IsUserIdBanned(UserId) then
			local Username = UsersGroup.GetUsernameFromUserId(UserId)
			if Username then
				-- Check Whitelist
				for _, WhitelistedPlayer in next, _G.TemporaryAdministrators do
					if tonumber(WhitelistedPlayer) == UserId or string.lower(tostring(WhitelistedPlayer)) == string.lower(Username) then
						return true, Username
					end
				end
				
				-- Default
				local IsInAGroup = false
				local InGroup, Tag = nil
				for GroupId, Rank in next, Settings.ACCESS.GROUP_IDS do
					InGroup, Tag = UsersGroup.IsUserIdInGroup(UserId, GroupId)
					
					if InGroup then
						IsInAGroup = true
						break
					end
				end
				
				if not IsInAGroup then
					Tag = "???"
					
					-- Check Groups
					for _, GroupId in next, _G.Groups do
						InGroup, Tag = UsersGroup.IsUserIdInGroup(UserId, GroupId)
						
						if InGroup then
							IsInAGroup = true
							break
						end
					end
				end
				
				-- Group Lock Checking
				if not IsInAGroup and _G.GroupLocked then
					return false, Username
				end
				
				Speaker:SendMessage(string.format("%s is requesting to join the server.", Username), {ChatColor = Settings.VISUAL.REQUEST_COLOR, NameColor = Settings.VISUAL.REQUEST_COLOR, Tags = {{TagText = Tag; TagColor = Settings.VISUAL.CLAN_COLOR}}})
			end
		end
	end
end

local function OnHandledJoinRequest(Message)
	local Data = Message.Data
	local Players = Data.Players
	local Accept = Data.Accept
	local Sender = Data.Sender
	local Type = Data.Type
	
	if Sender and #Players > 0 and not Type then
		Speaker:SendMessage(string.format("%s has %s %s.", Sender, Accept and "accepted" or "declined", table.concat(Players, ", ")), {ChatColor = Accept and Settings.VISUAL.ACCEPTED_COLOR or Settings.VISUAL.DECLINED_COLOR, NameColor = Accept and Settings.VISUAL.ACCEPTED_COLOR or Settings.VISUAL.DECLINED_COLOR})                 	
	elseif Type ~= nil then
		Speaker:SendMessage(string.format("%s has banned %s.", Sender, table.concat(Players, ", ")), {ChatColor = Settings.VISUAL.DECLINED_COLOR, NameColor = Settings.VISUAL.DECLINED_COLOR})                 	
	end 
end

-- Module
local Server = {}
Server.IsReserved = game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
Server.__index = Server

function Server.New(Name)
	local self = setmetatable({}, Server)
	
	-- Global Subscriptions
	MessagingService:SubscribeAsync("GroupLockEnabled", function()
		local Players = Players:GetPlayers()
		for _, Player in next, Players do
			local IsInAGroup = false
			for GroupId, Rank in next, Settings.ACCESS.GROUP_IDS do
				local InGroup, _ = UsersGroup.IsUserIdInGroup(Player.UserId, GroupId)

				if InGroup then
					IsInAGroup = true
					break
				end
			end

			if not IsInAGroup then
				-- Check Groups
				for _, GroupId in next, _G.Groups do
					local InGroup, _ = UsersGroup.IsUserIdInGroup(Player.UserId, GroupId)

					if InGroup then
						IsInAGroup = true
						break
					end
				end
			end
			
			if not IsInAGroup then
				Player:Kick("Group Locked.")
			end
		end
	end)
	
	-- Reserved/Pending
	if not Server.IsReserved then
		local GetSuccess, ReservedServerCode = RetryFunction(ServersStore.GetAsync, ServersStore, Name)
		if not GetSuccess or (GetSuccess and not ReservedServerCode) then
			ReservedServerCode = TeleportService:ReserveServer(game.PlaceId)
			local SetSuccess, Message = RetryFunction(ServersStore.SetAsync, ServersStore, Name, ReservedServerCode)
			if not SetSuccess then
				warn(Message)
				return
			end
		end
		
		self.ReservedServerCode = ReservedServerCode
		
		MessagingService:SubscribeAsync("HandleJoinRequest", function(Message)
			local Data = Message.Data
			local Usernames = Data.Players
			local Accept = Data.Accept
			local Sender = Data.Sender
			local Type = Data.Type
			local TargetPlayers = {}
			local PlayerData = {}
			
			for _, Username in next, Usernames do
				local Players = Players:GetPlayers()
				if Username == "all" and #Usernames == 1 then
					TargetPlayers = Players
					for _, Player in next, Players do
						table.insert(PlayerData, Player.Name)
					end
					break
				else
					for _, Player in next, Players do
						local PlayerUsername = string.lower(Player.Name)
						if string.sub(PlayerUsername, 1, string.len(Username)) == Username then
							table.insert(PlayerData, Player.Name)
							
							if Accept then
								table.insert(TargetPlayers, Player)
							elseif (Settings.ACCESS.DECLINE_TEMP_BAN and Sender) or Type == 0 then
								Blacklist:TemporarilyBanByUserId(Player.UserId)
							elseif Type == 1 then
								Blacklist:PermanentlyBanByUserId(Player.UserId)
							else
								Player:Kick("You've been declined from entering the server.")
							end
						end
					end
				end
			end
			
			self:SendMessage("HandledJoinRequest", {Players = PlayerData, Accept = Accept, Sender = Sender, Type = Type})

			if Accept then
				self:TeleportPlayers(TargetPlayers)
			end
		end)
	else
		-- Subscriptions
		MessagingService:SubscribeAsync("JoinRequest", function(Message)
			local Accept, Status = OnJoinRequest(Message)
			
			if Accept and Status then
				self:HandleJoinRequest({Status}, true)
			elseif Accept == false then
				self:HandleJoinRequest({Status}, false)
			end
		end)
		
		MessagingService:SubscribeAsync("HandledJoinRequest", OnHandledJoinRequest)
		
		-- Setup Server Starting and Ending
		local SetSuccess, Message = RetryFunction(ServersStore.SetAsync, ServersStore, string.format("%sLastOpenedServerTime", Name), tick())
		if not SetSuccess then
			warn(Message)
			return
		end
		
		local ServerInfo = TimezoneService:GetServerInfo()
		local IsDaylight = ServerInfo.daylightSavings
		local ServerTimezone, ServerTimezoneExtraInfo = TimezoneService:GetTimeZoneByOffset(ServerInfo.gmtOffset, nil, IsDaylight)
		local SetSuccess, Message = RetryFunction(ServersStore.SetAsync, ServersStore, string.format("%sLastOpenedServerRegion", Name), IsDaylight and ServerTimezoneExtraInfo.daylight.abbreviation or ServerTimezone)
		if not SetSuccess then
			warn(Message)
			return
		end
		
		game:BindToClose(function()
			RetryFunction(ServersStore.SetAsync, ServersStore, string.format("%sLastClosedServerTime", Name), tick())
			Blacklist:ClearTemporaryBanlist()
		end)
	end
	
	self.Name = Name
	
	return self
end

function Server:TeleportPlayers(Players)
	if not self.IsReserved then
		TeleportService:TeleportToPrivateServer(game.PlaceId, self.ReservedServerCode, Players)
	end
end

function Server:SendMessage(Topic, Message)
	local Success, _ = RetryFunction(MessagingService.PublishAsync, MessagingService, Topic, Message)
	return Success
end

function Server:RequestJoin(Player)
	self:SendMessage("JoinRequest", Player.UserId)
end

function Server:IsStarted()
	local GetLastOpenedSuccess, LastOpenedServerTime = RetryFunction(ServersStore.GetAsync, ServersStore, string.format("%sLastOpenedServerTime", self.Name))
	if GetLastOpenedSuccess then
		LastOpenedServerTime = LastOpenedServerTime or 0
		local GetLastClosedSuccess, LastClosedServerTime = RetryFunction(ServersStore.GetAsync, ServersStore, string.format("%sLastClosedServerTime", self.Name))
		if GetLastClosedSuccess then
			LastClosedServerTime = LastClosedServerTime or 0
			local IsStarted = LastOpenedServerTime > LastClosedServerTime
			
			local GetLastOpenedServerRegionSuccess, LastOpenedServerRegion = RetryFunction(ServersStore.GetAsync, ServersStore, string.format("%sLastOpenedServerRegion", self.Name))
			
			if IsStarted and LastOpenedServerRegion then
				return IsStarted, LastOpenedServerRegion
			end
			
			return IsStarted
		end
	end
	return false
end

function Server:HandleJoinRequest(Players, Accept, Sender, Type)
	Server:SendMessage("HandleJoinRequest", {Players = Players, Accept = Accept, Sender = Sender and Sender.Name or nil, Type = Type or nil})
end

return Server
