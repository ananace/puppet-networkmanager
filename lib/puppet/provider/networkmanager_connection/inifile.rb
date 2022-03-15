# frozen_string_literal: true

require 'puppet/util/inifile'
require 'securerandom'

Puppet::Type.type(:networkmanager_connection).provide(:inifile) do
  commands nmcli: '/usr/bin/nmcli'

  def exists?
    File.exist? file_path
  end

  def active?
    data = if uuid
             nmcli(:connection, :show, '--active', :uuid, uuid)
           else
             nmcli(:connection, :show, '--active', :id, resource[:name])
           end

    !data.strip.empty?
  rescue StandardError => ex
    Puppet.debug "#{ex.class}: #{ex} when checking connection status for #{resource[:name]}, assuming inactive"
    false
  end

  def create
    ensure_default_settings

    dirty = ini_file.sections.any?(&:dirty?)
    flush

    return false unless dirty

    nmcli :connection, :load, file_path
    true
  end

  def destroy
    ini_file.sections.each { |s| s.destroy = true }
    flush
  end

  def flush
    cleanup_sections
    ini_file.store
    @ini_file = nil
  end

  def activate(force = false)
    return unless create || force

    if uuid
      nmcli :connection, :up, :uuid, uuid
    else
      nmcli :connection, :up, :id, resource[:name]
    end
  end

  def file_path
    resource[:path] || "/etc/NetworkManager/system-connections/#{name}.nmconnection"
  end

  def uuid
    resource[:uuid] || settings['connection/uuid']
  end

  def uuid=(uuid)
    return if resource[:ensure] == :absent

    store = ini_file.get_section('connection') || ini_file.add_section('connection')
    store['uuid'] = uuid

    if resource[:ensure] == :present
      create
    else
      activate
    end
  end

  def all_settings
    default_settings.merge(settings)
  end

  def default_settings
    {
      'connection/id' => resource[:name],
      'connection/uuid' => resource[:uuid] || uuid || SecureRandom.uuid,
    }.compact
  end

  def ensure_default_settings
    default_settings.each do |key, value|
      section, setting = key.split('/')

      store = ini_file.get_section(section) || ini_file.add_section(section)
      store[setting] = value unless store[setting] == value
    end
  end

  def settings
    found = {}
    ini_file.sections.each do |section|
      section.entries.each do |entry|
        next unless entry.is_a? Array

        found["#{section.name}/#{entry.first}"] = entry.last
      end
    end

    found
  end

  def settings=(new_settings)
    return if resource[:ensure] == :absent

    ensure_default_settings
    cur_settings = settings

    # Find externally managed settings, to not interfere with them
    externally_managed = resource&.catalog&.resources
                                 &.select { |r| r.is_a? Puppet::Type::Networkmanager_connection_setting }
                                 &.map { |r| r.provider.generate_full_name }
    externally_managed ||= []

    to_set = Hash[*(new_settings.to_a - cur_settings.to_a).flatten]
    to_remove = (cur_settings.keys - new_settings.keys)

    default_settings.each { |k, _| to_remove.delete k }

    to_remove.each do |key|
      next if externally_managed.include? "#{resource[:name]}/#{key}"

      section, setting = key.split('/')
      remove_setting(section, setting)
    end
    to_set.each do |key, value|
      next if externally_managed.include? "#{resource[:name]}/#{key}"

      section, setting = key.split('/')
      set_setting(section, setting, value)
    end

    cleanup_sections

    if resource[:ensure] == :present
      create
    else
      activate
    end
  end

  def remove_setting(section, setting)
    store = ini_file.get_section(section)
    return unless store

    store.entries.delete_if { |(k, _)| k == setting }
    store.mark_dirty
  end

  def set_setting(section, setting, value)
    store = ini_file.get_section(section) || ini_file.add_section(section)
    store[setting] = value
  end

  private

  def cleanup_sections
    ini_file.sections.each do |section|
      next if section.entries.any? { |e| e.is_a? Array }

      section.destroy = true
      section.mark_dirty
    end
  end

  def ini_file
    @ini_file ||= begin
      file = Puppet::Util::IniConfig::PhysicalFile.new(file_path)
      file.destroy_empty = true
      file.read if File.exist? file_path
      file
    end
  end
end
