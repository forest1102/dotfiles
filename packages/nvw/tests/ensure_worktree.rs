use std::path::Path;
use std::process::Command;

use nvw::ensure_worktree;
use tempfile::TempDir;

fn run_git(repo: &Path, args: &[&str]) {
    let output = Command::new("git")
        .args(args)
        .current_dir(repo)
        .output()
        .expect("git should run");

    assert!(
        output.status.success(),
        "git {:?} failed\nstdout:\n{}\nstderr:\n{}",
        args,
        String::from_utf8_lossy(&output.stdout),
        String::from_utf8_lossy(&output.stderr)
    );
}

fn init_repo() -> TempDir {
    let temp = TempDir::new().expect("tempdir should be created");
    run_git(temp.path(), &["init"]);
    run_git(
        temp.path(),
        &["config", "user.email", "nvw@example.invalid"],
    );
    run_git(temp.path(), &["config", "user.name", "nvw"]);
    std::fs::write(temp.path().join("README.md"), "hello\n").expect("readme should be written");
    run_git(temp.path(), &["add", "README.md"]);
    run_git(temp.path(), &["commit", "-m", "initial"]);
    temp
}

#[test]
fn creates_new_branch_worktree_and_returns_path() {
    let repo = init_repo();
    let repo_path = repo
        .path()
        .canonicalize()
        .expect("repo path should resolve");

    let path = ensure_worktree(repo.path(), "feature/example", "HEAD")
        .expect("worktree should be created");

    assert_eq!(path, repo_path.join(".worktree").join("feature-example"));
    assert!(path.is_dir());
    run_git(
        repo.path(),
        &[
            "show-ref",
            "--verify",
            "--quiet",
            "refs/heads/feature/example",
        ],
    );
}

#[test]
fn reuses_existing_worktree_without_rerunning_init_script() {
    let repo = init_repo();
    let worktree_dir = repo.path().join(".worktree");
    std::fs::create_dir_all(&worktree_dir).expect("worktree dir should be created");
    std::fs::write(
        worktree_dir.join("init.sh"),
        "printf x >> \"$WORKTREE_MAIN_ROOT/.worktree/init-count\"\n",
    )
    .expect("init script should be written");

    let first = ensure_worktree(repo.path(), "feature/reuse", "HEAD")
        .expect("first ensure should create worktree");
    let second = ensure_worktree(repo.path(), "feature/reuse", "HEAD")
        .expect("second ensure should reuse worktree");

    assert_eq!(first, second);
    assert_eq!(
        std::fs::read_to_string(worktree_dir.join("init-count")).expect("init count should exist"),
        "x"
    );
}
