import os
import subprocess


def load_eoepca_state():
    # Source the eoepca state and capture the exported variables
    proc = subprocess.Popen(
        "source $HOME/.eoepca/state && env",
        stdout=subprocess.PIPE,
        shell=True,
        executable="/bin/bash",
    )
    output, _ = proc.communicate()
    # Parse the variables and update the environment
    for line in output.decode("utf-8").splitlines():
        key, _, value = line.partition("=")
        os.environ[key] = value
