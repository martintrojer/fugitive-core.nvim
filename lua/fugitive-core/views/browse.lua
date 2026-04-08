local M = {}

--- Parse a git remote URL into host, owner, repo, and web_base.
--- Supports: git@host:owner/repo(.git), ssh://git@host/owner/repo(.git), http(s)://host/owner/repo(.git)
function M.parse_remote_url(url)
  if not url or url == "" then
    return nil, "Empty remote URL"
  end

  local patterns = {
    { "^git@([^:]+):([^/]+)/(.+)$", nil },
    { "^ssh://git@([^/]+)/([^/]+)/(.+?)/?$", nil },
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
