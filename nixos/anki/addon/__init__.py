"""Anki add-on: runs yomitan_core.py's Yomitan hooks inside the app (anki-connect-server has its own entry point)."""
from aqt import mw
from aqt.operations import QueryOp
from aqt.qt import QAction
from aqt.utils import showInfo

from . import yomitan_core as core

core.register()


def fix_existing():
    QueryOp(
        parent=mw,
        op=core.fix_collection,
        success=lambda n: showInfo("Cleaned %d Yomitan note(s)." % n),
    ).with_progress("Cleaning Yomitan notes").run_in_background()


action = QAction("Clean Yomitan notes", mw)
action.triggered.connect(fix_existing)
mw.form.menuTools.addAction(action)
