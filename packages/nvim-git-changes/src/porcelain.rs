#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ChangedFile {
    pub file: String,
    pub old_file: Option<String>,
    pub status: FileStatus,
    pub label: String,
    pub deleted: bool,
    pub untracked: bool,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum FileStatus {
    Modified,
    Added,
    Deleted,
    Renamed,
    Untracked,
}

impl FileStatus {
    pub fn code(self) -> &'static str {
        match self {
            Self::Modified => "M",
            Self::Added => "A",
            Self::Deleted => "D",
            Self::Renamed => "R",
            Self::Untracked => "??",
        }
    }
}

pub fn parse_status(output: &[u8]) -> Result<Vec<ChangedFile>, String> {
    let mut chunks = output
        .split(|byte| *byte == 0)
        .filter(|chunk| !chunk.is_empty());
    let mut files = Vec::new();

    while let Some(chunk) = chunks.next() {
        let record = std::str::from_utf8(chunk)
            .map_err(|error| format!("git status output is not utf-8: {error}"))?;

        if let Some(path) = record.strip_prefix("? ") {
            files.push(changed_file(path, None, FileStatus::Untracked));
            continue;
        }

        if record.starts_with("1 ") {
            files.push(parse_ordinary_record(record)?);
            continue;
        }

        if record.starts_with("2 ") {
            let old_path = chunks
                .next()
                .ok_or_else(|| "git rename record is missing old path".to_string())
                .and_then(|path| {
                    std::str::from_utf8(path)
                        .map(str::to_string)
                        .map_err(|error| format!("git rename old path is not utf-8: {error}"))
                })?;
            files.push(parse_rename_record(record, old_path)?);
        }
    }

    Ok(files)
}

fn parse_ordinary_record(record: &str) -> Result<ChangedFile, String> {
    let mut parts = record.splitn(9, ' ');
    let _record_type = parts.next();
    let xy = parts
        .next()
        .ok_or_else(|| format!("git status record is missing status: {record}"))?;
    for _ in 0..6 {
        parts.next();
    }
    let path = parts
        .next()
        .ok_or_else(|| format!("git status record is missing path: {record}"))?;

    Ok(changed_file(path, None, status_from_xy(xy)))
}

fn parse_rename_record(record: &str, old_path: String) -> Result<ChangedFile, String> {
    let mut parts = record.splitn(10, ' ');
    let _record_type = parts.next();
    let xy = parts
        .next()
        .ok_or_else(|| format!("git rename record is missing status: {record}"))?;
    for _ in 0..7 {
        parts.next();
    }
    let path = parts
        .next()
        .ok_or_else(|| format!("git rename record is missing path: {record}"))?;

    let status = if xy.contains('R') {
        FileStatus::Renamed
    } else {
        status_from_xy(xy)
    };
    Ok(changed_file(path, Some(old_path), status))
}

fn status_from_xy(xy: &str) -> FileStatus {
    if xy.contains('R') {
        FileStatus::Renamed
    } else if xy.contains('D') {
        FileStatus::Deleted
    } else if xy.contains('A') {
        FileStatus::Added
    } else {
        FileStatus::Modified
    }
}

fn changed_file(path: &str, old_file: Option<String>, status: FileStatus) -> ChangedFile {
    let label = if status == FileStatus::Renamed {
        match old_file.as_deref() {
            Some(old_path) => format!("{} {} -> {}", status.code(), old_path, path),
            None => format!("{} {}", status.code(), path),
        }
    } else {
        format!("{} {}", status.code(), path)
    };

    ChangedFile {
        file: path.to_string(),
        old_file,
        status,
        label,
        deleted: status == FileStatus::Deleted,
        untracked: status == FileStatus::Untracked,
    }
}
