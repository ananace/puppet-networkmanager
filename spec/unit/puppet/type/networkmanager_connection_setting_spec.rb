require 'spec_helper'
require 'puppet'

describe Puppet::Type.type(:networkmanager_connection_setting) do
  let(:resource) do
    described_class.new(
      name: 'em1/connection/type',
      value: 'ethernet',
    )
  end

  context 'resource defaults' do
    it { expect(resource[:replace]).to eq true }
    it { expect(resource[:show_diff]).to eq :true }
  end

  it 'verify resource[:path] is absolute filepath' do
    expect { resource[:path] = 'relative/file' }.to raise_error(Puppet::Error, %r{File paths must be fully qualified, not 'relative/file'})
  end

  describe 'exec autonotify' do
    let(:connection_resource) { Puppet::Type.type(:networkmanager_connection).new(name: 'em1') }
    let(:auto_notify) do
      catalog = Puppet::Resource::Catalog.new
      catalog.add_resource(connection_resource)
      catalog.add_resource(resource)

      resource.autonotify
    end

    it { expect(auto_notify.first.target).to eq connection_resource }
    it { expect(auto_notify.first.source).to eq resource }
  end

  [true, false, 'true', 'false', 'md5', :md5].each do |param|
    describe "when show_diff => #{param}" do
      let(:value) { described_class.new(name: 'connection/section/value', value: 'whatever', show_diff: param).property(:value) }

      if [true, 'true'].include?(param)
        it 'displays diff' do
          expect(value.change_to_s('not_secret', 'at_all')).to include('not_secret', 'at_all')
        end

        it 'tells current value' do
          expect(value.is_to_s('not_secret_at_all')).to eq("'not_secret_at_all'")
        end

        it 'tells new value' do
          expect(value.should_to_s('not_secret_at_all')).to eq("'not_secret_at_all'")
        end
      elsif ['md5', :md5].include?(param)
        it 'tells correct md5 hashes for multiple values' do
          expect(value.change_to_s('not_at', 'all_secret')).to include('6edef0c4f5ec664feff6ca6fbc290970', '1660308ab156754fa09af0e8dc2c6629')
        end
        it 'does not tell singular value one' do
          expect(value.change_to_s('not_at #', 'all_secret')).not_to include('not_at')
        end
        it 'does not tell singular value two' do
          expect(value.change_to_s('not_at', 'all_secret')).not_to include('all_secret')
        end

        it 'tells md5 of current value' do
          expect(value.is_to_s('not_at_all_secret')).to eq("'{md5}858b46aee11b780b8f5c8853668efc05'")
        end
        it 'does not tell the current value' do
          expect(value.is_to_s('not_at_all_secret')).not_to include('not_secret_at_all')
        end

        it 'tells md5 of new value' do
          expect(value.should_to_s('not_at_all_secret')).to eq("'{md5}858b46aee11b780b8f5c8853668efc05'")
        end
        it 'does not tell the new value' do
          expect(value.should_to_s('not_at_all_secret')).not_to include('not_secret_at_all')
        end
      end
    end
  end
end
