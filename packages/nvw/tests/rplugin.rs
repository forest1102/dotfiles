use std::path::Path;
use std::process::Command;

use nvw::{handle_rpc_message, handle_rplugin_request, rplugin_specs};
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
fn exposes_nvw_ensure_function_spec() {
    let specs = rplugin_specs();

    let spec = specs
        .iter()
        .find_map(Value::as_map)
        .expect("spec should be a map");
    assert!(spec.contains(&(Value::from("type"), Value::from("function"),)));
    assert!(spec.contains(&(Value::from("name"), Value::from("NvwEnsure"),)));
    assert!(spec.contains(&(Value::from("sync"), Value::from(true))));
}

#[test]
fn handles_nvw_ensure_request_with_default_base() {
    let repo = init_repo();
    let repo_path = repo
        .path()
        .canonicalize()
        .expect("repo path should resolve");

    let result = handle_rplugin_request(
        "NvwEnsure",
        vec![
            Value::from(repo.path().to_string_lossy().into_owned()),
            Value::from("feature/rpc"),
        ],
    )
    .expect("request should succeed");

    assert_eq!(
        result.as_str(),
        Some(
            repo_path
                .join(".worktree")
                .join("feature-rpc")
                .to_string_lossy()
                .as_ref()
        )
    );
}

#[test]
fn uses_repository_cwd_from_nvw_ensure_arguments() {
    let requested_repo = init_repo();
    let requested_root = requested_repo
        .path()
        .canonicalize()
        .expect("requested repo path should resolve");

    let result = handle_rplugin_request(
        "NvwEnsure",
        vec![
            Value::from(requested_repo.path().to_string_lossy().into_owned()),
            Value::from("feature/requested-repo"),
        ],
    )
    .expect("request should succeed");

    assert_eq!(
        result.as_str(),
        Some(
            requested_root
                .join(".worktree")
                .join("feature-requested-repo")
                .to_string_lossy()
                .as_ref()
        )
    );
}

#[test]
fn rejects_nvw_ensure_request_without_cwd() {
    let error =
        handle_rplugin_request("NvwEnsure", Vec::new()).expect_err("missing cwd should fail");

    assert_eq!(error.as_str(), Some("NvwEnsure requires cwd"));
}

#[test]
fn rejects_nvw_ensure_request_with_empty_cwd() {
    let error = handle_rplugin_request(
        "NvwEnsure",
        vec![Value::from(""), Value::from("feature/empty-cwd")],
    )
    .expect_err("empty cwd should fail");

    assert_eq!(error.as_str(), Some("NvwEnsure requires cwd"));
}

#[test]
fn rejects_nvw_ensure_request_without_branch() {
    let error = handle_rplugin_request("NvwEnsure", vec![Value::from("/tmp/repo")])
        .expect_err("missing branch should fail");

    assert_eq!(error.as_str(), Some("NvwEnsure requires branch"));
}

#[test]
fn reports_git_errors_from_nvw_ensure_request() {
    let error = handle_rplugin_request(
        "NvwEnsure",
        vec![Value::from("/"), Value::from("feature/outside-repo")],
    )
    .expect_err("outside repo should fail");

    assert_eq!(error.as_str(), Some("nvw: not inside a git repository"));
}

#[test]
fn converts_rpc_request_to_success_response() {
    let repo = init_repo();

    let response = handle_rpc_message(Value::Array(vec![
        Value::from(0),
        Value::from(42),
        Value::from("NvwEnsure"),
        Value::Array(vec![
            Value::from(repo.path().to_string_lossy().into_owned()),
            Value::from("feature/message"),
        ]),
    ]))
    .expect("request should produce response");

    let values = response.as_array().expect("response should be an array");
    assert_eq!(values[0].as_i64(), Some(1));
    assert_eq!(values[1].as_i64(), Some(42));
    assert!(values[2].is_nil());
    assert!(values[3]
        .as_str()
        .expect("path should be returned")
        .contains("feature-message"));
}

#[test]
fn converts_rpc_request_to_error_response() {
    let response = handle_rpc_message(Value::Array(vec![
        Value::from(0),
        Value::from(43),
        Value::from("NvwEnsure"),
        Value::Array(Vec::new()),
    ]))
    .expect("request should produce response");

    let values = response.as_array().expect("response should be an array");
    assert_eq!(values[0].as_i64(), Some(1));
    assert_eq!(values[1].as_i64(), Some(43));
    assert_eq!(values[2].as_str(), Some("NvwEnsure requires cwd"));
    assert!(values[3].is_nil());
}
