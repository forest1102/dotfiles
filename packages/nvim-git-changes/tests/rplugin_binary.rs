use std::io::{Read, Write};
use std::process::{Command, Stdio};

use rmpv::Value;

#[test]
fn rplugin_binary_responds_to_specs_request() {
    let binary = env!("CARGO_BIN_EXE_nvim-git-changes-rplugin");
    let mut child = Command::new(binary)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .spawn()
        .expect("rplugin should start");

    let request = Value::Array(vec![
        Value::from(0),
        Value::from(7),
        Value::from("specs"),
        Value::Array(Vec::new()),
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
            >= 2
    );

    let status = child.wait().expect("child should exit");
    assert!(status.success());
}
