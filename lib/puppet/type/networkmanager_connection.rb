# frozen_string_literal: true

Puppet::Type.newtype(:networkmanager_connection) do
  desc <<~DOC
  Examples:

      networkmanager_connection { 'Wired Connection 1':
        ensure         => active,
        settings       => {
          'connection/interface-name' => 'eno1',
          'ethernet/mac-address'      => '00:01:02:03:04:05',
        },
        purge_settings => true,
      }
  DOC

  Puppet::Type.type(:networkmanager_connection_setting)

  ensurable do
    newvalue(:present) do
      provider.create
    end
    newvalue(:absent) do
      provider.destroy
    end
    newvalue(:active) do
      provider.activate
    end

    defaultto :present

    def insync?(current)
      case should
      when :present
        return true unless current == :absent
      when :absent
        return true if current == :absent && !provider.exists?
      when :active
        return true if current != :absent && provider.active?
      end
    end
  end

  def refresh
    return unless @parameters[:ensure].value == :active

    provider.activate(true)
  end

  def generate
    purge_services if self[:purge_settings]
    []
  end

  newparam(:name, namevar: true) do
    desc 'Connection name/identifier'
  end

  newproperty(:uuid) do
    desc 'Connection UUID'
  end

  newparam(:path) do
    desc 'The exact path to the connection to modify'
    validate do |value|
      unless Puppet::Util.absolute_path?(value)
        raise(Puppet::Error, _("File paths must be fully qualified, not '%{value}'") % { value: value })
      end
    end
  end

  newproperty(:settings) do
    desc 'A list of settings to manage on the connection'
    validate do |value|
      raise Puppet::Error, 'Must be a Hash[String,Data]' unless value.is_a? Hash
    end
  end

  newproperty(:purge_settings, boolean: true, parent: Puppet::Parameter::Boolean) do
    defaultto false

    def retrieve
      return false if @resource[:purge_settings] == false

      # Return value that's guaranteed to be different to force change
      provider.resource.services_purgable? ? :purgeable : true
    end
  end

  autorequire(:service) do
    [ 'NetworkManager' ]
  end
  autorequire(:file) do
    [
      self[:path] || "/etc/NetworkManager/system-connections/#{self[:name]}.nmconnection",
      File.basename(self[:path] || '/etc/NetworkManager/system-connections/placeholder'),
    ]
  end

  def settings_purgable?
    @settings_purgable
  end

  def purge_setting(nmset)
    if Puppet.settings[:noop] || self[:noop]
      Puppet.debug "Would have purged #{nmset.ref}, (noop)"
    else
      Puppet.debug "Purging #{nmset.ref}"
      nmset.provider.destroy if nmset.provider.exists?
    end
  end

  def purge_services
    return [] unless provider.exists?

    managed_services = []
    catalog.resources.select { |r| r.is_a? Puppet::Type::Networkmanager_connection_setting }.each do |nmset|
      managed_services << nmset.provider.generate_full_name
    end

    provider.get_services_for_purge.reject { |p| managed_services.include? p }.each do |purge|
      nmset = Puppet::Type.type(:networkmanager_connection_setting).new(
        ensure: :absent,
        name: purge,
        file_path: self[:path],
      )
      purge_setting(nmset)

      # Flag as changed, so the connection will reload
      @services_purgable = true
    end
  end
end
