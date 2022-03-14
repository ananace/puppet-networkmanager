require 'spec_helper'
require 'puppet'

describe Puppet::Type.type(:networkmanager_connection) do
  let(:resource) do
    described_class.new(
      name: 'em1',
    )
  end

  context 'resource defaults' do
    it { expect(resource[:ensure]).to eq :present }
  end

  it 'verify resource[:path] is absolute filepath' do
    expect { resource[:path] = 'relative/file' }.to raise_error(Puppet::Error, %r{File paths must be fully qualified, not 'relative/file'})
  end


end
