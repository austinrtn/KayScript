import os
import pwd
import subprocess
import sys
from pathlib import Path
from tempfile import TemporaryDirectory

from files import config_dir, files, launcher, sudoers, project_dir, root_service, udev_rule, user_service


def install_script(work_dir: TemporaryDirectory[str], download_files: bool) -> int:
    print("> Beginning Installation!")
    os.chdir(work_dir.name)

    if download_files:
        print("> Downloading Files")
        for file in files:
            if not file.download():
                return 1
            file.tmp_path = Path(work_dir.name) / file.name

        print("Files Downloaded!")
        print()

    else:
        for file in files:
            if not file.validate_path():
                print(f"Missing file: {file.name}")
                print("Exiting")
                return 1

    user = get_username()
    udev_rule.replace_text("__ROOT_SERVICE__", root_service.name)
    root_service.replace_text("__USER__", user)
    root_service.replace_text("__SERVICE__", user_service.name)
    sudoers.replace_text("__USER__", user)
    sudoers.replace_text("__SCRIPT__", str(launcher.dest))

    print(">Installing Files...")
    _ = subprocess.run(["sudo", "-v"], check=False)
    _ = subprocess.run(
        [
            "sudo",
            "mkdir",
            "-p",
            project_dir,
        ],
        check=False,
    )
    _ = subprocess.run(["mkdir", "-p", config_dir], check=False)
    _ = subprocess.run(["sudo", "mkdir", "-p", "/mnt/"], check=False)

    for file in files:
        file.install()

    print("Files Installed!")
    print()

    venv_dir = project_dir / ".venv"
    if not venv_dir.is_dir():
        print("> Installing Python Virtual Enviornment...")

        try:
            _ = subprocess.run(
                ["sudo", "python", "-m", "venv", str(project_dir / ".venv")], check=True
            )
        except subprocess.CalledProcessError as error:
            print(
                f"Unable to install python virtual enviornment: {error.returncode}",
                file=sys.stdout,
            )
            return 1

        print("Python Venv Installed!")

    print("> Updating Rules And Services")

    _ = subprocess.run(["sudo", "udevadm", "control", "--reload"], check=False)
    _ = subprocess.run(["sudo", "systemctl", "daemon-reload"], check=False)
    _ = subprocess.run(["systemctl", "--user", "daemon-reload"], check=False)

    print("Rules Updated!")

    return 0


def uninstall() -> None:
    confirm = input("Are you sure you want to uninstall KayScript? [Y/n]\t")
    confirm = confirm.lower()

    if confirm == "y":
        print(">Uninstalling...")
        for file in files:
            file.uninstall()

        _ = subprocess.run(["sudo", "rm", "-rf", str(project_dir)], check=False)
        print("Uninstalled!")

def get_username() -> str:
    if os.geteuid() == 0 and "SUDO_UID" in os.environ:
        uid = int(os.environ["SUDO_UID"])
    else: 
        uid = os.getuid()
        
    return pwd.getpwuid(uid).pw_name

def main() -> None:
    arg = "--i"
    if len(sys.argv) >= 1:
        arg = sys.argv[1]

    if arg in {"--d", "--l"}:
        work_dir = TemporaryDirectory()
        download_files = arg == "--d"
        try:
            _ = install_script(work_dir, download_files)
        finally:
            work_dir.cleanup()

    if arg == "--r":
        uninstall()


if __name__ == "__main__":
    main()
