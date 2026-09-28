local defaults = require("nvchad.configs.lspconfig")
defaults.defaults()

--------------------------------------------------
-- Capabilities
--------------------------------------------------
local capabilities = vim.lsp.protocol.make_client_capabilities()

local ok, cmp_lsp = pcall(require, "cmp_nvim_lsp")
if ok then
  capabilities = cmp_lsp.default_capabilities(capabilities)
end

capabilities.textDocument.foldingRange = {
  dynamicRegistration = false,
  lineFoldingOnly = true,
}

--------------------------------------------------
-- Diagnostics
--------------------------------------------------
vim.diagnostic.config({
  virtual_text = {
    spacing = 4,
    source = "if_many",
  },
  signs = true,
  underline = true,
  update_in_insert = true,
  severity_sort = true,
  float = {
    border = "rounded",
    source = true,
  },
})

--------------------------------------------------
-- Shared on_attach
--------------------------------------------------
local on_attach = function(client, bufnr)
  defaults.on_attach(client, bufnr)

  local map = vim.keymap.set

  map("n", "gd", vim.lsp.buf.definition, { buffer = bufnr })
  map("n", "gD", vim.lsp.buf.declaration, { buffer = bufnr })
  map("n", "gr", vim.lsp.buf.references, { buffer = bufnr })
  map("n", "gi", vim.lsp.buf.implementation, { buffer = bufnr })
  map("n", "gt", vim.lsp.buf.type_definition, { buffer = bufnr })

  map("n", "K", vim.lsp.buf.hover, { buffer = bufnr })
  map("n", "<C-k>", vim.lsp.buf.signature_help, { buffer = bufnr })

  map("n", "<leader>rn", vim.lsp.buf.rename, { buffer = bufnr })
  map("n", "<leader>ca", vim.lsp.buf.code_action, { buffer = bufnr })

  map("n", "[d", vim.diagnostic.goto_prev, { buffer = bufnr })
  map("n", "]d", vim.diagnostic.goto_next, { buffer = bufnr })

  map("n", "<leader>f", function()
    vim.lsp.buf.format({ async = true })
  end, { buffer = bufnr })

  if client.server_capabilities.documentHighlightProvider then
    local group = vim.api.nvim_create_augroup(
      "lsp_document_highlight_" .. bufnr,
      {}
    )

    vim.api.nvim_create_autocmd(
      { "CursorHold", "CursorHoldI" },
      {
        buffer = bufnr,
        group = group,
        callback = vim.lsp.buf.document_highlight,
      }
    )

    vim.api.nvim_create_autocmd(
      { "CursorMoved", "CursorMovedI" },
      {
        buffer = bufnr,
        group = group,
        callback = vim.lsp.buf.clear_references,
      }
    )
  end

  if vim.lsp.inlay_hint and client.server_capabilities.inlayHintProvider then
    vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
  end
end

--------------------------------------------------
-- PYREFLY
--------------------------------------------------
vim.lsp.config("pyrefly", {
  cmd = {
    "/data/data/com.termux/files/usr/bin/pyrefly",
    "lsp",
  },

  filetypes = { "python" },

  root_markers = {
    "pyproject.toml",
    "setup.py",
    "setup.cfg",
    "requirements.txt",
    ".git",
  },

  handlers = {
    ["textDocument/publishDiagnostics"] = function() end,
  },

  capabilities = capabilities,
  on_attach = on_attach,
})

--------------------------------------------------
-- RUFF
--------------------------------------------------
vim.lsp.config("ruff", {
  cmd = {
    "/data/data/com.termux/files/usr/bin/ruff",
    "server",
  },

  filetypes = { "python" },

  root_markers = {
    "pyproject.toml",
    "ruff.toml",
    ".ruff.toml",
    ".git",
  },

  capabilities = capabilities,

  on_attach = function(client, bufnr)
    client.server_capabilities.hoverProvider = false
    on_attach(client, bufnr)
  end,

  init_options = {
    settings = {
      fixAll = true,
      organizeImports = true,
    },
  },
})

--------------------------------------------------
-- CLANGD
--------------------------------------------------
vim.lsp.config("clangd", {
  cmd = {
    "/data/data/com.termux/files/usr/bin/clangd",
    "--background-index",
    "--clang-tidy",
    "--completion-style=detailed",
    "--header-insertion=iwyu",
    "--function-arg-placeholders",
    "--fallback-style=llvm",
    "--pch-storage=memory",
  },

  filetypes = {
    "c",
    "cpp",
    "objc",
    "objcpp",
    "cuda",
    "proto",
  },

  root_markers = {
    ".clangd",
    ".clang-tidy",
    "compile_commands.json",
    "compile_flags.txt",
    ".git",
  },

  capabilities = capabilities,
  on_attach = on_attach,
})

--------------------------------------------------
-- NEOCMAKELSP
--------------------------------------------------
vim.lsp.config("neocmakelsp", {
  cmd = {
    "/data/data/com.termux/files/usr/bin/neocmakelsp",
    "stdio",
  },

  filetypes = { "cmake" },

  root_markers = {
    "CMakeLists.txt",
    ".git",
  },

  capabilities = capabilities,
  on_attach = on_attach,
})

--------------------------------------------------
-- Enable
--------------------------------------------------
vim.lsp.enable("pyrefly")
vim.lsp.enable("ruff")
vim.lsp.enable("clangd")
vim.lsp.enable("neocmakelsp")

--------------------------------------------------
-- Borders
--------------------------------------------------
local border = "rounded"

vim.lsp.handlers["textDocument/hover"] =
  vim.lsp.with(vim.lsp.handlers.hover, {
    border = border,
  })

vim.lsp.handlers["textDocument/signatureHelp"] =
  vim.lsp.with(vim.lsp.handlers.signature_help, {
    border = border,
  })

--------------------------------------------------
-- Format on save
--------------------------------------------------
local fmt = vim.api.nvim_create_augroup(
  "LspFormatting",
  {}
)

vim.api.nvim_create_autocmd("BufWritePre", {
  group = fmt,
  callback = function(args)
    vim.lsp.buf.format({
      bufnr = args.buf,
      timeout_ms = 3000,
    })
  end,
})