
# hiera_consul

This module installs the consul_lookup backend. This backend has only been tested with hiera 5. THis module borrowed some code from following module https://github.com/crayfishx/hiera-http. But it is node a requirement to use this one.



## Sample configuration
``yaml
---
......
  - name: "consul lookup"
    lookup_key: "consul_lookup"
    uris:
      - 'nodes/%{hostname}'
    options:
       base_uri: 'http://consulserver.org:8500/v1/kv' [Defaults to http://localhost:8500/v1/kv]

``` 



## Why should I use this module and how does it work.
- This module is ment to be used with the hiera key/value store. This way you can easily manage hiera data and seperate it from your puppet environment/code.
- This module has a different lookup structure allowing you to have a directory for a key

Opposed to as with a normal hiera lookup where you look for a single file e.g nodes/hostname this module looks in the following way. nodes/hostname and nodes/hostname/*.

This means you can seperate your hiera data a bit more given a better overview so for example you could put all user needed data in nodes/hostname/users.

It will merge hashes found in the seperate files. A normal hash is merged but if a diplicate key,array,value is found the latest found value will be used. First nodes/hostname will be collected and then nodes/hostnames/*.


## WIP 
The module is still somewhat new. So feedback and issues are always welcome.

