use std::path::Path;

use nvim_git_changes::rpc::{handle_message, rplugin_specs};
use rmpv::Value;

#[test]
fn exposes_async_remote_function_specs() {
    let specs = rplugin_specs();

    assert!(specs.iter().any(|spec| {
        let Some(spec) = spec.as_map() else {
            return false;
        };
        spec.contains(&(Value::from("name"), Value::from("NvimGitChangesList")))
            && spec.contains(&(Value::from("sync"), Value::from(false)))
    }));
    assert!(specs.iter().any(|spec| {
        let Some(spec) = spec.as_map() else {
            return false;
        };
        spec.contains(&(Value::from("name"), Value::from("NvimGitChangesHead")))
            && spec.contains(&(Value::from("sync"), Value::from(false)))
    }));
}

#[test]
fn responds_to_specs_request() {
    let messages = handle_message(
        Path::new("."),
        Value::Array(vec![
            Value::from(0),
            Value::from(9),
            Value::from("specs"),
            Value::Array(Vec::new()),
        ]),
    )
    .expect("specs should be handled");

    assert_eq!(messages.len(), 1);
    let response = messages[0].as_array().expect("response should be array");
    assert_eq!(response[0].as_i64(), Some(1));
    assert_eq!(response[1].as_i64(), Some(9));
    assert!(response[2].is_nil());
    assert!(response[3].as_array().is_some());
}

#[test]
fn handles_async_list_notification_without_response() {
    let messages = handle_message(
        Path::new("/"),
        Value::Array(vec![
            Value::from(2),
            Value::from("NvimGitChangesList"),
            Value::Array(vec![Value::Array(vec![
                Value::from("request-1"),
                Value::from("/"),
            ])]),
        ]),
    )
    .expect("notification should be handled");

    assert_eq!(messages.len(), 1);
    let notification = messages[0]
        .as_array()
        .expect("completion should be notification");
    assert_eq!(notification[0].as_i64(), Some(2));
    assert_eq!(notification[1].as_str(), Some("nvim_exec_lua"));
    let params = notification[2].as_array().expect("params should be array");
    assert_eq!(
        params[0].as_str(),
        Some("require(\"dotfiles.git\")._nvim_git_changes_receive(...)")
    );
    let args = params[1].as_array().expect("lua args should be array");
    let payload = args[0].as_map().expect("payload should be map");
    assert!(payload.contains(&(Value::from("ok"), Value::from(false))));
    assert!(payload.contains(&(Value::from("kind"), Value::from("list"))));
    assert!(payload.contains(&(Value::from("request_id"), Value::from("request-1"))));
}
