.. _collections_galaxy_meta:

************************************
Collection Galaxy metadata structure
************************************

A key component of an Ansible collection is the ``galaxy.yml`` file placed in the root directory of a collection. This
file contains the metadata of the collection that is used to generate a collection artifact.

Structure
=========

The ``galaxy.yml`` file must contain the following keys in valid YAML:


.. rst-class:: documentation-table

.. list-table::
    :header-rows: 1
    :widths: auto

    * - Key
      - Comment

    * - .. rst-class:: value-name

        namespace |br|

        .. rst-class:: value-type

        string |_|

        .. rst-class:: value-separator

        / |_|

        .. rst-class:: value-required

        required
        
      - The namespace of the collection.

        This can be a company/brand/organization or product namespace under which all content lives.

        May only contain alphanumeric lowercase characters and underscores. Namespaces cannot start with underscores or numbers and cannot contain consecutive underscores.

        

    * - .. rst-class:: value-name

        name |br|

        .. rst-class:: value-type

        string |_|

        .. rst-class:: value-separator

        / |_|

        .. rst-class:: value-required

        required
        
      - The name of the collection.

        Has the same character restrictions as ``namespace``.

        

    * - .. rst-class:: value-name

        version |br|

        .. rst-class:: value-type

        string |_|

        .. rst-class:: value-separator

        / |_|

        .. rst-class:: value-required

        required
        
      - The version of the collection.

        Must be compatible with semantic versioning.

        

    * - .. rst-class:: value-name

        readme |br|

        .. rst-class:: value-type

        string |_|

        .. rst-class:: value-separator

        / |_|

        .. rst-class:: value-required

        required
        
      - The path to the Markdown (.md) readme file.

        This path is relative to the root of the collection.

        

    * - .. rst-class:: value-name

        authors |br|

        .. rst-class:: value-type

        list |_|

        .. rst-class:: value-separator

        / |_|

        .. rst-class:: value-required

        required
        
      - A list of the collection's content authors.

        Can be just the name or in the format 'Full Name <email> (url) @nicks:irc/im.site#channel'.

        

    * - .. rst-class:: value-name

        description |br|

        .. rst-class:: value-type

        string |_|

        
        
      - A short summary description of the collection.

        

    * - .. rst-class:: value-name

        license |br|

        .. rst-class:: value-type

        list |_|

        
        
      - Either a single license or a list of licenses for content inside of a collection.

        Ansible Galaxy currently only accepts `SPDX <https://spdx.org/licenses/>`_ licenses

        This key is mutually exclusive with ``license_file``.

        

    * - .. rst-class:: value-name

        license_file |br|

        .. rst-class:: value-type

        string |_|

        
        
      - The path to the license file for the collection.

        This path is relative to the root of the collection.

        This key is mutually exclusive with ``license``.

        

    * - .. rst-class:: value-name

        tags |br|

        .. rst-class:: value-type

        list |_|

        
        
      - A list of tags you want to associate with the collection for indexing/searching.

        A tag name has the same character requirements as ``namespace`` and ``name``.

        

    * - .. rst-class:: value-name

        dependencies |br|

        .. rst-class:: value-type

        dictionary |_|

        
        
      - Collections that this collection requires to be installed for it to be usable.

        The key of the dict is the collection label ``namespace.name``.

        The value is a version range `specifiers <https://python-semanticversion.readthedocs.io/en/latest/#requirement-specification>`_.

        Multiple version range specifiers can be set and are separated by ``,``.

        

    * - .. rst-class:: value-name

        repository |br|

        .. rst-class:: value-type

        string |_|

        
        
      - The URL of the originating SCM repository.

        

    * - .. rst-class:: value-name

        documentation |br|

        .. rst-class:: value-type

        string |_|

        
        
      - The URL to any online docs.

        

    * - .. rst-class:: value-name

        homepage |br|

        .. rst-class:: value-type

        string |_|

        
        
      - The URL to the homepage of the collection/project.

        

    * - .. rst-class:: value-name

        issues |br|

        .. rst-class:: value-type

        string |_|

        
        
      - The URL to the collection issue tracker.

        

    * - .. rst-class:: value-name

        build_ignore |br|

        .. rst-class:: value-type

        list |_|

        
        .. rst-class:: value-added-in

        |br| version_added: 2.10

        |_|
      - A list of file glob-like patterns used to filter any files or directories that should not be included in the build artifact.

        A pattern is matched from the relative path of the file or directory of the collection directory.

        This uses ``fnmatch`` to match the files or directories.

        Some directories and files like ``galaxy.yml``, ``*.pyc``, ``*.retry``, and ``.git`` are always filtered.

        

Examples
========

.. code-block:: yaml

    namespace: "namespace_name"
    name: "collection_name"
    version: "1.0.12"
    readme: "README.md"
    authors:
        - "Author1"
        - "Author2 (https://author2.example.com)"
        - "Author3 <author3@example.com>"
    dependencies:
        "other_namespace.collection1": ">=1.0.0"
        "other_namespace.collection2": ">=2.0.0,<3.0.0"
        "anderson55.my_collection": "*"    # note: "*" selects the highest version available
    license:
        - "MIT"
    tags:
        - demo
        - collection
    repository: "https://www.github.com/my_org/my_collection"

.. seealso::

  :ref:`developing_collections`
       Develop or modify a collection.
  :ref:`developing_modules_general`
       Learn about how to write Ansible modules
  :ref:`collections`
       Learn how to install and use collections.
  `Mailing List <https://groups.google.com/group/ansible-devel>`_
       The development mailing list
  `irc.libera.chat <https://libera.chat/>`_
       #ansible IRC chat channel