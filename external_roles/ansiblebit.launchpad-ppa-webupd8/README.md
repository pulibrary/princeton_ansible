# ansiblebit.launchpad-ppa-webupd8

[![License](https://img.shields.io/badge/license-New%20BSD-blue.svg?style=flat)](https://raw.githubusercontent.com/ansiblebit/launchpad-ppa-webupd8/master/LICENSE)
[![Build Status](https://travis-ci.org/ansiblebit/launchpad-ppa-webupd8.svg?branch=master)](https://travis-ci.org/ansiblebit/launchpad-ppa-webupd8)

[![Platform](http://img.shields.io/badge/platform-debian-a80030.svg?style=flat)](#)
[![Platform](http://img.shields.io/badge/platform-ubuntu-dd4814.svg?style=flat)](#)

[![Project Stats](https://www.openhub.net/p/ansiblebit-launchpad-ppa-webupd8/widgets/project_thin_badge.gif)](https://www.openhub.net/p/ansiblebit-launchpad-ppa-webupd8/)

An [Ansible](http://www.ansible.com) role to setup the [webupd8](http://www.webupd8.org/) launchpad apt repository. 


## Tests

| Family | Distribution | Version | Test Status |
|:-:|:-:|:-:|:-:|
| Debian | Debian  | Jessie  | [![x86_64](http://img.shields.io/badge/x86_64-passed-006400.svg?style=flat)](#) |
| Debian | Debian  | Wheezy  | [![x86_64](http://img.shields.io/badge/x86_64-passed-006400.svg?style=flat)](#) |
| Debian | Ubuntu  | Precise | [![x86_64](http://img.shields.io/badge/x86_64-passed-006400.svg?style=flat)](#) |
| Debian | Ubuntu  | Trusty  | [![x86_64](http://img.shields.io/badge/x86_64-passed-006400.svg?style=flat)](#) |
| Debian | Ubuntu  | Vivid   | [![x86_64](http://img.shields.io/badge/x86_64-passed-006400.svg?style=flat)](#) |


## Requirements

- ansible >= 1.8.4

# Facts

| variable | description |
|:-:|:--|
| launchpad_ppa_webupd8_os_supported | fact set by this role to determine if the host OS is supported. |


## Role Variables

None.


## Dependencies

None.


## Playbooks

Including an example of how to use your role
(for instance, with variables passed in as parameters)
is always nice for users too:

    - hosts: servers
      roles:
         - { role: ansiblebit.launchpad-ppa-webupd8, launchpad_ppa_webupd8_cache_valid_time: 3600 }


## Changelog

- v3.9.4 : 9 Sep 2015
    - idempotence tests now pass
    - removed launchpad_ppa_webupd8_cache_valid_time variable
- v3.9.2 : 9 Sep 2015
    - fixed tests
- v3.9.0 : 9 Sep 2015
    - merge with primogen v9
    - use ansible 1.9.3
    - removal of duplicate provisioning play when running tests
- v3.7.2 : 9 Sep 2015
    - Debian and Ubuntu update apt cache when adding repositories
- v3.7.0 : 10 Jul 2015
    - don't update the apt repositories cache when you're just adding new repos since it will get updated in the end
    - minor version number will now match primogen major version number
    - merge with ansiblebit.primogen v7
        - upgrade tests to use ansible v1.9.2 instead of v1.9.1
        - pass ANSIBLE_ASK_SUDO_PASS environment variable to the tox test environment
        - improved idempotence test
    - renamed fact os_supported to launchpad_ppa_webupd8_os_supported
- v3.0.0 : 7 May 2015
    - synchronized major version with primogen for easier reference
- v1.1.2 : 5 May 2015
    - standardize tests with primogen v2.2.0
- v1.1.0 : 30 April 2015
    - ansible minimum requirements now set to 1.8.4
    - renamed ppa_webupd8_cache_valid_time to launchpad_ppa_webupd8_cache_valid_time
    - standardized testing with primogen v2.0.6
    - added test/support for debian jessie
    - added test/support for ubuntu vivid
- v1.0.4 : 28 April 2015
    - update_cache is now run with sudo privileges
- v1.0.2 : 17 April 2015
    - update_cache=yes when adding new repositories
- v1.0.0 : 4 April 2015
    - initial release


## Links

- [WebUpd8 team : Oracle Java (JDK) 7 / 8 / 9 Installer PPA](https://launchpad.net/~webupd8team/+archive/ubuntu/java)


## License

BSD


## Author Information

- [steenzout](http://github.com/steenzout)
