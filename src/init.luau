--[[

	Rongo - MongoDB Atlas API Wrapper for Roblox
	
	Rongo gives developers easy access to MongoDB Atlas web 
	APIs so they're able to use Atlas databases directly in 
	their games.
	
	Rongo is a bare-bones module, meaning it contains only
	the essentials, which can be used standalone or to
	develop modules which use Rongo at its core. 
	
	Some modules which use Rongo can be found on the Rongo
	DevForum post!
	
	Rongo uses the Atlas Data API, which is disabled by
	default, so you must enable it in your Atlas settings.
	
	Version: 1.1.0
	License: MIT License
	Contributors:
		- Starnamics (Creator)
		- Midnightific (Contributor)
	Documentation: As per function.

--]]

--// Initialization

local HttpService = game:GetService("HttpService")

local APIVersion: string = "v1"
local URI: string = "https://data.mongodb-api.com/app/%s/endpoint/data/"..APIVersion

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
	}
}

local Rongo = {}

local RongoClient = {}
RongoClient.__index = RongoClient

local RongoCluster = {}
RongoCluster.__index = RongoCluster

local RongoDatabase = {}
RongoDatabase.__index = RongoDatabase

local RongoCollection = {}
RongoCollection.__index = RongoCollection

local RongoDocument = {}
RongoDocument.__index = RongoDocument

--// Function

--- Creates a new instance of the Rongo client.
---@param AppId string The application ID.
---@param Key string The client key.
---@return table The new Rongo client instance.
function Rongo.new(AppId: string, Key: string)
	local Client = {}
	setmetatable(Client, RongoClient)
	
	Client["AppId"] = AppId
	Client["Key"] = Key
	
	return Client
end

--- Sets the version of the Rongo client.
---@param Version string The version to set. Must be either "v1" or "beta".
function RongoClient:SetVersion(Version: "v1" | "beta")
	URI = "https://data.mongodb-api.com/app/%s/endpoint/data/"..Version
end

--- Creates a new Rongo cluster with the specified name.
---@param Name The name of the cluster.
---@return The newly created Rongo cluster.
function RongoClient:GetCluster(Name: string)
	local Cluster = {}
	setmetatable(Cluster, RongoCluster)
	
	Cluster["Client"] = self
	Cluster["Name"] = Name
	
	return Cluster
end

--- Creates a new database object within the Rongo cluster.
---@param Name The name of the database.
---@return Database The newly created database object.
function RongoCluster:GetDatabase(Name: string)
	local Database = {}
	setmetatable(Database, RongoDatabase)
	
	Database["Client"] = self["Client"]
	Database["Cluster"] = self
	Database["Name"] = Name
	
	return Database
end

--- Retrieves a collection from the Rongo database.
---@param Name The name of the collection to retrieve.
---@return The retrieved collection.
function RongoDatabase:GetCollection(Name: string)
	local Collection = {}
	setmetatable(Collection, RongoCollection)
	
	Collection["Client"] = self["Client"]
	Collection["Cluster"] = self["Cluster"]
	Collection["Database"] = self
	Collection["Name"] = Name
	
	return Collection
end

--- Finds and returns a single document from the collection that matches the specified filter.
--- If no filter is provided, it returns the first document found in the collection.
---@param Filter table | nil The filter to apply when searching for the document.
---@return table | nil The found document, or nil if no document matches the filter.
function RongoCollection:FindOne(Filter: {[string]: string | {[string]: string}}?): {[string]: any?}?
	local RequestData = {
		["dataSource"] = self["Cluster"]["Name"],
		["database"] = self["Database"]["Name"],
		["collection"] = self["Name"],
		["filter"] = Filter or nil,
	}
	local RequestHeaders = {
		["Access-Control-Request-Headers"] = "*",
		["api-key"] = self["Client"]["Key"]
	}
	RequestData = HttpService:JSONEncode(RequestData)
	local Success: boolean, Response = pcall(function()
		return HttpService:PostAsync(string.format(URI, self["Client"]["AppId"])..ENDPOINTS.POST.FindOne, RequestData, Enum.HttpContentType.ApplicationJson, false, RequestHeaders) 
	end)

	if not Success then 
		warn("[RONGO] Request Failed:", Response)
		return 
	end

	Response = HttpService:JSONDecode(Response)
	if not Response["document"] then return nil end

	return Response["document"]
