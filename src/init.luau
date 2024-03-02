--!nonstrict

--[[

	______                        
	| ___ \                       
	| |_/ /___  _ __   __ _  ___  
	|    // _ \| '_ \ / _` |/ _ \ 
	| |\ \ (_) | | | | (_| | (_) |
	\_| \_\___/|_| |_|\__, |\___/ 
	                   __/ |      
	                  |___/       

	Rongo - MongoDB API Wrapper for Roblox
	
	Rongo gives developers easy access to MongoDBs web APIs
	so they're able to use MongoDB directly in their games
	
	Rongo uses MongoDB's Data API, which is disabled by
	default so you must enable it in your Atlas settings
	
	Version: 2.0.0
	License: MIT License
	Documentation: https://devforum.roblox.com/t/rongo/1755615	
	
	Copyright (c) 2024 Untitled Games

--]]

--// Services

local HttpService = game:GetService("HttpService")

--// Constants

local ENDPOINTS = {
	POST = {
		["FindOne"] = "/action/findOne",
		["FindMany"] = "/action/find",
		["InsertOne"] = "/action/insertOne",
		["InsertMany"] = "/action/insertMany",
		["UpdateOne"] = "/action/updateOne",
		["UpdateMany"] = "/action/updateMany",
		["ReplaceOne"] = "/action/replaceOne",
		["DeleteOne"] = "/action/deleteOne",
		["DeleteMany"] = "/action/deleteMany",
		["Aggregate"] = "/action/aggregate",
	}
}

--// Variables

local Cache = {}

--// Private Functions

local function RongoError(message: string)
	error("[RONGO] "..message.."\n",2)
end

local function RongoWarn(message: string,...)
	warn("[RONGO] "..message,...)
end

local function ValidateStringArguments(Arguments: {[string]: any},Function: string)
	local err = 0
	for arg,value in pairs(Arguments) do
		if type(value) ~= "string" then err = 1 continue elseif #value < 1 then err = 2 continue end
	end
	if err == 0 then return end
	local keys = {}
	for k in pairs(Arguments) do table.insert(keys,k) end
	if err == 1 then
		return RongoError(`{table.concat(keys,", ")} argument(s) in '{Function}' were not valid (must be a string)`)
	elseif err == 2 then
		return RongoError(`{table.concat(keys,", ")} argument(s) in '{Function}' were empty strings, please ensure they have content`)
	end
end

local function CreateAuthHeaders(Auth: {[string]: string})
	if not Auth or not Auth.Type then return end
	if Auth.Type == "key" then
		return {
			["apiKey"] = Auth.Key
		}
	elseif Auth.Type == "emailpassword" then
		return {
			["email"] = Auth.Email,
			["password"] = Auth.Password
		}
	elseif Auth.Type == "bearer" then
		return {
			["Authorization"] = "Bearer "..string.gsub(Auth.Token,"Bearer ","")
		}
	end
	
	return
end

local function RongoRequest(Url: string,Auth: any, Data: any)
	local Success,Response = pcall(function() return HttpService:RequestAsync(	
		{
			Url = Url,
			Method = "POST",
			Headers = {
				["apiKey"] = Auth and Auth["apiKey"],
				["email"] = Auth and Auth["email"],
				["password"] = Auth and Auth["password"],
				["Authorization"] = Auth and Auth["Authorization"],
				["Content-Type"] = "application/json",
				["Accept"] = "application/json",
				["Access-Control-Request-Headers"] = "*"
			},
			Body = HttpService:JSONEncode(Data) 
		})
	end)
	
	if not Success or not Response or not Response.Body then RongoError(`Failed to send request to {Url}`); RongoWarn("Response data:",Response) return end

	local Body = HttpService:JSONDecode(Response.Body)
	if Body and Body["error"] then RongoWarn(`Request returned an error with the following details:\nError message: {Body["error"]}\nError code: {Body["error_code"]}\nLink: {Body["link"]}\n`) end
	if Response["Success"] == false then RongoWarn(`Request returned an error with the following details:\nError message: {Body}\nStatus code: {Response["StatusCode"]}\nStatus Message: {Response["StatusMessage"]}\n`) end
	return Body or Response.Body
end

--// Main Module

local Rongo = {}

--// Classes

local RongoClient = {}
RongoClient.__index = RongoClient

local RongoCluster = {}
RongoCluster.__index = RongoCluster

local RongoDatabase = {}
RongoDatabase.__index = RongoDatabase

local RongoCollection = {}
RongoCollection.__index = RongoCollection

--// Types 

export type RongoClient = typeof(RongoClient)
export type RongoCluster = typeof(RongoCluster)
export type RongoDatabase = typeof(RongoDatabase)
export type RongoCollection = typeof(RongoCollection)

--// Functions

function Rongo.new(Url: string,Key: string?) : RongoClient
	ValidateStringArguments({Url = Url},"Rongo.new()")
	return setmetatable({
		_settings = {
			Url = Url,
			Auth = {
				Key = Key,
				Type = "key",
			},
		},
		_type = "RongoClient"
	},RongoClient)
end

--// Rongo Client

function RongoClient:SetEmailPasswordAuth(Email: string, Password: string)
	if not self then return RongoWarn("Attempted to call 'RongoClient:SetEmailPasswordAuth()' without initializing a new client; you can do this with 'Rongo.new()'") end
	ValidateStringArguments({Email = Email,Password = Password},"RongoClient:SetPasswordAuth()")
	self._settings.Auth = {
		Type = "emailpassword",
		Email = Email,
		Password = Password
	}
end

function RongoClient:SetApiKeyAuth(Key: string)
	if not self then return RongoWarn("Attempted to call 'RongoClient:SetApiKeyAuth()' without initializing a new client; you can do this with 'Rongo.new()'") end
	ValidateStringArguments({Key = Key},"RongoClient:SetApiKeyAuth()")
	self._settings.Auth = {
		Type = "key",
		Key = Key	
	}
end

function RongoClient:SetBearerAuth(Token: string)
	if not self then return RongoWarn("Attempted to call 'RongoClient:SetBearerAuth()' without initializing a new client; you can do this with 'Rongo.new()'") end
	ValidateStringArguments({Token = Token},"RongoClient:SetBearer()")
	self._settings.Auth = {
		Type = "bearer",
		Token = Token	
	}
end

function RongoClient:GetCluster(Cluster: string) : RongoCluster
	if not self then return RongoWarn("Attempted to call 'RongoClient:GetCluster()' without initializing a new client; you can do this with 'Rongo.new()'") end
	ValidateStringArguments({Cluster = Cluster},"RongoClient:GetCluster()")
	return setmetatable({
		_cluster = Cluster,
		_client = self,
		_type = "RongoCluster"
	},RongoCluster)
end

--// Rongo Cluster

function RongoCluster:GetDatabase(Database: string) : RongoDatabase
	if not self then return RongoWarn("Attempted to call 'RongoCluster:GetDatabase()' without initializing a cluster; you can do this with 'RongoClient:GetCluster()'") end
	if self._type ~= "RongoCluster" or not self._client or not self._cluster then return RongoError("Missing required values on cluster object, please ensure you have correctly setup a new cluster") end
	ValidateStringArguments({Database = Database},"RongoCluster:GetCluster()")
	return setmetatable({
		_cluster = self._cluster,
		_client = self._client,
		_database = Database,
		_type = "RongoDatabase"
	},RongoDatabase)
end

--// Rongo Database

function RongoDatabase:GetCollection(Collection: string) : RongoCollection
	if not self then return RongoWarn("Attempted to call 'RongoDatabase:GetCollection()' without initializing a database; you can do this with 'RongoCluster:GetDatabase()'") end
	if self._type ~= "RongoDatabase" or not self._client or not self._cluster  or not self._database then return RongoError("Missing required values on database object, please ensure you have correctly setup a new database") end
	ValidateStringArguments({Collection = Collection},"RongoDatabase:GetCollection()")
	return setmetatable({
		_cluster = self._cluster,
		_client = self._client,
		_database = self._database,
		_collection = Collection,
		_type = "RongoCollection"
	},RongoCollection)
end

--// Rongo Collection

function RongoCollection:FindOne(Filter: {[string]: string | {[string]: string}}?): {[string]: any}?
	if not self then return RongoWarn("Attempted to call 'RongoCollection:FindOne()' without initializing a collection; you can do this with 'RongoDatabase:GetCollection()'") end
	if self._type ~= "RongoCollection" or not self._client or not self._cluster  or not self._database or not self._collection then return RongoError("Missing required values on database object, please ensure you have correctly setup a new database") end
	local url = self._client._settings.Url or nil
	local auth = self._client._settings.Auth or nil
	if not url or not auth then return RongoError("RongoClient contains invalid Url or Auth values, please ensure you have correctly initialized the client") end
	local authHeaders = CreateAuthHeaders(auth)
	if not authHeaders then return RongoError("RongoClient authorization was setup incorrectly, please ensure you have correctly initialized the client") end
	
	local bodyData = {
		["dataSource"] = self._cluster,
		["database"] = self._database,
		["collection"] = self._collection,
		["filter"] = Filter or {},
	}
	
	local response = RongoRequest(url .. ENDPOINTS.POST.FindOne,authHeaders, bodyData)
	if not response then return end
	
	if response["document"] then return response["document"] end
	return response
end

function RongoCollection:FindMany(Filter: {[string]: string | {[string]: string}}?, Projection: {[string]: number}?, Sort: {[string]: number}?,Limit: number?, Skip: number?) : {{[string]: any}}?
	if not self then return RongoWarn("Attempted to call 'RongoCollection:FindMany()' without initializing a collection; you can do this with 'RongoDatabase:GetCollection()'") end
	if self._type ~= "RongoCollection" or not self._client or not self._cluster  or not self._database or not self._collection then return RongoError("Missing required values on database object, please ensure you have correctly setup a new database") end
	local url = self._client._settings.Url or nil
	local auth = self._client._settings.Auth or nil
	if not url or not auth then return RongoError("RongoClient contains invalid Url or Auth values, please ensure you have correctly initialized the client") end
	local authHeaders = CreateAuthHeaders(auth)
	if not authHeaders then return RongoError("RongoClient authorization was setup incorrectly, please ensure you have correctly initialized the client") end

	local bodyData = {
		["dataSource"] = self._cluster,
		["database"] = self._database,
		["collection"] = self._collection,
		["filter"] = Filter or "{}",
		["projection"] = Projection,
		["sort"] = Sort,
		["limit"] = Limit,
		["skip"] = Skip,
	}

	local response = RongoRequest(url .. ENDPOINTS.POST.FindMany,authHeaders, bodyData)
	if not response then return end
	
	if response["documents"] then return response["documents"] end

	return response
end

function RongoCollection:InsertOne(Document: {[string]: any}): string?
	if not self then return RongoWarn("Attempted to call 'RongoCollection:InsertOne()' without initializing a collection; you can do this with 'RongoDatabase:GetCollection()'") end
	if self._type ~= "RongoCollection" or not self._client or not self._cluster  or not self._database or not self._collection then return RongoError("Missing required values on database object, please ensure you have correctly setup a new database") end
	local url = self._client._settings.Url or nil
	local auth = self._client._settings.Auth or nil
	if not url or not auth then return RongoError("RongoClient contains invalid Url or Auth values, please ensure you have correctly initialized the client") end
	local authHeaders = CreateAuthHeaders(auth)
	if not authHeaders then return RongoError("RongoClient authorization was setup incorrectly, please ensure you have correctly initialized the client") end

	local bodyData = {
		["dataSource"] = self._cluster,
		["database"] = self._database,
		["collection"] = self._collection,
		["document"] = Document,
	}

	local response = RongoRequest(url .. ENDPOINTS.POST.InsertOne,authHeaders, bodyData)
	if not response then return end

	if response["insertedId"] then return response["insertedId"] end
	return response
end

function RongoCollection:InsertMany(Documents: {{[string]: any}}) : {string}?
	if not self then return RongoWarn("Attempted to call 'RongoCollection:InsertMany()' without initializing a collection; you can do this with 'RongoDatabase:GetCollection()'") end
	if self._type ~= "RongoCollection" or not self._client or not self._cluster  or not self._database or not self._collection then return RongoError("Missing required values on database object, please ensure you have correctly setup a new database") end
	local url = self._client._settings.Url or nil
	local auth = self._client._settings.Auth or nil
	if not url or not auth then return RongoError("RongoClient contains invalid Url or Auth values, please ensure you have correctly initialized the client") end
	local authHeaders = CreateAuthHeaders(auth)
	if not authHeaders then return RongoError("RongoClient authorization was setup incorrectly, please ensure you have correctly initialized the client") end

	local bodyData = {
		["dataSource"] = self._cluster,
		["database"] = self._database,
		["collection"] = self._collection,
		["documents"] = Documents,
	}

	local response = RongoRequest(url .. ENDPOINTS.POST.InsertMany,authHeaders, bodyData)
	if not response then return end

	if response["insertedIds"] then return response["insertedIds"] end

	return response
end

function RongoCollection:UpdateOne(Filter: {[string]: string | {[string]: string}}?,Update: {[string]: {[string]: any}}?,Upsert: boolean): {matchedCount: number, modifiedCount: number}?
	if not self then return RongoWarn("Attempted to call 'RongoCollection:UpdateOne()' without initializing a collection; you can do this with 'RongoDatabase:GetCollection()'") end
	if self._type ~= "RongoCollection" or not self._client or not self._cluster  or not self._database or not self._collection then return RongoError("Missing required values on database object, please ensure you have correctly setup a new database") end
	local url = self._client._settings.Url or nil
	local auth = self._client._settings.Auth or nil
	if not url or not auth then return RongoError("RongoClient contains invalid Url or Auth values, please ensure you have correctly initialized the client") end
	local authHeaders = CreateAuthHeaders(auth)
	if not authHeaders then return RongoError("RongoClient authorization was setup incorrectly, please ensure you have correctly initialized the client") end

	local bodyData = {
		["dataSource"] = self._cluster,
		["database"] = self._database,
		["collection"] = self._collection,
		["filter"] = Filter or {},
		["update"] = Update,
		["upsert"] = Upsert,
	}

	local response = RongoRequest(url .. ENDPOINTS.POST.UpdateOne,authHeaders, bodyData)
	if not response then return end

	return response
end


function RongoCollection:UpdateMany(Filter: {[string]: string | {[string]: string}}?,Update: {[string]: {[string]: any}}?,Upsert: boolean): {matchedCount: number, modifiedCount: number}?
	if not self then return RongoWarn("Attempted to call 'RongoCollection:UpdateMany()' without initializing a collection; you can do this with 'RongoDatabase:GetCollection()'") end
	if self._type ~= "RongoCollection" or not self._client or not self._cluster  or not self._database or not self._collection then return RongoError("Missing required values on database object, please ensure you have correctly setup a new database") end
	local url = self._client._settings.Url or nil
	local auth = self._client._settings.Auth or nil
	if not url or not auth then return RongoError("RongoClient contains invalid Url or Auth values, please ensure you have correctly initialized the client") end
	local authHeaders = CreateAuthHeaders(auth)
	if not authHeaders then return RongoError("RongoClient authorization was setup incorrectly, please ensure you have correctly initialized the client") end

	local bodyData = {
		["dataSource"] = self._cluster,
		["database"] = self._database,
		["collection"] = self._collection,
		["filter"] = Filter or {},
		["update"] = Update,
		["upsert"] = Upsert,
	}

	local response = RongoRequest(url .. ENDPOINTS.POST.UpdateMany,authHeaders, bodyData)
	if not response then return end

	return response
end

function RongoCollection:DeleteOne(Filter: {[string]: string | {[string]: string}}?): number? 
	if not self then return RongoWarn("Attempted to call 'RongoCollection:DeleteOne()' without initializing a collection; you can do this with 'RongoDatabase:GetCollection()'") end
	if self._type ~= "RongoCollection" or not self._client or not self._cluster  or not self._database or not self._collection then return RongoError("Missing required values on database object, please ensure you have correctly setup a new database") end
	local url = self._client._settings.Url or nil
	local auth = self._client._settings.Auth or nil
	if not url or not auth then return RongoError("RongoClient contains invalid Url or Auth values, please ensure you have correctly initialized the client") end
	local authHeaders = CreateAuthHeaders(auth)
	if not authHeaders then return RongoError("RongoClient authorization was setup incorrectly, please ensure you have correctly initialized the client") end

	local bodyData = {
		["dataSource"] = self._cluster,
		["database"] = self._database,
		["collection"] = self._collection,
		["filter"] = Filter or {},
	}

	local response = RongoRequest(url .. ENDPOINTS.POST.DeleteOne,authHeaders, bodyData)
	if not response then return end

	if response["deletedCount"] then return response["deletedCount"] end
	return response
end

function RongoCollection:DeleteMany(Filter: {[string]: string | {[string]: string}}?): number? 
	if not self then return RongoWarn("Attempted to call 'RongoCollection:DeleteMany()' without initializing a collection; you can do this with 'RongoDatabase:GetCollection()'") end
	if self._type ~= "RongoCollection" or not self._client or not self._cluster  or not self._database or not self._collection then return RongoError("Missing required values on database object, please ensure you have correctly setup a new database") end
	local url = self._client._settings.Url or nil
	local auth = self._client._settings.Auth or nil
	if not url or not auth then return RongoError("RongoClient contains invalid Url or Auth values, please ensure you have correctly initialized the client") end
	local authHeaders = CreateAuthHeaders(auth)
	if not authHeaders then return RongoError("RongoClient authorization was setup incorrectly, please ensure you have correctly initialized the client") end

	local bodyData = {
		["dataSource"] = self._cluster,
		["database"] = self._database,
		["collection"] = self._collection,
		["filter"] = Filter or {},
	}

	local response = RongoRequest(url .. ENDPOINTS.POST.DeleteMany,authHeaders, bodyData)
	if not response then return end

	if response["deletedCount"] then return response["deletedCount"] end
	return response
end

function RongoCollection:Aggregate(Pipeline: {{[string]: any}}): {{[string]: any}}? 
	if not self then return RongoWarn("Attempted to call 'RongoCollection:Aggregate()' without initializing a collection; you can do this with 'RongoDatabase:GetCollection()'") end
	if self._type ~= "RongoCollection" or not self._client or not self._cluster  or not self._database or not self._collection then return RongoError("Missing required values on database object, please ensure you have correctly setup a new database") end
	local url = self._client._settings.Url or nil
	local auth = self._client._settings.Auth or nil
	if not url or not auth then return RongoError("RongoClient contains invalid Url or Auth values, please ensure you have correctly initialized the client") end
	local authHeaders = CreateAuthHeaders(auth)
	if not authHeaders then return RongoError("RongoClient authorization was setup incorrectly, please ensure you have correctly initialized the client") end

	local bodyData = {
		["dataSource"] = self._cluster,
		["database"] = self._database,
		["collection"] = self._collection,
		["pipeline"] = Pipeline,
	}

	local response = RongoRequest(url .. ENDPOINTS.POST.Aggregate,authHeaders, bodyData)
	if not response then return end

	return response
end

return Rongo
