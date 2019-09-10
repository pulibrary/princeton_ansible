from functools import reduce
import glob
from invoke import task
import os
from pathlib import Path
import subprocess
import sys


@task
def test(command):
    # Retrieve all possible roles with molecule tests
    current_path = os.path.dirname(os.path.realpath(__file__))
    role_paths = []
    for glob_path in glob.glob(f"{current_path}/roles/**/molecule/.."):
        role_path = os.path.realpath(glob_path)
        role_paths.append(role_path)

    # Divide and find out which subset should have their tests run

    # The parallelism setting
    if 'CI_NODE_TOTAL' in os.environ:
        batch_size = int(os.environ['CI_NODE_TOTAL'])
    else:
        batch_size = len(role_paths)

    # The job index passed by the current CI build environment
    if 'CI_NODE_INDEX' in os.environ:
        job_index = int(os.environ['CI_NODE_INDEX'])
    else:
        job_index = 0

    roles_indices = range((len(role_paths) + batch_size - 1) // batch_size)
    roles_subsets = [role_paths[i*batch_size:(i+1)*batch_size] for i in roles_indices]
    roles_subset = roles_subsets[job_index]

    # Execute each Molecule test
    statuses = []
    # Unfortunately, these still need to block for the process status code to be
    #   returned (please see https://docs.python.org/3/library/os.html#os.spawnvp)
    for role_path in roles_subset:
        role_molecule_command_args = ["molecule", "test"]
        completed = subprocess.run(role_molecule_command_args, cwd=role_path)
        status = completed.returncode
        statuses.append(status)

    # Reduce the status of each
    exit_status = reduce((lambda u, v: u | v), statuses)
    sys.exit(exit_status)


@task
def molecularize(command, role):
    current_path = os.path.dirname(os.path.realpath(__file__))
    role_dir_path = Path(current_path, "roles", role)
    if not role_dir_path.exists():
        raise Exception(f"The directory for {role} does not exist {role_dir_path}."
                        "  Have you created this role and place it within the"
                        " \"roles\" directory?")
    role_molecule_dir_path = Path(role_dir_path, "molecule")
    if role_molecule_dir_path.exists():
        raise Exception(f"Molecule test suite(s) already exist for {role}."
                        " Please remove these before attempting to regenerate a"
                        " new configuration.")

    molecule_defaults_path = Path(current_path, "molecule", "default", "molecule.yml")
    if not molecule_defaults_path.exists():
        raise Exception(f"Failed to find the molecule default configuration file"
                        " in {molecule_defaults_path}")
    molecule_playbooks_path = Path(current_path, "molecule", "default", "playbooks.yml")
    if not molecule_playbooks_path.exists():
        raise Exception(f"Failed to find the molecule playbooks file in"
                        " {molecule_defaults_path}")
    tmp_roles_path = Path("/", "tmp", "roles")
    tmp_role_dir_path = Path(tmp_roles_path, role)
    if tmp_role_dir_path.exists():
        command.run(f"/bin/rm -rf {tmp_role_dir_path}")
    command.run(f"/bin/mkdir -p {tmp_role_dir_path}")
    command.run(f"/bin/mv {role_dir_path} {tmp_roles_path}")
    command.run(f"cd roles && molecule init role -r {role}")
    command.run(f"/bin/rm -rf {role_dir_path}/defaults")
    command.run(f"/bin/rm -rf {role_dir_path}/tasks")
    command.run(f"/bin/cp -r {tmp_role_dir_path}/* {role_dir_path}")
    command.run(f"/bin/cp {molecule_defaults_path} {role_dir_path}/molecule/default/")
    command.run(f"/usr/bin/sed -i -e 's/playbooks\.yml/playbook\.yml/' {role_dir_path}/molecule/default/molecule.yml")
    command.run(f"/usr/bin/sed -i -e 's/roles:/&\\\n    - role: {role}/' {molecule_playbooks_path}")
