{ pkgs, lib, ... }:

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
  codexAgents = ''
    # Codex global guidance

    ${sharedMemory}
  '';
  claudeAgents = ''
    # Claude global guidance

    ${sharedMemory}
  '';
  codexConfigFile = pkgs.writeText "codex-config.toml" codexConfig;
  claudeSettingsFile = pkgs.writeText "claude-settings.json" (builtins.toJSON claudeSettings);
in
{
  home.file.".claude/agents/executor.md".source = ./ai-agents/claude/agents/executor.md;
  home.file.".claude/skills/coordinator-driven-development/SKILL.md".source =
    ./ai-agents/claude/skills/coordinator-driven-development/SKILL.md;
  home.file.".claude/CLAUDE.md".text = claudeAgents;
  home.file.".codex/AGENTS.md".text = codexAgents;

  xdg.configFile."ai-agents/shared-memory.md".source = ./ai-agents/shared-memory.md;

  home.activation.seedAiAgentFiles = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    seed() {
      local src dest mode
      src="$1"; dest="$2"; mode="$3"
      if [ ! -e "$dest" ] && [ ! -L "$dest" ]; then
        run mkdir -p "$(dirname "$dest")"
        run install -m "$mode" "$src" "$dest"
      fi
    }
    seed ${codexConfigFile} "''${HOME}/.codex/config.toml" 600
    seed ${claudeSettingsFile} "''${HOME}/.claude/settings.json" 600
  '';
}
