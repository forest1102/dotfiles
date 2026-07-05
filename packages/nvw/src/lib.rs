use std::path::{Path, PathBuf};

use clap::Parser;

#[derive(Debug, Parser, PartialEq, Eq)]
#[command(name = "nvw")]
pub struct Cli {
    #[arg(value_name = "BRANCH")]
    pub branch: String,

    #[arg(value_name = "BASE", default_value = "HEAD")]
    pub base: String,
}

pub fn sanitize_worktree_name(value: &str) -> String {
    let mut sanitized = String::new();
    let mut previous_was_dash = false;

    for character in value.chars() {
        let next = if character == '/' || character.is_whitespace() {
            '-'
        } else if character.is_ascii_alphanumeric()
            || character == '.'
            || character == '_'
            || character == '-'
        {
            character
        } else {
            '-'
        };

        if next == '-' {
            if !previous_was_dash {
                sanitized.push(next);
                previous_was_dash = true;
            }
        } else {
            sanitized.push(next);
            previous_was_dash = false;
        }
    }

    if sanitized.is_empty() {
        "worktree".to_string()
    } else {
        sanitized
    }
}

pub fn main_root_from_git_common_dir(git_common_dir: &Path) -> Option<PathBuf> {
    git_common_dir.parent().map(Path::to_path_buf)
}

pub fn worktree_path(main_root: &Path, branch: &str) -> PathBuf {
    main_root
        .join(".worktree")
        .join(sanitize_worktree_name(branch))
}

pub fn trim_line_endings(value: &str) -> &str {
    value.trim_end_matches(['\r', '\n'])
}

pub fn worktree_add_args(
    branch_exists: bool,
    worktree_path: &Path,
    branch: &str,
    base: &str,
) -> Vec<String> {
    let path = worktree_path.to_string_lossy().into_owned();

    if branch_exists {
        vec![
            "worktree".to_string(),
            "add".to_string(),
            path,
            branch.to_string(),
        ]
    } else {
        vec![
            "worktree".to_string(),
            "add".to_string(),
            "-b".to_string(),
            branch.to_string(),
            path,
            base.to_string(),
        ]
    }
}

pub fn init_environment(
    main_root: &Path,
    worktree_path: &Path,
    branch: &str,
    base: &str,
) -> Vec<(String, String)> {
    vec![
        (
            "WORKTREE_MAIN_ROOT".to_string(),
            main_root.to_string_lossy().into_owned(),
        ),
        (
            "WORKTREE_PATH".to_string(),
            worktree_path.to_string_lossy().into_owned(),
        ),
        ("WORKTREE_BRANCH".to_string(), branch.to_string()),
        ("WORKTREE_BASE".to_string(), base.to_string()),
    ]
}
