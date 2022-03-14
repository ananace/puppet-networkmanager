# frozen_string_literal: true

require 'spec_helper'

describe Puppet::Type.type(:networkmanager_connection).provider(:inifile) do
  let(:name) do
    'Wired Connection 1'
  end
  let(:parameters) do
    {
      name: name,
    }
  end

  let(:resource) { Puppet::Type::Networkmanager_connection.new(parameters) }
  let(:provider) { described_class.new(resource) }

  context 'with example configuration' do
    let(:parameters) do
      {
        name: name,
        ensure: :active,
        settings: {
          'connection/interface-name' => 'eno1',
          'ethernet/mac-address' => '00:01:02:03:04:05',
        },
        purge_settings: true,
      }
    end

    it 'executes nmcli' do
      expect(provider).to receive(:settings).and_return({})
      expect(provider).to receive(:nmcli).with(:connection, :show, '--active', :id, name).and_return('yes')

      expect(provider.active?).to eq(true)
    end
  end
end
