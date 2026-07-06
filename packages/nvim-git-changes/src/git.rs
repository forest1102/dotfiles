use std::fmt;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};

use crate::porcelain::{parse_status, ChangedFile};

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct HeadFile {
    pub lines: Vec<String>,
    pub binary: bool,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct GitError {
    message: String,
}

impl GitError {
    fn new(message: impl Into<String>) -> Self {
        Self {
            message: message.into(),
        }
    }
}

impl fmt::Display for GitError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str(&self.message)
    }
}

impl std::error::Error for GitError {}

pub fn repo_root(cwd: &Path) -> Result<PathBuf, GitError> {
    let output = Command::new("git")
        .args(["rev-parse", "--show-toplevel"])
        .current_dir(cwd)
        .stdin(Stdio::null())
        .output()
        .map_err(|error| GitError::new(format!("git: failed to run git: {error}")))?;

    if !output.status.success() {
        return Err(GitError::new("git: not inside a git repository"));
    }

    let root = String::from_utf8_lossy(&output.stdout)
        .trim_end_matches(['\r', '\n'])
        .to_string();
    if root.is_empty() {
        Err(GitError::new("git: not inside a git repository"))
    } else {
        Ok(PathBuf::from(root))
    }
}

pub fn changed_files(cwd: &Path) -> Result<Vec<ChangedFile>, GitError> {
    let root = repo_root(cwd)?;
    let output = Command::new("git")
        .args([
            "status",
            "--porcelain=v2",
            "-z",
            "--untracked-files=all",
            "--renames",
        ])
        .current_dir(&root)
        .stdin(Stdio::null())
        .output()
        .map_err(|error| GitError::new(format!("git: failed to run git status: {error}")))?;

    if !output.status.success() {
        return Err(command_error("git: git status failed", &output.stderr));
    }

    let mut files = parse_status(&output.stdout).map_err(GitError::new)?;
    files.sort_by(|left, right| left.file.cmp(&right.file));
    Ok(files)
}

pub fn head_file(cwd: &Path, file: &str) -> Result<HeadFile, GitError> {
    let root = repo_root(cwd)?;
    let spec = format!("HEAD:{file}");
    let output = Command::new("git")
        .args(["-C", root.to_string_lossy().as_ref(), "show", spec.as_str()])
        .stdin(Stdio::null())
        .output()
        .map_err(|error| GitError::new(format!("git: failed to run git show: {error}")))?;

    if !output.status.success() {
        return Ok(HeadFile {
            lines: Vec::new(),
            binary: false,
        });
    }

    match String::from_utf8(output.stdout) {
        Ok(text) => Ok(HeadFile {
            lines: text.lines().map(str::to_string).collect(),
            binary: false,
        }),
        Err(_) => Ok(HeadFile {
            lines: Vec::new(),
            binary: true,
        }),
    }
}

fn command_error(fallback: &str, stderr: &[u8]) -> GitError {
    let stderr = String::from_utf8_lossy(stderr);
    let message = stderr.trim();
    if message.is_empty() {
        GitError::new(fallback)
    } else {
        GitError::new(format!("git: {message}"))
    }
}
