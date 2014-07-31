require 'puppet'
Puppet::Type.type(:rabbitmq_binding).provide(:rabbitmqadmin) do

  commands :rabbitmqctl => '/usr/sbin/rabbitmqctl'
  commands :rabbitmqadmin => '/usr/local/bin/rabbitmqadmin'
  defaultfor :feature => :posix

  BINDING_INT_FIELDS = [['x-bound-from', 'hops']]

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
            # only create binding resource if it is not on the default exchange
            # checks if first character is a tab which means default exchange binding
            if line[0] != 9
              # checks if last character is a tab which means empty routing key
              if line[-1] == 9
                source, destination, destination_type = line.split("\t")
                routing_key = ''
              else
                source, destination, destination_type, routing_key = line.split("\t")
              end
            # honestly don't care about anything but name for prefetch
            binding = {
              :ensure           => :present,
              :name             => "%s%s%s%s%s" % [vhost, source, destination, destination_type, routing_key],
              :vhost            => vhost,
              :source           => source,
              :destination      => destination,
              :destination_type => destination_type,
              :routing_key      => routing_key,
            }
            resources << new(binding)
          end
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
    rabbitmqadmin('declare', 'binding', "--vhost=#{resource[:vhost]}", "--user=#{resource[:user]}", "--password=#{resource[:password]}", "source=#{resource[:source]}", "destination=#{resource[:destination]}", "destination_type=#{resource[:destination_type]}", "routing_key=#{resource[:routing_key]}", "arguments=#{resource[:arguments].to_json}")
    @property_hash[:ensure] = :present
  end

  def destroy
    rabbitmqadmin('delete', 'binding', "--vhost=#{resource[:vhost]}", "--user=#{resource[:user]}", "--password=#{resource[:password]}", "source=#{resource[:source]}", "destination=#{resource[:destination]}", "destination_type=#{resource[:destination_type]}", "properties_key=#{resource[:routing_key] == '' ? '~' : resource[:routing_key]}")
    @property_hash[:ensure] = :absent
  end

end
