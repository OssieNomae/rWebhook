--[[
	@license MIT License
	@version 2.0.0
	@authors OssieNomae - 2025
	
	rWebhook: A Discord Webhook wrapper emulating methods of discord.js
	
	--------------------------------
	
	Webhook.new(Url) -- Returns a 'Webhook' object
		
	rWebhook.EmbedBuilder() -- Returns an 'Embed' object
	Webhook.EmbedBuilder() -- Returns an 'Embed' object
	
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
	
	Webhook:Send({ -- Sends the embed, Returns Success [boolean], HttpResponse
		content = string,
		embeds = {Embed}
	})
	
	--------------------------------
	
	local rWebhook = require(rWebhook.Module.Location)
	local Webhook = rWebhook.new("https://discord.com/api/webhooks/xxxxxxxxxxxx/xxxxxxxxxxxx")
	
	local Embed = Webhook.MessageEmbed()
		:setColor('#0099ff')
		:setTitle('Test Embed')
		:setURL('https://discord.js.org/')
		:setAuthor({ name = 'Some name', iconURL = 'https://i.imgur.com/AfFp7pu.png', url = 'https://discord.js.org' })
		:setDescription('Some description here')
		:setThumbnail('https://i.imgur.com/AfFp7pu.png')
		:addFields({
			{ name = 'Regular field title', value = 'Some value here' },
			{ name = "\u{200B}", value = "\u{200B}" },
			{ name = 'Inline field title', value = 'Some value here', inline = true },
			{ name = 'Inline field title', value = 'Some value here', inline = true },
		})
		:addField('Inline field title', 'Some value here', true)
		:setImage('https://i.imgur.com/AfFp7pu.png')
		:setTimestamp()
		:setFooter({ text = 'Some footer text here', iconURL = 'https://i.imgur.com/AfFp7pu.png' });
		
	local Success, Response = Webhook:Send({content = "This is additional text!", embeds = {Embed}})
]]

----- Module / Class / Object Table -----------
local Module = {}

local rWebhookObject = {}
rWebhookObject.__index = rWebhookObject

local EmbedObject = {}
EmbedObject.__index = EmbedObject

----- Loaded Services -----
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

----- Util / Modules / Shared -----
local Util = ReplicatedStorage:WaitForChild("Util")
local Promise = require(Util:WaitForChild("Promise")) -- Location to Promise

local HttpWrapper = require(script.Parent:WaitForChild("HttpWrapper")) -- Location to HttpWrapper

----- Types / Enums -----
type Field = {
	name: string,
	value: string,
	inline: boolean?,
}

export type FooterArgs = {
	text: string,
	iconURL: string,
}

export type AuthorArgs = {
	name: string,
	iconURL: string,
	url: string
}

export type Embed = {
	color: number,
	title: string?,
	url: string?,
	author: {
		name: string,
		icon_url: string,
		url: string
	}?,
	description: string?,
	thumbnail: {
		url: string,
	}?,
	fields: {Field}, -- this is jsoned...
	image: {
		url: string,
	}?,
	timestamp: string, -- ISOString
	footer: {
		text: string,
		icon_url: string,
	}?,
}

export type rWebhookObject = typeof(setmetatable({} :: {
	Url: string,
	Retries: number,
	_RateLimitedUtil: number,
}, rWebhookObject))

export type EmbedObject = typeof(setmetatable({} :: {
	Data: Embed
}, EmbedObject))

export type SendArgs = {
	content: string?,
	embeds: {EmbedObject}?
}

----- Private Variables -----
local ERROR_BAD_ARGUMENT = "Bad argument %d, [%s] expected got [%s]."

----- Public Methods -----
function Module.new(Url: string)
	local self = setmetatable({}, rWebhookObject)
	
	self.Url = Url
	self.Retries = 3
	self._RateLimitedUntil = 0
	
	return self
end

function Module.EmbedBuilder(): EmbedObject
	local self = setmetatable({}, EmbedObject)
	self.Data = {
		fields = {}
	}

	return self
end

----- Public Object Methods -----
function rWebhookObject:Send(SendArgs: SendArgs)
	if typeof(SendArgs) ~= "table" then
		error(ERROR_BAD_ARGUMENT:format(1, "table", typeof(SendArgs)))
	end
	
	local embeds = {}
	if SendArgs.embeds then
		for Index,Embed in SendArgs.embeds do -- unpack data
			local EmbedData = Embed.Data
			embeds[Index] = EmbedData
		end
	end
	
	return self:_SendRequest(HttpService:JSONEncode({
		content = SendArgs.content,
		embeds = embeds,
	}))
end

function rWebhookObject:_RateLimit(): boolean
	local RateLimit = self._RateLimitedUntil - time()
	if RateLimit > 0 then
		task.wait(RateLimit)
		self:_RateLimit()
	end
	return true
end

