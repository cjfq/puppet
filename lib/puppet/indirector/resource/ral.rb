require 'puppet/indirector/resource/validator'

class Puppet::Resource::Ral < Puppet::Indirector::Code
  include Puppet::Resource::Validator

  desc "Manipulate resources with the resource abstraction layer. Only used internally."

  def allow_remote_requests?
    false
  end

  def find( request )
    # find by name
    res   = type(request).instances.find { |o| o.name == resource_name(request) }
    if !res
      res = type(request).new(:name => resource_name(request))
      # Register all of the properties for data collection
      type(request).properties.collect do |s|
        res.newattr(s.name.to_sym)
      end
    end

    res.to_resource
  end

  def search( request )
    conditions = request.options.dup
    conditions[:name] = resource_name(request) if resource_name(request)

    type(request).instances.map do |res|
      res.to_resource
    end.find_all do |res|
      conditions.all? {|property, value| res.to_resource[property].to_s == value.to_s}
    end.sort do |a,b|
      a.title <=> b.title
    end
  end

  def save( request )
    # In RAL-land, to "save" means to actually try to change machine state
    res = request.instance
    ral_res = res.to_ral

    catalog = Puppet::Resource::Catalog.new(nil, request.environment)
    catalog.add_resource ral_res
    transaction = catalog.apply

    [ral_res.to_resource, transaction.report]
  end

  private

  # {type,resource}_name: the resource name may contain slashes:
  # File["/etc/hosts"]. To handle, assume the type name does
  # _not_ have any slashes in it, and split only on the first.

  def type_name( request )
    request.key.split('/', 2)[0]
  end

  def resource_name( request )
    name = request.key.split('/', 2)[1]
    name unless name == ""
  end

  def type( request )
    Puppet::Type.type(type_name(request)) or raise Puppet::Error, _("Could not find type %{request_type}") % { request_type: type_name(request) }
  end
end
