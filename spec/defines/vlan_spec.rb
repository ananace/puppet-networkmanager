# frozen_string_literal: true

require 'spec_helper'

describe 'networkmanager::vlan' do
  let(:title) { 'namevar' }
  let(:params) do
    {
      mac: '00:01:02:03:04:05',
      mtu: 1400,
      vlanid: 1010
    }
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile }
    end
  end
end
