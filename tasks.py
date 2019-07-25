from invoke import task
import os
from pathlib import Path

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
