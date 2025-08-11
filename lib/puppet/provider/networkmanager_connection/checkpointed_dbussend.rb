Puppet::Type.type(:networkmanager_connection).provide(:checkpointed_dbussend, parent: :inifile, source: :inifile) do
  commands dbus_send: '/usr/bin/dbus-send'

  def dbus_call(method, *args)
    dbus_object = '/org/freedesktop/NetworkManager'
    dbus_service = 'org.freedesktop.NetworkManager'

    dbus_send '--system', "--dest=#{dbus_service}", '--print-reply', dbus_object, "#{dbus_service}.#{method}", *args
  end

  def with_checkpoint(timeout: 15, &_block)
    checkpoint_flags = 0
    checkpoint_flags |= 0x02 # NM_CHECKPOINT_CREATE_FLAG_DELETE_NEW_CONNECTIONS
    checkpoint_flags |= 0x04 # NM_CHECKPOINT_CREATE_FLAG_DISCONNECT_NEW_DEVICES

    ret = dbus_call :CheckpointCreate, 'array:objpath:', "uint32:#{timeout}", "uint32:#{checkpoint_flags}"
    checkpoint_path = ret.split('"')[1]

    yield

    # Check if the connection is still valid
    verify_connection

    # Remove the checkpoint object, to keep the configuration
    dbus_call :CheckpointDestroy, "objpath:#{checkpoint_path}"
  rescue StandardError
    dbus_call :CheckpointRollback, "objpath:#{checkpoint_path}" if checkpoint_path
    raise
  end

  def verify_connection
    attempts = 0
    loop do
      attempts += 1

      Puppet.debug "Connection verification attempt ##{attempts} after activating connection"
      client = Puppet.runtime[:http]
      session = client.create_session
      service = Puppet::HTTP::Service.create_service(client, session, :puppetserver)
      service.get_simple_status
      return true
    rescue StandardError
      raise if attempts >= 10

      sleep 0.5
    end
  end
end
