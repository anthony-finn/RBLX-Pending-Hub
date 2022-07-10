-- Pending Hub Revision

-- Services
local Bin = script:WaitForChild("Bin")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

-- Load Modules
local Modules do
	Modules = script:WaitForChild("Modules")
	local LoadModules = require(script:WaitForChild("LoadModules"))
	LoadModules(Modules)
	Modules = getfenv().Modules
end

-- Bin Setup
local BansUI = Bin:WaitForChild("BansUI")
local BanTemplate = Bin:WaitForChild("BanTemplate")

-- Module Setup
local Settings = _G.PENDING_HUB_SETTINGS
local Speaker = Modules.SpeakerService.Get("HUB")
local Blacklist = Modules.Blacklist.Load()
local Server = Modules.Server.New("ReservedPrivateServer")

-- HTTP Service
local HttpSuccess, HttpResult = pcall(function()
	return HttpService:GetAsync("https://google.com")
end)

if string.find(string.lower(HttpResult), "http requests are not enabled") then
	task.wait(5)
	Speaker:SendMessage("You must enable HttpService in Studio by setting Game Settings->Security->Allow Http Requests to true.")
	return {}
end

-- Settings
local PREFIX = Settings.VISUAL.PREFIX

-- Timezone Setup
local PREFERRED_REGION = string.upper(Settings.ACCESS.PRIORITY_REGION)
local PreferredRegionInfo = Modules.TimezoneService:GetTimeZoneInfo(PREFERRED_REGION)
local ServerInfo = Modules.TimezoneService:GetServerInfo()
local ServerInfoSuccess, IsDaylight = pcall(function() return ServerInfo.daylightSavings end)

if not ServerInfoSuccess then
	task.wait(5)
	Speaker:SendMessage("Failed to fetch server's location. You must restart the server.")
	return {}
end

local ServerTimezone, ServerTimezoneExtraInfo = Modules.TimezoneService:GetTimeZoneByOffset(ServerInfo.gmtOffset, nil, IsDaylight)
local ServerStarterId = nil
local PlayerTimezones = {}

-- Speaker Visual Appearance Setup
Speaker:SetColor(Settings.VISUAL.SPEAKER_COLOR)
Speaker:SetFontSize(Settings.VISUAL.FONT_SIZE)

-- Temporary Settings
_G.TemporaryAdministrators = {}
_G.Groups = {}
_G.GroupLocked = Settings.ACCESS.GROUP_LOCK
local GroupNames = {}

local CurrentlyPending = {}

-- Functions
local function GetArticle(String)
	if string.len(String) <= 0 then return "" end
	local Start = string.lower(string.sub(String, 1, 1))
	if Start == "a" or Start == "e" or Start == "i" or Start == "o" or Start == "u" then
		return "an"
	else
		return "a"
	end
end

local function GetTarget(SearchUsername)
	local Players = Players:GetPlayers()
	for _, Player in next, Players do
		local PlayerUsername = string.lower(Player.Name)
		if string.sub(PlayerUsername, 1, string.len(SearchUsername)) == SearchUsername then
			return Player
		end
	end
end

local function IsPlayerWhitelisted(Player)
	local UserId = Player.UserId
	local Username = Player.Name
	
	for GroupId, Rank in next, Settings.ACCESS.GROUP_IDS do
		if Modules.UsersGroup.GetRankInGroupFromUserId(UserId, GroupId) >= Rank then
			return true, true
		end
	end
	
	for _, WhitelistedPlayer in next, Settings.ACCESS.WHITELISTED do
		if tonumber(WhitelistedPlayer) == UserId or string.lower(tostring(WhitelistedPlayer)) == string.lower(Username) then
			return true, true
		end
	end
	
	for _, WhitelistedPlayer in next, _G.TemporaryAdministrators do
		if tonumber(WhitelistedPlayer) == UserId or string.lower(tostring(WhitelistedPlayer)) == string.lower(Username) then
			return true, false
		end
	end
	
	return false, false
end