end

--- Finds multiple documents in the Rongo collection based on the specified filter, limit, sort, and skip parameters.
--- If no filter is provided, all documents in the collection will be returned.
--- If no limit is provided, all matching documents will be returned.
--- If no sort is provided, the documents will be returned in the order they were inserted.
--- If no skip is provided, no documents will be skipped.
---@param Filter table | nil The filter to apply to the documents. It can be a table of key-value pairs or nested tables of key-value pairs.
---@param Limit number | nil The maximum number of documents to return.
---@param Sort table | nil The sorting criteria for the documents. It can be a table of values to sort by.
---@param Skip number | nil The number of documents to skip before returning the results.
---@return table | nil An array of documents that match the specified filter, limit, sort, and skip parameters. Returns nil if the request fails or no documents are found.
function RongoCollection:FindMany(Filter: {[string]: string | {[string]: string}}?, Limit: number?, Sort: {any?}?, Skip: number?): {[number]: {[string]: any?}}?
	local RequestData = {
		["dataSource"] = self["Cluster"]["Name"],
		["database"] = self["Database"]["Name"],
		["collection"] = self["Name"],
		["filter"] = Filter or nil,
		["limit"] = Limit or nil,
		["sort"] = Sort or nil,
		["skip"] = Skip or nil,
	}

	local RequestHeaders = {
		["Access-Control-Request-Headers"] = "*",
		["api-key"] = self["Client"]["Key"]
	}

	RequestData = HttpService:JSONEncode(RequestData)

	local Success: boolean, Response = pcall(function() 
		return HttpService:PostAsync(string.format(URI, self["Client"]["AppId"])..ENDPOINTS.POST.FindMany, RequestData, Enum.HttpContentType.ApplicationJson, false, RequestHeaders) 
	end)

	if not Success then 
		warn("[RONGO] Request Failed:", Response) 
		return 
	end

	Response = HttpService:JSONDecode(Response)
	if not Response["documents"] then return nil end

	return Response["documents"]
end

--- Inserts a single document into the collection.
---@param Document table: The document to be inserted.
---@return string | nil: The inserted document's ID, or nil if the insertion failed.
function RongoCollection:InsertOne(Document: {[string]: any?}): string?
	if not Document then
		warn("[RONGO] Document argument cannot be empty") 
		return nil
	end

	local RequestData = {
		["dataSource"] = self["Cluster"]["Name"],
		["database"] = self["Database"]["Name"],
		["collection"] = self["Name"],
		["document"] = Document,
	}

	local RequestHeaders = {
		["Access-Control-Request-Headers"] = "*",
		["api-key"] = self["Client"]["Key"]
	}

	RequestData = HttpService:JSONEncode(RequestData)

	local Success: boolean, Response = pcall(function() 
		return HttpService:PostAsync(string.format(URI, self["Client"]["AppId"])..ENDPOINTS.POST.InsertOne, RequestData, Enum.HttpContentType.ApplicationJson, false, RequestHeaders) 
	end)

	if not Success then 
		warn("[RONGO] Request Failed:", Response) 
		return 
	end

	Response = HttpService:JSONDecode(Response)

	if not Response["insertedId"] then 
		return nil 
	end

	return Response["insertedId"]
end

--- Inserts multiple documents into the collection.
---@param Documents table: A table containing multiple documents to be inserted.
--- Each document should be a table with string keys and any values.
---@return table | nil: A table containing the inserted IDs if successful, or nil if the request failed.
function RongoCollection:InsertMany(Documents: {[number]: {[string]: any?}}): {[number]: string}?
	if not Documents then 
		warn("[RONGO] Documents argument cannot be empty") 
		return nil 
	end

	local RequestData = {
		["dataSource"] = self["Cluster"]["Name"],
		["database"] = self["Database"]["Name"],
		["collection"] = self["Name"],
		["documents"] = Documents,
	}

	local RequestHeaders = {
		["Access-Control-Request-Headers"] = "*",
		["api-key"] = self["Client"]["Key"]
	}

	RequestData = HttpService:JSONEncode(RequestData)

	local Success: boolean, Response = pcall(function() 
		return HttpService:PostAsync(string.format(URI, self["Client"]["AppId"])..ENDPOINTS.POST.InsertMany, RequestData, Enum.HttpContentType.ApplicationJson, false, RequestHeaders) 
	end)

	if not Success then 
		warn("[RONGO] Request Failed:", Response) 
		return 
	end

	Response = HttpService:JSONDecode(Response)

	if not Response["insertedIds"] then 
		return nil 
	end

	return Response["insertedIds"]
