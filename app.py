import subprocess
import json
from pathlib import Path
from textual.app import App, ComposeResult
from textual.binding import Binding
from textual.screen import Screen
from textual.widgets import DataTable, Static, Footer, Header, Label

device_list = Path.cwd() / "devices"

class MenuApp(App[None]): 
    def on_mount(self) -> None: 
        self.push_screen(MainMenu())

class MainMenu(Screen): 
    BINDINGS=[Binding("enter", "select", "Select", priority=True)]
    def compose(self) -> ComposeResult:
        yield Header()
        yield Label(id="msg")
        yield DataTable(cursor_type="row")
        yield Footer()

    def on_mount(self) -> None: 
        if device_list.stat().st_size == 0:
            label = self.query_one("#msg")
            label.update("No devices found, please select one:")

            table = self.query_one(DataTable)
            table.add_columns("Name", "Type", "Size")

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
