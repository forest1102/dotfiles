use nvim_git_changes::porcelain::{parse_status, FileStatus};

#[test]
fn parses_modified_file_from_porcelain_v2_z_output() {
    let files = parse_status(b"1 .M N... 100644 100644 100644 abc abc src/main.rs\0")
        .expect("status should parse");

    assert_eq!(files.len(), 1);
    assert_eq!(files[0].file, "src/main.rs");
    assert_eq!(files[0].old_file, None);
    assert_eq!(files[0].status, FileStatus::Modified);
    assert_eq!(files[0].label, "M src/main.rs");
    assert!(!files[0].deleted);
    assert!(!files[0].untracked);
}

#[test]
fn parses_renamed_file_with_old_path() {
    let files = parse_status(
        b"2 R. N... 100644 100644 100644 abc abc R100 src/new name.rs\0src/old name.rs\0",
    )
    .expect("status should parse");

    assert_eq!(files.len(), 1);
    assert_eq!(files[0].file, "src/new name.rs");
    assert_eq!(files[0].old_file.as_deref(), Some("src/old name.rs"));
    assert_eq!(files[0].status, FileStatus::Renamed);
    assert_eq!(files[0].label, "R src/old name.rs -> src/new name.rs");
}

#[test]
fn parses_untracked_file() {
    let files = parse_status(b"? notes/today.md\0").expect("status should parse");

    assert_eq!(files.len(), 1);
    assert_eq!(files[0].file, "notes/today.md");
    assert_eq!(files[0].status, FileStatus::Untracked);
    assert_eq!(files[0].label, "?? notes/today.md");
    assert!(files[0].untracked);
}

#[test]
fn parses_deleted_file() {
    let files = parse_status(b"1 .D N... 100644 100644 000000 abc abc old.txt\0")
        .expect("status should parse");

    assert_eq!(files.len(), 1);
    assert_eq!(files[0].file, "old.txt");
    assert_eq!(files[0].status, FileStatus::Deleted);
    assert_eq!(files[0].label, "D old.txt");
    assert!(files[0].deleted);
}
