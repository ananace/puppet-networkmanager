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

  def generate
    res = []

    # TODO: Why does this cause tests to fail to write data?
    # res << Puppet::Type.type(:file).new(
    #   ensure: self[:ensure] == :absent ? :absent : :file,
    #   name: provider.file_path,
    #   owner: 'root',
    #   group: 'root',
    #   mode: '0600',
    #   backup: false,
    #   replace: false,
    # )

    res += purge_settings if self[:purge_settings]

    res
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

  newparam(:purge_settings, boolean: true, parent: Puppet::Parameter::Boolean) do
    defaultto false
  end

  autorequire(:service) do
    [ 'NetworkManager' ]
  end

  # Put generated resources before this one
  def depthfirst?
    true
  end

  def purge_settings
    externally_managed = catalog.resources.select { |r| r.is_a? Puppet::Type::Networkmanager_connection_setting }.map { |r| r.provider.generate_full_name }

    externally_managed += (self[:settings] || {}).keys.map { |s| "#{self[:name]}/#{s}" }
    externally_managed += provider.default_settings.keys.map { |s| "#{self[:name]}/#{s}" }

    provider.settings.keys.reject { |p| externally_managed.include? "#{self[:name]}/#{p}" }.map do |purge|
      section, setting = purge.split('/')
      Puppet::Type.type(:networkmanager_connection_setting).new(
        name: "Purge #{purge}",
        connection: self[:name],
        section: section,
        setting: setting,
        path: provider.file_path,
        ensure: :absent,
      )
    end
  end
end
