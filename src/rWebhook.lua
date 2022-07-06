--[[

		rWebhook: A Discord Webhook wrapper emulating methods of discord.js
		
		Developed by OssieNomae
		Licensed under the MIT License
		Version 1.0.0
		
		--------------------------------
		
		rWebhook(Url) -- Returns a 'rWebhook' object
		
		rWebhook.MessageEmbed() -- Returns an 'Embed' object
		
		Embed. 	
		- setTitle(string)
		- setDescription(string)
		- setURL(url)
		- setAuthor({name = string, value = string, inline = boolean})
		- setFooter({text = string, iconURL = url});
		- addFields({
			{ name = string, value = string, inline = boolean },
			{ name = string, value = string, inline = boolean },
			...
		})
		- addField(name [string], value [string], inline [boolean])
		- setColor(color) -- Color3, Hex Or Number
		- setThumbnail(imageUrl)
		- setImage(imageUrl)
		- setTimestamp()
		
		https://discordjs.guide/popular-topics/embeds.html#embed-preview
		
		rWebhook:Send({ -- Sends the embed, Returns Success [boolean], Response [table {Code, Message}]
			content = string,
			embeds = {Embed}
		})
		
		--------------------------------
		
		local rWebhook = require(rWebhook.Module.Location)("https://discord.com/api/webhooks/xxxxxxxxxxxx/xxxxxxxxxxxx")
		
		local Embed = rWebhook.MessageEmbed()
			.setColor('#0099ff')
			.setTitle('Test Embed')
			.setURL('https://discord.js.org/')
			.setAuthor({ name = 'Some name', iconURL = 'https://i.imgur.com/AfFp7pu.png', url = 'https://discord.js.org' })
			.setDescription('Some description here')
			.setThumbnail('https://i.imgur.com/AfFp7pu.png')
			.addFields({
				{ name = 'Regular field title', value = 'Some value here' },
				{ name = "\u{200B}", value = "\u{200B}" },
				{ name = 'Inline field title', value = 'Some value here', inline = true },
				{ name = 'Inline field title', value = 'Some value here', inline = true },
			})
			.addField('Inline field title', 'Some value here', true)
			.setImage('https://i.imgur.com/AfFp7pu.png')
			.setTimestamp()
			.setFooter({ text = 'Some footer text here', iconURL = 'https://i.imgur.com/AfFp7pu.png' });
			
		local Success, Response = rWebhook:Send({content = "This is additional text!", embeds = {Embed}})
		
]]

local HttpService = game:GetService("HttpService")

local ERROR_BAD_ARGUMENT = "Bad argument %d, [%s] expected got [%s]."

local DiscordWrapper = {}
DiscordWrapper.WebhookUrl = ""
DiscordWrapper.__index = DiscordWrapper