function rWebhookObject:_SendRequest(Body: string, UrlParams: HttpWrapper.UrlParameters?): (boolean, HttpWrapper.HttpResponse)
	return Promise.retry(function()
		return Promise.new(function(Resolve, Reject)
			self:_RateLimit()
			
			local Response = HttpWrapper.HttpRequest({
				Url = HttpWrapper.AddURLParams(self.Url, UrlParams),
				Method = "POST",
				Headers = {
					["Content-Type"] = "application/json"
				},
				Body = Body
			})
			
			if not Response.Success then -- HttpRequest Failed?
				Reject(Response)
				return
			end
			
			-- Verify
			if Response.StatusCode == 200 then
				Resolve(Response)
				
			elseif Response.StatusCode == 404 then
				Response.Body = "Webhook not found"
				Reject(Response)
				
			elseif Response.StatusCode == 401 or Response.StatusCode == 403 then
				Response.Body = "Invalid webhook"
				Reject(Response)
				
			elseif Response.StatusCode == 429 then -- Rate Limited
				local Retry_After = Response.Headers["x-ratelimit-retry-after"] or 10 -- discord doesn't always give out the retry-after header?
				if Retry_After then
					self._RateLimitedUntil = time() + Retry_After
				end
				
				Reject(Response)
			else
				Reject(Response) -- anything else
			end
		end)
	end, self.Retries):await()
end

function EmbedObject:setColor(Color: Color3 | number | string)
	if typeof(Color) == "number" then
		self.Data.color = Color -- color is just a number
	elseif typeof(Color) == "Color3" then
		self.Data.color = tonumber(Color:ToHex(),16) -- Color3 to Number
	elseif string.match(Color, "#") then
		self.Data.color = tonumber(string.gsub(Color, "#", ""), 16); -- Hex to Number
	else
		error(ERROR_BAD_ARGUMENT:format(1, "number, Color3 or Hex string", typeof(Color)))
	end
	
	return self
end

function EmbedObject:setTitle(title)
	if typeof(title) ~= "string" then
		error(ERROR_BAD_ARGUMENT:format(1, "string", typeof(title)))
	end
	self.Data.title = title
	
	return self
end

function EmbedObject:setDescription(desc)
	if typeof(desc) ~= "string" then
		error(ERROR_BAD_ARGUMENT:format(1, "string", typeof(desc)))
	end
	self.Data.description = desc
	return self
end

function EmbedObject:setURL(url)
	if typeof(url) ~= "string" then
		error(ERROR_BAD_ARGUMENT:format(1, "url string", typeof(url)))
	end
	self.Data.url = url
	return self
end

function EmbedObject:setTimestamp()
	self.Data.timestamp = DateTime.now():ToIsoDate()
	return self
end

function EmbedObject:setThumbnail(url)
	if typeof(url) ~= "string" then
		error(ERROR_BAD_ARGUMENT:format(1, "image url string", typeof(url)))
	end
	self.Data.thumbnail = {
		url = url
	}
	return self
end

function EmbedObject:setImage(url)
	if typeof(url) ~= "string" then
		error(ERROR_BAD_ARGUMENT:format(1, "image url string", typeof(url)))
	end
	self.Data.image = {
		url = url
	}
	return self
end

function EmbedObject:addFields(fields: {Field})
	if typeof(fields) ~= "table" then
		error(ERROR_BAD_ARGUMENT:format(1, "table", typeof(fields)))
	end
	for _,Args in pairs(fields) do
		self:addField(Args.name, Args.value, Args.inline)
	end
	return self
end

function EmbedObject:addField(name: string, value: string, inline: boolean?)
	if typeof(name) ~= "string" then
		error(ERROR_BAD_ARGUMENT:format(1, "field name string", typeof(name)))
	end
	if typeof(value) ~= "string" then
		error(ERROR_BAD_ARGUMENT:format(1, "field value string", typeof(value)))
	end
	
	table.insert(self.Data.fields, {
		name = name,
		value = value,
		inline = inline
	})
	
	return self
end

function EmbedObject:setAuthor(Args: AuthorArgs)
	if typeof(Args) ~= "table" then
		error(ERROR_BAD_ARGUMENT:format(1, "table", typeof(Args)))
	end
	self.Data.author = {
		name = Args.name,
		icon_url = Args.iconURL,
		url = Args.url,
	}
	return self
end

function EmbedObject:setFooter(Args: FooterArgs)
	if typeof(Args) ~= "table" then
		error(ERROR_BAD_ARGUMENT:format(1, "table", typeof(Args)))
	end
	self.Data.footer = {
		text = Args.text,
		icon_url = Args.iconURL
	}
	
	return self
end

----- Shortcuts -----
rWebhookObject.EmbedBuilder = Module.EmbedBuilder -- allows access to EmbedBuilder from both rWebhook and WebhookObject

return Module