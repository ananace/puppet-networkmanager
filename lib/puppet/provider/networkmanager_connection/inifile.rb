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
    # Ensure there's a cache of nameservers
    cached_nameservers

    discovered_connections = {}
    # TODO: load active connections
    # data = nmcli_safe :connection, :show
    # if data.exitstatus.zero?
    # end

    Dir['/etc/NetworkManager/system-connections/*.nmconnection'].each do |file|
      conn_file = PuppetX::Networkmanager::Connection.new(file)
      conn = {
        name: conn.get_setting('connection', 'id'),
        uuid: conn.get_setting('connection', 'uuid'),
        path: file,
      }

      (discovered_connections[conn[:uuid]] ||= {}).merge! conn
    end

    discovered_connections.map { |_, data| new(data) }
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
    connection.save

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

  def reload_connection
    if resource[:ensure] == :absent
      destroy if loaded?
    elsif resource[:ensure] == :active || active?
      activate
    else
      create
    end
  end

  # Trigger a refresh-like reload if settings are purged
  def flush
    reload_connection
  end

  def destroy
    self.class.cached_nameservers # Ensure nameservers have been cached
    with_checkpoint do
      if uuid
        nmcli :connection, :delete, :uuid, uuid
      else
        nmcli :connection, :delete, :id, resource[:name]
      end
    end
  end

  def with_checkpoint(*)
    yield
  end

  def activate(inject_settings: false)
    return if @activated_this_session

    @activated_this_session = true
    self.class.cached_nameservers # Ensure nameservers have been cached
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
  end

  # Lifecycle handling
  #
  def self.cached_nameservers
    @nameservers = nil if @nameservers&.empty?
    @nameservers ||= File.readlines('/etc/resolv.conf').select { |l| l.start_with? 'nameserver ' }.map(&:strip)
  end

  def self.post_resource_eval
    resolvconf = File.readlines('/etc/resolv.conf')
    return if resolvconf.any? { |l| l.start_with? 'nameserver ' }

    to_add = cached_nameservers
    Puppet.debug "Catalog application left /etc/resolv.conf without nameservers, adding #{to_add}"
    File.open('/etc/resolv.conf', 'a') do |file|
      file << "\n"
      to_add.each { |line| file << "#{line}\n" }
    end
  end

  private

  def connection
    PuppetX::Networkmanager::Connection[file_path].tap do |conn|
      conn.is_managed = true
    end
  end
end
