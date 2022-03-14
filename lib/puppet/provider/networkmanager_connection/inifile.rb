# frozen_string_literal: true

require 'puppet/util/inifile'
require 'securerandom'

Puppet::Type.type(:networkmanager_connection).provide(:inifile) do
  commands :nmcli => '/usr/bin/nmcli'

  def exists?
    File.exist? file_path
  end

  def active?
    uuid = settings['connection/uuid']

    data = if uuid
             nmcli(:connection, :show, '--active', 'uuid', uuid)
           else
             nmcli(:connection, :show, '--active', 'id', resource[:name])
           end

    !data.empty?
  rescue StandardError => ex
    Puppet.debug "#{ex.class}: #{ex} when checking connection status for #{resource[:name]}, assuming inactive"
    false
  end

  def create
    ensure_default_settings

    dirty = ini_file.sections.any?(&:dirty?)
    ini_file.store

    return unless dirty

    nmcli :connection, :load, file_path
  end

  def destroy
    ini_file.destroy_empty = true
    ini_file.sections.each { |s| s.destroy = true }
    ini_file.store
  end

  def activate(force = false)
    dirty = ini_file.sections.any?(&:dirty?)
    create

    return unless dirty || force

    uuid = settings['connection/uuid']

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
    settings['connection/uuid']
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

  def get_settings_for_purge
    settings.map { |s| "#{resource[:name]}/#{s}" }
  end

  def default_settings
    {
      'connection/id' => resource[:name],
      'connection/uuid' => resource[:uuid],
    }.compact
  end

  def ensure_default_settings
    to_set = default_settings
    to_set['connection/uuid'] ||= SecureRandom.uuid unless settings.keys.include? 'connection/uuid'

    to_set.each do |key, value|
      section, setting = key.split('/')

      store = ini_file.get_section(section) || ini_file.add_section(section)
      store[setting] = value unless store[setting] == value
    end
  end

  def settings
    found = {}
    ini_file.sections.each do |section|
      section.entries.each do |entry|
        found["#{section.name}/#{entry.first}"] = entry.last
      end
    end

    found.uniq
  end

  def settings=(new_settings)
    return if resource[:ensure] == :absent

    ensure_default_settings
    new_settings = new_settings
    cur_settings = settings

    to_set = Hash[*(new_settings.to_a - cur_settings.to_a).flatten]
    to_remove = new_settings.keys - cur_settings.keys if resource[:purge_settings]
    to_remove ||= []

    default_settings.each { |k, _| to_remove.delete k }

    to_remove.each do |key|
      section, setting = key.split('/')
      next unless ini_file.section? section

      store = ini_file.get_section(section)
      store.entries.delete_if { |(k, _)| k == setting }
      store.mark_dirty
    end
    to_set.each do |key, value|
      section, setting = key.split('/')

      store = ini_file.get_section(section) || ini_file.add_section(section)
      store[setting] = value
    end

    if resource[:ensure] == :present
      create
    else
      activate
    end
  end

  private

  def ini_file
    @ini_file ||= begin
      file = Puppet::Util::IniConfig::PhysicalFile.new(file_path)
      file.read if File.exist? file_path
      file
    end
  end
end
