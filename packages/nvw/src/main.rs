use std::fs;
use std::path::{Path, PathBuf};
use std::process::{self, Command, Stdio};

use clap::Parser;
use nvw::{
    init_environment, main_root_from_git_common_dir, trim_line_endings, worktree_add_args,
    worktree_path, Cli,
};

fn main() {
    let cli = Cli::parse();

    if !git_status(["rev-parse", "--show-toplevel"]) {
        eprintln!("nvw: not inside a git repository");
        process::exit(1);
    }

    let git_common_dir =
        match git_output(["rev-parse", "--path-format=absolute", "--git-common-dir"]) {
            Ok(path) => PathBuf::from(path),
            Err(message) => {
                eprintln!("{message}");
                process::exit(1);
            }
        };

    let Some(main_root) = main_root_from_git_common_dir(&git_common_dir) else {
        eprintln!(
            "nvw: could not determine main worktree from {}",
            git_common_dir.display()
        );
        process::exit(1);
    };

    let worktree_dir = main_root.join(".worktree");
    let worktree_path = worktree_path(&main_root, &cli.branch);
    let init_script = worktree_dir.join("init.sh");

    if let Err(error) = fs::create_dir_all(&worktree_dir) {
        eprintln!("nvw: failed to create {}: {error}", worktree_dir.display());
        process::exit(1);
    }

    if !worktree_path.exists() {
        add_worktree(&worktree_path, &cli.branch, &cli.base);
        run_init_script(
            &init_script,
            &main_root,
            &worktree_path,
            &cli.branch,
            &cli.base,
        );
    }

    exec_nvim(&worktree_path);
}

fn git_status<const N: usize>(args: [&str; N]) -> bool {
    Command::new("git")
        .args(args)
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()
        .is_ok_and(|status| status.success())
}

fn git_output<const N: usize>(args: [&str; N]) -> Result<String, String> {
    let output = Command::new("git")
        .args(args)
        .stdin(Stdio::null())
        .output()
        .map_err(|error| format!("nvw: failed to run git: {error}"))?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        let message = stderr.trim();
        if message.is_empty() {
            return Err("nvw: git command failed".to_string());
        }
        return Err(message.to_string());
    }

    Ok(trim_line_endings(&String::from_utf8_lossy(&output.stdout)).to_string())
}

fn add_worktree(worktree_path: &Path, branch: &str, base: &str) {
    let branch_ref = format!("refs/heads/{branch}");
    let branch_exists = git_status(["show-ref", "--verify", "--quiet", branch_ref.as_str()]);
    let status = Command::new("git")
        .args(worktree_add_args(
            branch_exists,
            worktree_path,
            branch,
            base,
        ))
        .status();

    match status {
        Ok(status) if status.success() => {}
        Ok(status) => process::exit(status.code().unwrap_or(1)),
        Err(error) => {
            eprintln!("nvw: failed to run git worktree add: {error}");
            process::exit(1);
        }
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

#[cfg(unix)]
fn exec_nvim(path: &Path) -> ! {
    use std::os::unix::process::CommandExt;

    let error = Command::new("nvim").arg(path).exec();
    eprintln!("nvw: failed to exec nvim: {error}");
    process::exit(1);
}

#[cfg(not(unix))]
fn exec_nvim(path: &Path) -> ! {
    match Command::new("nvim").arg(path).status() {
        Ok(status) => process::exit(status.code().unwrap_or(1)),
        Err(error) => {
            eprintln!("nvw: failed to run nvim: {error}");
            process::exit(1);
        }
    }
}
