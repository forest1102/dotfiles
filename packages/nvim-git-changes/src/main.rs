use std::io::{self, ErrorKind, Write};
use std::path::Path;
use std::process;

use nvim_git_changes::rpc::handle_message;

fn main() {
    if let Err(error) = run() {
        eprintln!("{error}");
        process::exit(1);
    }
}

fn run() -> Result<(), String> {
    let stdin = io::stdin();
    let stdout = io::stdout();
    let mut reader = stdin.lock();
    let mut writer = stdout.lock();

    loop {
        let message = match rmpv::decode::read_value(&mut reader) {
            Ok(message) => message,
            Err(error) if error.kind() == ErrorKind::UnexpectedEof => return Ok(()),
            Err(error) => {
                return Err(format!(
                    "nvim-git-changes: failed to read rpc message: {error}"
                ))
            }
        };

        let messages = handle_message(Path::new("."), message)
            .map_err(|error| format!("nvim-git-changes: failed to handle rpc message: {error}"))?;
        for message in messages {
            rmpv::encode::write_value(&mut writer, &message).map_err(|error| {
                format!("nvim-git-changes: failed to write rpc message: {error}")
            })?;
        }
        writer
            .flush()
            .map_err(|error| format!("nvim-git-changes: failed to flush rpc message: {error}"))?;
    }
}
