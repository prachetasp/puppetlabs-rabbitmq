Puppet::Type.newtype(:rabbitmq_exchange) do
  desc 'Native type for managing rabbitmq exchanges'

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
    desc 'Name of exchange'
    defaultto('DEFAULT_NAME')
  end

  newparam(:vhost) do
    desc 'Vhost of exchange. Defaults to /. Set *on creation*'
    defaultto('/')
  end

  newparam(:exchange_name) do
    desc 'Name of exchange. Set *on creation*'
    newvalues(/^((?!\s\s).)+$/)
  end

  newparam(:unique_name) do
    desc 'Unique name of exchange. It is built on the fly from other fields!'
    defaultto('DEFAULT_NAME')

    validate do |unique_name|
      unless unique_name == 'DEFAULT_NAME'
        raise ArgumentError, 'unique_name field should not be populated in manifest - it is built on the fly from other fields!'
      end
    end

    munge do |unique_name|
      unique_name = resource[:exchange_name] + '@' + resource[:vhost]
    end
  end

  newparam(:type) do
    desc 'Exchange type to be set *on creation*'
    newvalues(/^\S+$/)
  end

  newparam(:durable) do
    desc 'Durable exchanges survive broker restarts. Set *on creation*'
    newvalues(/true|false/)
    # Can the following be broken out into a method?
    munge do |value|
      # converting to_s incase its a boolean
      value.to_s.to_sym
    end
    defaultto :true
  end

  newparam(:auto_delete) do
    desc 'Auto delete exchanges are deleted when the last consumer disconnects. Set *on creation*'
    newvalues(/true|false/)
    # Can the following be broken out into a method?
    munge do |value|
      # converting to_s incase its a boolean
      value.to_s.to_sym
    end
    defaultto :false
  end

  newparam(:internal) do
    desc 'Internal exchanges cannot be published to by clients. Set *on creation*'
    newvalues(/true|false/)
    # Can the following be broken out into a method?
    munge do |value|
      # converting to_s incase its a boolean
      value.to_s.to_sym
    end
    defaultto :false
  end

  newparam(:arguments) do
    desc 'Arguments allow detailed customization of exchanges. Expects a Hash. Set *on creation*'
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

  validate do
    if self[:ensure] == :present and self[:type].nil?
      raise ArgumentError, "must set type when creating exchange for #{self[:name]} whose type is #{self[:type]}"
    end
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
