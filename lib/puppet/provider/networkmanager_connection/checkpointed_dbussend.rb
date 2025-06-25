Puppet::Type.type(:networkmanager_connection).provide(:checkpointed_dbussend, parent: :inifile, source: :inifile) do
  commands dbus_send: '/usr/bin/dbus-send'

  def dbus_call(method, *args)
    dbus_object = '/org/freedesktop/NetworkManager'
    dbus_service = 'org.freedesktop.NetworkManager'

    dbus_send '--system', "--dest=#{dbus_service}", '--print-reply', dbus_object, "#{dbus_object}.#{method}", *args
  end

  def with_checkpoint(timeout: 15, &block)
    checkpoint_flags = 0
    checkpoint_flags |= 0x02 # NM_CHECKPOINT_CREATE_FLAG_DELETE_NEW_CONNECTIONS
    checkpoint_flags |= 0x04 # NM_CHECKPOINT_CREATE_FLAG_DISCONNECT_NEW_DEVICES

    interface_list = 'array:objpath:'
    # TODO: Figure out relevant interfaces and discover their device paths
    # if settings['connection/interface-name']
    #   interface_list += ...
    # end

    ret = dbus_call :CheckpointCreate, interface_list, "uint32:#{timeout}", "uint32:#{checkpoint_flags}"
    checkpoint_path = ret.split('"')[1]

    block.call

    # Check if the connection is still valid
    verify_connection

    # Remove the checkpoint object, to keep the configuration
    dbus_call :CheckpointDestroy, "objpath:#{checkpoint_path}"
  rescue StandardError
    dbus_call :CheckpointRollback, "objpath:#{checkpoint_path}" if checkpoint_path
    raise
  end

  def verify_connection
    client = Puppet.runtime[:http]
    session = client.create_session
    service = Puppet::HTTP::Service.create_service(client, session, :puppetserver)
    service.get_simple_status
  end

  def activate
    # Force a load even if the connection doesn't look dirty
    create(handle_backup: false) || load!

    with_checkpoint do
      if uuid
        nmcli :connection, :up, :uuid, uuid
      else
        nmcli :connection, :up, :id, resource[:name]
      end
    end
  # Move backup handling to the activate method, to not keep unusable connections on disk
  rescue StandardError
    connection.revert!
    raise
  ensure
    connection.delete_backup!
  end
end
