local M = {}

--- Parse a git remote URL into host, owner, repo, and web_base.
--- Supports: git@host:owner/repo(.git), ssh://git@host/owner/repo(.git), http(s)://host/owner/repo(.git)
function M.parse_remote_url(url)
  if not url or url == "" then
    return nil, "Empty remote URL"
  end

  local host, owner, repo

  host, owner, repo = url:match("^git@([^:]+):([^/]+)/(.+)%.git$")
  if not host then
    host, owner, repo = url:match("^git@([^:]+):([^/]+)/([^%.]+)$")
  end
  if host and owner and repo then
    return {
      host = host,
      owner = owner,
      repo = repo,
      web_base = string.format("https://%s/%s/%s", host, owner, repo),
    }
  end

  host, owner, repo = url:match("^ssh://git@([^/]+)/([^/]+)/(.+)%.git/?$")
  if not host then
    host, owner, repo = url:match("^ssh://git@([^/]+)/([^/]+)/([^%./]+)/?$")
  end
  if host and owner and repo then
    return {
      host = host,
      owner = owner,
      repo = repo,
      web_base = string.format("https://%s/%s/%s", host, owner, repo),
    }
  end

  local scheme
  scheme, host, owner, repo = url:match("^(https?)://([^/]+)/([^/]+)/([^/]+)$")
  if host and owner and repo then
    repo = repo:gsub("%.git$", ""):gsub("/$", "")
    return {
      host = host,
      owner = owner,
      repo = repo,
      web_base = string.format("%s://%s/%s/%s", scheme, host, owner, repo),
    }
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

--- Open a URL in the default browser. Falls back to clipboard.
function M.open_url(url)
  if not url then
    return false
  end

  if vim.ui and vim.ui.open then
    vim.ui.open(url)
    return true
  end

  if vim.fn.has("mac") == 1 then
    vim.fn.jobstart({ "open", url }, { detach = true })
    return true
  end
  if vim.fn.executable("xdg-open") == 1 then
    vim.fn.jobstart({ "xdg-open", url }, { detach = true })
    return true
  end
  if vim.fn.has("win32") == 1 then
    vim.fn.jobstart({ "cmd", "/c", "start", url }, { detach = true })
    return true
  end

  vim.fn.setreg("+", url)
  vim.notify("Browse URL copied to clipboard: " .. url, vim.log.levels.INFO)
  return true
end

--- Get current visual selection or cursor line range.
--- Returns start_line, end_line (end_line is nil for single line).
function M.line_range()
  local start_line
  local end_line
  local mode = vim.fn.mode()

  if mode:match("^[vV\22]") then
    local s = vim.fn.getpos("<")[2]
    local e = vim.fn.getpos(">")[2]
    if s and e then
      start_line = math.min(s, e)
      end_line = math.max(s, e)
    end
  else
    start_line = vim.fn.line(".")
  end

  return start_line, end_line
end

return M
