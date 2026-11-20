-- Run from the repository root:
-- nvim --headless -u nvim/.config/nvim/init.lua -n -i NONE -c 'luafile nvim/tests/tailwind_roots.lua'
vim.lsp.enable('tailwindcss', false)

local temporary = vim.fn.tempname()
vim.fn.mkdir(temporary, 'p')
local passed = 0

local function file(path, content)
  vim.fn.mkdir(vim.fs.dirname(path), 'p')
  vim.fn.writefile({ content or '' }, path)
  return path
end

local function check(name, path, expected)
  local buffer = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buffer, path)
  local actual, called
  vim.lsp.config.tailwindcss.root_dir(buffer, function(root)
    actual, called = root, true
  end)
  vim.api.nvim_buf_delete(buffer, { force = true })
  assert(actual == expected, name .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual))
  if not expected then
    assert(not called, name .. ': blocked roots must not start an LSP client')
  end
  passed = passed + 1
  print('PASS ' .. name)
end

local ok, err = pcall(function()
  check('standalone home file is not a home-wide workspace', vim.uv.os_homedir() .. '/nvim-root-regression.html', nil)

  local v3 = temporary .. '/tailwind-v3'
  file(v3 .. '/tailwind.config.js', 'module.exports = {}')
  check('Tailwind v3 config stays enabled', file(v3 .. '/src/page.html'), v3)

  local v4 = temporary .. '/tailwind-v4'
  file(v4 .. '/package.json', '{"devDependencies":{"tailwindcss":"^4.0.0"}}')
  check('Tailwind v4 dependency stays enabled', file(v4 .. '/src/page.html'), v4)

  local plain = temporary .. '/plain'
  file(plain .. '/package.json', '{"name":"plain-html"}')
  check('unrelated package does not enable Tailwind', file(plain .. '/page.html'), nil)

  local git = temporary .. '/git-project'
  vim.fn.mkdir(git .. '/.git', 'p')
  check('project-scoped Git fallback stays enabled', file(git .. '/src/page.html'), git)

  local nested = git .. '/nested'
  file(nested .. '/tailwind.config.ts', 'export default {}')
  check('nested Tailwind root takes precedence', file(nested .. '/src/page.html'), nested)
end)

vim.fn.delete(temporary, 'rf')
if not ok then
  print(err)
  vim.cmd('cquit 1')
end
print(string.format('%d/6 root checks passed', passed))
vim.cmd('qa!')
