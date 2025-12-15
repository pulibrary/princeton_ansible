# Execution Environments in Tower

Jobs in Tower run inside containers called execution environments, or EEs. In our old Tower environment, we ran everything on the default EE and installed the Ansible collections we needed into the EE at runtime. Now we can build custom EEs, building in the collections and other tools we need for each template ahead of time.

## Building a new EE

Our custom EEs are built from the YAML files in the ``tower_ees`` directory of the princeton_ansible repo. To build or rebuild an EE:

### Initial steps

* Log into an x86-architected machine (NOT a Mac laptop with an M-series chip) or have a solution for building x86-architected containers on your M-series Mac. If you build on an M-series chip without a solution, the resulting image will fail to load on Tower with the error ``image platform (linux/arm64) does not match the expected platform (linux/amd64)``.
* Authenticate to registry.redhat.io.  If you have sufficient privileges, you can access the authentication details for a service account from <https://access.redhat.com/terms-based-registry/>
* Authenticate to quay.io. For easy authN, create a ~/.config/containers/auth.json file with the top level items ‘auths’ and an entry for each container registry you want to use. Each entry contains a key/value pair: the key is “auth” and the value is the output of “echo -n ‘username:password’ | openssl base64”. See [this PR](https://github.com/containers/image/pull/821/files) and [this superuser post](https://superuser.com/questions/120796/how-to-encode-base64-via-command-line) for more details. To authenticate from the command line: ``podman login quay.io``
* Open the princeton_ansible repo and change into the tower_ees directory: ``cd tower_ees``
* Create or Edit an EE definition file as needed: ``vim my-execution-environment.yml``
* Run podman-desktop.
* Run [ansible-builder](https://ansible.readthedocs.io/projects/builder/en/stable/index.html): ``ansible-builder build -v3 -f my-execution-environment.yml -t <TagOrNameOfEE> --squash all``
  * On an M-series (ARM) machine, you may instead `cd context && podman manifest create execution-environment-manifest && cd .. && podman build --platform linux/amd64  --manifest execution-environment-manifest -f context/Containerfile -t core2dot15:1.3`
* Note the hash of the built image in the output of the ansible-builder command.
* Push the new image to quay.io: ``podman push <hash-of-image-ID> quay.io/pulibrary/<name-of-image>:<image-tag>``. This command also creates a new repository on quay.io if needed.
* If the repository is new, log into quay.io and grant the pulibrary+ansibletower robot user `Read` permissions to it.
* Create an EE in Tower, or update the existing EE to point to the new tag. For changes to existing EEs, test the Templates that use the EE. If anything fails, reset the EE to pull the previous tag.
