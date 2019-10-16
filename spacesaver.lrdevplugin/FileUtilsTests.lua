lu = require('luaunit')

FileUtils = require('FileUtils')

function testFileNameThreeLetters()
    local filePath = "fileName.txt"
    local expected = "fileName"
    lu.assertEquals(FileUtils.fileNameWithoutEnding(filePath), expected)
end

function testFileNameFourLetters()
    local filePath = "fileName.text"
    local expected = "fileName"
    lu.assertEquals(FileUtils.fileNameWithoutEnding(filePath), expected)
end

function testFileNameFromPath()
    local filePath = "bla/bla/bla/fileName.text"
    local expected = "fileName"
    lu.assertEquals(FileUtils.fileNameWithoutEnding(filePath), expected)
end

function testFileNameFromWindowsPath()
    local filePath = "bla\\bla\\bla\\fileName.text"
    local expected = "fileName"
    lu.assertEquals(FileUtils.fileNameWithoutEnding(filePath), expected)
end

function testFileEndingFourLetters()
    local filePath = "fileName.text"
    local expected = "text"
    lu.assertEquals(FileUtils.getFileEnding(filePath), expected)

end

function testFileEndingThreeLetters()
    local filePath = "fileName.txt"
    local expected = "txt"
    lu.assertEquals(FileUtils.getFileEnding(filePath), expected)
end

function testFileEndingFromPath()
    local filePath = "bla/bla/bla/fileName.text"
    local expected = "text"
    lu.assertEquals(FileUtils.getFileEnding(filePath), expected)
end

function testFileEndingFromWindowsPath()
    local filePath = "bla\\bla\\bla\\fileName.text"
    local expected = "text"
    lu.assertEquals(FileUtils.getFileEnding(filePath), expected)
end

function testFormatFileSizeMegaByte()
    local fileSize = 6100000
    local expected = "6.1MB"
    lu.assertEquals(FileUtils.formatFileSize(fileSize), expected)
end

function testFormatFileSizeGigabyte()
    local fileSize = 6100000000
    local expected = "6.1GB"
    lu.assertEquals(FileUtils.formatFileSize(fileSize), expected)
end

function testFormatFileSizeGigabyte()
    local fileSize = 0
    local expected = "0B"
    lu.assertEquals(FileUtils.formatFileSize(fileSize), expected)
end



os.exit( lu.LuaUnit.run())
