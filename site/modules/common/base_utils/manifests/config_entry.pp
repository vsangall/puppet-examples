# Defined type: manage a key=value entry in a configuration file.
# Demonstrates the `define` keyword for reusable resource patterns.
define base_utils::config_entry (
  Stdlib::Absolutepath     $file,
  String                   $key,
  String                   $value,
  String                   $separator = '=',
  Enum['present','absent'] $ensure    = 'present',
) {

  case $ensure {
    'present': {
      file_line { "config_entry_${file}_${key}":
        ensure => present,
        path   => $file,
        line   => "${key}${separator}${value}",
        match  => "^${key}${separator}",
      }
    }
    'absent': {
      file_line { "config_entry_${file}_${key}":
        ensure            => absent,
        path              => $file,
        match             => "^${key}${separator}",
        match_for_absence => true,
      }
    }
    default: {
      fail("Invalid ensure value: ${ensure}")
    }
  }
}
