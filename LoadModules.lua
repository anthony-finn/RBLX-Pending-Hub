return function(Directory)
	local FunctionEnvironment = getfenv(2)
	if not FunctionEnvironment.Modules then
		FunctionEnvironment.Modules = {}
		local DirectoryChildren = Directory:GetChildren()
		for _, Module in next, DirectoryChildren do
			FunctionEnvironment.Modules[Module.Name] = require(Module)
		end
	end
end
