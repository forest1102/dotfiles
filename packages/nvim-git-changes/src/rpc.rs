use std::path::Path;

use rmpv::Value;

use crate::git::{changed_files, head_file, repo_root};
use crate::porcelain::ChangedFile;

const LUA_RECEIVER: &str = "require(\"dotfiles.git\")._nvim_git_changes_receive(...)";

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RpcError {
    message: String,
}

impl RpcError {
    fn new(message: impl Into<String>) -> Self {
        Self {
            message: message.into(),
        }
    }
}

impl std::fmt::Display for RpcError {
    fn fmt(&self, formatter: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        formatter.write_str(&self.message)
    }
}

impl std::error::Error for RpcError {}

pub fn rplugin_specs() -> Vec<Value> {
    vec![
        function_spec("NvimGitChangesList", false),
        function_spec("NvimGitChangesHead", false),
    ]
}

pub fn handle_message(cwd: &Path, message: Value) -> Result<Vec<Value>, RpcError> {
    let values = message
        .as_array()
        .ok_or_else(|| RpcError::new("nvim-git-changes: rpc message must be an array"))?;
    let message_type = values
        .first()
        .and_then(Value::as_i64)
        .ok_or_else(|| RpcError::new("nvim-git-changes: rpc message type must be an integer"))?;

    match message_type {
        0 => handle_request(cwd, values),
        2 => handle_notification(cwd, values),
        _ => Err(RpcError::new(
            "nvim-git-changes: only rpc requests and notifications are supported",
        )),
    }
}

fn handle_request(_cwd: &Path, values: &[Value]) -> Result<Vec<Value>, RpcError> {
    if values.len() != 4 {
        return Err(RpcError::new(
            "nvim-git-changes: rpc request must have 4 items",
        ));
    }
    let request_id = values[1].clone();
    let method = values[2]
        .as_str()
        .ok_or_else(|| RpcError::new("nvim-git-changes: rpc request method must be a string"))?;

    let (error, result) = if method == "specs" {
        (Value::Nil, Value::Array(rplugin_specs()))
    } else {
        (
            Value::from(format!("unknown request method: {method}")),
            Value::Nil,
        )
    };

    Ok(vec![Value::Array(vec![
        Value::from(1),
        request_id,
        error,
        result,
    ])])
}

fn handle_notification(cwd: &Path, values: &[Value]) -> Result<Vec<Value>, RpcError> {
    if values.len() != 3 {
        return Err(RpcError::new(
            "nvim-git-changes: rpc notification must have 3 items",
        ));
    }
    let method = values[1].as_str().ok_or_else(|| {
        RpcError::new("nvim-git-changes: rpc notification method must be a string")
    })?;
    let params = values[2]
        .as_array()
        .ok_or_else(|| RpcError::new("nvim-git-changes: rpc notification params must be an array"))?
        .clone();
    let args = normalize_function_args(params);

    if method.ends_with("NvimGitChangesList") {
        return Ok(vec![lua_completion(list_payload(cwd, args))]);
    }
    if method.ends_with("NvimGitChangesHead") {
        return Ok(vec![lua_completion(head_payload(cwd, args))]);
    }

    Err(RpcError::new(format!(
        "unknown notification method: {method}"
    )))
}

fn list_payload(cwd: &Path, args: Vec<Value>) -> Value {
    let request_id = string_arg(&args, 0).unwrap_or_default();
    let cwd_arg = string_arg(&args, 1).unwrap_or_else(|| cwd.to_string_lossy().into_owned());
    let cwd = Path::new(&cwd_arg);

    match repo_root(cwd).and_then(|root| {
        changed_files(cwd).map(|files| {
            success_payload(vec![
                ("kind", Value::from("list")),
                ("request_id", Value::from(request_id.as_str())),
                ("cwd", Value::from(cwd_arg.as_str())),
                ("root", Value::from(root.to_string_lossy().into_owned())),
                (
                    "files",
                    Value::Array(files.into_iter().map(changed_file_value).collect()),
                ),
            ])
        })
    }) {
        Ok(payload) => payload,
        Err(error) => error_payload("list", &request_id, error.to_string()),
    }
}

fn head_payload(cwd: &Path, args: Vec<Value>) -> Value {
    let request_id = string_arg(&args, 0).unwrap_or_default();
    let cwd_arg = string_arg(&args, 1).unwrap_or_else(|| cwd.to_string_lossy().into_owned());
    let file = string_arg(&args, 2).unwrap_or_default();
    let old_file = string_arg(&args, 3).unwrap_or_else(|| file.clone());

    match head_file(Path::new(&cwd_arg), &old_file) {
        Ok(head) => success_payload(vec![
            ("kind", Value::from("head")),
            ("request_id", Value::from(request_id.as_str())),
            ("cwd", Value::from(cwd_arg.as_str())),
            ("file", Value::from(file.as_str())),
            ("old_file", Value::from(old_file.as_str())),
            (
                "lines",
                Value::Array(head.lines.into_iter().map(Value::from).collect()),
            ),
            ("binary", Value::from(head.binary)),
        ]),
        Err(error) => error_payload("head", &request_id, error.to_string()),
    }
}

fn function_spec(name: &str, sync: bool) -> Value {
    Value::Map(vec![
        (Value::from("type"), Value::from("function")),
        (Value::from("name"), Value::from(name)),
        (Value::from("sync"), Value::from(sync)),
        (Value::from("opts"), Value::Map(Vec::new())),
    ])
}

fn lua_completion(payload: Value) -> Value {
    Value::Array(vec![
        Value::from(2),
        Value::from("nvim_exec_lua"),
        Value::Array(vec![Value::from(LUA_RECEIVER), Value::Array(vec![payload])]),
    ])
}

fn success_payload(fields: Vec<(&str, Value)>) -> Value {
    let mut map = vec![(Value::from("ok"), Value::from(true))];
    map.extend(
        fields
            .into_iter()
            .map(|(key, value)| (Value::from(key), value)),
    );
    Value::Map(map)
}

fn error_payload(kind: &str, request_id: &str, error: String) -> Value {
    Value::Map(vec![
        (Value::from("ok"), Value::from(false)),
        (Value::from("kind"), Value::from(kind)),
        (Value::from("request_id"), Value::from(request_id)),
        (Value::from("error"), Value::from(error)),
    ])
}

fn changed_file_value(file: ChangedFile) -> Value {
    Value::Map(vec![
        (Value::from("file"), Value::from(file.file)),
        (
            Value::from("old_file"),
            file.old_file.map(Value::from).unwrap_or(Value::Nil),
        ),
        (Value::from("status"), Value::from(file.status.code())),
        (Value::from("label"), Value::from(file.label)),
        (Value::from("dir"), Value::from(false)),
        (Value::from("deleted"), Value::from(file.deleted)),
        (Value::from("untracked"), Value::from(file.untracked)),
    ])
}

fn normalize_function_args(args: Vec<Value>) -> Vec<Value> {
    if args.len() == 1 {
        if let Some(values) = args[0].as_array() {
            return values.clone();
        }
    }
    args
}

fn string_arg(args: &[Value], index: usize) -> Option<String> {
    args.get(index).and_then(Value::as_str).map(str::to_string)
}
