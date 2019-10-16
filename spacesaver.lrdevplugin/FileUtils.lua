local FileUtils = {}

function FileUtils.getFileEnding(path)
    local fileEnding = string.match(path, "%..*")
    --return fileEnding without the dot
    return fileEnding:sub(2, -1)
end

function FileUtils.fileNameWithoutEnding(path)
    local fileEnding = '.' .. FileUtils.getFileEnding(path)
    local withoutEnding = path:gsub(fileEnding, "")

    --local sep = package.config:sub(1,1)
    local sep = '[/\\]'

    if (withoutEnding:find(sep) == nil) then
        -- this is just the leaf name, we can exit here
        return withoutEnding
    end

    --try to remove everything after the last path separator
    local res = string.match(withoutEnding, ".*" .. sep .. "(.*)")

    return res
end

return FileUtils