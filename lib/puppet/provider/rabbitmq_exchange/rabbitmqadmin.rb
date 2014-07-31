require 'puppet'
Puppet::Type.type(:rabbitmq_exchange).provide(:rabbitmqadmin) do

  commands :rabbitmqctl => '/usr/sbin/rabbitmqctl'
  commands :rabbitmqadmin => '/usr/local/bin/rabbitmqadmin'
  defaultfor :feature => :posix

  # these :arguments fields must be integers in command
  EXCHANGE_INT_FIELDS=['x-max-hops']

  def self.all_vhosts
    vhosts = []
    parse_command(rabbitmqctl('list_vhosts')).collect do |vhost|
        vhosts.push(vhost)
    end
    vhosts
  end

  def self.all_exchanges(vhost)
    exchanges = []
    parse_command(rabbitmqctl('list_exchanges', '-p', vhost, 'name', 'type'))
  end

  def self.parse_command(cmd_output)
    # first line is:
    # Listing exchanges/vhosts ...
    # while the last line is
    # ...done.
    #
    cmd_output.split(/\n/)[1..-2]
  end

  def self.instances
    resources = []
    all_vhosts.each do |vhost|
        all_exchanges(vhost).collect do |line|
            if line[0] != 9
              name, type = line.split("\t")
              exchange = {
                :type   => type,
                :ensure => :present,
                :name   => "%s@%s" % [name, vhost],
              }
              resources << new(exchange)
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
    resources
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def clean_arguments
    # some fields must be integers etc.
    args = resource[:arguments]
    unless args.empty?
      EXCHANGE_INT_FIELDS.each do |field|
        if args.has_key?(field)
          args[field] = args[field].to_i
        end
      end
    end
    args
  end

  def create
    rabbitmqadmin('declare', 'exchange', "--vhost=#{resource[:vhost]}", "--user=#{resource[:user]}", "--password=#{resource[:password]}", "name=#{resource[:exchange_name]}", "type=#{resource[:type]}", "durable=#{resource[:durable]}", "auto_delete=#{resource[:auto_delete]}", "internal=#{resource[:internal]}", "arguments=#{clean_arguments.to_json}")
    @property_hash[:ensure] = :present
  end

  def destroy
    rabbitmqadmin('delete', 'exchange', "--vhost=#{resource[:vhost]}", "--user=#{resource[:user]}", "--password=#{resource[:password]}", "name=#{resource[:exchange_name]}")
    @property_hash[:ensure] = :absent
  end

end
