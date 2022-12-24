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
local FileUtils = require 'FileUtils'
local LrProgressScope = import 'LrProgressScope'
local LrExportSession = import 'LrExportSession'

-- Create the logger and enable the print function.
local myLogger = LrLogger( 'exportLogger' )
myLogger:enable( "print" ) -- Pass either a string or a table of actions.

--------------------------------------------------------------------------------
-- Write trace information to the logger.
local function outputToLog( message )
	myLogger:trace( message )
end

SizeRemoved = 0
SizeAdded = 0
OutputMessage = ''
DebugMessage = ''
DebugMode = true
local function addDebugMessage ( message )
	DebugMessage = DebugMessage .. message .. ', '
	myLogger:trace(message)
end

NumRawsRemoved = 0
NumJPGsRemoved = 0
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

		--account for total file of added jpegs
		local fileSize = newPhoto:getRawMetadata('fileSize')
		SizeAdded = SizeAdded + fileSize

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

local function isPhotoRawFile(photo)
	rawEndings = {'RAF', 'NEF', 'NRW', 'CRW', 'CR2', 'CR3', 'GPR', 'RAW', 'RWL', 'DNG'}
	local fileType = photo:getRawMetadata( 'fileFormat' )

	for _, ending in ipairs(rawEndings) do
		if (fileType == ending) then
			addDebugMessage('found raw file: ' .. getPhotoName(photo))
			return true
		end
	end

	addDebugMessage('not a raw file: ' .. getPhotoName(photo))
	return false
end

local function isPhotoJPEG(photo)
	local fileType = photo:getRawMetadata( 'fileFormat' )
	jpegEndings = {'JPG', 'jpg', 'JPEG', 'jpeg'}
	for _, ending in ipairs(jpegEndings) do
		if (fileType == ending) then
			addDebugMessage('found jpeg file: ' .. getPhotoName(photo))
			return true
		end
	end
end

local function isPhotoRejected(photo)
	local pickStatus = photo:getRawMetadata('pickStatus')
	local rejected = -1

	if (pickStatus == rejected) then
		return true
	end

	return false
end

local function isPhotoPicked(photo)
	local pickStatus = photo:getRawMetadata('pickStatus')
	local picked = 1

	if (pickStatus == picked) then
		return true
	end

	return false
end


local function getRawVersionFromCatalogue(photo, catalog)
	local oldPath = photo:getRawMetadata('path')
	local fileEnding = "." .. FileUtils.getFileEnding(oldPath)

	for i, ending in ipairs({'.RAF', '.NEF', '.NRW', '.CRW', '.CR2', '.CR3', '.GPR', 'RAW', '.RWL', '.DNG'}) do
		local newFileName = oldPath:gsub(fileEnding, ending)
		local newPhoto = catalog:findPhotoByPath(newFileName, false)
		if newPhoto ~= nil then
			return newPhoto
		end
	end
	return nil
end

local function getJpegVersionFromCatalogue(rawPhoto, catalog)
	local oldPath = rawPhoto:getRawMetadata('path')
	local fileEnding = "." .. FileUtils.getFileEnding(oldPath)

	for i, ending in ipairs({'.JPG', '.jpg', '.jpeg', '.JPEG'}) do
		local newFileName = oldPath:gsub(fileEnding, ending)
		local photo = catalog:findPhotoByPath(newFileName, false)
		if photo ~= nil then
			return photo
		end
	end
	return nil
end

local function getRatingOfPhoto(photo)
	local rating = photo:getFormattedMetadata( 'rating' )
	if (rating == nil) then
		return -1
	end

	return rating
end

local function setRatingOfPhoto(photo, catalog, rating)
	local processedRating = rating
	if (rating == -1) then
		processedRating = nil
	end

	catalog:withWriteAccessDo("RatePicture", function (context)
		photo:setRawMetadata( 'rating', processedRating )
	end)
end

local function setPhotoPicked(photo, catalog, picked)
	catalog:withWriteAccessDo("RatePicture", function (context)
		photo:setRawMetadata( 'pickStatus', picked )
	end)
end

local function shouldSaveJPGSpace(photo, catalog)
	local correspondingRawPhoto = getRawVersionFromCatalogue(photo, catalog)

	--if there is no corresponding raw photo, keep Jpeg file
	if correspondingRawPhoto == nil then
		addDebugMessage('found no corresponding raw file for ' .. getPhotoName(photo))
		return false
	end

	--if this photo has high rating or is picked
	local jpegRating = photo:getFormattedMetadata('rating')
	if (jpegRating ~= nil and jpegRating >= 4) then
		return false
	end

	if isPhotoPicked(photo) then
		return false
	end

	--otherwise check for the rating of the raw
	local rawRating = correspondingRawPhoto:getFormattedMetadata( 'rating' )
	if (rawRating ~= nil and rawRating >= 4) then
		addDebugMessage('found high rated corresponding raw file: ' .. getPhotoName(correspondingRawPhoto))
		return true
	end

