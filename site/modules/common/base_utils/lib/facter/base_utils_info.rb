# Custom fact: gathers base utility information from the system.
Facter.add(:base_utils_info) do
  confine kernel: 'Linux'

  setcode do
    info = {}

    # Check for common utility packages
    %w[curl wget jq vim].each do |pkg|
      info[pkg] = Facter::Core::Execution.execute("rpm -q #{pkg} 2>/dev/null || dpkg -l #{pkg} 2>/dev/null | grep '^ii'").strip != '' rescue false
    end

    # Get system uptime in seconds
    uptime_file = '/proc/uptime'
    if File.exist?(uptime_file)
      info['uptime_seconds'] = File.read(uptime_file).split.first.to_i
    end

    info
  end
end
