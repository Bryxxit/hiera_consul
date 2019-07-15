# The `consul_lookup` is a hiera 5 `data_hash` data provider function.
# See [the configuration guide documentation](https://puppet.com/docs/puppet/latest/hiera_config_yaml_5.html#configuring-a-hierarchy-level-built-in-backends) for
# how to use this function.
#
## This lookup uses some code from https://github.com/crayfishx/hiera-http/blob/master/lib/puppet/functions/hiera_http.rb
require 'net/http'
require 'net/https'
require 'json'
require 'base64'
require 'yaml'

# https://stackoverflow.com/a/32268942/9164420
class ::Hash
  def deep_merge(second)
    merger = proc { |key, v1, v2| Hash === v1 && Hash === v2 ? v1.merge(v2, &merger) : v2 }
    self.merge(second, &merger)
  end
end

Puppet::Functions.create_function(:consul_lookup) do
  dispatch :consul_lookup do
    param 'Variant[String, Numeric]', :key
    param 'Hash', :options
    param 'Puppet::LookupContext', :context
  end
  

  def consul_lookup(key, options, context)
    options['base_uri'] = 'http://localhost:8500/v1/kv' unless options['base_uri']
    result = parse_url(options['base_uri'], options['uri'])
    answer = return_answer(result, key, options)
    if answer == :not_found
      context.not_found
      return nil
    else
      return context.interpolate(answer)
    end
    # end
  end
  def lookup_supported_params
    [
        :output,
        :failure,
        :ignore_404,
        :headers,
        :http_connect_timeout,
        :http_read_timeout,
        :use_ssl,
        :ssl_ca_cert,
        :ssl_cert,
        :ssl_key,
        :ssl_verify,
        :base_uri,
    ]
  end

  def return_answer(result, key, options)

    # dig defaults to true, dig_key defaults to the value of the 
    # lookup key.
    #
    dig = options.has_key?('dig') ? options['dig'] : true
    dig_key = options.has_key?('dig_key') ? options['dig_key'] : key

    # Interpolate values such as __KEY__ into each element of the
    # dig path, eg: dig_key: document.data.__MODULE__
    #
    dig_path = dig_key.split(/\./).map { |p| parse_tags(key, p) }


    if result.nil?
      return :not_found
    elsif result.is_a?(Hash)
      return dig ? hash_dig(result, dig_path) : result
    else
      return result
    end

  end


  def hash_dig(data, dig_path)
    key = dig_path.shift
    if dig_path.empty?
      if data.has_key?(key)
        return data[key]
      else
        return :not_found
      end
    else
      return :not_found unless data[key].is_a?(Hash)
      return hash_dig(data[key], dig_path)
    end
  end

  def parse_tags(key,str)
    key_parts = key.split(/::/)

    parsed_str = str.gsub(/__(\w+)__/i) do
      case $1
      when 'KEY'
        key
      when 'MODULE'
        key_parts.first if key_parts.length > 1
      when 'CLASS'
        key_parts[0..-2].join('::') if key_parts.length > 1
      when 'PARAMETER'
        key_parts.last
      end
    end

    return parsed_str
  end

  def parse_url(base_url, key2)
    # base_url: the basic  path to your api eg. 'http://localhost:8500/v1/kv'
    # key: The key to search eg production
    # First see if the key is defined
    url = base_url + "/" + key2
    h = get_key(url)
    hashes = []
    hashes.push(h)
    ## next we see if this is also a directory
    # TODO ensure datacenter value is set &dc=...
    keys = get_keys(url + '/?keys&separator=%2F')
    keys.each do |key3|
      ### if key is not a directory we collect the hash values
      unless key3.end_with?("/")
        hashes.push(get_key(base_url + '/' + key3))
      end
    end

    ### lastly merge all hashes an return
    # for keys the last value is always used
    full_hash = {}
    hashes.each do |h|
      ### TODO set merge strategy
      # This will merge hashes
      full_hash = full_hash.deep_merge(h)
      # this will only take the latest entry its value
      # full_hash = full_hash.merge(h)
    end
    full_hash
  end

### get_keys scans the given url for available keys
  def get_keys(url)
    uri = URI(url)
    response = Net::HTTP.get(uri)
    if response != ""
      return JSON.parse(response)
    end
    []
  end

### get_key gets yaml data from the url endpoint and returns them in hash form
  def get_key(url)
    uri = URI(url)
    response = Net::HTTP.get(uri)
    unless response == ""
      json_arr = JSON.parse(response)
      if json_arr.length > 0
        j = json_arr[0]
        yaml_data = Base64.decode64(j['Value'])
        return YAML.load(yaml_data)
      end
    end
    {}
  end
end