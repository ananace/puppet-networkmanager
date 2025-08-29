# frozen_string_literal: true

Puppet::Type.newtype(:networkmanager_connection_setting) do
  def munge_boolean_md5(value)
    case value
    when true, :true, 'true', :yes, 'yes'
      :true
    when false, :false, 'false', :no, 'no'
      :false
    when :md5, 'md5'
      :md5
    else
      raise(_('expected a boolean value or :md5'))
    end
  end

  desc <<~DOC
  Examples:

      networkmanager_connection_setting { 'Wired Connection 1/ipv4/method':
        value => 'auto',
      }

      networkmanager_connection_setting { 'An example setting':
        connection => 'Wired Connection 1',
        section    => 'ipv4',
        setting    => 'method',
        value      => 'auto',
      }
  DOC

  ensurable

  newparam(:name, namevar: true) do
    desc 'Section/setting name to manage for the connection'
  end

  newparam(:connection) do
    desc 'The name of the connection to modify'
  end

  newparam(:section) do
    desc 'The section to modify'
  end

  newparam(:setting) do
    desc 'The setting to modify'
  end

  newproperty(:value, array_matching: :all) do
    desc 'The value of the setting'

    munge do |value|
      value = value.unwrap if value.respond_to? :unwrap

      PuppetX::Networkmanager::Connection.serialize_value(value)
    end

    def should_to_s(value)
      if @resource[:show_diff] == :true
        if value.is_a? Array
          value.inspect
        else
          value = PuppetX::Networkmanager::Connection.deserialize_value(value)
          if value.is_a?(Array) || value.is_a?(String)
            value.inspect
          else
            value
          end
        end
      elsif @resource[:show_diff] == :md5
        "{md5}#{Digest::MD5.hexdigest(value.to_s)}"
      else
        '[redacted sensitive information]'
      end
    end

    def is_to_s(value) # rubocop:disable Naming/PredicateName
      should_to_s(PuppetX::Networkmanager::Connection.serialize_value(value))
    end

    def insync?(current)
      return true unless @resource[:replace]

      current = current.first if current.is_a?(Array) && current.size == 1

      PuppetX::Networkmanager::Connection.serialize_value(current) == PuppetX::Networkmanager::Connection.serialize_value(should)
    end

    def should
      real = super
      real = real.first if real.size == 1

      real
    end
  end

  newparam(:replace, boolean: true, parent: Puppet::Parameter::Boolean) do
    desc 'Should the setting be replaced if it exists'
    defaultto true
  end

  newparam(:path) do
    desc 'The exact path to the connection to modify'
    validate do |value|
      unless Puppet::Util.absolute_path?(value)
        raise(Puppet::Error, _("File paths must be fully qualified, not '%{value}'") % { value: value })
      end
    end
  end

  newparam(:show_diff) do
    desc 'Whether to display differences when the setting changes.'

    defaultto :true

    newvalues(:true, :md5, :false)

    munge do |value|
      @resource.munge_boolean_md5(value)
    end
  end

  validate do
    need_connection = !(self[:connection] || self[:path])
    need_section = !self[:section]

    if (need_connection && self[:name] !~ %r{\S+/\S+/\S+}) ||
       (need_section && self[:name] !~ %r{\S+/\S+})
      raise("Invalid networkmanager_connection_setting #{self[:name]}, either specify connection/path, section, and setting, or provide a name in the form of \"connection/section/setting\".")
    end

    if self[:ensure] == :present
      if self[:value].nil?
        raise Puppet::Error, "Property value must be set for #{self[:name]} when ensure is present"
      end
    end
  end

  autonotify(:networkmanager_connection) do
    [
      self[:connection],
      self[:name].split('/', 3).first,
    ]
  end
  autorequire(:service) do
    [ 'NetworkManager' ]
  end
  autorequire(:file) do
    [
      self[:path] || provider&.file_path || "/etc/NetworkManager/system-connections/#{self[:connection] || self[:name].split('/').first}.nmconnection",
      File.basename(self[:path] || provider&.file_path || '/etc/NetworkManager/system-connections/placeholder'),
    ]
  end
end
