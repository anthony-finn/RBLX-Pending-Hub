-- Services
local ServerScriptService = game:GetService("ServerScriptService")
local TextChatService = game:GetService("TextChatService")

-- ChatSpeaker Module
local ChatSpeaker = {}
local Speakers = {}
ChatSpeaker.__index = ChatSpeaker

if TextChatService.ChatVersion == Enum.ChatVersion.LegacyChatService then
	local ChatService = require(ServerScriptService:WaitForChild("ChatServiceRunner"):WaitForChild("ChatService"))

	--Wait for the channel 'All' to exist
	if not ChatService:GetChannel("All") then
		while true do
			local ChannelName = ChatService.ChannelAdded:Wait()
			if ChannelName == "All" then
				break
			end
		end
	end

	function ChatSpeaker.Get(Name)
		-- ChatSpeaker Cached
		if Speakers[Name] then
			return Speakers[Name]
		end
		
		-- Get Chat Speaker
		local Speaker = ChatService:GetSpeaker(Name)
		if not Speaker then
			Speaker = ChatService:AddSpeaker(Name)
		end
		
		-- Join Channel
		Speaker:JoinChannel("All")
		
		-- Object Wrapper
		local self = {Name = Name, Speaker = Speaker}
		
		setmetatable(self, ChatSpeaker)
		Speakers[Name] = self
		return self
	end

	function ChatSpeaker:SendPrivateMessage(Message, Player, ExtraData)
		local PlayerName = Player.Name
		local PlayerSpeaker = ChatService:GetSpeaker(PlayerName)
		
		if not PlayerSpeaker then
			repeat
				PlayerSpeaker = ChatService:GetSpeaker(PlayerName)
				task.wait()
			until PlayerSpeaker or not game:IsAncestorOf(Player)
		end
		
		if PlayerSpeaker and PlayerSpeaker:GetPlayer() == Player then
			PlayerSpeaker:SendMessage(Message, "All", self.Name, ExtraData)
		end
	end

	function ChatSpeaker:SendMessage(Message, ExtraData)
		self.Speaker:SayMessage(Message, "All", ExtraData)
	end

	function ChatSpeaker:SetTag(Text, Color)
		if not Text and not Color then
			self.Speaker:SetExtraData("Tags", {})
		else
			self.Speaker:SetExtraData("Tags", {{TagText = Text, TagColor = Color}})
		end
	end

	function ChatSpeaker:SetColor(Color)
		self.Speaker:SetExtraData("NameColor", Color)
		self.Speaker:SetExtraData("ChatColor", Color)
	end

	function ChatSpeaker:SetFontSize(Size)
		self.Speaker:SetExtraData("TextSize", Size)
	end

	return ChatSpeaker
else
	local Players = game:GetService("Players")
	local TextChannels = TextChatService:WaitForChild("TextChannels")
	local RBXGeneral = TextChannels:WaitForChild("RBXGeneral")
	
	local NewMessage = script:WaitForChild("NewMessage")
	
	function ChatSpeaker.Get(Name)
		-- ChatSpeaker Cached
		if Speakers[Name] then
			return Speakers[Name]
		end

		-- Object Wrapper
		local self = {Name = Name, ExtraData = {NameColor = Color3.fromRGB(255, 255, 255), ChatColor = Color3.fromRGB(255, 255, 255), TextSize = 14, Tags = {}}}

		setmetatable(self, ChatSpeaker)
		Speakers[Name] = self
		return self
	end
	
	local function Color3ToString(Color)
		return string.format("%s, %s, %s", tostring(math.floor(Color.r * 255 + 0.5)), tostring(math.floor(Color.g * 255 + 0.5)), tostring(math.floor(Color.b * 255 + 0.5)))
	end
	
	local function ParseMessage(self, Message, ExtraData)
		if ExtraData then
			for Key, Value in next, self.ExtraData do
				if not ExtraData[Key] then
					ExtraData[Key] = self.ExtraData[Key]
				end
			end
		else
			ExtraData = self.ExtraData
		end

		local Message = string.format("<font color=\"rgb(%s)\">%s:</font> <font color=\"rgb(%s)\">%s</font>", Color3ToString(ExtraData.NameColor), self.Name, Color3ToString(ExtraData.ChatColor), Message)

		if #ExtraData.Tags > 0 then
			local TagMessage = ""
			for _, Tag in next, ExtraData.Tags do
				TagMessage = string.format("<font color=\"rgb(%s)\">[%s]</font>", Color3ToString(Tag.TagColor), tostring(Tag.TagText)) .. TagMessage
			end

			Message = string.format("%s %s", TagMessage, Message)
		end

		Message = string.format("<font size=\"%s\">%s</font>", tostring(ExtraData.TextSize), Message)
		
		return Message
	end

	function ChatSpeaker:SendPrivateMessage(Message, Player, ExtraData)
		local NewMessage = NewMessage:Clone()
		NewMessage.MessageText.Value = ParseMessage(self, Message, ExtraData)
		NewMessage.Parent = Player.PlayerGui
		NewMessage.Disabled = false
		NewMessage:Destroy()
	end

	function ChatSpeaker:SendMessage(Message, ExtraData)
		Message = ParseMessage(self, Message, ExtraData)
		local Players = Players:GetPlayers()
		for _, Player in next, Players do
			local NewMessage = NewMessage:Clone()
			NewMessage.MessageText.Value = Message
			NewMessage.Parent = Player.PlayerGui
			NewMessage.Disabled = false
			NewMessage:Destroy()
		end
	end

	function ChatSpeaker:SetTag(Text, Color)
		self.ExtraData.Tags = {{TagColor = Color, TagText = Text}}
	end

	function ChatSpeaker:SetColor(Color)
		self.ExtraData.NameColor = Color
		self.ExtraData.ChatColor = Color
	end

	function ChatSpeaker:SetFontSize(Size)
		self.ExtraData.TextSize = Size - 4
	end

	return ChatSpeaker
end
