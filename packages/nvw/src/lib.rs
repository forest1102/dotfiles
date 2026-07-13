use std::fmt;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};

use clap::Parser;
use rmpv::Value;

#[derive(Debug, Parser, PartialEq, Eq)]
#[command(name = "nvw")]
pub struct Cli {
    #[arg(value_name = "BRANCH")]
    pub branch: String,

    #[arg(value_name = "BASE", default_value = "HEAD")]
    pub base: String,
}

#[derive(Debug, PartialEq, Eq)]
pub struct NvwError {
    message: String,
}

impl NvwError {
    fn new(message: impl Into<String>) -> Self {
        Self {
            message: message.into(),
        }
    }
}

impl fmt::Display for NvwError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str(&self.message)
    }
}

impl std::error::Error for NvwError {}

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

pub fn ensure_worktree(cwd: &Path, branch: &str, base: &str) -> Result<PathBuf, NvwError> {
    if !git_status(cwd, ["rev-parse", "--show-toplevel"]) {
        return Err(NvwError::new("nvw: not inside a git repository"));
    }

    let git_common_dir = PathBuf::from(git_output(
        cwd,
        ["rev-parse", "--path-format=absolute", "--git-common-dir"],
    )?);
    let Some(main_root) = main_root_from_git_common_dir(&git_common_dir) else {
        return Err(NvwError::new(format!(
            "nvw: could not determine main worktree from {}",
            git_common_dir.display()
        )));
    };

    let worktree_dir = main_root.join(".worktree");
    let worktree_path = worktree_path(&main_root, branch);
    let init_script = worktree_dir.join("init.sh");

    fs::create_dir_all(&worktree_dir).map_err(|error| {
        NvwError::new(format!(
            "nvw: failed to create {}: {error}",
            worktree_dir.display()
        ))
    })?;

    if !worktree_path.exists() {
        add_worktree(cwd, &worktree_path, branch, base)?;
        run_init_script(&init_script, &main_root, &worktree_path, branch, base);
    }

    Ok(worktree_path)
}

pub fn rplugin_specs() -> Vec<Value> {
    vec![Value::Map(vec![
        (Value::from("type"), Value::from("function")),
        (Value::from("name"), Value::from("NvwEnsure")),
        (Value::from("sync"), Value::from(true)),
        (Value::from("opts"), Value::Map(Vec::new())),
    ])]
}

pub fn handle_rplugin_request(method: &str, args: Vec<Value>) -> Result<Value, Value> {
    if method == "specs" {
        return Ok(Value::Array(rplugin_specs()));
    }

    if !method.ends_with("NvwEnsure") {
        return Err(Value::from(format!("unknown method: {method}")));
    }

    let args = normalize_function_args(args);
    let Some(cwd) = args
        .first()
        .and_then(Value::as_str)
        .filter(|cwd| !cwd.is_empty())
    else {
        return Err(Value::from("NvwEnsure requires cwd"));
    };
    let Some(branch) = args.get(1).and_then(Value::as_str) else {
        return Err(Value::from("NvwEnsure requires branch"));
    };
    let base = args.get(2).and_then(Value::as_str).unwrap_or("HEAD");

    ensure_worktree(Path::new(cwd), branch, base)
        .map(|path| Value::from(path.to_string_lossy().into_owned()))
        .map_err(|error| Value::from(error.to_string()))
}

pub fn handle_rpc_message(message: Value) -> Result<Value, NvwError> {
    let values = message
        .as_array()
        .ok_or_else(|| NvwError::new("nvw-rplugin: rpc message must be an array"))?;
    if values.len() != 4 || values[0].as_i64() != Some(0) {
        return Err(NvwError::new(
            "nvw-rplugin: only rpc requests are supported",
        ));
    }

    let request_id = values[1].clone();
    let method = values[2]
        .as_str()
        .ok_or_else(|| NvwError::new("nvw-rplugin: rpc method must be a string"))?;
    let params = values[3]
        .as_array()
        .ok_or_else(|| NvwError::new("nvw-rplugin: rpc params must be an array"))?
        .clone();

    let (error, result) = match handle_rplugin_request(method, params) {
        Ok(result) => (Value::Nil, result),
        Err(error) => (error, Value::Nil),
    };

    Ok(Value::Array(vec![
        Value::from(1),
        request_id,
        error,
        result,
    ]))
}

fn normalize_function_args(args: Vec<Value>) -> Vec<Value> {
    if args.len() == 1 {
        if let Some(values) = args[0].as_array() {
            return values.clone();
        }
    }
    args
}

fn git_status<const N: usize>(cwd: &Path, args: [&str; N]) -> bool {
    Command::new("git")
        .args(args)
        .current_dir(cwd)
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()
        .is_ok_and(|status| status.success())
}

fn git_output<const N: usize>(cwd: &Path, args: [&str; N]) -> Result<String, NvwError> {
    let output = Command::new("git")
        .args(args)
        .current_dir(cwd)
        .stdin(Stdio::null())
        .output()
        .map_err(|error| NvwError::new(format!("nvw: failed to run git: {error}")))?;

    if !output.status.success() {
        return Err(command_error("nvw: git command failed", &output.stderr));
    }

    Ok(trim_line_endings(&String::from_utf8_lossy(&output.stdout)).to_string())
}

fn add_worktree(
    cwd: &Path,
    worktree_path: &Path,
    branch: &str,
    base: &str,
) -> Result<(), NvwError> {
    let branch_ref = format!("refs/heads/{branch}");
    let branch_exists = git_status(
        cwd,
        ["show-ref", "--verify", "--quiet", branch_ref.as_str()],
    );
    let output = Command::new("git")
        .args(worktree_add_args(
            branch_exists,
            worktree_path,
            branch,
            base,
        ))
        .current_dir(cwd)
        .output()
        .map_err(|error| NvwError::new(format!("nvw: failed to run git worktree add: {error}")))?;

    if output.status.success() {
        Ok(())
    } else {
        Err(command_error(
            "nvw: git worktree add failed",
            &output.stderr,
        ))
    }
}

fn run_init_script(
    init_script: &Path,
    main_root: &Path,
    worktree_path: &Path,
    branch: &str,
    base: &str,
) {
    if !init_script.is_file() {
        return;
    }

    let mut command = Command::new("sh");
    command.arg(init_script).current_dir(worktree_path);
    for (key, value) in init_environment(main_root, worktree_path, branch, base) {
        command.env(key, value);
    }

    match command.status() {
        Ok(status) if status.success() => {}
        Ok(status) => {
            eprintln!(
                "nvw: warning: .worktree/init.sh failed with exit status {}",
                status.code().unwrap_or(1)
            );
        }
        Err(error) => {
            eprintln!("nvw: warning: failed to run .worktree/init.sh: {error}");
        }
    }
}

fn command_error(fallback: &str, stderr: &[u8]) -> NvwError {
    let stderr = String::from_utf8_lossy(stderr);
    let message = stderr.trim();
    if message.is_empty() {
        NvwError::new(fallback)
    } else {
        NvwError::new(message.to_string())
    }
}
