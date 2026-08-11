from textual.app import App, ComposeResult
from textual.screen import Screen
from textual.widgets import Static, Footer, Header, Label

class MenuApp(App[None]): 
    def on_mount(self) -> None: 
        self.push_screen(MainMenu())

class MainMenu(Screen): 
    def compose(self) -> ComposeResult:
        yield Header()
        yield Label("Hello!")
        yield Footer()

if __name__ == "__main__":
    app = MenuApp()
    app.run()
    input()
