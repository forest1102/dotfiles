rec {
  envOrNull =
    name:
    let
      value = builtins.getEnv name;
    in
    if value == "" then null else value;

  envFirstOrNull =
    names:
    let
      values = builtins.filter (value: value != null) (map envOrNull names);
    in
    if values == [ ] then null else builtins.head values;

  envFirstOrThrow =
    names:
    let
      value = envFirstOrNull names;
    in
    if value == null then
      throw "None of these environment variables are set: ${builtins.concatStringsSep ", " names}. Use --impure."
    else
      value;
}
