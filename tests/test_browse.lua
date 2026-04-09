local new_set = MiniTest.new_set
local eq = MiniTest.expect.equality

local browse = require("fugitive-core.views.browse")

local T = new_set()

-- parse_remote_url -----------------------------------------------------------

T["parse_remote_url"] = new_set()

T["parse_remote_url"]["git@ SSH"] = function()
  local r = browse.parse_remote_url("git@github.com:user/repo.git")
  eq(r.host, "github.com")
  eq(r.owner, "user")
  eq(r.repo, "repo")
  eq(r.web_base, "https://github.com/user/repo")
end

T["parse_remote_url"]["git@ without .git"] = function()
  local r = browse.parse_remote_url("git@github.com:user/repo")
  eq(r.host, "github.com")
  eq(r.repo, "repo")
  eq(r.web_base, "https://github.com/user/repo")
end

T["parse_remote_url"]["ssh://"] = function()
  local r = browse.parse_remote_url("ssh://git@github.com/user/repo.git/")
  eq(r.host, "github.com")
  eq(r.owner, "user")
  eq(r.repo, "repo")
  eq(r.web_base, "https://github.com/user/repo")
end

T["parse_remote_url"]["ssh:// without .git"] = function()
  local r = browse.parse_remote_url("ssh://git@github.com/user/repo")
  eq(r.host, "github.com")
  eq(r.repo, "repo")
end

T["parse_remote_url"]["https"] = function()
  local r = browse.parse_remote_url("https://github.com/user/repo")
  eq(r.host, "github.com")
  eq(r.owner, "user")
  eq(r.repo, "repo")
  eq(r.web_base, "https://github.com/user/repo")
end

T["parse_remote_url"]["https with .git"] = function()
  local r = browse.parse_remote_url("https://github.com/user/repo.git")
  eq(r.repo, "repo")
end

T["parse_remote_url"]["http"] = function()
  local r = browse.parse_remote_url("http://gitlab.example.com/team/project")
  eq(r.host, "gitlab.example.com")
  eq(r.web_base, "http://gitlab.example.com/team/project")
end

T["parse_remote_url"]["empty returns nil"] = function()
  local r, err = browse.parse_remote_url("")
  eq(r, nil)
  eq(type(err), "string")
end

T["parse_remote_url"]["nil returns nil"] = function()
  local r = browse.parse_remote_url(nil)
  eq(r, nil)
end

T["parse_remote_url"]["unrecognized returns nil"] = function()
  local r = browse.parse_remote_url("ftp://something/weird")
  eq(r, nil)
end

-- build_file_url -------------------------------------------------------------

T["build_file_url"] = new_set()

local github_remote = { host = "github.com", web_base = "https://github.com/u/r" }
local gitlab_remote = { host = "gitlab.com", web_base = "https://gitlab.com/u/r" }

T["build_file_url"]["github basic"] = function()
  local url = browse.build_file_url(github_remote, "src/main.lua", "abc123")
  eq(url, "https://github.com/u/r/blob/abc123/src/main.lua")
end

T["build_file_url"]["github with line"] = function()
  local url = browse.build_file_url(github_remote, "foo.lua", "main", 42)
  eq(url, "https://github.com/u/r/blob/main/foo.lua#L42")
end

T["build_file_url"]["github with line range"] = function()
  local url = browse.build_file_url(github_remote, "foo.lua", "main", 10, 20)
  eq(url, "https://github.com/u/r/blob/main/foo.lua#L10-L20")
end

T["build_file_url"]["gitlab basic"] = function()
  local url = browse.build_file_url(gitlab_remote, "src/main.lua", "abc123")
  eq(url, "https://gitlab.com/u/r/-/blob/abc123/src/main.lua")
end

T["build_file_url"]["gitlab with line range"] = function()
  local url = browse.build_file_url(gitlab_remote, "foo.lua", "main", 10, 20)
  eq(url, "https://gitlab.com/u/r/-/blob/main/foo.lua#L10-20")
end

T["build_file_url"]["spaces encoded"] = function()
  local url = browse.build_file_url(github_remote, "my file.lua", "main")
  eq(url, "https://github.com/u/r/blob/main/my%20file.lua")
end

T["build_file_url"]["nil remote returns nil"] = function()
  local url = browse.build_file_url(nil, "foo.lua", "main")
  eq(url, nil)
end

-- build_commit_url -----------------------------------------------------------

T["build_commit_url"] = new_set()

T["build_commit_url"]["github"] = function()
  local url = browse.build_commit_url(github_remote, "abc123")
  eq(url, "https://github.com/u/r/commit/abc123")
end

T["build_commit_url"]["gitlab"] = function()
  local url = browse.build_commit_url(gitlab_remote, "abc123")
  eq(url, "https://gitlab.com/u/r/-/commit/abc123")
end

-- build_custom_file_url ------------------------------------------------------

T["build_custom_file_url"] = new_set()

T["build_custom_file_url"]["matching forge"] = function()
  require("fugitive-core").config.forges = {
    { match = "myrepo", url = "https://code.example.com/myrepo/{path}?lines={lines}" },
  }
  local url = browse.build_custom_file_url("ssh://git@server/myrepo", "src/foo.lua", 42)
  eq(url, "https://code.example.com/myrepo/src/foo.lua?lines=42")
end

T["build_custom_file_url"]["matching forge with range"] = function()
  require("fugitive-core").config.forges = {
    { match = "myrepo", url = "https://code.example.com/myrepo/{path}?lines={lines}" },
  }
  local url = browse.build_custom_file_url("ssh://git@server/myrepo", "src/foo.lua", 10, 20)
  eq(url, "https://code.example.com/myrepo/src/foo.lua?lines=10-20")
end

T["build_custom_file_url"]["no lines strips placeholder"] = function()
  require("fugitive-core").config.forges = {
    { match = "myrepo", url = "https://code.example.com/myrepo/{path}?lines={lines}" },
  }
  local url = browse.build_custom_file_url("ssh://git@server/myrepo", "src/foo.lua")
  eq(url, "https://code.example.com/myrepo/src/foo.lua")
end

T["build_custom_file_url"]["no match returns nil"] = function()
  require("fugitive-core").config.forges = {
    { match = "myrepo", url = "https://example.com/{path}" },
  }
  local url = browse.build_custom_file_url("ssh://git@server/other", "foo.lua")
  eq(url, nil)
end

T["build_custom_file_url"]["no forges configured returns nil"] = function()
  require("fugitive-core").config.forges = nil
  local url = browse.build_custom_file_url("ssh://git@server/repo", "foo.lua")
  eq(url, nil)
end

-- line_range -----------------------------------------------------------------

T["line_range"] = new_set()

T["line_range"]["returns cursor line in normal mode"] = function()
  local s, e = browse.line_range()
  eq(type(s), "number")
  eq(e, nil)
end

return T
