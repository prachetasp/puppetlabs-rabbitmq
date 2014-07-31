require 'puppet'
Puppet::Type.type(:rabbitmq_queue).provide(:rabbitmqadmin) do

  commands :rabbitmqctl => '/usr/sbin/rabbitmqctl'
  commands :rabbitmqadmin => '/usr/local/bin/rabbitmqadmin'
  defaultfor :feature => :posix

  # these :arguments fields must be integers in command
  QUEUE_INT_FIELDS=['x-message-ttl', 'x-expires']

  def self.to_bool(val)
    return true if val == true || val == :true || val =~ (/(true|t|yes|y|1)$/i)
    return false if val == false || val == :false || val.empty? || val =~ (/(false|f|no|n|0)$/i)
    raise ArgumentError.new("invalid value for Boolean: \"#{val}\"")
  end

  def self.all_vhosts
    vhosts = []
    parse_command(rabbitmqctl('list_vhosts')).collect do |vhost|
        vhosts.push(vhost)
    end
    vhosts
  end

  def self.all_queues(vhost)
    queues = []
    # only need name here because queues cannot be updated and have no properties
    # so we just need to ensure present or absent not complete resource match
    parse_command(rabbitmqctl('list_queues', '-p', vhost, 'name'))
  end

  def self.parse_command(cmd_output)
    # first line is:
    # Listing queues ...
    # while the last line is
    # ...done.
    #
    cmd_output.split(/\n/)[1..-2]
  end

  def self.instances
    queues = []
    all_vhosts.each do |vhost|
        all_queues(vhost).collect do |line|
          queues << new({:ensure => :present, :name => "%s@%s" % [line, vhost]})
        end
    end
    queues
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

  def self.clean_arguments
    # some fields must be integers etc.
    args = resource[:arguments]
    unless args.empty?
      QUEUE_INT_FIELDS.each do |field|
        if args.has_key?(field)
          args[field] = args[field].to_i
        end
      end
    end
    args
  end

  def create
    rabbitmqadmin('declare', 'queue', "--vhost=#{resource[:vhost]}", "--user=#{resource[:user]}", "--password=#{resource[:password]}", "name=#{resource[:queue_name]}", "durable=#{resource[:durable]}", "auto_delete=#{resource[:auto_delete]}", "arguments=#{self.clean_arguments.to_json}")
    @property_hash[:ensure] = :present
  end

  def destroy
    rabbitmqadmin('delete', 'queue', "--vhost=#{resource[:vhost]}", "--user=#{resource[:user]}", "--password=#{resource[:password]}", "name=#{resource[:queue_name]}")
    @property_hash[:ensure] = :absent
  end

end
