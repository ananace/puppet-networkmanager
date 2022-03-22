# frozen_string_literal: true

Facter.add(:networkmanager) do
  confine kernel: :linux

  @nmcli_cmd = Facter::Util::Resolution.which('nmcli')
  confine { @nmcli_cmd }
  @nm_cmd = Facter::Util::Resolution.which('NetworkManager')
  confine { @nm_cmd }

  setcode do
    version = Facter::Core::Execution.execute("#{@nm_cmd} --version").strip
    status = Facter::Core::Execution.execute("#{@nmcli_cmd} general status").strip.split("\n")

    status = Hash[status.first.split.map(&:downcase).zip(status.last.split)]

    {
      version: version,
      status: status
    }
  end
end
