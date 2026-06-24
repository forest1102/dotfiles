{ lib }:

{
  withDefaultAlias =
    name: value:
    {
      default = value;
    }
    // lib.optionalAttrs (name != "default") {
      ${name} = value;
    };
}
