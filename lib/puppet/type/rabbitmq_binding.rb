Puppet::Type.newtype(:rabbitmq_binding) do
  desc 'Native type for managing rabbitmq bindings'

  ensurable do
    defaultto(:present)
    newvalue(:present) do
      provider.create
    end
    newvalue(:absent) do
      provider.destroy
    end
  end

  newparam(:name) do
    desc 'Name set to title. Completely unused. See unique name'
    defaultto('DEFAULT_NAME')
  end

  newparam(:vhost) do
    desc 'Vhost of binding. Defaults to /. Set *on creation*'
    defaultto('/')
  end

  newparam(:source) do
    desc 'Name of source of binding, always an exchange. Set *on creation*'
  end

  newparam(:destination) do
    desc 'Name of destination of binding, queue or exchange. Set *on creation*'
  end

  newparam(:destination_type) do
    desc 'Type of the destination, can be queue or exchange. Set *on creation*'
    newvalues(/queue|exchange/)
    defaultto('queue')
  end

  newparam(:routing_key) do
    desc 'Routing key of binding. Defaults to empty string'
    newvalues(/^[\w\/-]*$/)
    defaultto('')
    munge do |routing_key|
      Puppet.debug 'here first'
      Puppet.debug resource.to_s
      #Puppet.debug resource.vhost.to_s
      routing_key = routing_key
    end
  end

  newparam(:unique_name) do
    desc 'Unique name of binding. It is built on the fly from other fields!'
    defaultto('DEFAULT_NAME')

    validate do |unique_name|
      unless unique_name == 'DEFAULT_NAME'
        raise ArgumentError, 'unique_name field should not be populated in manifest - it is built on the fly from other fields!'
      end
    end

    munge do |unique_name|
      unique_name = resource[:vhost] + resource[:source] + resource[:destination] + resource[:destination_type] + resource[:routing_key]
    end
  end

  newparam(:arguments) do
    desc 'Arguments allow detailed customization of bindings. Expects a Hash. Set *on creation*'
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
