# frozen_string_literal: true

Facter.add(:networkmanager) do
  confine kernel: :linux

  @nmcli_cmd = Facter::Util::Resolution.which('nmcli')
  confine { @nmcli_cmd }
  @nm_cmd = Facter::Util::Resolution.which('NetworkManager')
  confine { @nm_cmd }

  setcode do
    version = Facter::Core::Execution.execute("#{@nm_cmd} --version", on_fail: nil)&.strip
    return {} unless version

    key, value = Facter::Core::Execution.execute("#{@nmcli_cmd} general status", on_fail: nil)&.strip&.split("\n")
    status = Hash[key.split(%r(\s{2,})).map(&:downcase).zip(value.split(%r(\s{2,}/)))] if key && value
    status ||= {}

    {
      version: version,
      running: !status.nil?,
      status: status
    }
  end
end