local function Chatted(Player, Message)
	task.wait()
	
	local HasPrefix = string.match(Message, string.format("^%s", PREFIX))
	if HasPrefix then
		-- Split Message
		Message = string.gsub(Message, HasPrefix, "", string.len(PREFIX))
		local Command, Arguments = nil, {}
		for Argument in string.gmatch(Message,"[^%s]+") do
			Argument = string.lower(Argument)
			if not Command then
				Command = Argument
			else
				table.insert(Arguments, Argument)
			end
		end
		
		-- Handle Commands
		-- Commands for all users
		if Command == "ss" or Command == "sc" or Command == "servercreator" or Command == "serverstarter" or Command == "starter" or Command == "creator" then
			local StarterUsername = Modules.UsersGroup.GetUsernameFromUserId(ServerStarterId)
			if StarterUsername then
				Speaker:SendPrivateMessage(string.format("%s [%s] started the server.", StarterUsername, ServerStarterId), Player)
			end
		elseif Command == "sl" or Command == "loc" or Command == "location" or Command == "region" or Command == "l" or Command == "timezone" then
			Speaker:SendPrivateMessage(string.format("Server Location: %s [%s]", ServerInfo.timezone, IsDaylight and ServerTimezoneExtraInfo.daylight.abbreviation or ServerTimezone), Player)
		end
		
		-- Commands for admins
		local IsWhitelisted, FullAccess = IsPlayerWhitelisted(Player)
		if IsWhitelisted then
			if not FullAccess then
				if not (Command == "accept" or Command == "decline") then
					-- Temporary Administrators cannot have full access to the commands.
					return
				end
			end
			
			if Command == "lock" or Command == "gl" or Command == "grouplock" then
				if Server.IsReserved then
					_G.GroupLocked = not _G.GroupLocked
					Speaker:SendMessage(string.format("Group lock %s by %s", _G.GroupLocked and "enabled" or "disabled", Player.Name))
					
					-- Handle Temporary Bans
					if _G.GroupLocked then
						Server:SendMessage("GroupLockEnabled")
					end
				end
			elseif Command == "accept" then
				if Server.IsReserved then
					Server:HandleJoinRequest(Arguments, true, Player)
				end
			elseif Command == "decline" then
				if Server.IsReserved then
					Server:HandleJoinRequest(Arguments, false, Player)
				end
			elseif Command == "tban" or Command == "ban" or Command == "tempban" then
				for _, Argument in next, Arguments do
					local Target = GetTarget(Argument)
					if Target then
						local IsWhitelisted, FullAccess = IsPlayerWhitelisted(Target)
						if not FullAccess then
							Blacklist:TemporarilyBanByUserId(Target.UserId)
						end
					else
						Server:HandleJoinRequest(Arguments, false, Player , 0)
					end
				end
			elseif Command == "pban" or Command == "permban" then
				for _, Argument in next, Arguments do
					local Target = GetTarget(Argument)
					if Target then
						local IsWhitelisted, FullAccess = IsPlayerWhitelisted(Target)
						if not FullAccess then
							Blacklist:PermanentlyBanByUserId(Target.UserId)
						end
					else
						Server:HandleJoinRequest(Arguments, false, Player , 1)
					end
				end
			elseif Command == "unban" then
				local PermBans, TempBans = Blacklist:GetBans()
				local Successes = {}
				
				for _, Argument in next, Arguments do
					for _, PermBan in next, PermBans do
						local Number = tonumber(Argument)
						if tonumber(Argument) then
							-- UserIds
							if PermBan == Number then
								Blacklist:UnPermanentBanByUserId(PermBan)
								table.insert(Successes, tostring(PermBan))
								break
							end
						else
							-- Usernames
							local Username = Modules.UsersGroup.GetUsernameFromUserId(PermBan)
							local SearchString = string.lower(Username)
							if string.sub(SearchString, 1, string.len(Argument)) == Argument then
								Blacklist:UnPermanentBanByUserId(PermBan)
								table.insert(Successes, Username)
								break
							end
						end
					end
					
					for _, TempBan in next, TempBans do
						local Number = tonumber(Argument)
						if tonumber(Argument) then
							-- UserIds
							if TempBan == Number then
								Blacklist:UnPermanentBanByUserId(TempBan)
								table.insert(Successes, tostring(TempBan))
								break
							end
						else
							local Username = string.lower(Modules.UsersGroup.GetUsernameFromUserId(TempBan))
							if string.sub(Username, 1, string.len(Argument)) == Argument then
								Blacklist:UnTemporaryBanByUserId(TempBans)
								table.insert(Successes, Username)
								break
							end
						end
					end
				end
				
				if #Successes > 0 then
					Speaker:SendMessage(string.format("%s has unbanned %s.", Player.Name, table.concat(Successes, ", ")), {ChatColor = Settings.VISUAL.ACCEPTED_COLOR, NameColor = Settings.VISUAL.ACCEPTED_COLOR})
				end
			elseif Command == "bans" then
				local Interface = BansUI:Clone()
				local PermBans, TempBans = Blacklist:GetBans()
								
				for _, PermBan in next, PermBans do
					local BanFrame = BanTemplate:Clone()
					BanFrame.Type.Text = "PERM"
					BanFrame.Type.TextColor3 = Color3.fromRGB(170, 0, 0)
					BanFrame.Username.Text = "Username: " .. Modules.UsersGroup.GetUsernameFromUserId(PermBan)
					BanFrame.Parent = Interface.Background.BansFrame
				end
				
				for _, TempBan in next, TempBans do
					local BanFrame = BanTemplate:Clone()
					BanFrame.Username.Text = "Username: " .. Modules.UsersGroup.GetUsernameFromUserId(TempBan)
					BanFrame.Parent = Interface.Background.BansFrame
				end
				
				Interface.Parent = Player.PlayerGui
			elseif Command == "admins" then
				if Server.IsReserved then
					local Admins = {}
					for _, UserId in next, _G.TemporaryAdministrators do
						table.insert(Admins, Modules.UsersGroup.GetUsernameFromUserId(UserId))
					end
					
					Speaker:SendPrivateMessage(string.format("Admins: %s.", #Admins > 0 and table.concat(Admins, ", ") or "None"), Player)
				end
			elseif Command == "addadmin" or Command == "addadmins" or Command == "add" then
				if Server.IsReserved then
					local Targets = {}
					for _, Username in next, Arguments do
						local Number = tonumber(Username)
						if Number then
							local Players = Players:GetPlayers()
							for _, Target in next, Players do
								if Target.UserId == Number and not IsPlayerWhitelisted(Target) then
									table.insert(_G.TemporaryAdministrators, Target.UserId)
									table.insert(Targets, Target.Name)
								end
							end
						else
							local Target = GetTarget(Username)
							if Target and not IsPlayerWhitelisted(Target) then
								table.insert(_G.TemporaryAdministrators, Target.UserId)
								table.insert(Targets, Target.Name)
							end
						end
					end
					
					if #Targets > 0 then
						Speaker:SendMessage(string.format("%s has given permissions to %s.", Player.Name, table.concat(Targets, ", ")), {ChatColor = Settings.VISUAL.ACCEPTED_COLOR, NameColor = Settings.VISUAL.ACCEPTED_COLOR})
					end
				end
			elseif Command == "removeadmin" or Command == "removeadmins" or Command == "remove" then
				if Server.IsReserved then
					local Targets = {}
					for _, Username in next, Arguments do
						local Number = tonumber(Username)
						if Number then
							local Players = Players:GetPlayers()
							for _, Target in next, Players do
								for Index, WhitelistedPlayer in pairs(_G.TemporaryAdministrators) do
									if WhitelistedPlayer == Target.UserId then
										table.insert(Targets, tostring(Target.Name))
										table.remove(_G.TemporaryAdministrators, Index)
										break
									end
								end
							end
						else
							local Target = GetTarget(Username)
							if Target then
								for Index, WhitelistedPlayer in pairs(_G.TemporaryAdministrators) do
									if WhitelistedPlayer == Target.UserId then
										table.insert(Targets, Target.Name)
										table.remove(_G.TemporaryAdministrators, Index)
										break
									end
								end
							end
						end
					end

					if #Targets > 0 then
						Speaker:SendMessage(string.format("%s has removed permissions from %s.", Player.Name, table.concat(Targets, ", ")), {ChatColor = Settings.VISUAL.DECLINED_COLOR, NameColor = Settings.VISUAL.DECLINED_COLOR})
					end
				end
			elseif Command == "addgroup" then
				if Server.IsReserved then
					local AddedGroups = {}
					
					for _, Argument in next, Arguments do
						local GroupId = tonumber(Argument)
						if GroupId then
							local GroupInfo = Modules.UsersGroup.GetGroupInfo(GroupId)
							if GroupInfo then
								table.insert(_G.Groups, GroupId)
								table.insert(AddedGroups, GroupInfo.Name)
								table.insert(GroupNames, GroupInfo.Name)
							end
						end
					end
					
					if #AddedGroups > 0 then
						Speaker:SendMessage(string.format("Added %s %s.", #AddedGroups > 1 and "groups" or "group", table.concat(AddedGroups, ", ")))
					end
				end
			elseif Command == "setgroups" then
				if Server.IsReserved then
					_G.Groups = {}
					GroupNames = {}
					
					local AddedGroups = {}

					for _, Argument in next, Arguments do
						local GroupId = tonumber(Argument)
						if GroupId then
							local GroupInfo = Modules.UsersGroup.GetGroupInfo(GroupId)
							if GroupInfo then
								table.insert(_G.Groups, GroupId)
								table.insert(AddedGroups, GroupInfo.Name)
								table.insert(GroupNames, GroupInfo.Name)
							end
						end
					end

					if #AddedGroups > 0 then
						Speaker:SendMessage(string.format("Set %s to %s.", #AddedGroups > 1 and "groups" or "group", table.concat(AddedGroups, ", ")))
					end
				end
			elseif Command == "removegroup" then
				if Server.IsReserved then
					local RemovedGroups = {}

					for _, Argument in next, Arguments do
						local GroupId = tonumber(Argument)
						if GroupId then
							local GroupInfo = Modules.UsersGroup.GetGroupInfo(GroupId)
							if GroupInfo then
								for Index, TargetGroupId in next, _G.Groups do
									if GroupId == TargetGroupId then
										table.insert(RemovedGroups, GroupInfo.Name)
										table.remove(_G.Groups, Index)
										table.remove(GroupNames, Index)
										break
									end
								end
							end
						end
					end

					if #RemovedGroups > 0 then
						Speaker:SendMessage(string.format("Removed %s %s.", #RemovedGroups > 1 and "groups" or "group", table.concat(RemovedGroups, ", ")))
					end
				end
			elseif Command == "groups" then
				if Server.IsReserved then
					Speaker:SendPrivateMessage(string.format("Groups: %s.", #GroupNames > 0 and table.concat(GroupNames, ", ") or "None"), Player)
				end
			elseif Command == "join" then
				if not Server.IsReserved then
					Server:TeleportPlayers({Player})
				end
			elseif Command == "place" then
				if not Server.IsReserved then
					local Targets = {}
					for _, Username in next, Arguments do
						local Target = GetTarget(Username)
						if Target then
							table.insert(Targets, Target)
						end
					end
					Server:TeleportPlayers(Targets)
				end
			end
		end
	end
end

local function PlayerAdded(Player)
	if PlayerTimezones[Player] then 
		return 
	end
	
	PlayerTimezones[Player] = true
	
	if not ServerStarterId then
		ServerStarterId = Player.UserId
	end
	
	-- Check Account Age
	if Settings.ACCESS.ACCOUNT_AGE.MINIMUM > 0 and Player.AccountAge < Settings.ACCESS.ACCOUNT_AGE.MINIMUM then
		if Settings.ACCESS.ACCOUNT_AGE.PERM_BAN then
			Blacklist:PermanentlyBanByUserId(Player.UserId)
		else
			Blacklist:TemporarilyBanByUserId(Player.UserId)
		end
		return
	end
	
	task.wait(1)
	
	if not Server.IsReserved then
		local ClientTimezone, ClientTimezoneInfo = Modules.TimezoneService:GetClientTimeZone(Player)
		PlayerTimezones[Player] = ClientTimezone
		local IsStarted, Region = Server:IsStarted()
		
		if not Modules.Blacklist:IsUserIdBanned(Player.UserId) then
			if IsPlayerWhitelisted(Player) then
				if IsStarted then
					Server:TeleportPlayers({Player})
				else
					if (ServerTimezone == PREFERRED_REGION and Player.UserId == ServerStarterId) or ClientTimezone == PREFERRED_REGION then
						Server:TeleportPlayers({Player})
					else
						if not IsDaylight or (IsDaylight and not PreferredRegionInfo.daylight) then
							Speaker:SendPrivateMessage(string.format("Waiting for %s %s server. Type '%sjoin' for %s %s server.", GetArticle(PREFERRED_REGION), PREFERRED_REGION, PREFIX, GetArticle(ClientTimezone), ClientTimezone), Player, {NameColor = Settings.VISUAL.ACCEPTED_COLOR, ChatColor = Settings.VISUAL.ACCEPTED_COLOR})
						else
							local PREFERRED_REGION = PreferredRegionInfo.daylight.abbreviation
							local ClientTimezone = ClientTimezoneInfo.daylight.abbreviation
							Speaker:SendPrivateMessage(string.format("Waiting for %s %s server. Type '%sjoin' for %s %s server.", GetArticle(PREFERRED_REGION), PREFERRED_REGION, PREFIX, GetArticle(ClientTimezone), ClientTimezone), Player, {NameColor = Settings.VISUAL.ACCEPTED_COLOR, ChatColor = Settings.VISUAL.ACCEPTED_COLOR})
						end
					end
				end
			else
				CurrentlyPending[Player] = true
				if IsStarted then
					Server:RequestJoin(Player)
				elseif ClientTimezone == PREFERRED_REGION then
					local PREFERRED_REGION = PreferredRegionInfo.daylight.abbreviation
					local Username = Player.Name
					local Players = Players:GetPlayers()
					for _, Player in next, Players do
						local IsWhitelisted, FullAccess = IsPlayerWhitelisted(Player)
						if IsWhitelisted then
							Speaker:SendPrivateMessage(string.format("%s can start %s %s server. Type \"%splace %s\" to start the server.", Username, GetArticle(PREFERRED_REGION), PREFERRED_REGION, PREFIX, Username), Player, {NameColor = Settings.VISUAL.ACCEPTED_COLOR, ChatColor = Settings.VISUAL.ACCEPTED_COLOR})
						end
					end
				end
			end
		end
		Speaker:SendPrivateMessage("You are currently in the pending server.", Player)
	else
		Speaker:SendPrivateMessage("You are currently in the main server.", Player)
	end
	
	-- Commands
	Player.Chatted:Connect(function(Message) 
		Chatted(Player, Message) 
	end)
end

local function Initialize()	
	-- Load Dependencies
	if not (Blacklist and Server) then
		Speaker:SendMessage("Pending Hub failed to load.")
		return
	end
	
	-- Setup Players
	Players.PlayerAdded:Connect(PlayerAdded)
	for _, Player in next, Players:GetPlayers() do
		PlayerAdded(Player)
	end
	
	Players.PlayerRemoving:Connect(function(Player)
		PlayerTimezones[Player] = nil
		CurrentlyPending[Player] = nil
	end)
	
	-- Display Information
	Speaker:SendMessage(string.format("Server Location: %s [%s]", ServerInfo.timezone, IsDaylight and ServerTimezoneExtraInfo.daylight.abbreviation or ServerTimezone))
end

-- Initialize
return Initialize
