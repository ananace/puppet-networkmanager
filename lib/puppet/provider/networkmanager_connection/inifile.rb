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

  def nmcli_safe(*args)
    cmd = Puppet::Provider::Command.new(
      :nmcli,
      'nmcli',
      Puppet::Util,
      Puppet::Util::Execution,
      failonfail: false,
    )
    cmd.execute(args)
  end

  def self.instances
    Dir['/etc/NetworkManager/system-connections/*.nmconnection'].map do |file|
      conn = PuppetX::Networkmanager::Connection.new(file)

      new(
        name: conn.get_setting('connection', 'id'),
        uuid: conn.get_setting('connection', 'uuid'),
        path: file,
      )
    end
  end

  def exists?
    File.exist? file_path
  end

  def loaded?
    @connection_loaded ||= \
      begin
        data = if uuid
                 nmcli_safe :connection, :show, :uuid, uuid
               else
                 nmcli_safe :connection, :show, :id, resource[:name]
               end

        data.exitstatus.zero?
      rescue StandardError
        nil
      end
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

  def create(skip_backup: false, inject_settings: false)
    self.settings = resource[:settings] if resource[:settings] && inject_settings
    ensure_default_settings

    dirty = connection.dirty?
    connection.flush

    return false if !dirty && loaded?

    load!

    true
  rescue StandardError
    Puppet.debug "Failed to load NM connection #{resource[:name]}, rolling back"
    connection.revert! unless skip_backup
    raise
  ensure
    connection.delete_backup! unless skip_backup
  end

  def load!
    ret = nmcli :connection, :load, file_path
    raise Puppet::Error, ret if ret&.downcase&.include? 'could not load'

    @connection_loaded = true
  end

  def destroy
    connection.destroy
  end

  def with_checkpoint(*)
    yield
  end

  def activate(inject_settings: false)
    nameservers = File.readlines('/etc/resolv.conf').select { |l| l.start_with? 'nameserver ' }
    with_checkpoint do
      # Force a load even if the connection doesn't look dirty
      create(skip_backup: true, inject_settings: inject_settings) || load!

      if uuid
        nmcli :connection, :up, :uuid, uuid
      else
        nmcli :connection, :up, :id, resource[:name]
      end
    end
  # Handle backup reverting in the activate method, to not keep unusable connections on disk
  rescue StandardError
    Puppet.debug "Failed to activate/verify NM connection #{resource[:name]}, rolling back"
    connection.revert!

    # Check that the revert hasn't left resolv.conf in a broken state,
    # this can happen when going from no NM state directly to a failed initial connection
    revertedconf = File.readlines('/etc/resolv.conf')
    File.open('/etc/resolv.conf', 'a') { |file| file << "\n" << nameservers.join } unless revertedconf.any? { |l| l.start_with? 'nameserver ' }

    raise
  ensure
    connection.delete_backup!
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
      next if connection.get_setting(section, setting) == value.to_s

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
    PuppetX::Networkmanager::Connection[file_path].tap do |conn|
      conn.is_managed = true
    end
  end
end
