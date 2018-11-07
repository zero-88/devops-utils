#!/usr/bin/python
"""
Kubernetes deployment script
"""

import argparse
import fileinput
import logging
import os
import re
import subprocess
from os.path import isfile
from pathlib import Path

from dotenv import dotenv_values, load_dotenv

parser = argparse.ArgumentParser()
parser.add_argument("-e", "--env", action="store", default="dev", choices=["dev", "stag", "prod"], help="Environment")
parser.add_argument("-m", "--mode", action="store", default="minikube", choices=["local", "gcp"], help="Cluster mode")
parser.add_argument("-d", "--dir", action="store", default="./", type=str, help="Working directory")
parser.add_argument("-v", "--verbose", action="store_true", help="Verbose log")
args = parser.parse_args()
logging.basicConfig(level=logging.DEBUG if args.verbose else logging.INFO, handlers=[logging.StreamHandler()],
                    format="%(asctime)s %(levelname)-5s %(name)s %(message)s")
logger = logging.getLogger("k8s_deploy")


def __subtitle_var(f_yaml: str, envs: dict) -> str:
    content = ""
    with fileinput.FileInput(f_yaml, inplace=False, backup=".bak") as f:
        for line in f:
            new_line = line
            for key, val in envs.items():
                new_line = new_line.replace("$"+key, val or "\"\"")
            content += new_line
    return content


def __execute_command(command: list):
    complete = subprocess.run(command, env=os.environ,
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    try:
        if complete.returncode == 0:
            logger.debug("\t%s", complete)
        else:
            logger.info("-" * 25)
            logger.info("\tstdout:\n%s", complete.stdout.decode('utf-8'))
            logger.info("-" * 25)
            logger.error("\tstderr:\n%s", complete.stderr.decode('utf-8'))
            logger.info("-" * 25)
            raise RuntimeError("Failed when executing command: %s" % command)
    finally:
        logger.log(logging.INFO if complete.returncode == 0 else logging.ERROR,
                   "\tReturn code: %s", complete.returncode)


def __execute_yaml(f_yaml: str, envs: dict):
    logger.info("- YAML: %s", f_yaml)
    content = __subtitle_var(f_yaml, envs)
    logger.debug(content)
    logger.debug("-" * 50)
    __execute_command(["echo", content, "|", "kubectl", "apply", "-f", "-"])


def __execute_py(f_py: str, envs: dict):
    logger.info("- PYTHON: %s", f_py)
    logger.warning("Not yet implemented")


def __execute(f: str, envs: dict):
    if f.endswith(".yaml"):
        __execute_yaml(f, envs)
    if f.endswith(".py"):
        __execute_py(f, envs)
    if f.endswith(".sh"):
        logger.info("- BASH: %s", f)
        __execute_command(["bash", f])


def run(mode: str, envs: dict):
    files = sorted([f for f in os.listdir() if isfile(f) and re.match(r"^\d{2}_.+\.(yaml|sh|py)$", f)])
    for f in files:
        if re.match(r"^0\d_.+", f):
            if mode == "gcp":
                __execute(f, envs)
            continue
        __execute(f, envs)


def load_env(arguments):
    load_dotenv()
    envs = dotenv_values()
    if arguments.env == "prod":
        prod_env = Path("./.prod.env")
        load_dotenv(dotenv_path=prod_env, override=True)
        envs.update(dotenv_values(dotenv_path=prod_env))
    return envs


def print_context(arguments, envs):
    logger.debug("=" * 50)
    logger.debug("Parameters:")
    logger.debug("-" * 25)
    logger.debug("Environment:  %s", arguments.env)
    logger.debug("Mode:         %s", arguments.mode)
    logger.debug("Verbose:      %s", arguments.verbose)
    logger.debug("=" * 50)
    logger.info("=" * 50)
    logger.info("Context:")
    logger.info("-" * 25)
    for k, val in envs.items():
        logger.info('%s=%s', k, val)
    logger.info("=" * 50)


ENVS = load_env(args)
print_context(args, ENVS)
run(args.mode, ENVS)