end

--- Updates a single document in the collection that matches the specified filter.
---@param Filter string The filter expression used to select the document to update.
---@param Update table The update operation to apply to the selected document.
---@param Upsert boolean (optional) If true, creates a new document if no document matches the filter.
---@return table | nil A table containing the number of matched documents, modified documents, and the upserted ID if applicable. Returns nil if the update operation fails.
function RongoCollection:UpdateOne(Filter: string, Update: {[string]: any?}, Upsert: boolean?): {["matchedCount"]: number, ["modifiedCount"]: number, ["upsertedId"]: string?}?
	if not Filter then 
		warn("[RONGO] Filter argument cannot be empty")
		return nil 
	end

	if not Update then 
		warn("[RONGO] Update argument cannot be empty")
		return nil 
	end

	local RequestData = {
		["dataSource"] = self["Cluster"]["Name"],
		["database"] = self["Database"]["Name"],
		["collection"] = self["Name"],
		["filter"] = Filter or nil,
		["update"] = Update or nil,
		["upsert"] = Upsert or nil,
	}

	local RequestHeaders = {
		["Access-Control-Request-Headers"] = "*",
		["api-key"] = self["Client"]["Key"]
	}

	RequestData = HttpService:JSONEncode(RequestData)

	local Success: boolean, Response = pcall(function()
		return HttpService:PostAsync(string.format(URI, self["Client"]["AppId"])..ENDPOINTS.POST.UpdateOne, RequestData, Enum.HttpContentType.ApplicationJson, false, RequestHeaders) 
	end)

	if not Success then 
		warn("[RONGO] Request Failed:", Response) 
		return 
	end

	Response = HttpService:JSONDecode(Response)
	
	return Response
end

--- Updates multiple documents in the collection that match the specified filter.
---@param Filter string The filter expression to match documents.
---@param Update table The update operation to apply to the matched documents.
---@param Upsert boolean (optional) Whether to perform an upsert operation if no documents match the filter.
---@return table | nil A table containing the number of matched documents, modified documents, and the upserted ID (if upsert is true), or nil if the request fails.
function RongoCollection:UpdateMany(Filter: string, Update: {[string]: any?}, Upsert: boolean?): {["matchedCount"]: number, ["modifiedCount"]: number, ["upsertedId"]: string?}?
	if not Filter then 
		warn("[RONGO] Filter argument cannot be empty") 
		return nil 
	end

	if not Update then 
		warn("[RONGO] Update argument cannot be empty") 
		return nil 
	end

	local RequestData = {
		["dataSource"] = self["Cluster"]["Name"],
		["database"] = self["Database"]["Name"],
		["collection"] = self["Name"],
		["filter"] = Filter or nil,
		["update"] = Update or nil,
		["upsert"] = Upsert or nil,
	}

	local RequestHeaders = {
		["Access-Control-Request-Headers"] = "*",
		["api-key"] = self["Client"]["Key"]
	}

	RequestData = HttpService:JSONEncode(RequestData)

	local Success: boolean, Response = pcall(function() 
		return HttpService:PostAsync(string.format(URI, self["Client"]["AppId"])..ENDPOINTS.POST.UpdateMany, RequestData, Enum.HttpContentType.ApplicationJson, false, RequestHeaders) 
	end)

	if not Success then 
		warn("[RONGO] Request Failed:", Response) 
		return 
	end

	Response = HttpService:JSONDecode(Response)

	return Response
end

