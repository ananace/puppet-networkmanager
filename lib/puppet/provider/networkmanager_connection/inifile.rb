# frozen_string_literal: true

begin
  require 'puppet_x/networkmanager/connection'
rescue LoadError
  require 'pathname' # WORK_AROUND #14073 and #7788

  nmmodule = Puppet::Module.find('networkmanager', Puppet[:environment].to_s)
  raise(LoadError, "Unable to find networkmanager module in modulepath #{Puppet[:basemodulepath] || Puppet[:modulepath]}") unless nmmodule

  require File.join nmmodule.path, 'lib/puppet_x/networkmanager/connection'
end

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

    dirty = connection.dirty?
    connection.flush

    return false unless dirty

    nmcli :connection, :load, file_path
    true
  end

  def destroy
    connection.destroy
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

    store = connection.get_section('connection', create: true)
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

      store = connection.get_section(section, create: true)
      store[setting] = value unless store[setting] == value
    end
  end

  def settings
    connection.settings
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
      connection.remove_setting(section, setting)
    end
    to_set.each do |key, value|
      next if externally_managed.include? "#{resource[:name]}/#{key}"

      section, setting = key.split('/')
      connection.set_setting(section, setting, value)
    end

    if resource[:ensure] == :present
      create
    else
      activate
    end
  end

  private

  def connection
    @connection ||= PuppetX::Networkmanager::Connection[file_path]
  end
end
