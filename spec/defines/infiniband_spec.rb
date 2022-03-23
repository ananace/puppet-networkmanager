# frozen_string_literal: true

require 'spec_helper'

describe 'networkmanager::infiniband' do
  let(:title) { 'namevar' }
  let(:params) do
    {
      mac: '00:01:02:03:04:05:06:07:08:09:10:11:12:13:14:15:16:17:18:19',
      mtu: 4096,
    }
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile }
    end
  end
end
