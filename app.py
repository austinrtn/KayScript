import json
import subprocess
from pathlib import Path
from typing import ClassVar

from textual import events
from textual.app import App, ComposeResult
from textual.screen import Screen
from textual.timer import Timer
from textual.widgets import DataTable, Footer, Header, Label

device_list = Path.cwd() / "devices"

class MenuApp(App[None]):
    def on_mount(self) -> None:
        if device_list.stat().st_size == 0: 
            self.push_screen(BlockSelector())
        else: 
            self.push_screen(FileUploader())
        

class BlockSelector(Screen):
    BINDINGS: ClassVar = [
        ("escape", "app.quit", "Exit"),
    ]

    def __init__(self) -> None:
        super().__init__()
        self.devices: list[dict[str, str]] = []

    def compose(self) -> ComposeResult:
        yield Header()
        yield Label(id="msg")
        yield DataTable(cursor_type="row")
        yield Footer()

    def on_mount(self) -> None:
        label = self.query_one("#msg")
        label.update("No devices found, please select one:")

        table = self.query_one(DataTable)
        table.add_columns("Name", "Type", "Size", "ID")

        lsblk = subprocess.run(
            ["lsblk", "--json", "--output", "NAME,TYPE,SIZE,ID-LINK"],
            check=True,
            capture_output=True,
            text=True,
        )

        self.devices = json.loads(lsblk.stdout)["blockdevices"]

        for device in self.devices:
            table.add_row(
                device["name"], device["type"], device["size"], device["id-link"]
            )

    def on_data_table_row_selected(self, event: DataTable.RowSelected) -> None:
        index = event.cursor_row
        device = self.devices[index]
        device_list.write_text(f"{device["id-link"]}")
        self.notify(f"Device: {device['name']} added.")
        self.app.pop_screen()

class FileUploader(Screen): 
    BINDINGS: ClassVar = [("escape", "app.quit", "Exit")]
    waiting: bool = True
    timer: Timer
    remaining: int = 4
    
    def compose(self) -> ComposeResult: 
        yield Header()
        yield Label(id="msg")
        yield Footer()

    def on_mount(self) -> None: 
        self.timer = self.set_interval(1, self.tick)

    def tick(self) -> None: 
        self.remaining -= 1
        self.query_one("#msg", Label).update(f"Press enter for menu... [{self.remaining}]")

        if self.remaining <= 0: 
            self.timer.stop()
            self.timer_finished()

    def timer_finished(self) -> None: 
        self.notify("Timer finished")

    def on_key(self, event: events.Key) -> None: 
        print("hello")

if __name__ == "__main__":
    if not device_list.exists():
        device_list.touch()
        
    app = MenuApp()
    app.run()
    input()
