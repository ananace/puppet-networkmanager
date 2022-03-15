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

  attr_reader :settings_purgable

  def generate
    purge_settings if self[:purge_settings]
    []
  end

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

      false
    end
  end

  def refresh
    return unless @parameters[:ensure].value == :active

    provider.activate(true)
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
      provider.resource.settings_purgable ? :purgeable : true
    end
  end

  autorequire(:service) do
    [ 'NetworkManager' ]
  end
  autorequire(:file) do
    [
      self[:path] || provider&.file_path || "/etc/NetworkManager/system-connections/#{self[:name]}.nmconnection",
      File.basename(self[:path] || provider&.file_path || '/etc/NetworkManager/system-connections/placeholder'),
    ]
  end

  def purge_settings
    return [] unless provider&.exists?

    externally_managed = catalog.resources.select { |r| r.is_a? Puppet::Type::Networkmanager_connection_setting }.map { |r| r.provider.generate_full_name }

    externally_managed += (self[:settings] || {}).keys.map { |s| "#{self[:name]}/#{s}" }
    externally_managed += provider.default_settings.keys.map { |s| "#{self[:name]}/#{s}" }

    provider.settings.keys.reject { |p| externally_managed.include? "#{self[:name]}/#{p}" }.each do |purge|
      Puppet.debug "Purging Networkmanager_connection_setting[#{self[:name]}/#{purge}]"

      section, setting = purge.split('/')
      provider.remove_setting(section, setting)

      # Flag as changed, so the connection will reload
      @settings_purgable = true
    end
    provider.flush
  end
end
