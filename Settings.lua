-- Pending Hub 2022
-- Scripted by chaust#3543

local ACCESS_SETTINGS = {
	-- Insert Group Ids inside the table in the format mentioned below.
	-- Multiple groups can be allowed, however, you must separate them by a semicolon(;) or comma(,)
	-- FORMAT: {[GroupId] = Rank, [GroupId] = Rank}
	GROUP_IDS = {[1004235] = 250};
	
	-- Insert UserIds within the table to add users to their respective permission.
	-- Whitelisted Players are given full access to commands.
	-- Blacklisted Players are banned from entering.
	-- FORMAT: {17936965, 1232121}
	WHITELISTED = {};
	BLACKLISTED = {};
	
	-- A player that is not in a group will be temporary banned.
	-- If this setting is enabled, make sure groups are set up correctly.
	GROUP_LOCK = false;
	
	-- Temporarily bans users that are declined.
	DECLINE_TEMP_BAN = true;
	
	-- Minimum Account Age
	-- Set to -1 or math.huge to disable.
	ACCOUNT_AGE = {
		MINIMUM = 30,
		PERM_BAN = false
	};
	
	-- Experimental Feature
	-- Attempts to start a server in the given timezone.
	-- The region can be bypassed by whitelisted players.
	-- The server will not start if this setting is filled.
	-- Common Regions:
	-- EST, PST, CST, GMT
	PRIORITY_REGION = "EST";
}

local VISUAL_SETTINGS = {
	-- Color Settings
	SPEAKER_COLOR = Color3.fromRGB(255, 255, 255);
	REQUEST_COLOR = Color3.fromRGB(255, 255, 255);
	CLAN_COLOR = Color3.fromRGB(255, 255, 255);
	ACCEPTED_COLOR = Color3.fromRGB(0, 202, 67);
	DECLINED_COLOR = Color3.fromRGB(255, 47, 47);
	
	-- Other Settings
	FONT_SIZE = 19;
	
	-- Prefix
	PREFIX = "!";
}

return {ACCESS = ACCESS_SETTINGS, VISUAL = VISUAL_SETTINGS}
