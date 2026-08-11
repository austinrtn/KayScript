import sys 
import subprocess
import os
from tempfile import TemporaryDirectory
from dataclasses import dataclass
from pathlib import Path

@dataclass()
class File: 
    name: str
    url: str
    dest: Path
    mode: int
    root_owned: bool 
    tmp_path: Path = Path("/tmp")

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
                return True
            case 6:
                print(f"Could not resolve the host for {self.name}", file=sys.stderr)
            case 22:
                print(f"The server returned an HTTP error for {self.name}", file=sys.stderr)
                print(f"{self.url}")
            case 28:
                print(f"The download timed out for {self.name}", file=sys.stderr)
            case error_code:
                print(
                    f"Failed to download {self.name}: curl exited with code {error_code}",
                    file=sys.stderr,
                )

        return False

    def replace_text(self, old: str, new: str) -> None: 
        self.tmp_path.write_text(self.tmp_path.read_text().replace(old, new))

    def install(self) -> None: 
        if self.root_owned:
            subprocess.run([
                "sudo", 
                "install", 
                "-o", "root", 
                "-g", "root", 
                "-m", f"{self.mode:o}",
                f"{self.tmp_path}", f"{self.dest}",
            ], check=False)
        else:
            subprocess.run([
                "install", 
                "-m", f"{self.mode:o}",
                f"{self.tmp_path}", f"{self.dest}",
            ], check=False)

config_dir = Path.home() / ".config/systemd/user/"
project_dir = Path.home() / ".local/share/KayScript/"
gh_url="https://raw.githubusercontent.com/austinrtn/KayScript/refs/heads/master/"

udev_rule = File(
    name="99-usb-connected.rules",
    url=f"{gh_url}99-usb-connected.rules",
    dest=Path("/etc/udev/rules.d/99-usb-connected.rules"),
    mode=0o644,
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
    name="kayscript.sh",
    url=f"{gh_url}KayScript.sh",
    dest=project_dir / "KayScript.sh",
    mode=0o755,
    root_owned=False,
)

app = File(
    name="app.py",
    url=f"{gh_url}app.py",
    dest=project_dir / "app.py",
    mode=0o644,
    root_owned=False,
)

reqs = File(
    name="requirements.json",
    url=f"{gh_url}requirements.json",
    dest=project_dir / "requirements.json",
    mode=0o644,
    root_owned=False,
)

files = [udev_rule, root_service, user_service, launcher, app, reqs]

def main(): 
    arg = sys.argv[1]
    if arg == "--i":
        work_dir = TemporaryDirectory()
        try: 
            install(work_dir)
        finally:
            work_dir.cleanup()

def install(work_dir: TemporaryDirectory) -> int:
    print("Beginning Installation!")
    os.chdir(work_dir.name)
    
    for file in files: 
        if not file.download(): 
            return 1
        file.tmp_path = Path(work_dir.name) / file.name
    
    print("Files Downloaded!")

    
    udev_rule.replace_text("__ROOT_SERVICE__", root_service.name)
    user_service.replace_text("__SCRIPT_PATH__", launcher.name)

    print("Installing Files...")
    subprocess.run(["sudo", "-v"], check=False)
    subprocess.run(["mkdir", "-p", config_dir, project_dir], check=False)
    subprocess.run(["sudo", "mkdir", "-p", "/mnt/"], check=False)

    for file in files: 
        file.install()
        
    return 0

if __name__ == "__main__":
    main()
