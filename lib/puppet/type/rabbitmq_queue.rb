Puppet::Type.newtype(:rabbitmq_queue) do
  desc 'Native type for managing rabbitmq queues'

  ensurable do
    defaultto(:present)
    newvalue(:present) do
      provider.create
    end
    newvalue(:absent) do
      provider.destroy
    end
  end

  newparam(:name, :namevar => true) do
    desc 'Name of queue'
    newvalues(/^\S*@\S+$/)
  end

  newparam(:durable) do
    desc 'Durable queues survive broker restarts. Set *on creation*'
    newvalues(/true|false/)
    # Can the following be broken out into a method?
    munge do |value|
      # converting to_s incase its a boolean
      value.to_s.to_sym
    end
    defaultto :true
  end

  newparam(:auto_delete) do
    desc 'Auto delete queues are deleted when the last consumer disconnects. Set *on creation*'
    newvalues(/true|false/)
    # Can the following be broken out into a method?
    munge do |value|
      # converting to_s incase its a boolean
      value.to_s.to_sym
    end
    defaultto :false
  end


  newparam(:arguments) do
    desc 'Arguments allow detailed customization of queues. Expects a Hash. Set *on creation*'
    defaultto({})
    validate do |arguments|
      unless arguments.is_a?(Hash)
        raise ArgumentError, 'arguments must be a Hash'
      end
    end
  end

  newparam(:user) do
    desc 'The user to use to connect to rabbitmq'
    defaultto('guest')
    newvalues(/^\S+$/)
  end

  newparam(:password) do
    desc 'The password to use to connect to rabbitmq'
    defaultto('guest')
    newvalues(/\S+/)
  end

  autorequire(:rabbitmq_vhost) do
    [self[:name].split('@')[1]]
  end

  autorequire(:rabbitmq_user) do
    [self[:user]]
  end

  autorequire(:rabbitmq_user_permissions) do
    ["#{self[:user]}@#{self[:name].split('@')[1]}"]
  end

end
