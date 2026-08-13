import subprocess
import json
from pathlib import Path
from textual.app import App, ComposeResult
from textual.screen import Screen
from textual.widgets import DataTable, Static, Footer, Header, Label

device_list = Path.cwd() / "devices"

class MenuApp(App[None]): 
    def on_mount(self) -> None: 
        self.push_screen(MainMenu())

class MainMenu(Screen): 
    def compose(self) -> ComposeResult:
        yield Header()
        yield DataTable(cursor_type="row")
        yield Footer()

    def on_mount(self) -> None: 
        table = self.query_one(DataTable)
        table.add_columns("Name", "Type", "Size")

        if device_list.stat().st_size == 0:
            lsblk = subprocess.run(
                ["lsblk", "--json", "--output", "NAME,TYPE,SIZE"],
                check=True,
                capture_output=True,
                text=True,
            )

            devices=json.loads(lsblk.stdout)["blockdevices"]

            for device in devices: 
                table.add_row(device["name"], device["type"], device["size"])

if __name__ == "__main__":
    app = MenuApp()
    app.run()
    input()
