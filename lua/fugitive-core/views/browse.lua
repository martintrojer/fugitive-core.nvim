local M = {}

--- Parse a git remote URL into host, owner, repo, and web_base.
--- Supports: git@host:owner/repo(.git), ssh://git@host/owner/repo(.git), http(s)://host/owner/repo(.git)
function M.parse_remote_url(url)
  if not url or url == "" then
    return nil, "Empty remote URL"
  end

  local patterns = {
    { "^git@([^:]+):([^/]+)/(.+)$", nil },
    { "^ssh://git@([^/]+)/([^/]+)/(.-)/?$", nil },
    { "^(https?)://([^/]+)/([^/]+)/([^/]+)$", true },
  }

  for _, pat in ipairs(patterns) do
    local captures = { url:match(pat[1]) }
    if #captures > 0 then
      local host, owner, repo, scheme
      if pat[2] then
        scheme, host, owner, repo = captures[1], captures[2], captures[3], captures[4]
      else
        host, owner, repo = captures[1], captures[2], captures[3]
      end
      repo = repo:gsub("%.git$", ""):gsub("/$", "")
      local base = scheme and string.format("%s://%s/%s/%s", scheme, host, owner, repo)
        or string.format("https://%s/%s/%s", host, owner, repo)
      return { host = host, owner = owner, repo = repo, web_base = base }
    end
  end

  return nil, "Unsupported or unrecognized remote URL: " .. url
end

--- Try to build a URL from configured custom forges.
--- Forges are configured in setup({ forges = { { match = "pattern", url = "...{path}...{lines}" }, ... } })
--- URL template placeholders: {path}, {rev}, {lines}
--- Returns url or nil if no forge matched.
function M.build_custom_file_url(remote_url, path, line_start, line_end)
  local forges = require("fugitive-core").config.forges
  if not forges then
    return nil
  end

  for _, forge in ipairs(forges) do
    if remote_url:match(forge.match) then
      local encoded_path = path:gsub(" ", "%%20")
      local url = forge.url:gsub("{path}", encoded_path)
      url = url:gsub("{rev}", "")

      if line_start and url:match("{lines}") then
        local lines = tostring(line_start)
        if line_end and line_end ~= line_start then
          lines = lines .. "-" .. line_end
        end
        url = url:gsub("{lines}", lines)
      else
        -- Remove lines placeholder and any preceding ? or &
        url = url:gsub("[%?&]lines={lines}", "")
        url = url:gsub("{lines}", "")
      end

      return url
    end
  end

  return nil
end

--- Build a web URL for a file on GitHub/GitLab-style forges.
function M.build_file_url(remote, path, rev, line_start, line_end)
  if not remote or not remote.web_base or not path or not rev then
    return nil, "Missing parameters to build file URL"
  end

  local encoded_path = path:gsub(" ", "%%20")
  local url

  if remote.host:match("gitlab%.com$") then
    url = string.format("%s/-/blob/%s/%s", remote.web_base, rev, encoded_path)
    if line_start and line_end and line_start ~= line_end then
      url = string.format("%s#L%d-%d", url, line_start, line_end)
    elseif line_start then
      url = string.format("%s#L%d", url, line_start)
    end
    return url
  end

  url = string.format("%s/blob/%s/%s", remote.web_base, rev, encoded_path)
  if line_start and line_end and line_start ~= line_end then
    url = string.format("%s#L%d-L%d", url, line_start, line_end)
  elseif line_start then
    url = string.format("%s#L%d", url, line_start)
  end
  return url
end

--- Build a web URL for a commit on GitHub/GitLab-style forges.
function M.build_commit_url(remote, rev)
  if not remote or not remote.web_base or not rev then
    return nil, "Missing parameters to build commit URL"
  end

  if remote.host:match("gitlab%.com$") then
    return string.format("%s/-/commit/%s", remote.web_base, rev)
  end
  return string.format("%s/commit/%s", remote.web_base, rev)
end

--- Open a URL in the default browser.
function M.open_url(url)
  if not url then
    return false
  end
  vim.ui.open(url)
  return true
end

--- Get current visual selection or cursor line range.
--- Returns start_line, end_line (end_line is nil for single line).
function M.line_range()
  local mode = vim.fn.mode()

  if mode:match("^[vV\22]") then
    local s = vim.fn.getpos("v")[2]
    local e = vim.fn.getpos(".")[2]
    return math.min(s, e), math.max(s, e)
  end

  return vim.fn.line("."), nil
end

return M
