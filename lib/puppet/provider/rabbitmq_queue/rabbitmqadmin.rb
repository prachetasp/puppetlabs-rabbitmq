require 'puppet'
Puppet::Type.type(:rabbitmq_queue).provide(:rabbitmqadmin) do

  commands :rabbitmqctl => '/usr/sbin/rabbitmqctl'
  commands :rabbitmqadmin => '/usr/local/bin/rabbitmqadmin'
  defaultfor :feature => :posix

  # these :arguments fields must be integers in command
  INT_FIELDS=['x-message-ttl', 'x-expires']

  def self.to_bool(val)
    return true if val == true || val == :true || val =~ (/(true|t|yes|y|1)$/i)
    return false if val == false || val == :false || val.empty? || val =~ (/(false|f|no|n|0)$/i)
    raise ArgumentError.new("invalid value for Boolean: \"#{val}\"")
  end

  def should_vhost
    if @should_vhost
      @should_vhost
    else
      @should_vhost = resource[:name].split('@')[1]
    end
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
      if provider = packages.find{ |pkg| pkg.name == name }
        resources[name].provider = provider
      end
    end
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def vhost_and_name
    {:name => resource[:name].split('@')[0],
     :vhost => should_vhost ? "--vhost=#{should_vhost}" : ''
    }
  end

  def clean_arguments
    # some fields must be integers etc.
    args = resource[:arguments]
    unless args.empty?
      INT_FIELDS.each do |field|
        if args.has_key?(field)
          args[field] = args[field].to_i
        end
      end
    end
    args
  end

  def create
    v_and_n = vhost_and_name
    rabbitmqadmin('declare', 'queue', v_and_n[:vhost], "--user=#{resource[:user]}", "--password=#{resource[:password]}", "name=#{v_and_n[:name]}", "durable=#{resource[:durable]}", "auto_delete=#{resource[:auto_delete]}", "arguments=#{clean_arguments.to_json}")
    @property_hash[:ensure] = :present
  end

  def destroy
    v_and_n = vhost_and_name
    rabbitmqadmin('delete', 'queue', v_and_n[:vhost], "--user=#{resource[:user]}", "--password=#{resource[:password]}", "name=#{v_and_n[:name]}")
    @property_hash[:ensure] = :absent
  end

end
