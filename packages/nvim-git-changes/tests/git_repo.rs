use std::path::Path;
use std::process::Command;

use nvim_git_changes::git::{changed_files, head_file};
use nvim_git_changes::porcelain::FileStatus;
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
        &["config", "user.email", "nvim-git-changes@example.invalid"],
    );
    run_git(temp.path(), &["config", "user.name", "nvim-git-changes"]);
    std::fs::create_dir_all(temp.path().join("src")).expect("src dir should be created");
    std::fs::write(temp.path().join("src/changed.rs"), "before\n")
        .expect("tracked file should be written");
    std::fs::write(temp.path().join("src/old.rs"), "rename before\n")
        .expect("renamed file should be written");
    std::fs::write(temp.path().join("delete-me.txt"), "delete before\n")
        .expect("deleted file should be written");
    run_git(temp.path(), &["add", "."]);
    run_git(temp.path(), &["commit", "-m", "initial"]);
    temp
}

#[test]
fn lists_changed_files_from_git_repo() {
    let repo = init_repo();
    std::fs::write(repo.path().join("src/changed.rs"), "after\n")
        .expect("tracked file should be modified");
    run_git(repo.path(), &["mv", "src/old.rs", "src/new.rs"]);
    std::fs::remove_file(repo.path().join("delete-me.txt")).expect("file should be deleted");
    std::fs::write(repo.path().join("notes new.md"), "new\n")
        .expect("untracked file should be written");

    let files = changed_files(repo.path()).expect("changed files should be returned");

    assert!(files
        .iter()
        .any(|file| file.file == "src/changed.rs" && file.status == FileStatus::Modified));
    assert!(files.iter().any(|file| {
        file.file == "src/new.rs"
            && file.old_file.as_deref() == Some("src/old.rs")
            && file.status == FileStatus::Renamed
    }));
    assert!(files
        .iter()
        .any(|file| file.file == "delete-me.txt" && file.deleted));
    assert!(files
        .iter()
        .any(|file| file.file == "notes new.md" && file.untracked));
}

#[test]
fn reads_head_file_lines_for_tracked_file() {
    let repo = init_repo();

    let head = head_file(repo.path(), "src/changed.rs").expect("head file should be read");

    assert_eq!(head.lines, vec!["before"]);
    assert!(!head.binary);
}

#[test]
fn returns_empty_text_for_missing_head_file() {
    let repo = init_repo();

    let head = head_file(repo.path(), "new-file.rs").expect("missing head file should be empty");

    assert_eq!(head.lines, Vec::<String>::new());
    assert!(!head.binary);
}

#[test]
fn reports_error_outside_git_repo() {
    let temp = TempDir::new().expect("tempdir should be created");

    let error = changed_files(temp.path()).expect_err("outside repo should fail");

    assert!(error.to_string().contains("not inside a git repository"));
}
