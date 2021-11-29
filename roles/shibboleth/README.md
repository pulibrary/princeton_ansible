Role Name
=========

A role that installs a shibboleth service provider. Note that running this role 
alone will not be enough to set up shibboleth authentication. 

First, run this role and ensure you can get to https://YOUR_SERVER_NAME/Shibboleth.sso/Metadata

Once that's working you will also need to contact the Identity and Access 
Management group in OIT: Fill out this form to register a new service provider 
(a.k.a. "shibboleth-sp"). Note that it will require the Metadata url mentioned above.
https://princeton.service-now.com/service?id=sc_cat_item&sys_id=edd831664f2c3340f56c0ad14210c7df


Requirements
------------

The Apache Webserver

Role Variables
--------------

* The [defaults/main.yml](defaults/main.yml) lists the ubuntu release
* shib_hostname: e.g., "https://vireo-staging.princeton.edu"
  * `shib_hostname` will become your shibboleth `entityID`. Note that shib_hostname must include the https prefix. This is the hostname as it appears to the OIT shibboleth auth service.
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