--- Replaces a single document in the collection that matches the specified filter.
---@param Filter string The filter expression to match documents.
---@param Replacement table The replacement document.
---@param Upsert boolean (optional) Whether to perform an upsert if no matching document is found.
---@return table | nil A table containing the number of matched documents, modified documents, and the upserted ID, or nil if the request fails.
function RongoCollection:ReplaceOne(Filter: string, Replacement: any, Upsert: boolean?)
	if not Filter then 
		warn("[RONGO] Filter argument cannot be empty") 
		return nil 
	end

	if not Replacement then 
		warn("[RONGO] Update argument cannot be empty") 
		return nil 
	end

	local RequestData = {
		["dataSource"] = self["Cluster"]["Name"],
		["database"] = self["Database"]["Name"],
		["collection"] = self["Name"],
		["filter"] = Filter or nil,
		["replacement"] = Replacement,
		["upsert"] = Upsert
	}

	local RequestHeaders = {
		["Access-Control-Request-Headers"] = "*",
		["api-key"] = self["Client"]["Key"]
	}

	RequestData = HttpService:JSONEncode(RequestData)

	local Success, Response = pcall(function() 
		return HttpService:PostAsync(string.format(URI, self["Client"]["AppId"])..ENDPOINTS.POST.ReplaceOne, RequestData, Enum.HttpContentType.ApplicationJson, false, RequestHeaders) 
	end)

	if not Success then 
		warn("[RONGO] Request Failed:", Response)
		return
	end

	Response = HttpService:JSONDecode(Response)

	return Response
end

--- Deletes a single document from the collection that matches the specified filter.
---@param Filter string The filter expression used to match the document to be deleted.
---@return number|nil The number of documents deleted, or nil if the request fails.
function RongoCollection:DeleteOne(Filter: string): number?
	if not Filter then 
		warn("[RONGO] Filter argument cannot be empty") 
		return nil 
	end

	local RequestData = {
		["dataSource"] = self["Cluster"]["Name"],
		["database"] = self["Database"]["Name"],
		["collection"] = self["Name"],
		["filter"] = Filter or nil,
	}

	local RequestHeaders = {
		["Access-Control-Request-Headers"] = "*",
		["api-key"] = self["Client"]["Key"]
	}

	RequestData = HttpService:JSONEncode(RequestData)

	local Success: boolean, Response = pcall(function()
		return HttpService:PostAsync(string.format(URI, self["Client"]["AppId"])..ENDPOINTS.POST.DeleteOne, RequestData, Enum.HttpContentType.ApplicationJson, false, RequestHeaders) 
	end)

	if not Success then 
		warn("[RONGO] Request Failed:", Response) 
		return 
	end

	Response = HttpService:JSONDecode(Response)

	if not Response["deletedCount"] then 
		return 0 
	end

	return Response["deletedCount"]
end

--- Deletes multiple documents from the collection based on the specified filter.
---@param Filter string The filter expression used to select the documents to delete.
---@return number|nil The number of documents deleted, or nil if the filter argument is empty or the request fails.
function RongoCollection:DeleteMany(Filter: string): number?
	if not Filter then 
		warn("[RONGO] Filter argument cannot be empty") 
		return nil 
	end

	local RequestData = {
		["dataSource"] = self["Cluster"]["Name"],
		["database"] = self["Database"]["Name"],
		["collection"] = self["Name"],
		["filter"] = Filter or nil,
	}

	local RequestHeaders = {
		["Access-Control-Request-Headers"] = "*",
		["api-key"] = self["Client"]["Key"]
	}

	RequestData = HttpService:JSONEncode(RequestData)

	local Success: boolean, Response = pcall(function() 
		return HttpService:PostAsync(string.format(URI, self["Client"]["AppId"])..ENDPOINTS.POST.DeleteMany, RequestData, Enum.HttpContentType.ApplicationJson, false, RequestHeaders) 
	end)

	if not Success then 
		warn("[RONGO] Request Failed:", Response) 
		return 
	end

	Response = HttpService:JSONDecode(Response)

	if not Response["deletedCount"] then 
		return 0 
	end

	return Response["deletedCount"]
end

return Rongo
