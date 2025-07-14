# frozen_string_literal: true

require 'spec_helper'

describe Puppet::Type.type(:networkmanager_connection).provider(:checkpointed_dbussend) do
  include PuppetlabsSpec::Files

  let(:name) { 'Wired Connection 1' }
  let(:uuid) { 'c2fec85c-d2ba-4db9-bed3-cf0471623963' }
  let(:parameters) do
    {
      name: name,
      uuid: uuid,
    }
  end

  let(:resource) { Puppet::Type::Networkmanager_connection.new(parameters) }
  let(:provider) { described_class.new(resource) }

  context 'with example configuration' do
    let(:nmconn_file) { tmpfilename('nm-connection') }
    let(:nmconn_settings) do
      {
        'connection/interface-name' => 'eno1',
        'ethernet/mac-address' => '00:01:02:03:04:05',
      }
    end
    let(:parameters) do
      {
        name: name,
        uuid: uuid,
        ensure: :active,
        settings: nmconn_settings,
        purge_settings: true,
        path: nmconn_file
      }
    end

    it 'uses nmcli to activate the connection, with a checkpoint taken and then removed after success' do
      allow(resource).to receive(:[]).with(:name).and_return(name)
      allow(resource).to receive(:[]).with(:uuid).and_return(uuid)
      allow(resource).to receive(:[]).with(:path).and_return(parameters[:path])

      allow(provider).to receive(:create)
      allow(provider).to receive(:load!)

      dbus_return = <<~EOF
      method return time=1750674443.608379 sender=:1.5 -> destination=:1.41936 serial=1334191 reply_serial=2
         object path "/org/freedesktop/NetworkManager/Checkpoint/1"
      EOF
      expect(provider).to receive(:dbus_call).with(:CheckpointCreate, 'array:objpath:', 'uint32:15', 'uint32:6').and_return(dbus_return)
      expect(provider).to receive(:nmcli).with(:connection, :up, :uuid, uuid)

      service_mock = double
      expect(Puppet::HTTP::Service).to receive(:create_service).and_return(service_mock)
      expect(service_mock).to receive(:get_simple_status).and_return(true)

      expect(provider).to receive(:dbus_call).with(:CheckpointDestroy, 'objpath:/org/freedesktop/NetworkManager/Checkpoint/1')

      provider.activate
    end

    it 'uses nmcli to activate the connection, with a checkpoint taken and then rolled back on failure' do
      allow(resource).to receive(:[]).with(:name).and_return(name)
      allow(resource).to receive(:[]).with(:uuid).and_return(uuid)
      allow(resource).to receive(:[]).with(:path).and_return(parameters[:path])

      allow(provider).to receive(:create)
      allow(provider).to receive(:load!)

      dbus_return = <<~EOF
      method return time=1750674443.608379 sender=:1.5 -> destination=:1.41936 serial=1334191 reply_serial=2
         object path "/org/freedesktop/NetworkManager/Checkpoint/2"
      EOF
      expect(provider).to receive(:dbus_call).with(:CheckpointCreate, 'array:objpath:', 'uint32:15', 'uint32:6').and_return(dbus_return)
      expect(provider).to receive(:nmcli).with(:connection, :up, :uuid, uuid)

      service_mock = double
      expect(Puppet::HTTP::Service).to receive(:create_service).and_return(service_mock)
      expect(service_mock).to receive(:get_simple_status).and_raise(Net::OpenTimeout)

      expect(provider).to receive(:dbus_call).with(:CheckpointRollback, 'objpath:/org/freedesktop/NetworkManager/Checkpoint/2')

      expect { provider.activate }.to raise_error(Net::OpenTimeout)
    end
  end
end
