from textual.app import App, ComposeResult
from textual.binding import Binding
from textual.widgets import Button, Header, Footer, Static

class MyApp(App):
    BINDINGS = [
        Binding("up", "focus_previous", show=False),
        Binding("down", "focus_next", show=False),
        Binding("escape", "quit", show=False),
    ]

    def compose(self) -> ComposeResult:
        yield Header()
        yield Button("Login to Drive")
        yield Footer()

if __name__ == "__main__":
    MyApp().run()
