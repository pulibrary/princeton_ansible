Fits
====

Installs fits

Requirements
------------

Requires the `unzip` package available.

Role Variables
--------------

* `fits_version`: Version to install
* `fits_install`: Location to install
* `fits_disable_tika`: (boolean) Disable Apache Tika Toolkit

Dependencies
------------

Ansible 1.9+

Example Playbook
----------------

    - hosts: servers
      roles:
         - { role: ucsdlib.fits, fits_version: 1.0.2 }

License
-------

BSD 2 Clause

Author Information
------------------

John H. Robinson, IV  
The Library  
UC San Diego  