--[[
	-- remove jpeg if raw is rejected and jpeg is not marked as pick or 4+ stars
	-- (if the latter is the case, we have already bailed)
	if (isPhotoRejected(correspondingRawPhoto)) then
		return true
	end
]]

	return false
end

local function shouldSaveRawSpace(photo, catalog)
	--if rating is higher than four, then keep
	local rating = photo:getFormattedMetadata( 'rating' )
	if (rating ~= nil and rating >= 4) then
		addDebugMessage('found high rated raw file: ' .. getPhotoName(photo))
		return false
	end

	--if already rejected, we should skip
	local pickStatus = photo:getRawMetadata('pickStatus')
	if (pickStatus == -1 or pickStatus == 1) then
		--if photo is picked, we want to keep the raw file as is
		--if photo is rejected, we don't want to add the jpeg getJpegSidecar
		addDebugMessage('Skipping file with pickStatus: ' .. tostring(pickStatus) .. ': ' .. getPhotoName(photo))
		return false
	end

	local correspondingJpegPhoto = getJpegVersionFromCatalogue(photo, catalog)
	if (correspondingJpegPhoto ~= nil) then
		local jpegRating = getRatingOfPhoto(correspondingJpegPhoto)
		local jpegPicked = isPhotoPicked(correspondingJpegPhoto)

		if (jpegRating >= 4 or jpegPicked) then
			setRatingOfPhoto(photo, catalog, jpegRating)
			addDebugMessage("Setting corresponding rating of jpeg file to raw photo:" .. tostring(jpegRating))
			setPhotoPicked(photo, catalog, jpegPicked)
			addDebugMessage("Setting corresponding picked status")
			return false
		end
	end

	addDebugMessage('will save space with photo: ' .. getPhotoName(photo))
	return true
end

local function shouldSaveSpace(photo, catalog)
	if (isPhotoRawFile(photo)) then
		return shouldSaveRawSpace(photo, catalog)
	end

	if (isPhotoJPEG(photo)) then
		return shouldSaveJPGSpace(photo, catalog)
	end

	return false
end

local function getJpegSidecar(rawPhoto)
	local oldPath = rawPhoto:getRawMetadata( 'path' )
	local fileEnding = "." .. FileUtils.getFileEnding(oldPath)

	for i, ending in ipairs({'.JPG', '.jpg', '.jpeg', '.JPEG'}) do
		local newFileName = oldPath:gsub(fileEnding, ending)
		local status = LrFileUtils.exists(newFileName)
		if (status == 'file') then
			addDebugMessage('found corresponding jpeg: ' .. newFileName)
			return newFileName
		end
	end
	return nil
end

local function exportNewJpegFromRaw(rawPhoto)
	local params = {}
    params.LR_collisionHandling = 'rename'
    params.LR_export_bitDepth = 16
    params.LR_export_destinationType = "sourceFolder"
    params.LR_export_useSubfolder = false
    params.LR_extensionCase = "lowercase"
    params.LR_format = "JPEG"
    params.LR_initialSequenceNumber = 1
    params.LR_jpeg_limitSize = 100
    params.LR_jpeg_quality = 1
    params.LR_jpeg_useLimitSize = false
    params.LR_metadata_keywordOptions = "lightroomHierarchical"
    params.LR_minimizeEmbeddedMetadata = false
    params.LR_outputSharpeningLevel = 2
    params.LR_outputSharpeningMedia = "screen"
    params.LR_outputSharpeningOn = false
    params.LR_reimportExportedPhoto = false
    params.LR_reimport_stackWithOriginal = false
    params.LR_reimport_stackWithOriginal_position = "below"
    params.LR_renamingTokensOn = true
    params.LR_size_doConstrain = false
    params.LR_size_resolution = 240
    params.LR_size_resolutionUnits = "inch"
    params.LR_tokenCustomString = ""

	local exportSession = LrExportSession{
		exportSettings = params, 
		photosToExport = { rawPhoto } ,
	}

	exportSession:doExportOnCurrentTask()

	for i, rendition in exportSession:renditions() do
		status, pathOrMessage = rendition:waitForRender()
		addDebugMessage('status from render: ' .. tostring(status))
		if status then 
			addDebugMessage('path of render: ' .. rendition.destinationPath)
			return rendition.destinationPath
		end
	end
