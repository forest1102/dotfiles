{ ... }:

let
  sharedMemory = builtins.readFile ./ai-agents/shared-memory.md;
  codexConfig = ''
    model = "gpt-5.5"
    model_reasoning_effort = "high"
    personality = "pragmatic"
    service_tier = "fast"
    approval_policy = "on-request"
    approvals_reviewer = "user"
    sandbox_mode = "workspace-write"

    [features]
    multi_agent = true
    js_repl = false

    [plugins."google-calendar@openai-curated"]
    enabled = true

    [plugins."gmail@openai-curated"]
    enabled = true

    [plugins."canva@openai-curated"]
    enabled = true

    [plugins."github@openai-curated"]
    enabled = true

    [plugins."superpowers@openai-curated"]
    enabled = true

    [plugins."documents@openai-primary-runtime"]
    enabled = true

    [plugins."spreadsheets@openai-primary-runtime"]
    enabled = true

    [plugins."presentations@openai-primary-runtime"]
    enabled = true

    [plugins."browser@openai-bundled"]
    enabled = true

    [plugins."pdf@openai-primary-runtime"]
    enabled = true

    [plugins."template-creator@openai-primary-runtime"]
    enabled = true

    [plugins."code-simplifier@claude-plugins-official"]
    enabled = true

    [desktop]
    localeOverride = "ja-JP"
    git-create-pull-request-as-draft = false
  '';
  claudeSettings = {
    model = "opusplan";
    effortLevel = "medium";
    editorMode = "vim";
    theme = "dark-daltonized";
    tui = "fullscreen";
    skipAutoPermissionPrompt = true;
    permissions.defaultMode = "auto";
    enabledPlugins = {
      "context7@claude-plugins-official" = true;
      "code-review@claude-plugins-official" = true;
      "code-simplifier@claude-plugins-official" = true;
      "claude-md-management@claude-plugins-official" = true;
      "commit-commands@claude-plugins-official" = true;
      "slack@claude-plugins-official" = true;
      "superpowers@claude-plugins-official" = true;
      "typescript-lsp@claude-plugins-official" = true;
      "playwright@claude-plugins-official" = true;
    };
  };
in
{
  home.file.".config/ai-agents/shared-memory.md".source = ./ai-agents/shared-memory.md;

  home.file.".codex/config.toml".text = codexConfig;
  home.file.".codex/AGENTS.md".text = ''
    # Codex global guidance

    ${sharedMemory}
  '';

  home.file.".claude/settings.json".text = builtins.toJSON claudeSettings;
  home.file.".claude/CLAUDE.md".text = ''
    # Claude global guidance

    ${sharedMemory}
  '';
}
