require 'puppet'
Puppet::Type.type(:rabbitmq_binding).provide(:rabbitmqadmin) do

  commands :rabbitmqctl => '/usr/sbin/rabbitmqctl'
  commands :rabbitmqadmin => '/usr/local/bin/rabbitmqadmin'
  defaultfor :feature => :posix

  def self.all_vhosts
    vhosts = []
    parse_command(rabbitmqctl('list_vhosts')).collect do |vhost|
        vhosts.push(vhost)
    end
    vhosts
  end

  def self.all_bindings(vhost)
    bindings = []
    parse_command(rabbitmqctl('list_bindings', '-p', vhost, 'source_name', 'destination_name', 'destination_kind', 'routing_key'))
  end

  def self.parse_command(cmd_output)
    # first line is:
    # Listing bindings ...
    # while the last line is
    # ...done.
    #
    cmd_output.split(/\n/)[1..-2]
  end

  def self.instances
    resources = []
    all_vhosts.each do |vhost|
        all_bindings(vhost).collect do |line|
            binding_params = line.split()
            # either source_name (default exchange) or routing key can be an empty
            # string so we must explicitly replace the missing param with empty strings
            if binding_params.length == 3
              # this is a tricky case since we don't know which value is the empty string
              if binding_params.last =~ /queue|exchange/
                binding_params.push('')
              else
                binding_params.insert(0, '')
              end
            end
            # we don't care to match up arguments because the resource cannot be changed
            # honestly don't care about anything but name for prefetch
            binding = {
              :ensure           => :present,
              :name             => "%s%s%s%s%s" % [vhost, *binding_params],
              :vhost            => vhost,
              :source           => binding_params[0],
              :destination      => binding_params[1],
              :destination_type => binding_params[2],
              :routing_key      => binding_params[3],
            }
            # only create binding resource if it is not on the default exchange
            resources << new(binding) if binding_params[0] != ''
        end
    end
    resources
  end

  def self.prefetch(resources)
    packages = instances
    resources.keys.each do |name|
      if provider = packages.find{ |pkg| pkg.name == resources[name][:unique_name] }
        resources[name].provider = provider
      end
    end
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def create
    rabbitmqadmin('declare', 'binding', "--vhost=#{resource[:vhost]}", "--user=#{resource[:user]}", "--password=#{resource[:password]}", "source=#{resource[:source]}", "destination=#{resource[:destination]}", "destination_type=#{resource[:destination_type]}", "routing_key=#{resource[:routing_key]}", "arguments=#{resource[:arguments]}")
    @property_hash[:ensure] = :present
  end

  def destroy
    rabbitmqadmin('delete', 'binding', "--vhost=#{resource[:vhost]}", "--user=#{resource[:user]}", "--password=#{resource[:password]}", "source=#{resource[:source]}", "destination=#{resource[:destination]}", "destination_type=#{resource[:destination_type]}", "properties_key=#{resource[:routing_key]}")
    @property_hash[:ensure] = :absent
  end

end
