local codeFormat  = require 'code_format'
local ws          = require 'workspace'
local furi        = require 'file-uri'
local fs          = require 'bee.filesystem'
local fw          = require 'filewatch'
local util        = require 'utility'
local diagnostics = require 'provider.diagnostic'

local loadedUris = {}

local updateType = {
    Created = 1,
    Changed = 2,
    Deleted = 3,
}

fw.event(function (ev, path)
    if util.stringEndWith(path, '.editorconfig') then
        for uri, fsPath in pairs(loadedUris) do
            loadedUris[uri] = nil
            if fsPath ~= true then
                local status, err = codeFormat.update_config(updateType.Deleted, uri, fsPath:string())
                if not status and err then
                    log.error(err)
                end
            end
        end
        for _, scp in ipairs(ws.folders) do
            diagnostics.diagnosticsScope(scp.uri)
        end
    end
end)

local m = {}

---@param uri uri
function m.updateConfig(uri)
    local currentUri = uri
    while true do
        currentUri = currentUri:match('^(.+)/[^/]*$')
        if not currentUri or loadedUris[currentUri] then
            return
        end
        loadedUris[currentUri] = true

        local currentPath        = furi.decode(currentUri)
        local editorConfigFSPath = fs.path(currentPath) / '.editorconfig'
        if fs.exists(editorConfigFSPath) then
            loadedUris[uri] = editorConfigFSPath
            local status, err = codeFormat.update_config(updateType.Created, currentUri, editorConfigFSPath:string())
            if not status and err then
                log.error(err)
            end
        end

        if not ws.rootUri then
            return
        end

        for _, scp in ipairs(ws.folders) do
            if scp.uri == currentUri then
                return
            end
        end
    end
end

return m
