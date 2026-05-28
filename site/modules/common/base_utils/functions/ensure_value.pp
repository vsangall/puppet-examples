# Puppet 4+ function: return a default value if input is undef or empty.
function base_utils::ensure_value(
  Optional[String] $input,
  String           $default_value,
) >> String {
  if $input =~ Undef or $input == '' {
    $default_value
  } else {
    $input
  }
}
