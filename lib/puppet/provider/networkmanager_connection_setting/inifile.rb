# frozen_string_literal: true

begin
  require 'puppet_x/networkmanager/connection'
rescue LoadError
  require 'pathname' # WORK_AROUND #14073 and #7788

  nmmodule = Puppet::Module.find('networkmanager', Puppet[:environment].to_s)
  raise(LoadError, "Unable to find networkmanager module in modulepath #{Puppet[:basemodulepath] || Puppet[:modulepath]}") unless nmmodule

  require File.join nmmodule.path, 'lib/puppet_x/networkmanager/connection'
end

Puppet::Type.type(:networkmanager_connection_setting).provide(:inifile) do
  def connection_name
    resource[:connection] || resource[:name].split('/', 3).first
  end

  def section
    resource[:section] || resource[:name].split('/', 3)[1]
  end

  def setting
    resource[:setting] || resource[:name].split('/', 3).last
  end

  def generate_full_name
    "#{connection_name}/#{section}/#{setting}"
  end

  def exists?
    !connection.get_setting(section, setting).nil?
  end

  def create
    self.value = :dummy # trigger #value=() method
  end

  def destroy
    connection.remove_setting(section, setting)
    flush
  end

  def value
    connection.get_setting(section, setting)
  end

  def value=(_value)
    return if !resource[:replace] && exists?
    return if connection.get_setting(section, setting) == resource[:value]

    if setting.nil? && resource[:value].nil?
      remove_section(section)
    else
      connection.set_setting(section, setting, resource[:value])
    end

    flush
  end

  def file_path
    resource[:path] || "/etc/NetworkManager/system-connections/#{connection_name}.nmconnection"
  end

  private

  # TODO: A better way to do this
  def flush
    # return if resource&.catalog&.resources&.any? { |r| r.is_a? Puppet::Type::Networkmanager_connection && r.name == connection_name }

    connection.flush
  end

  def remove_section(section)
    section = connection.get_section(section)
    return unless section

    section.destroy = true
    section.mark_dirty
  end

  def connection
    @connection ||= PuppetX::Networkmanager::Connection[file_path]
  end
end
