Role Name
=========

A role that installs a shibboleth service provider. Note that running this role 
alone will not be enough to set up shibboleth authentication. 

This installation attempts to follow the guides here: 
* https://medium.com/@winma.15/shibboleth-sp-installation-in-ubuntu-d284b8d850da
* https://www.switch.ch/aai/guides/sp/configuration/

This role will install shibd, apache2, and the apache2 modules necessary, which include SSL.
In order to configure SSL, you will need to generate SSL keys and put them into a vault in 
the group_vars directory for your project. See group_vars/vireo for an example.

After running this role, you should be able to run this on the command line and see 
your shibboleth metadata.

```
curl --insecure https://localhost/Shibboleth.sso/Metadata
```

In your playbook, you will also need to set up an SSL enabled virtual host. Again, see
the vireo role for an example. After setting that up, you should be able to visit the 
following url and see the same shibboleth metadata (except it will have your server name
instead of localhost)

https://YOUR_SERVER_NAME/Shibboleth.sso/Metadata

Once that's working you will need to contact the Identity and Access 
Management group in OIT: Fill out this form to register a new service provider 
(a.k.a. "shibboleth-sp"). Note that it will require the Metadata url mentioned above.
https://princeton.service-now.com/service?id=sc_cat_item&sys_id=edd831664f2c3340f56c0ad14210c7df

Requirements
------------

The Apache Webserver

Role Variables
--------------

* The [defaults/main.yml](defaults/main.yml) lists the ubuntu release
* shib_hostname: e.g., "vireo-staging.princeton.edu"
  * `shib_hostname` will become your shibboleth `entityID`. Note that shib_hostname must NOT include the https prefix. This is the hostname as it appears to the OIT shibboleth auth service.
* shib_host: e.g., "vireo-staging"

Dependencies
------------

The common and apache2 roles.

Example Playbook
----------------

This role will usually be the dependent on another and is therefore unlikely to have/need a playbook.

License
-------

BSD

Author Information
------------------

An optional section for the role authors to include contact information, or a
website (HTML is not allowed).
