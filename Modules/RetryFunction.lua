return function(Function, ...)
	local Tries = 0
	local Success, Message
	repeat
		Success, Message =  pcall(function(...)
			return { Function(...) }
		end, ...)
		Tries = Tries + 1
	until Success or Tries > 3
	if not Success then
		return Success, Message
	end
	return Success, unpack(Message)
end
