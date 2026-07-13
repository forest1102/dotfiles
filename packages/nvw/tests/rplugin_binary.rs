use std::io::{Read, Write};
use std::path::Path;
use std::process::{Command, Stdio};

use rmpv::Value;
use tempfile::TempDir;

fn run_git(repo: &Path, args: &[&str]) {
    let output = Command::new("git")
        .args(args)
        .current_dir(repo)
        .output()
        .expect("git should run");

    assert!(
        output.status.success(),
        "git {args:?} failed\nstdout:\n{}\nstderr:\n{}",
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
fn rplugin_binary_responds_to_specs_request() {
    let binary = env!("CARGO_BIN_EXE_nvw");
    let mut child = Command::new(binary)
        .env("NVW_RPLUGIN", "1")
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .spawn()
        .expect("nvw-rplugin should start");

    let request = Value::Array(vec![
        Value::from(0),
        Value::from(7),
        Value::from("specs"),
        Value::Array(vec![Value::from("/tmp/nvw-rplugin")]),
    ]);
    rmpv::encode::write_value(
        child.stdin.as_mut().expect("stdin should be open"),
        &request,
    )
    .expect("request should be written");
    child
        .stdin
        .take()
        .expect("stdin should be available")
        .flush()
        .expect("stdin should flush");

    let mut stdout = child.stdout.take().expect("stdout should be open");
    let response = rmpv::decode::read_value(&mut stdout).expect("response should decode");
    let mut remaining = Vec::new();
    stdout
        .read_to_end(&mut remaining)
        .expect("stdout should close");

    let values = response.as_array().expect("response should be array");
    assert_eq!(values[0].as_i64(), Some(1));
    assert_eq!(values[1].as_i64(), Some(7));
    assert!(values[2].is_nil());
    assert!(
        values[3]
            .as_array()
            .expect("spec result should be array")
            .len()
            > 0
    );

    let status = child.wait().expect("child should exit");
    assert!(status.success());
}

#[test]
fn rplugin_binary_uses_rpc_cwd_instead_of_process_cwd() {
    let process_repo = init_repo();
    let requested_repo = init_repo();
    let requested_root = requested_repo
        .path()
        .canonicalize()
        .expect("requested repo path should resolve");
    let binary = env!("CARGO_BIN_EXE_nvw");
    let mut child = Command::new(binary)
        .env("NVW_RPLUGIN", "1")
        .current_dir(process_repo.path())
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .spawn()
        .expect("nvw-rplugin should start");

    let request = Value::Array(vec![
        Value::from(0),
        Value::from(8),
        Value::from("NvwEnsure"),
        Value::Array(vec![
            Value::from(requested_repo.path().to_string_lossy().into_owned()),
            Value::from("feature/requested-repo"),
            Value::from("HEAD"),
        ]),
    ]);
    rmpv::encode::write_value(
        child.stdin.as_mut().expect("stdin should be open"),
        &request,
    )
    .expect("request should be written");
    child
        .stdin
        .take()
        .expect("stdin should be available")
        .flush()
        .expect("stdin should flush");

    let response = rmpv::decode::read_value(
        child
            .stdout
            .as_mut()
            .expect("stdout should remain available"),
    )
    .expect("response should decode");
    let values = response.as_array().expect("response should be array");
    assert_eq!(values[0].as_i64(), Some(1));
    assert_eq!(values[1].as_i64(), Some(8));
    assert!(values[2].is_nil(), "RPC error: {}", values[2]);

    let expected = requested_root
        .join(".worktree")
        .join("feature-requested-repo");
    assert_eq!(values[3].as_str(), Some(expected.to_string_lossy().as_ref()));
    assert!(expected.is_dir());
    assert!(!process_repo
        .path()
        .join(".worktree")
        .join("feature-requested-repo")
        .exists());

    let status = child.wait().expect("child should exit");
    assert!(status.success());
}
