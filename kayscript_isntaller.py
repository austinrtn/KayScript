import sys 
import subprocess
import os
import tempfile
from dataclasses import dataclass
from pathlib import Path

@dataclass(frozen=True)
class File: 
    name: str
    url: str
    dest: Path
    mode: int
    root_owned: bool 

    def download(self) -> bool:
        result = subprocess.run(
            [
                "curl",
                "--fail",
                "--silent",
                "--show-error",
                "--location",
                "--max-time", "15",
                "--output", self.name,
                self.url,
            ],
            check=False,
        )

        match result.returncode:
            case 0:
                print(f"{self.name} downloaded")
                return True
            case 6:
                print(f"Could not resolve the host for {self.name}", file=sys.stderr)
            case 22:
                print(f"The server returned an HTTP error for {self.name}", file=sys.stderr)
            case 28:
                print(f"The download timed out for {self.name}", file=sys.stderr)
            case error_code:
                print(
                    f"Failed to download {self.name}: curl exited with code {error_code}",
                    file=sys.stderr,
                )

        return False

project_dir = Path.home() / ".local/share/KayScript/"
gh_url="https://raw.githubusercontent.com/austinrtn/KayScript/refs/heads/master/"

files = [
    File(
        name="99-usb-connected.rules",
        url=f"{gh_url}99-usb-connected.rules",
        dest=Path("/etc/udev/rules.d/99-usb-drive.rules"),
        mode=0o644,
        root_owned=True,
    ),
    File(
        name="kayscript-usb.service",
        url=f"{gh_url}kayscript-usb.service",
        dest=Path("/etc/systemd/system/kayscript-usb.service"),
        mode=0o644,
        root_owned=True,
    ),
    File(
        name="kayscript.service",
        url=f"{gh_url}kayscript.service",
        dest=Path.home() / ".config/systemd/user/kayscript.service",
        mode=0o644,
        root_owned=False,
    ),
    File(
        name="kayscript.sh",
        url=f"{gh_url}KayScript.sh",
        dest=project_dir / "KayScript.sh",
        mode=0o644,
        root_owned=False,
    ),
    File(
        name="app.py",
        url=f"{gh_url}app.py",
        dest=project_dir / "app.py",
        mode=0o644,
        root_owned=False,
    ),
]

def main(): 
    arg = sys.argv[1]
    if arg == "--i":
        install()

def install():
    work_dir = tempfile.TemporaryDirectory() 
    os.chdir(work_dir.name)
    
    for file in files: 
        if not file.download(): 
            exit(1)

    print(os.listdir())

if __name__ == "__main__":
    main()
