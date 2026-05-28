# Defined type: conditional notification (only fires when debug fact is set).
# Avoids excessive Puppet master load from unconditional notify resources.
define base_utils::managed_notify () {
  if $facts['base_utils_debug'] == '1' or $facts['base_utils_debug'] == 'true' {
    notify { $title:
      message => $title,
    }
  }
}
