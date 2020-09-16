local wp = minetest.get_worldpath()
local datadir = wp .. "/whitelist_data/"
assert(minetest.mkdir(datadir), "Unable to create whitelist data dir at " .. datadir)

local path = function(name)
	return datadir .. name
end

local check = function(name)
	-- note, assumed sanitised as below
	local f, err = io.open(path(name))
	-- err could be "doesn't exist" but also other errors, so fail shut in that case.
	-- some versions of lua return the underlying exit code too but this is not portable,
	-- neither across OSes nor even lua versions should minetest ever upgrade.
	-- so just log the error in that case.
	if not f then
		minetest.log(
			"info",
			"whitelist: player " .. name .. "failed to validate. " ..
			"opening whitelist file for player said: " .. err)
		return false
	end
	f:close()
	return true
end

local allowed = "^[0-9A-Za-z-_]*$"
local sanitise = function(name)
	local result, _ = name:match(allowed)
	return result ~= nil
end

-- whitelist and blacklist functions: returns error string on failure, nil otherwise
local whitelist = function(name)
	local f, err = io.open(path(name), "w+")
	if not f then
		assert(err)
		return err
	end
	f:close()
	return nil
end

local blacklist = function(name)
	local ret, err = os.remove(path(name))
	if not ret then
		assert(err)
		return err
	end
	return nil
end



-- TODO: allow customising this from settings
local wrongchars = "Forbidden characters present in username. Allowed pattern is " .. allowed
local nope = "You are not on the whitelist. Please contact the server admin if this is in error."
minetest.register_on_prejoinplayer(function(name, ip)
	if not sanitise(name) then
		return wrongchars
	end
	if not check(name) then
		return nope
	end
end)




-- command section
local priv = "whitelist"
minetest.register_privilege(priv, {
	description = "Allows inspection and modification of the player login whitelist",
})

local privs = {[priv] = true}
local empty = function()
	return false, "No target user specified."
end
local invalid = function()
	return false, "That username is forbidden by the whitelist."
end

minetest.register_chatcommand("whitelist_add", {
	params = "playername",
	description = "Add a player to the whitelist",
	privs = privs,
	func = function(invoker, target)
		if not target or #target < 1 then
			return empty()
		end
		if not sanitise(target) then
			return invalid()
		end
		if check(target) then
			return true, "User already in whitelist."
		end
		local err = whitelist(target)
		if err then
			return false, "Failed to whitelist user: " .. err
		end
		return true, "Successfully added the player to the whitelist."
	end
})

minetest.register_chatcommand("whitelist_remove", {
	params = "playername",
	description = "Removes a player from the whitelist",
	privs = privs,
	func = function(invoker, target)
		if not target or #target < 1 then
			return empty()
		end
		if not sanitise(target) then
			return invalid()
		end
		if not check(target) then
			return true, "User was already taken out of the whitelist."
		end
		local err = blacklist(target)
		if err then
			return false, "Failed to blacklist user: " .. err
		end
		return true, "Successfully removed player from the whitelist."
	end
})

minetest.register_chatcommand("whitelist_check", {
	params = "playername",
	description = "Check if a player is in the whitelist",
	privs = privs,
	func = function(invoker, target)
		if not target or #target < 1 then
			return empty()
		end
		if not sanitise(target) then
			return invalid()
		end
		return true, target .. ": " .. (check(target) and "true" or "false")
	end
})


