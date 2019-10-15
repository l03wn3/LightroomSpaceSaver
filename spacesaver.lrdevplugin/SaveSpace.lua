--[[----------------------------------------------------------------------------

ADOBE SYSTEMS INCORPORATED
 Copyright 2007 Adobe Systems Incorporated
 All Rights Reserved.

NOTICE: Adobe permits you to use, modify, and distribute this file in accordance
with the terms of the Adobe license agreement accompanying it. If you have received
this file from a source other than Adobe, then your use, modification, or distribution
of it requires the prior written permission of Adobe.

--------------------------------------------------------------------------------

ExportMenuItem.lua
From the Hello World sample plug-in. Displays a modal dialog and writes debug info.

------------------------------------------------------------------------------]]

-- Access the Lightroom SDK namespaces.
local LrDialogs = import 'LrDialogs'
local LrLogger = import 'LrLogger'
local LrApplication = import 'LrApplication'
local LrFileUtils = import 'LrFileUtils'

-- Create the logger and enable the print function.
local myLogger = LrLogger( 'exportLogger' )
myLogger:enable( "print" ) -- Pass either a string or a table of actions.

--------------------------------------------------------------------------------
-- Write trace information to the logger.
local function outputToLog( message )
	myLogger:trace( message )
end

OutputMessage = ''
DebugMessage = ''
DebugMode = true
local function addDebugMessage ( message )
	DebugMessage = DebugMessage .. message .. ', '
end

NumRawsRemoved = 0
NumProcessedPhotos = 0

local function getPhotoName(photo)
	return photo:getFormattedMetadata('fileName')
end

local function addPhoto(photoToAdd, catalog, containingCollections)
	catalog:withWriteAccessDo("AddNewPicture", function (context)

		--add photo if it does not already exist
		local photoExists = catalog:findPhotoByPath(photoToAdd)
		local newPhoto
		if (photoExists == nil) then
			--photo does not exist in catalogue
			addDebugMessage('Trying to add photo to catalogue' .. photoToAdd)
			newPhoto = catalog:addPhoto(photoToAdd, nil, nil)
		else
			--photo already existed, no need to add
			addDebugMessage('photo already exists in catalogue: ' .. photoToAdd)
			newPhoto = photoExists
		end

		--add the new smaller photo to any collections the
		--large photos was present in
		for i, collection in ipairs(containingCollections) do
			collection:addPhotos({newPhoto})
		end
	end)
	return true
end

local function getVisiblePhotos(catalog)
	local selectedPhoto = catalog:getTargetPhoto()
	local selectedPhotos = catalog:getTargetPhotos()

	--If there is currently no selection
	if selectedPhoto == nil then
		selectedPhoto = selectedPhotos[1]
	end

	catalog:setSelectedPhotos(selectedPhoto, {})
	local allVisiblePhotos = catalog:getMultipleSelectedOrAllPhotos()

	--return selection to what user had before
	catalog:setSelectedPhotos(selectedPhoto, selectedPhotos)

	addDebugMessage('selected ' .. #allVisiblePhotos .. ' photos')
	return allVisiblePhotos
end

local function shouldSaveSpace(photo)
	-- if photo is not raw, then keep
	local fileType = photo:getRawMetadata( 'fileFormat' )

	if (fileType ~= 'RAW') then
		addDebugMessage('not a raw file: ' .. getPhotoName(photo))
		return false
	end

	--if rating is higher than four, then keep
	local rating = photo:getFormattedMetadata( 'rating' )
	if (rating ~= nil and rating >= 4) then
		addDebugMessage('found high rated raw file: ' .. getPhotoName(photo))
		return false
	end

	addDebugMessage('will save space with photo: ' .. getPhotoName(photo))
	return true
end

local function getJpegSidecar(photo)
	local oldPath = photo:getRawMetadata( 'path' )

	for i, ending in ipairs({'.JPG', '.jpg', '.jpeg', '.JPEG'}) do
		local newFileName = oldPath:gsub(".RAF", ending)
		local status = LrFileUtils.exists(newFileName)
		if (status == 'file') then
			addDebugMessage('found corresponding jpeg: ' .. newFileName)
			return newFileName
		end
	end
	addDebugMessage('found no corresponding jpeg for: ' .. getPhotoName(photo))
	return nil
end

local function deletePhoto(photo, catalog)
	catalog:withWriteAccessDo("RejectPicture", function (context)
		photo:setRawMetadata( 'pickStatus', -1)
	end)
	NumRawsRemoved = NumRawsRemoved + 1
end

local function saveSpace(photo, catalog)
	local jpegSidecarName = getJpegSidecar(photo)
	local containingCollections = photo:getContainedCollections()
	addDebugMessage('found ' .. #containingCollections .. ' collections containing ' .. getPhotoName(photo))

	if (jpegSidecarName ~= nil) then
		local additionSuccess = addPhoto(jpegSidecarName, catalog, containingCollections)
		if additionSuccess then
			--only delete stuff if we actually succeeded in adding the smaller version
			deletePhoto(photo, catalog)
		end
	end
end

local function startSpaceSaver()
	outputToLog( "MyHWExportItem.saveSpace function entered." )
	local activeCatalog = LrApplication.activeCatalog()
	local allVisiblePhotos = getVisiblePhotos(activeCatalog)

	for i, photo in ipairs(allVisiblePhotos) do
		NumProcessedPhotos = NumProcessedPhotos + 1
		if (shouldSaveSpace(photo)) then
			addDebugMessage('saving space with photo: ' .. getPhotoName(photo))
			saveSpace(photo, activeCatalog)
		end
	end

	OutputMessage = 'Went through ' .. NumProcessedPhotos .. ' photos and removed ' .. NumRawsRemoved .. ' raw files.'
	LrDialogs.message( "All done", OutputMessage, "info" )

	if DebugMode then
		LrDialogs.message( "DebugMessages", DebugMessage, "info" )
	end
	outputToLog( "MyHWExportItem.saveSpace function exiting." )
end

-- Display a dialog.
import 'LrTasks'.startAsyncTask(startSpaceSaver)