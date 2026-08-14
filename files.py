import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path


#################################
###### FILE CLASS ###############
#################################
@dataclass()
class File:
    name: str
    url: str
    dest: Path
    mode: int
    root_owned: bool
    tmp_path: Path = Path("/tmp/")

    def __post_init__(self) -> None:
        self.tmp_path = Path.cwd() / self.name

    def validate_path(self) -> bool:
        return self.tmp_path.exists()

    def download(self) -> bool:
        result = subprocess.run(
            [
                "curl",
                "--fail",
                "--silent",
                "--show-error",
                "--location",
                "--max-time",
                "15",
                "--output",
                self.name,
                self.url,
            ],
            check=False,
        )

        match result.returncode:
            case 0:
                return True
            case 6:
                print(f"Could not resolve the host for {self.name}", file=sys.stderr)
            case 22:
                print(
                    f"The server returned an HTTP error for {self.name}",
                    file=sys.stderr,
                )
                print(f"{self.url}")
            case 28:
                print(f"The download timed out for {self.name}", file=sys.stderr)
            case error_code:
                print(
                    f"Failed to download {self.name}: "
                    + f"curl exited with code {error_code}",
                    file=sys.stderr,
                )

        return False

    def replace_text(self, old: str, new: str) -> None:
        _ = self.tmp_path.write_text(self.tmp_path.read_text().replace(old, new))

    def install(self) -> None:
        if self.root_owned:
            _ = subprocess.run(
                [
                    "sudo",
                    "install",
                    "-o",
                    "root",
                    "-g",
                    "root",
                    "-m",
                    f"{self.mode:o}",
                    f"{self.tmp_path}",
                    f"{self.dest}",
                ],
                check=False,
            )
        else:
            _ = subprocess.run(
                [
                    "install",
                    "-m",
                    f"{self.mode:o}",
                    f"{self.tmp_path}",
                    f"{self.dest}",
                ],
                check=False,
            )

    def uninstall(self) -> None:
        _ = subprocess.run(["sudo", "rm", "-f", str(self.dest)], check=False)

#################################
###### FILE PATHS ##############
#################################
config_dir = Path.home() / ".config/systemd/user/"
project_dir = Path("/var/lib/kayscript")
gh_url = "https://raw.githubusercontent.com/austinrtn/KayScript/refs/heads/master/"

udev_rule = File(
    name="99-usb-connected.rules",
    url=f"{gh_url}99-usb-connected.rules",
    dest=Path("/etc/udev/rules.d/99-usb-connected.rules"),
    mode=0o644,
    root_owned=True,
)

sudoers_rule = File(
    name="kayscript-bypass",
    url=f"{gh_url}kayscript-bypass",
    dest=Path("/etc/sudoers.d/kayscript-bypass"),
    mode=0o440,
    root_owned=True,
)

root_service = File(
    name="kayscript-usb.service",
    url=f"{gh_url}kayscript-usb.service",
    dest=Path("/etc/systemd/system/kayscript-usb.service"),
    mode=0o644,
    root_owned=True,
)

user_service = File(
    name="kayscript.service",
    url=f"{gh_url}kayscript.service",
    dest=Path.home() / ".config/systemd/user/kayscript.service",
    mode=0o644,
    root_owned=False,
)

launcher = File(
    name="KayScript.sh",
    url=f"{gh_url}KayScript.sh",
    dest=project_dir / "KayScript.sh",
    mode=0o755,
    root_owned=True,
)

app = File(
    name="app.py",
    url=f"{gh_url}app.py",
    dest=project_dir / "app.py",
    mode=0o644,
    root_owned=True,
)

reqs = File(
    name="requirements.json",
    url=f"{gh_url}requirements.json",
    dest=project_dir / "requirements.json",
    mode=0o644,
    root_owned=True,
)

files = [udev_rule, root_service, user_service, launcher, app, reqs, sudoers_rule]