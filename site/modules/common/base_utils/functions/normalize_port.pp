# Puppet 4+ function: normalize a port value to Integer.
# Accepts String or Integer input, returns validated Integer.
function base_utils::normalize_port(
  Variant[String, Integer] $port,
) >> Base_utils::Port {
  Integer($port)
}