function DiscordWrapper.MessageEmbed() -- Create Message
	local Embed = {
		["data"] = {}
	}
	
	local self = setmetatable(Embed.data, {})
	
	function Embed.setColor(color)
		if typeof(color) == "number" then
			self.color = color -- color is just a number
		elseif typeof(color) == "Color3" then
			self.color = tonumber(color:ToHex(),16) -- Color3 to Number
		elseif string.match(color, "#") then
			self.color = tonumber(string.gsub(color, "#", ""), 16); -- Hex to Number
		else
			error(ERROR_BAD_ARGUMENT:format(1, "number, Color3 or Hex string", typeof(color)))
		end
		return Embed
	end
	
	function Embed.setTitle(title)
		if typeof(title) ~= "string" then
			error(ERROR_BAD_ARGUMENT:format(1, "string", typeof(title)))
		end
		self.title = title
		return Embed
	end
	
	function Embed.setDescription(desc)
		if typeof(desc) ~= "string" then
			error(ERROR_BAD_ARGUMENT:format(1, "string", typeof(desc)))
		end
		self.description = desc
		return Embed
	end
	
	function Embed.setURL(url)
		if typeof(url) ~= "string" then
			error(ERROR_BAD_ARGUMENT:format(1, "url string", typeof(url)))
		end
		self.url = url
		return Embed
	end
	
	function Embed.setTimestamp()
		self.timestamp = DateTime.now():ToIsoDate()
		return Embed
	end
	
	function Embed.setThumbnail(url)
		if typeof(url) ~= "string" then
			error(ERROR_BAD_ARGUMENT:format(1, "image url string", typeof(url)))
		end
		self.thumbnail = {
			["url"] = url
		}
		return Embed
	end
	
	function Embed.setImage(url)
		if typeof(url) ~= "string" then
			error(ERROR_BAD_ARGUMENT:format(1, "image url string", typeof(url)))
		end
		self.image = {
			["url"] = url
		}
		return Embed
	end
	
	function Embed.addFields(fields)
		if typeof(fields) ~= "table" then
			error(ERROR_BAD_ARGUMENT:format(1, "table", typeof(fields)))
		end
		if not self.fields then
			self.fields = {}
		end
		for _,args in pairs(fields) do
			self.fields[#self.fields + 1] = {
				["name"] = args.name,
				["value"] = args.value,
				["inline"] = args.inline,
			}
		end
		return Embed
	end
	
	function Embed.addField(name, value, inline)
		if not self.fields then
			self.fields = {}
		end
		self.fields[#self.fields + 1] = {
			["name"] = name,
			["value"] = value,
			["inline"] = inline,
		}
		return Embed
	end
	
	function Embed.setAuthor(args)
		if typeof(args) ~= "table" then
			error(ERROR_BAD_ARGUMENT:format(1, "table", typeof(args)))
		end
		self.author = {
			["name"] = args.name,
			["icon_url"] = args.iconURL,
			["url"] = args.url,
		}
		return Embed
	end
	
	function Embed.setFooter(args)
		if typeof(args) ~= "table" then
			error(ERROR_BAD_ARGUMENT:format(1, "table", typeof(args)))
		end
		self.footer = {
			["text"] = args.text,
			["icon_url"] = args.iconURL
		}
		return Embed
	end
	
	return Embed
end

return function(Url) -- Actual module
	local self = setmetatable({}, DiscordWrapper)
	self.WebhookUrl = Url
	self.RateLimited = false

	function self:Send(args)
		if typeof(args) ~= "table" then
			error(ERROR_BAD_ARGUMENT:format(1, "table", typeof(args)))
		end
		
		if self.RateLimited then repeat task.wait(3) until self.RateLimited == false end
		local embeds = {}
		local content = args.content or ""
		
		for Index,Embed in pairs(args.embeds) do -- unpack data
			local EmbedData = Embed.data
			embeds[Index] = EmbedData
		end
	
		
		local response = HttpService:RequestAsync({
			Url = self.WebhookUrl,
			Method = "POST",
			Headers = {
				["Content-Type"] = "application/json"
			},
			Body = HttpService:JSONEncode({
				["content"] = content,
				["embeds"] = embeds,
			})
		})
		
		if response.StatusCode == 200 then
			return true, {
				Code = response.StatusCode,
				Message = "Webhook has been sent!"
			}
		elseif response.StatusCode == 404 then
			return false, {
				Code = response.StatusCode,
				Message = "Webhook not found"
			}
		elseif response.StatusCode == 401 or response.StatusCode == 403 then
			return false, {
				Code = response.StatusCode,
				Message = "Invalid webhook"
			}
		elseif response.StatusCode == 429 then
			local retry_after = response["Headers"]["x-ratelimit-retry-after"]

			if not retry_after then
				return false, {
					Code = response.StatusCode,
					Message = "Could not retry request"
				}
			end

			self.RateLimited = true
			task.wait(retry_after)
			self.RateLimited = false

			return self:Send(args)
		else
			return false, {
				Code = response.StatusCode,
				Message = response.StatusMessage,
			}
		end
	end
	
	return self
end
