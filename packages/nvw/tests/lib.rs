use std::path::{Path, PathBuf};

use clap::Parser;
use nvw::{
    init_environment, main_root_from_git_common_dir, sanitize_worktree_name, trim_line_endings,
    worktree_add_args, worktree_path, Cli,
};

#[test]
fn parses_branch_with_default_base() {
    let cli = Cli::try_parse_from(["nvw", "feature/example"]).expect("arguments should parse");

    assert_eq!(cli.branch, "feature/example");
    assert_eq!(cli.base, "HEAD");
}

#[test]
fn parses_branch_with_explicit_base() {
    let cli = Cli::try_parse_from(["nvw", "feature/example", "origin/main"])
        .expect("arguments should parse");

    assert_eq!(cli.branch, "feature/example");
    assert_eq!(cli.base, "origin/main");
}

#[test]
fn rejects_missing_branch() {
    let error = Cli::try_parse_from(["nvw"]).expect_err("branch is required");

    assert_eq!(
        error.kind(),
        clap::error::ErrorKind::MissingRequiredArgument
    );
    assert_eq!(error.exit_code(), 2);
    assert!(error.to_string().contains("Usage: nvw"));
}

#[test]
fn rejects_unexpected_extra_args() {
    let error = Cli::try_parse_from(["nvw", "feature/example", "origin/main", "ignored"])
        .expect_err("extra arguments should be rejected");

    assert_eq!(error.kind(), clap::error::ErrorKind::UnknownArgument);
    assert_eq!(error.exit_code(), 2);
}

#[test]
fn sanitizes_branch_names_for_worktree_directories() {
    assert_eq!(sanitize_worktree_name("feature/foo bar"), "feature-foo-bar");
    assert_eq!(sanitize_worktree_name("topic///branch"), "topic-branch");
    assert_eq!(sanitize_worktree_name("fix:#123"), "fix-123");
    assert_eq!(sanitize_worktree_name("release_1.2.3"), "release_1.2.3");
}

#[test]
fn uses_fallback_for_empty_sanitized_name() {
    assert_eq!(sanitize_worktree_name(""), "worktree");
}

#[test]
fn derives_main_root_from_git_common_dir() {
    assert_eq!(
        main_root_from_git_common_dir(Path::new("/repo/.git")),
        Some(PathBuf::from("/repo"))
    );
}

#[test]
fn derives_worktree_path_under_main_root() {
    assert_eq!(
        worktree_path(Path::new("/repo"), "feature/foo bar"),
        PathBuf::from("/repo/.worktree/feature-foo-bar")
    );
}

#[test]
fn trims_only_trailing_line_endings_from_git_output() {
    assert_eq!(
        trim_line_endings(" /repo with spaces \n"),
        " /repo with spaces "
    );
    assert_eq!(
        trim_line_endings(" /repo with spaces \r\n"),
        " /repo with spaces "
    );
}

#[test]
fn builds_existing_branch_worktree_args() {
    let args = worktree_add_args(true, Path::new("/repo/.worktree/topic"), "topic", "HEAD");

    assert_eq!(
        args,
        vec!["worktree", "add", "/repo/.worktree/topic", "topic"]
    );
}

#[test]
fn builds_new_branch_worktree_args() {
    let args = worktree_add_args(
        false,
        Path::new("/repo/.worktree/topic"),
        "topic",
        "origin/main",
    );

    assert_eq!(
        args,
        vec![
            "worktree",
            "add",
            "-b",
            "topic",
            "/repo/.worktree/topic",
            "origin/main",
        ]
    );
}

#[test]
fn builds_init_environment() {
    let env = init_environment(
        Path::new("/repo"),
        Path::new("/repo/.worktree/topic"),
        "topic",
        "HEAD",
    );

    assert_eq!(
        env,
        vec![
            ("WORKTREE_MAIN_ROOT".to_string(), "/repo".to_string()),
            (
                "WORKTREE_PATH".to_string(),
                "/repo/.worktree/topic".to_string()
            ),
            ("WORKTREE_BRANCH".to_string(), "topic".to_string()),
            ("WORKTREE_BASE".to_string(), "HEAD".to_string()),
        ]
    );
}
