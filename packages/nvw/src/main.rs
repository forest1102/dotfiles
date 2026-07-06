use std::env;
use std::io::{self, ErrorKind, Write};
use std::path::{Path, PathBuf};
use std::process::{self, Command};

use clap::Parser;
use nvw::{ensure_worktree, handle_rpc_message, Cli};

fn main() {
    if is_rplugin_binary() {
        if let Err(error) = run_rplugin() {
            eprintln!("{error}");
            process::exit(1);
        }
        return;
    }

    let cli = Cli::parse();
    let worktree_path =
        ensure_worktree(Path::new("."), &cli.branch, &cli.base).unwrap_or_else(|error| {
            eprintln!("{error}");
            process::exit(1);
        });

    exec_nvim(&worktree_path);
}

fn is_rplugin_binary() -> bool {
    if env::var_os("NVW_RPLUGIN").is_some() {
        return true;
    }

    env::args_os()
        .next()
        .map(PathBuf::from)
        .and_then(|path| path.file_name().map(|name| name == "nvw-rplugin"))
        .unwrap_or(false)
}

fn run_rplugin() -> Result<(), String> {
    let stdin = io::stdin();
    let stdout = io::stdout();
    let mut reader = stdin.lock();
    let mut writer = stdout.lock();

    loop {
        let message = match rmpv::decode::read_value(&mut reader) {
            Ok(message) => message,
            Err(error) if error.kind() == ErrorKind::UnexpectedEof => return Ok(()),
            Err(error) => return Err(format!("nvw-rplugin: failed to read rpc message: {error}")),
        };

        let response = handle_rpc_message(Path::new("."), message)
            .map_err(|error| format!("nvw-rplugin: failed to handle rpc message: {error}"))?;
        rmpv::encode::write_value(&mut writer, &response)
            .map_err(|error| format!("nvw-rplugin: failed to write rpc response: {error}"))?;
        writer
            .flush()
            .map_err(|error| format!("nvw-rplugin: failed to flush rpc response: {error}"))?;
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
