# frozen_string_literal: true

Puppet::Functions.create_function(:'networkmanager::munge_foreman_interfaces') do
  # Converts and instantiates a Foreman interfaces hash as networkmanager objects
  #
  # @example
  #     networkmanager::foreman_interfaces()
  dispatch :munge_foreman_interfaces do
    return_type 'Hash'
  end

  def munge_foreman_interfaces
    scope = closure_scope
    foreman_interfaces = scope['foreman_interfaces']&.select { |iface| iface['managed'] && iface['type'] != 'BMC' }

    return {} if foreman_interfaces.nil?

    host_interfaces = (scope['facts'].dig('networking', 'interfaces') || {}).select { |_, hiface| hiface.key? 'mac' }
    munged = foreman_interfaces.each_with_object({}) do |iface, hash|
      identifier = iface['identifier'] unless (iface['identifier'] || '') == ''
      identifier ||= host_interfaces.find { |_, hiface| hiface['mac'].casecmp(iface['mac'])&.zero? }&.first
      identifier ||= host_interfaces.find { |_, hiface| hiface['ip'] == iface['ip'] }&.first if (iface['ip'] || '') != ''
      identifier ||= host_interfaces.select { |_, hiface| hiface.key? 'ip6' }.find { |_, hiface| hiface['ip6'] == iface['ip6'] }&.first if (iface['ip6'] || '') != ''
      hidentifier = host_interfaces.find { |_, hiface| hiface['mac'].casecmp(iface['mac'])&.zero? }&.first
      hidentifier ||= host_interfaces.find { |_, hiface| hiface['ip'] == iface['ip'] }&.first if (iface['ip'] || '') != ''
      hidentifier ||= host_interfaces.select { |_, hiface| hiface.key? 'ip6' }.find { |_, hiface| hiface['ip6'] == iface['ip6'] }&.first if (iface['ip6'] || '') != ''
      hidentifier ||= iface['identifier'] unless (iface['identifier'] || '') == ''

      if identifier.nil?
        scope.call_function('warning', ["Unable to find an identifier for foreman_interface #{iface}, skipping it"])
        next hash
      end

      if iface['virtual'] && iface['type'] == 'Interface' && identifier !~ %r{^.+\..+$}
        # Extra address for existing interface
        data = (hash[iface['attached_to']] ||= {})
      else
        if iface['virtual']
          data = (hash[identifier] ||= {})
          data['tag'] = iface['tag'] unless (iface['tag'] || '') == ''
          if iface['type'] == 'Interface'
            data['mac'] = hash[iface['attached_to']]['mac']
            data['tag'] ||= iface['subnet']['vlanid'] unless (iface['subnet'] || '') == ''
            data['tag'] ||= iface['subnet6']['vlanid'] unless (iface['subnet6'] || '') == ''
          elsif iface['type'] == 'Bond'
            data['mac'] = iface['mac'] unless (iface['mac'] || '') == ''
            data['mode'] = iface['mode']
            data['bond_options'] = Hash[iface['bond_options'].split(' ').map { |part| part.split('=') }]
            data['attached_devices'] = iface['attached_devices'].split(',').map(&:strip)
          elsif iface['type'] == 'Bridge'
            data['mac'] = iface['mac'] unless (iface['mac'] || '') == ''
            data['attached_devices'] = iface['attached_devices'].split(',').map(&:strip)
          end
        else
          data = (hash[hidentifier] ||= {})
          data['mac'] = iface['mac']
        end
        data['virtual'] = iface['virtual']
        data['type'] = iface['type']
        data['primary'] = iface['primary']
      end

      data[:raw_addresses] ||= []
      if iface['ip'] && iface['ip'] != ''
        cidr = "#{iface['ip']}/#{IPAddr.new(iface.dig('subnet', 'mask')).to_i.to_s(2).count('1')}"
        data[:raw_addresses] << {
          ip: IPAddr.new(iface['ip']),
          cidr: cidr,
          netmask: iface.dig('subnet', 'mask'),
          subnet: iface['subnet']
        }
      end
      if iface['ip6'] && iface['ip6'] != ''
        cidr = "#{iface['ip6']}/#{IPAddr.new(iface.dig('subnet6', 'mask')).to_i.to_s(2).count('1')}"
        data[:raw_addresses] << {
          ip: IPAddr.new(iface['ip6']),
          cidr: cidr,
          netmask: iface.dig('subnet6', 'mask'),
          subnet: iface['subnet6']
        }
      end
      next hash unless data[:raw_addresses].any?

      subnet = data[:raw_addresses].first[:subnet]
      data['vlan'] = subnet['vlanid']
      data['mtu'] = subnet['mtu']

      get_subnet(data, 4)
      get_subnet(data, 6)

      data.compact!

      hash
    end

    munged.each do |_, iface|
      iface.delete :raw_addresses
    end

    munged
  end

  def get_subnet(data, version)
    filter = if version == 4
               proc { |a| a[:ip].ipv4? }
             else
               proc { |a| a[:ip].ipv6? }
             end

    subnet = data[:raw_addresses].find(&filter)&.fetch(:subnet, nil)
    return unless subnet

    data["dhcp#{version}"] = data[:raw_addresses].select(&filter).all? { |a| a[:subnet]['boot_mode'] == 'DHCP' }
    data["mtu#{version}"] = subnet['mtu']
    data["gateway#{version}"] = subnet['gateway']
    data["ips#{version}"] = data[:raw_addresses].select(&filter).map { |a| a[:ip].to_s }
    data["netmasks#{version}"] = data[:raw_addresses].select(&filter).map { |a| a[:netmask] }
    data["cidrs#{version}"] = data[:raw_addresses].select(&filter).map { |a| a[:cidr] }
    data["dns#{version}"] = data[:raw_addresses].select(&filter).map { |a|
      addr = []
      addr << a[:subnet]['dns_primary'] unless a[:subnet]['dns_primary'] == ''
      addr << a[:subnet]['dns_secondary'] unless a[:subnet]['dns_secondary'] == ''
      addr
    }.flatten.uniq
  end
end
