-- Places: one Rex session per place, where a place is a git worktree or a project.
--
--   cmd+p        Go to Place…       jump to a place, or type a name to create a worktree
--   cmd+;        Previous Place     toggle between this place and the last one
--   shift+cmd+x  Remove…            remove one worktree (and its session), or close one session
--
-- Session labels are the link between a session and its directory:
--   fe/feat-ds-table   a worktree (repo prefix from ALIASES, else the repo's name)
--   cdp-marketplace    a project (a repo's main checkout, or a directory in EXTRA)
-- Renaming a session by hand unlinks it.
--
-- worktrunk's hooks call place_open / place_close through ~/scripts/bin/wt-rex,
-- so `wt switch` and `wt remove` typed in a shell keep the sessions in step.

local M = {}

local HOME     = os.getenv("HOME")
local PROJECTS = HOME .. "/projects"
local GIT      = "/opt/homebrew/bin/git"
local WT       = "/opt/homebrew/bin/wt"
local STATE    = HOME .. "/.local/state/rex/places.json"
local SHELL    = "com.superlogical.terminal.shell"
local TERMINAL = "com.superlogical.terminal"

-- Short repo names used as the label prefix.
local ALIASES = { ["fe-monorepo"] = "fe" }

-- Repos under ~/projects the picker never offers.
local HIDDEN = {
  ["cre-deploy-old"]    = true,
  ["cre-deploy-mirror"] = true,
  ["gitops-test"]       = true,
  ["fe-monorepo-2"]     = true,
  ["frontend-handover"] = true,
}

-- Directories that aren't git repos but are offered as projects anyway.
local EXTRA = { PROJECTS .. "/fe-run" }

-- The server's own PATH lacks Homebrew. Clearing REX_SESSION keeps wt-rex quiet
-- when wt runs from here, since these actions manage the sessions themselves.
local EXEC_ENV = {
  PATH        = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin",
  REX_SESSION = false,
  REX_BLOCK   = false,
}

local DIRTY  = { "staged", "modified", "untracked", "renamed", "deleted", "conflicted" }

---------------------------------------------------------------------------
-- Helpers

local function must(result, err)
  if result == nil then error(err, 0) end
  return result
end

local function trim(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function basename(path)
  return ((path:gsub("/+$", "")):match("([^/]+)$"))
end

local function tilde(path)
  if path:sub(1, #HOME) == HOME then return "~" .. path:sub(#HOME + 1) end
  return path
end

local function shell_quote(s)
  return "'" .. (s:gsub("'", "'\\''")) .. "'"
end

-- Runs a command and returns its stdout, or nil and what it printed on failure.
local function exec(argv, opts)
  opts = opts or {}
  opts.env = opts.env or EXEC_ENV
  opts.timeout = opts.timeout or 10
  local r, err = rex.exec(argv, opts)
  if r == nil then return nil, err end
  if not r.ok then return nil, trim(r.stderr ~= "" and r.stderr or r.stdout) end
  return r.stdout
end

local function need_ui()
  if rex.ui == nil then
    error("Places needs Rex server preview.21 or newer for rex.ui. Restart the server to update it.", 0)
  end
end

function M.terminal_directory(block_id)
  if block_id == nil then return nil end
  local result = rex.block.call(TERMINAL, "pwd", { block_id = block_id })
  if result == nil or result.pwd == nil then return nil end
  local path = result.pwd:match("^file://[^/]*(/.*)$")
  if path == nil then return nil end
  return (path:gsub("%%(%x%x)", function(hex) return string.char(tonumber(hex, 16)) end))
end

---------------------------------------------------------------------------
-- State: the current and previous place, and sessions waiting for `wt` to
-- create their worktree.

local function load_state()
  local f = io.open(STATE, "r")
  if f == nil then return {} end
  local text = f:read("*a")
  f:close()
  return rex.json.decode(text) or {}
end

local function save_state(state)
  local f = io.open(STATE, "w")
  if f == nil then return end
  f:write(rex.json.encode(state))
  f:close()
end

---------------------------------------------------------------------------
-- Labels

local function repo_name(repo_dir)
  return (basename(repo_dir):gsub("%.git$", ""))
end

local function repo_prefix(repo_dir)
  local name = repo_name(repo_dir)
  return ALIASES[name] or name
end

-- worktrunk's default layout puts worktrees beside the repo as repo.branch;
-- drop the repo part so cdp-marketplace.feat-x reads cdp-marketplace/feat-x.
local function worktree_label(path, repo_dir)
  local base, name = basename(path), repo_name(repo_dir)
  if base:sub(1, #name + 1) == name .. "." and #base > #name + 1 then
    base = base:sub(#name + 2)
  end
  return repo_prefix(repo_dir) .. "/" .. base
end

-- Describes the place a path belongs to: { root, repo?, label }.
local function place_of(path)
  local out = exec({ GIT, "-C", path, "rev-parse", "--path-format=absolute",
                     "--git-common-dir", "--show-toplevel" }, { timeout = 5 })
  local common, top
  if out then common, top = out:match("^([^\n]+)\n([^\n]+)") end
  if top == nil then return { root = path, label = basename(path) } end
  local repo = common:match("^(.*)/%.git/?$") or common
  if top == repo then return { root = top, repo = repo, label = basename(top) } end
  return { root = top, repo = repo, label = worktree_label(top, repo) }
end

---------------------------------------------------------------------------
-- Discovery: every repo directly under ~/projects, with its worktrees.

local DISCOVER = [[
root=$1; shift
worktrees() {
  git -C "$1" worktree list --porcelain | awk -v repo="$1" -v skip="$2" '
    function emit() { if (path != "" && !bare && path != skip) print "wt\t" repo "\t" path "\t" branch; path = "" }
    /^worktree / { emit(); path = substr($0, 10); branch = ""; bare = 0; next }
    /^branch /   { branch = substr($0, 8); sub(/^refs\/heads\//, "", branch); next }
    /^bare$/     { bare = 1; next }
    /^$/         { emit() }
    END          { emit() }'
}
for d in "$root"/*/; do
  d=${d%/}
  [ -d "$d/.git" ] || continue
  if [ "$(git -C "$d" rev-parse --is-bare-repository 2>/dev/null)" = true ]; then
    main=$(git -C "$d" config --get worktrunk.default-branch ||
      git -C "$d" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||')
    printf 'bare\t%s\t%s\n' "$d" "$main"
    worktrees "$d" ""
  else
    printf 'repo\t%s\n' "$d"
    if [ -d "$d/.git/worktrees" ]; then worktrees "$d" "$d"; fi
  fi
done
for e in "$@"; do
  if [ -d "$e" ]; then printf 'dir\t%s\n' "$e"; fi
done
]]

-- Returns places, a list of { root, repo?, label, kind = "worktree" | "project",
-- branch? }, and repos, a list of { dir, bare, main, worktrees }.
local function discover()
  local out = must(exec({ "/bin/sh", "-c", DISCOVER, "sh", PROJECTS, unpack(EXTRA) }, { timeout = 15 }))
  local places, repos, by_dir = {}, {}, {}
  for line in out:gmatch("[^\n]+") do
    local f = {}
    for field in (line .. "\t"):gmatch("([^\t]*)\t") do f[#f + 1] = field end
    local kind, dir = f[1], f[2]
    if (kind == "bare" or kind == "repo") and not HIDDEN[basename(dir)] then
      local repo = { dir = dir, bare = kind == "bare", default = f[3], worktrees = {} }
      repos[#repos + 1], by_dir[dir] = repo, repo
      if not repo.bare then
        repo.main = dir
        places[#places + 1] = { root = dir, repo = dir, label = basename(dir), kind = "project" }
      end
    elseif kind == "wt" and by_dir[dir] then
      local repo = by_dir[dir]
      local place = { root = f[3], repo = dir, branch = f[4], kind = "worktree",
                      label = worktree_label(f[3], dir) }
      repo.worktrees[#repo.worktrees + 1] = place
      if repo.bare and place.branch == repo.default then repo.main = place.root end
      places[#places + 1] = place
    elseif kind == "dir" then
      places[#places + 1] = { root = dir, label = basename(dir), kind = "project" }
    end
  end
  for _, repo in ipairs(repos) do
    if repo.main == nil and repo.worktrees[1] then repo.main = repo.worktrees[1].root end
  end
  return places, repos
end

---------------------------------------------------------------------------
-- Sessions

local function sessions()
  return must(rex.call("session.list")).sessions or {}
end

local function find_session(list, label)
  for _, s in ipairs(list) do
    if s.label == label then return s end
  end
end

-- Rex only lets a caller change a session it's attached to, so attach and retry.
local function session_call(method, args)
  local result, err = rex.call(method, args)
  if err then
    rex.call("session.attach", { session_id = args.session_id })
    result, err = rex.call(method, args)
  end
  return result, err
end

-- Records the jump for Previous Place.
local function remember(from, to)
  if from == nil or from == to then return end
  local state = load_state()
  state.prev, state.cur = from, to
  save_state(state)
end

-- Shows a session in the app.
local function show(ctx, session_id, window_id)
  remember(ctx.session_id, session_id)
  local ok, err = pcall(rex.client.queue, "session.select",
    { session_id = session_id, window_id = window_id })
  if not ok then
    rex.log("warn", "places: can't show " .. session_id .. ": " .. tostring(err))
  end
end

-- Moves a session to just after the other sessions of its repo.
local function group_with_siblings(session_id, label)
  local prefix = label:match("^[^/]+/")
  if prefix == nil then return end
  local list, last = sessions(), nil
  for i, s in ipairs(list) do
    if s.session_id ~= session_id and s.label:sub(1, #prefix) == prefix then last = i end
  end
  if last == nil then return end
  local after = list[last + 1]
  if after and after.session_id == session_id then return end
  session_call("session.move", { session_id = session_id, before_session_id = after and after.session_id })
end

local function create_session(label, cwd, input)
  local created = must(rex.call("session.create", {
    label = label,
    initial_windows = { {
      layout = rex.layout.block{ flavor = SHELL, options = { cwd = cwd, initial_input = input } },
    } },
  }))
  group_with_siblings(created.session_id, label)
  local window = created.initial_windows and created.initial_windows[1]
  return created.session_id, window and window.window_id
end

local function destroy_session(session_id)
  local _, err = session_call("session.destroy", { session_id = session_id })
  if err then rex.log("warn", "places: can't close " .. session_id .. ": " .. tostring(err)) end
  return err
end

-- Shows the place's session, creating it with one shell tab if needed.
local function open_place(ctx, place, list)
  local s = find_session(list or sessions(), place.label)
  local session_id, window_id
  if s then
    session_id = s.session_id
  else
    session_id, window_id = create_session(place.label, place.root)
  end
  if session_id ~= ctx.session_id then show(ctx, session_id, window_id) end
  return session_id
end

-- The place cmd+; goes to: the previous one, or the last one Rex knows of
-- when you've moved some other way, such as the sidebar.
local function back_session(current, list)
  local state = load_state()
  local target = state.cur == current and state.prev or state.cur
  if target == nil or target == current then return nil end
  for _, s in ipairs(list) do
    if s.session_id == target then return s end
  end
end

---------------------------------------------------------------------------
-- Creating worktrees

local function repo_of_block(ctx, repos)
  local pwd = M.terminal_directory(ctx.block_id)
  if pwd == nil then return nil end
  local place = place_of(pwd)
  for _, repo in ipairs(repos) do
    if repo.dir == place.repo then return repo end
  end
end

local function choose_repo(name, repos)
  local items = {}
  for _, repo in ipairs(repos) do
    items[#items + 1] = { id = repo.dir, title = repo_name(repo.dir), subtitle = tilde(repo.dir), icon = "folder" }
  end
  local dir = rex.ui.pick{ title = "Create worktree " .. name .. " in…", placeholder = "Filter repos", items = items }
  for _, repo in ipairs(repos) do
    if repo.dir == dir then return repo end
  end
end

-- Opens a session that runs `wt switch` where you can watch it, since
-- worktrunk's hooks (env copies, pnpm install) can outlast an action's 30s.
-- The session is labelled with a guess; wt-rex fixes it once the worktree exists.
local function create_worktree(ctx, name, places, repos, list)
  if name == "" then return end
  local repo = repo_of_block(ctx, repos) or choose_repo(name, repos)
  if repo == nil then return end

  for _, place in ipairs(places) do
    if place.repo == repo.dir and place.kind == "worktree"
        and (place.branch == name or basename(place.root) == name) then
      return open_place(ctx, place, list)
    end
  end

  local cwd = repo.main or repo.dir
  local existing = name:match("^[mp]r:%d+$")
    or exec({ GIT, "-C", cwd, "rev-parse", "--verify", "--quiet", "refs/heads/" .. name })
    or exec({ GIT, "-C", cwd, "rev-parse", "--verify", "--quiet", "refs/remotes/origin/" .. name })
  local command = "wt switch " .. (existing and "" or "--create ") .. shell_quote(name) .. "\r"
  local label = repo_prefix(repo.dir) .. "/" .. (name:gsub("[/\\:]", "-"))

  local s = find_session(list, label)
  if s then return show(ctx, s.session_id) end

  local session_id, window_id = create_session(label, cwd, command)
  local state = load_state()
  state.pending = state.pending or {}
  state.pending[session_id] = true
  save_state(state)
  show(ctx, session_id, window_id)
end

---------------------------------------------------------------------------
-- Actions

local ICONS = { worktree = "branch", project = "folder" }

rex.action{
  name        = "place_go",
  title       = "Go to Place…",
  category    = "Places",
  description = "Jump to a worktree or project, or type a branch name to create a worktree.",
  run = function(ctx)
    need_ui()
    local places, repos = discover()
    local list = sessions()

    local by_label, open = {}, {}
    for _, place in ipairs(places) do by_label[place.label] = place end
    for _, s in ipairs(list) do open[s.label] = true end

    local items = {}
    local back = back_session(ctx.session_id, list)
    if back then
      local place = by_label[back.label]
      items[1] = { id = "s:" .. back.session_id, title = back.label, icon = "clock", detail = "previous",
                   subtitle = place and tilde(place.root) }
    end
    for _, s in ipairs(list) do
      if s.session_id ~= ctx.session_id and s ~= back then
        local place = by_label[s.label]
        items[#items + 1] = { id = "s:" .. s.session_id, title = s.label, detail = "open",
                              icon = place and ICONS[place.kind] or "terminal",
                              subtitle = place and tilde(place.root) }
      end
    end
    for _, kind in ipairs{ "worktree", "project" } do
      for _, place in ipairs(places) do
        if place.kind == kind and not open[place.label] then
          items[#items + 1] = { id = "p:" .. place.root, title = place.label, icon = ICONS[kind],
                                subtitle = place.branch ~= nil and place.branch ~= "" and place.branch
                                           or tilde(place.root) }
        end
      end
    end

    local choice = rex.ui.pick{
      title       = "Go to place",
      placeholder = "Worktree or project, or a new branch name",
      items       = items,
      allow_other = true,
    }
    if choice == nil then return end
    if type(choice) == "table" then
      return create_worktree(ctx, trim(choice.text), places, repos, list)
    end
    local kind, value = choice:match("^(%a):(.*)$")
    if kind == "s" then return show(ctx, value) end
    for _, place in ipairs(places) do
      if place.root == value then return open_place(ctx, place, list) end
    end
  end,
}

rex.action{
  name     = "place_back",
  title    = "Go to Previous Place",
  category = "Places",
  run = function(ctx)
    local target = back_session(ctx.session_id, sessions())
    if target then show(ctx, target.session_id) end
  end,
}

rex.action{
  name        = "place_remove",
  title       = "Remove Worktree or Session…",
  category    = "Places",
  description = "Remove a worktree with wt remove and close its session, or close a session.",
  run = function(ctx)
    need_ui()
    local places, repos = discover()
    local list = sessions()

    -- worktrunk's status for each repo with worktrees, fetched in parallel.
    local jobs = {}
    for _, repo in ipairs(repos) do
      local removable = {}
      for _, place in ipairs(repo.worktrees) do
        if place.root ~= repo.main then removable[#removable + 1] = place end
      end
      if #removable > 0 then
        local h = rex.exec.start({ WT, "-C", repo.main or repo.dir, "list", "--format=json" },
                                 { env = EXEC_ENV, timeout = 20 })
        jobs[#jobs + 1] = { repo = repo, removable = removable, h = h }
      end
    end

    local open = {}
    for _, s in ipairs(list) do open[s.label] = s end
    local current_label
    for _, s in ipairs(list) do
      if s.session_id == ctx.session_id then current_label = s.label end
    end

    -- The current place goes first so Enter removes it.
    local items, info, worktree_labels = {}, {}, {}
    local function add(item)
      if item.title == current_label then table.insert(items, 1, item) else items[#items + 1] = item end
    end

    for _, job in ipairs(jobs) do
      local status = {}
      local r = job.h and job.h:wait(20)
      local data = r and r.ok and rex.json.decode(r.stdout)
      for _, item in ipairs(data and data.items or {}) do
        if item.worktree and item.worktree.path then status[item.worktree.path] = item end
      end
      for _, place in ipairs(job.removable) do
        local st = status[place.root]
        local changes = st and st.worktree.changes or {}
        local dirty = false
        for _, k in ipairs(DIRTY) do dirty = dirty or changes[k] == true end
        local display = st and st.display or {}
        local symbols = type(display.symbols) == "string" and display.symbols ~= "" and display.symbols or nil
        local detail = open[place.label] and ((symbols and symbols .. "  " or "") .. "open") or symbols
        info["w:" .. place.root] = { place = place, repo = job.repo, dirty = dirty }
        worktree_labels[place.label] = true
        add{ id = "w:" .. place.root, title = place.label, icon = "branch", detail = detail,
             subtitle = place.branch ~= "" and place.branch or tilde(place.root) }
      end
    end

    -- Sessions that aren't a removable worktree: closing one leaves its directory alone.
    local by_label = {}
    for _, place in ipairs(places) do by_label[place.label] = place end
    for _, s in ipairs(list) do
      if not worktree_labels[s.label] then
        local place = by_label[s.label]
        add{ id = "s:" .. s.session_id, title = s.label, detail = "close session",
             icon = place and ICONS[place.kind] or "terminal",
             subtitle = place and tilde(place.root) }
      end
    end
    if #items == 0 then error("There are no worktrees or sessions to remove.", 0) end

    local choice = rex.ui.pick{
      title = "Remove worktree or close session", placeholder = "Filter worktrees and sessions",
      confirm = "Remove", items = items,
    }
    if choice == nil then return end

    local kind, value = choice:match("^(%a):(.*)$")
    if kind == "s" then
      if value == ctx.session_id then
        local back = back_session(ctx.session_id, list)
        if back then show(ctx, back.session_id) end
      end
      destroy_session(value)
      return
    end

    local i = info[choice]
    if i == nil then return end
    if i.dirty then
      local answer = rex.ui.pick{
        title = i.place.label .. " has uncommitted changes",
        items = {
          { id = "cancel", title = "Cancel" },
          { id = "force",  title = "Force-remove it", subtitle = "Its uncommitted changes are lost" },
        },
      }
      if answer ~= "force" then return end
    end

    local argv = { WT, "-C", i.repo.main or i.repo.dir, "remove", value }
    if i.dirty then argv[#argv + 1] = "--force" end
    -- Detached, so the deletion wt leaves running in the background
    -- isn't stopped when this action returns.
    local h, err = rex.exec.start(argv, { env = EXEC_ENV, detach = true })
    local r = h and h:wait(20)
    if h and r == nil then err = "wt remove timed out" end
    if r and not r.ok then err = trim(r.stderr ~= "" and r.stderr or r.stdout) end
    if err then
      rex.ui.pick{ title = "Couldn't remove " .. i.place.label,
                   items = { { id = value, title = i.place.label, subtitle = err } } }
      return
    end

    local s = open[i.place.label]
    if s and s.session_id == ctx.session_id then
      for _, place in ipairs(places) do
        if place.root == i.repo.main then open_place(ctx, place, list) end
      end
    end
    if s then destroy_session(s.session_id) end
  end,
}

-- For wt-rex: show (or create) the session for a path. A session the picker
-- opened for a new worktree takes its final label here instead.
rex.action{
  name        = "place_open",
  title       = "Open Place at Path",
  category    = "Places",
  description = "Show the session for a worktree or project directory. Used by worktrunk's post-switch hook.",
  args        = { path = "string" },
  run = function(ctx, args)
    local place = place_of(args.path)
    local state = load_state()
    if ctx.session_id and state.pending and state.pending[ctx.session_id] then
      state.pending[ctx.session_id] = nil
      save_state(state)
      session_call("session.set_label", { session_id = ctx.session_id, label = place.label })
      group_with_siblings(ctx.session_id, place.label)
      return { session_id = ctx.session_id }
    end
    return { session_id = open_place(ctx, place) }
  end,
}

-- For wt-rex: close a removed worktree's session. When it's the session the
-- hook runs in, show the repo's main worktree first.
rex.action{
  name        = "place_close",
  title       = "Close Place at Path",
  category    = "Places",
  description = "Close the session of a removed worktree. Used by worktrunk's post-remove hook.",
  args        = { path = "string", primary = "string?" },
  run = function(ctx, args)
    local main = args.primary and place_of(args.primary)
    local label = basename(args.path)
    if main and main.repo and args.path ~= main.repo then label = worktree_label(args.path, main.repo) end
    local list = sessions()
    local s = find_session(list, label)
    if s == nil then return end
    if s.session_id == ctx.session_id and main then open_place(ctx, main, list) end
    return { closed = s.session_id, error = destroy_session(s.session_id) }
  end,
}

-- One-off: relabel sessions from the old " name" scheme and group them by repo.
rex.action{
  name     = "place_migrate",
  title    = "Relabel Sessions as Places",
  category = "Places",
  run = function(ctx)
    local by_base = {}
    for _, place in ipairs((discover())) do
      local base = basename(place.root)
      by_base[base] = by_base[base] == nil and place or false
    end
    local renamed = {}
    for _, s in ipairs(sessions()) do
      local place = by_base[(s.label:gsub("^[\128-\255]+%s*", ""))]
      if place and place.label ~= s.label then
        must(session_call("session.set_label", { session_id = s.session_id, label = place.label }))
        renamed[#renamed + 1] = s.label .. " -> " .. place.label
      end
    end

    -- Each repo's sessions together, at the position of its first one.
    local list, groups, order = sessions(), {}, {}
    for _, s in ipairs(list) do
      local key = s.label:match("^([^/]+)/") or s.session_id
      if groups[key] == nil then groups[key] = {}; order[#order + 1] = key end
      table.insert(groups[key], s)
    end
    local sorted = {}
    for _, key in ipairs(order) do
      for _, s in ipairs(groups[key]) do sorted[#sorted + 1] = s end
    end
    for i, s in ipairs(sorted) do
      if list[i].session_id ~= s.session_id then
        for _, t in ipairs(sorted) do session_call("session.move", { session_id = t.session_id }) end
        break
      end
    end
    return { renamed = renamed }
  end,
}

rex.bind("cmd+p", "place_go")
rex.bind("cmd+;", "place_back")
rex.bind("shift+cmd+x", "place_remove")

rex.exec({ "/bin/mkdir", "-p", (STATE:gsub("/[^/]+$", "")) })

M.discover, M.place_of = discover, place_of  -- for poking at from `rex do`

return M
