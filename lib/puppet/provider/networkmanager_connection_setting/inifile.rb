# frozen_string_literal: true

require 'puppet/util/inifile'

Puppet::Type.type(:networkmanager_connection_setting).provide(:inifile) do
  def connection
    resource[:connection] || resource[:name].split('/', 3).first
  end

  def section
    resource[:section] || resource[:name].split('/', 3)[1]
  end

  def setting
    resource[:setting] || resource[:name].split('/', 3).last
  end

  def exists?
    !get_value(section, setting).nil?
  end

  def create
    self.value = :dummy # trigger #value=() method
  end

  def destroy
    remove_value(section, setting)
    ini_file.store
  end

  def value
    get_value(section, setting)
  end

  def value=(_value)
    return if !resource[:replace] && exists?
    return if get_value(section, setting) == resource[:value]

    if setting.nil? && resource[:value].nil?
      remove_section(section)
    else
      set_value(section, setting, resource[:value])
    end
    ini_file.store
  end

  def file_path
    resource[:path] || "/etc/NetworkManager/system-connections/#{connection}.nmconnection"
  end

  private

  def section?(name)
    !ini_file.get_section(name).nil?
  end

  def get_value(section, setting)
    return unless section?(section)

    ini_file.get_section(section)[setting]
  end

  def set_value(section, setting, value)
    store = ini_file.get_section(section) || ini_file.add_section(section)
    store[setting] = value
  end

  def remove_value(section, setting)
    return unless section?(section)

    section = ini_file.get_section(section)
    section.entries.delete_if { |(k, _)| k == setting }
    section.mark_dirty
  end

  def remove_section(section)
    return unless section?(section)

    ini_file.get_section(section).destroy = true
  end

  def ini_file
    @ini_file ||= begin
      file = Puppet::Util::IniConfig::PhysicalFile.new(file_path)
      file.read if File.exist? file_path
      file
    end
  end
end
