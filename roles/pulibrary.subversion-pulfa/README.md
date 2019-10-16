pulibrary.subversion-pulfa
=========

This role downloads the EAD files for the Princeton University Library Finding 
Aids (PULFA) tracked using Subversion.

Requirements
------------

None

Role Variables
--------------

`subversion_pulfa_repo`: the URL for the Subversion repository
`subversion_pulfa_dir_path`: the directory into which the tree is checked out
`subversion_pulfa_username`: the repository user name
`subversion_pulfa_password`: the repository password

Dependencies
------------

This role depends on `pulibrary.subversion`

Example Playbook
----------------

    - hosts: servers
      roles:
         - { role: pulibrary.subversion-pulfa, subversion_pulfa_username: archivist1, subversion_pulfa_password: secret }

License
-------

MIT

Author Information
------------------

Please find us at [https://github.com/pulibrary].
