{ pkgs, ... }:

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
  codexAgentsFile = pkgs.writeText "codex-AGENTS.md" codexAgents;
  claudeSettingsFile = pkgs.writeText "claude-settings.json" (builtins.toJSON claudeSettings);
  claudeAgentsFile = pkgs.writeText "claude-CLAUDE.md" claudeAgents;
  aiAgentsSync = pkgs.writeShellApplication {
    name = "ai-agents-sync";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      set -euo pipefail

      timestamp="$(date +%Y%m%d%H%M%S)"

      backup_existing() {
        target="$1"
        backup="$target.backup.$timestamp"
        counter=0

        while [ -e "$backup" ] || [ -L "$backup" ]; do
          counter=$((counter + 1))
          backup="$target.backup.$timestamp.$counter"
        done

        if [ -L "$target" ] && [ ! -e "$target" ]; then
          mv "$target" "$backup"
        else
          cp -p "$target" "$backup"
        fi

        printf 'backed up %s -> %s\n' "$target" "$backup"
      }

      install_file() {
        source="$1"
        target="$2"
        mode="$3"
        directory="$(dirname "$target")"

        mkdir -p "$directory"

        if [ -d "$target" ] && [ ! -L "$target" ]; then
          printf 'ai-agents-sync: refusing to replace directory: %s\n' "$target" >&2
          return 1
        fi

        tmp="$(mktemp "$directory/.ai-agents-sync.XXXXXX")"
        cp "$source" "$tmp"
        chmod "$mode" "$tmp"

        if [ -e "$target" ] || [ -L "$target" ]; then
          if cmp -s "$tmp" "$target"; then
            rm -f "$tmp"
            printf 'unchanged %s\n' "$target"
            return 0
          fi

          backup_existing "$target"
        fi

        mv -f "$tmp" "$target"
        printf 'synced %s\n' "$target"
      }

      install_file ${codexConfigFile} "$HOME/.codex/config.toml" 600
      install_file ${codexAgentsFile} "$HOME/.codex/AGENTS.md" 644
      install_file ${claudeSettingsFile} "$HOME/.claude/settings.json" 600
      install_file ${claudeAgentsFile} "$HOME/.claude/CLAUDE.md" 644
      install_file ${./ai-agents/shared-memory.md} "$HOME/.config/ai-agents/shared-memory.md" 644
    '';
  };
in
{
  home.packages = [ aiAgentsSync ];
}
