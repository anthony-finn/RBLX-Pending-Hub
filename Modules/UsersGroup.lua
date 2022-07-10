local Users = { Cache = {}, GroupCache = {} }

local UserService = game:GetService("UserService")
local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")

local function Search(Key, Value)
	for MultiKey, UserInfo in next, Users.Cache do
		if MultiKey[Key] == Value then
			return UserInfo
		end
	end
end

function Users.GetUsernameFromUserId(UserId)
	local UserInformation = Search("UserId", UserId)
	if UserInformation then
		return UserInformation.Username
	end
	
	local Success, UserInformation = pcall(UserService.GetUserInfosByUserIdsAsync, UserService, {UserId})
	if Success and #UserInformation > 0 then
		UserInformation = UserInformation[1]
		local MultiKey = {Username = UserInformation.Username, UserId = UserId}
		Users.Cache[MultiKey] = UserInformation
		return MultiKey.Username
	end
end

function Users.GetUserIdFromUsername(Username)
	local UserInformation = Search("Username", Username)
	if UserInformation then
		return UserInformation.Id
	end
	
	local Success, UserId = pcall(Players.GetUserIdFromNameAsync, Players, Username)
	if Success then
		local Success, UserInformation = pcall(UserService.GetUserInfosByUserIdsAsync, UserService, {UserId})
		if Success and #UserInformation > 0 then
			UserInformation = UserInformation[1]
			local MultiKey = {Username = UserInformation.Username, UserId = UserId}
			Users.Cache[MultiKey] = UserInformation
			return MultiKey.UserId
		end
	end
end

function Users.GetDisplayNameFromUserId(UserId)
	local UserInformation = Search("UserId", UserId)
	if UserInformation then
		return UserInformation.DisplayName
	end
	
	local Username = Users.GetUsernameFromUserId(UserId)
	if Username then
		local UserInformation = Search("UserId", UserId)
		if UserInformation then
			return UserInformation.DisplayName
		end
	end
end

function Users.GetDisplayNameFromUsername(Username)
	local UserInformation = Search("Username", Username)
	if UserInformation then
		return UserInformation.DisplayName
	end

	local UserId = Users.GetUserIdFromUsername(Username)
	if UserId then
		local UserInformation = Search("Username", Username)
		if UserInformation then
			return UserInformation.DisplayName
		end
	end
end

function Users.IsUserIdInGroup(UserId, GroupId)
	local Username = Users.GetUsernameFromUserId(UserId)
	if Username then
		local UserGroups = Users.GroupCache[UserId] or GroupService:GetGroupsAsync(UserId)
		Users.GroupCache[UserId] = UserGroups
		for _, Group in next, UserGroups do
			if Group.Id == GroupId then
				return true, Group.Name
			end
		end
	end
	
	return false
end

function Users.IsUsernameInGroup(Username, GroupId)
	local UserId = Users.GetUserIdFromUsername(Username)
	if UserId then
		return Users.IsUserIdInGroup(UserId)
	end
	
	return false
end

function Users.GetRankInGroupFromUserId(UserId, GroupId)
	local Username = Users.GetUsernameFromUserId(UserId)
	if Username then
		local UserGroups = Users.GroupCache[UserId] or GroupService:GetGroupsAsync(UserId)
		Users.GroupCache[UserId] = UserGroups
		for _, Group in next, UserGroups do
			if Group.Id == GroupId then
				return Group.Rank
			end
		end
	end

	return 0
end

function Users.GetRoleInGroupFromUserId(UserId, GroupId)
	local Username = Users.GetUsernameFromUserId(UserId)
	if Username then
		local UserGroups = Users.GroupCache[UserId] or GroupService:GetGroupsAsync(UserId)
		Users.GroupCache[UserId] = UserGroups
		for _, Group in next, UserGroups do
			if Group.Id == GroupId then
				return Group.Role
			end
		end
	end

	return
end

function Users.GetRankInGroupFromUsername(Username, GroupId)
	local UserId = Users.GetUserIdFromUsername(Username)
	if UserId then
		return Users.GetRankInGroupFromUserId(UserId, GroupId)
	end

	return 0
end

function Users.GetRoleInGroupFromUsername(Username, GroupId)
	local UserId = Users.GetUserIdFromUsername(Username)
	if UserId then
		return Users.GetRoleInGroupFromUserId(UserId, GroupId)
	end

	return 0
end

function Users.GetGroupInfo(GroupId)
	return GroupService:GetGroupInfoAsync(GroupId)
end

return Users