end

local function getNewJpegFile(photo)
	local jpegSidecarName = getJpegSidecar(photo)
	if jpegSidecarName then
		local newJpegFile = LrFileUtils.chooseUniqueFileName(jpegSidecarName)
		local status = LrFileUtils.move(jpegSidecarName, newJpegFile)
		if status then
			return newJpegFile
		end
	end
	addDebugMessage('found no corresponding jpeg sidecar for: ' .. getPhotoName(photo))

	addDebugMessage('will export jpeg from Raw instead.')
	local jpegPhoto = exportNewJpegFromRaw(photo)
	if (jpegPhoto) then
		addDebugMessage('Created jpeg from Raw. New jpeg: ' .. jpegPhoto)
		return jpegPhoto
	end

	return nil
end

local function deletePhoto(photo, catalog)
	catalog:withWriteAccessDo("RejectPicture", function (context)
		photo:setRawMetadata( 'pickStatus', -1)
	end)

	local fileSize = photo:getRawMetadata('fileSize')
	SizeRemoved = SizeRemoved + fileSize

	if isPhotoRawFile(photo) then
		NumRawsRemoved = NumRawsRemoved + 1
	elseif isPhotoJPEG(photo) then
		NumJPGsRemoved = NumJPGsRemoved + 1
	end
end

local function jpegVersionIsInCatalogue(rawPhoto, catalog)
	local file = getJpegVersionFromCatalogue(rawPhoto, catalog)
	if (file ~= nil) then
		return true
	end
	return false
end

local function saveJPGSpace(photo, catalog)
	deletePhoto(photo, catalog)
end

local function saveRawSpace(photo, catalog)
	local containingCollections = photo:getContainedCollections()
	addDebugMessage('found ' .. #containingCollections .. ' collections containing ' .. getPhotoName(photo))

	if (jpegVersionIsInCatalogue(photo, catalog)) then
		addDebugMessage('found Jpeg version of ' .. getPhotoName(photo) .. ' already in collection')
		deletePhoto(photo, catalog)
		return
	end

	local jpegFilePath = getNewJpegFile(photo)
	if (jpegFilePath ~= nil) then
		local additionStatus = addPhoto(jpegFilePath, catalog, containingCollections)
		if additionStatus then
			--only delete stuff if we actually succeeded in adding the smaller version
			deletePhoto(photo, catalog)
		end
	end
end

local function saveSpace(photo, catalog)
	if (isPhotoRawFile(photo)) then
		return saveRawSpace(photo, catalog)
	end

	if (isPhotoJPEG(photo)) then
		return saveJPGSpace(photo, catalog)
	end
end

local function getFormattedSavedSize()
	local savedBytes = SizeRemoved - SizeAdded
	return FileUtils.formatFileSize(savedBytes)
end

local function startSpaceSaver()
	outputToLog( "MyHWExportItem.saveSpace function entered." )
	local activeCatalog = LrApplication.activeCatalog()
	local allVisiblePhotos = getVisiblePhotos(activeCatalog)
	local progressScope = LrProgressScope({ title = "Saving Space"})

	progressScope:setPortionComplete(0, #allVisiblePhotos)

	for i, photo in ipairs(allVisiblePhotos) do
		NumProcessedPhotos = NumProcessedPhotos + 1
		if (shouldSaveSpace(photo, activeCatalog)) then
			addDebugMessage('saving space with photo: ' .. getPhotoName(photo))
			saveSpace(photo, activeCatalog)
		end
		progressScope:setPortionComplete(i, #allVisiblePhotos)
	end
	progressScope:done()

	OutputMessage = 'Went through ' .. NumProcessedPhotos .. ' photos and removed ' .. NumRawsRemoved .. ' raw files and ' .. NumJPGsRemoved .. ' jpgs, saving ' .. getFormattedSavedSize() .. '.'
	LrDialogs.message( "All done", OutputMessage, "info" )

	addDebugMessage('size added: ' .. FileUtils.formatFileSize(SizeAdded) .. ', size raws: ' .. FileUtils.formatFileSize(SizeRemoved))

	if DebugMode then
		LrDialogs.message( "DebugMessages", DebugMessage, "info" )
	end
	outputToLog( "MyHWExportItem.saveSpace function exiting." )
end

-- Display a dialog.
import 'LrTasks'.startAsyncTask(startSpaceSaver)
