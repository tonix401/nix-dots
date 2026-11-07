"""Hooks for notes that Yomitan adds to Anki, shared by the Anki add-on and anki-connect-server.

Only the standard library and `anki` are used (no Qt), so the same file runs in the app and headless:

- scrub_contacts(): drop clauses with phone numbers, emails, links or messenger handles from `Examples`,
  since example sentences come from chats and emails.
- clean_meaning(): reduce the dictionary HTML Yomitan puts in `Meaning` to <ul><li>..</li></ul>.
- ensure_audio(): fill an empty `Audio` field with a human recording (Wikimedia Commons: the Wiktionary
  `Zh-<pinyin>.ogg` files, then Lingua Libre), else a local Piper voice. The source goes on the note as a
  tag `audio::<source>`; a note tagged `audio::piper` gets a human recording on a later run when one exists.

Tools come from the environment, set by home.nix: YOMITAN_PIPER, YOMITAN_PIPER_MODEL, YOMITAN_FFMPEG.
"""
import hashlib
import html
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.parse
import urllib.request
from html.parser import HTMLParser

NOTE_TYPES = ("Chinese Word Yomitan",)
COMMONS_API = "https://commons.wikimedia.org/w/api.php"
# Lingua Libre's Mandarin recordings: File:LL-Q9192 (cmn)-<speaker>-<word>.wav
COMMONS_LANG = "LL-Q9192 (cmn)"
USER_AGENT = "yomitan-hooks/1.0 (personal Anki add-on)"
TIMEOUT = 8

CLEAN = re.compile(r"<ul>(<li>[^<>]*</li>)+</ul>")

VOID = {"br", "hr", "img", "input", "meta", "link", "wbr"}
BLOCK = {"div", "p", "br", "li", "ul", "ol", "tr", "details", "summary"}
# Elements that never carry a meaning
DROP_TAGS = {"style", "script", "a", "details", "summary", "rt", "rp"}
# data-sc-* values (Yomitan's structured content) of parts around the meaning: headwords, readings,
# synonym chips, example sentences, links, tags
NOISE = re.compile(
    r"headword|reading|backlink|related|synonym|antonym|tags?$|example|preamble|sense-label|extra-info|summary|details",
    re.I,
)
# data-sc-* values that mark the list holding the meanings
DEFINITION = {"glosses", "gloss", "definition", "definitions"}


class Node:
    def __init__(self, tag, attrs, parent):
        self.tag = tag
        self.attrs = dict(attrs)
        self.parent = parent
        self.children = []

    def sc_values(self):
        return [v or "" for k, v in self.attrs.items() if k.startswith("data-sc")]


class Tree(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.root = Node("root", [], None)
        self.cur = self.root

    def handle_starttag(self, tag, attrs):
        node = Node(tag, attrs, self.cur)
        self.cur.children.append(node)
        if tag not in VOID:
            self.cur = node

    def handle_startendtag(self, tag, attrs):
        self.cur.children.append(Node(tag, attrs, self.cur))

    def handle_endtag(self, tag):
        n = self.cur
        while n is not self.root and n.tag != tag:
            n = n.parent
        if n is not self.root:
            self.cur = n.parent

    def handle_data(self, data):
        self.cur.children.append(data)


def is_noise(node):
    if node.tag in DROP_TAGS:
        return True
    if re.search(r"display\s*:\s*none", node.attrs.get("style") or "", re.I):
        return True
    return any(NOISE.search(v) for v in node.sc_values())


def text_of(node, skip_lists=False):
    """Visible text of a node, without noise (and nested lists when skip_lists)."""
    out = []

    def walk(n):
        for c in n.children:
            if isinstance(c, str):
                out.append(c)
            elif is_noise(c) or (skip_lists and c.tag in ("ul", "ol")):
                continue
            else:
                if c.tag in BLOCK:
                    out.append(" ")
                walk(c)
                if c.tag in BLOCK:
                    out.append(" ")

    walk(node)
    return re.sub(r"\s+", " ", "".join(out)).strip()


def find_lists(node, pred):
    """Lists (ul/ol) below node that satisfy pred, outermost first, skipping noise."""
    found = []

    def walk(n):
        for c in n.children:
            if isinstance(c, str) or is_noise(c):
                continue
            if c.tag in ("ul", "ol") and pred(c):
                found.append(c)
            else:
                walk(c)

    walk(node)
    return found


def list_items(lst):
    """Texts of a list's items; nested lists (sub-senses) become items of their own."""
    items = []
    for li in lst.children:
        if isinstance(li, str) or li.tag != "li" or is_noise(li):
            continue
        own = text_of(li, skip_lists=True)
        if own:
            items.append(own)
        for sub in find_lists(li, lambda _: True):
            items.extend(list_items(sub))
    return items


def clean_meaning(value):
    """The meanings in a Yomitan glossary as <ul><li>..</li></ul>; clean fields stay as they are."""
    if not value.strip() or CLEAN.fullmatch(value.strip()):
        return value
    if "<" not in value:
        return "<ul><li>%s</li></ul>" % html.escape(value.strip(), quote=False)
    tree = Tree()
    tree.feed(value)
    tree.close()
    root = tree.root
    lists = find_lists(root, lambda n: any(v in DEFINITION for v in n.sc_values()))
    if not lists:
        lists = find_lists(root, lambda _: True)
    items = [i for lst in lists for i in list_items(lst)]
    if not items:
        whole = text_of(root)
        items = [whole] if whole else []
    items = list(dict.fromkeys(items))
    if not items:
        return value
    return "<ul>%s</ul>" % "".join("<li>%s</li>" % html.escape(i, quote=False) for i in items)


# ---- personal data ----

CLAUSE_END = "，,、。！？!?；;\n"
CONTACT = re.compile(
    r"[\w.+-]+@[\w-]+(\.[\w-]+)+"  # email
    r"|https?://|www\."  # link
    r"|(?<![\w])@\w{3,}"  # @handle
    r"|\+?\d[\d ()\-]{6,}\d"  # phone number (8+ digits)
    r"|(?<![A-Za-z])(ins|instagram|whatsapp|wechat|weixin|telegram|snapchat|tiktok|facebook|qq)(?![A-Za-z])"
    r"|微信|微博|电话|手机号|邮箱|ins号|qq号",
    re.I,
)


def scrub_contacts(value):
    """Example sentences without the clauses that give out contact details (of whoever wrote them)."""
    if not CONTACT.search(value):
        return value
    parts = re.split("([%s])" % re.escape(CLAUSE_END), value)
    kept = []  # (clause, delimiter after it)
    for i in range(0, len(parts), 2):
        clause, delim = parts[i], parts[i + 1] if i + 1 < len(parts) else ""
        if clause.strip() and not CONTACT.search(clause):
            kept.append([clause, delim])
    if kept and kept[-1][1] in "，,、；;":
        kept[-1][1] = "。"
    return "".join(c + d for c, d in kept)


# ---- audio ----

def _get(url, timeout=TIMEOUT):
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read()


def commons_pinyin(word, pinyin):
    """Wiktionary's recordings, File:Zh-<pinyin>.ogg on Commons: exact for the reading, one lookup."""
    syllables = re.sub(r"<[^>]*>|[\s']+", "", html.unescape(pinyin)).lower()
    if not syllables:
        return None
    query = urllib.parse.urlencode({
        "action": "query", "format": "json", "titles": "File:Zh-%s.ogg" % syllables,
        "prop": "imageinfo", "iiprop": "url",
    })
    for page in json.loads(_get("%s?%s" % (COMMONS_API, query))).get("query", {}).get("pages", {}).values():
        if page.get("imageinfo"):
            return _get(page["imageinfo"][0]["url"], timeout=20), "ogg"
    return None


def commons_recording(word, pinyin=""):
    """(bytes, extension) of a Lingua Libre recording of the word on Commons, or None."""
    query = urllib.parse.urlencode({
        "action": "query", "format": "json", "generator": "search", "gsrnamespace": 6,
        "gsrsearch": '"%s" "%s"' % (COMMONS_LANG, word), "gsrlimit": 20,
        "prop": "imageinfo", "iiprop": "url",
    })
    pages = json.loads(_get("%s?%s" % (COMMONS_API, query))).get("query", {}).get("pages", {})
    exact = re.compile(r"^File:%s-[^-]+-%s\.(wav|ogg|mp3|flac)$" % (re.escape(COMMONS_LANG), re.escape(word)))
    for page in sorted(pages.values(), key=lambda p: p["title"]):
        if exact.match(page["title"]) and page.get("imageinfo"):
            url = page["imageinfo"][0]["url"]
            return _get(url, timeout=20), page["title"].rsplit(".", 1)[1].lower()
    return None


def synthesize(word):
    """(wav bytes, "wav") from the local Piper voice, or None."""
    piper = os.environ.get("YOMITAN_PIPER") or shutil.which("piper")
    model = os.environ.get("YOMITAN_PIPER_MODEL")
    if not piper or not model:
        return None
    with tempfile.TemporaryDirectory() as tmp:
        out = os.path.join(tmp, "out.wav")
        subprocess.run([piper, "--model", model, "--output_file", out], input=word.encode(),
                       check=True, capture_output=True, timeout=60)
        with open(out, "rb") as f:
            return f.read(), "wav"


def to_mp3(data, ext):
    """Recordings as mp3 like the other cards (smaller than wav); unchanged without ffmpeg."""
    ffmpeg = os.environ.get("YOMITAN_FFMPEG") or shutil.which("ffmpeg")
    if not ffmpeg or ext == "mp3":
        return data, ext
    with tempfile.TemporaryDirectory() as tmp:
        src, dst = os.path.join(tmp, "in." + ext), os.path.join(tmp, "out.mp3")
        with open(src, "wb") as f:
            f.write(data)
        subprocess.run([ffmpeg, "-loglevel", "error", "-i", src, "-codec:a", "libmp3lame", "-q:a", "4", dst],
                       check=True, capture_output=True, timeout=60)
        with open(dst, "rb") as f:
            return f.read(), "mp3"


# (tag, fetcher(word, pinyin)); the first that returns audio wins. Human recordings come first.
HUMAN_SOURCES = (("commons-zh", commons_pinyin), ("lingualibre", commons_recording))
SYNTH_SOURCES = (("piper", lambda word, pinyin: synthesize(word)),)
TAG = "audio::%s"


def find_audio(word, pinyin, sources):
    """(bytes, extension, source tag) from the first source that has the word, or None."""
    for name, fetch in sources:
        try:
            audio = fetch(word, pinyin)
        except Exception as e:  # includes rate limiting (HTTP 429) and being offline
            log("%s failed for %s: %s" % (name, word, e))
            continue
        if audio:
            try:
                audio = to_mp3(*audio)
            except Exception as e:
                log("mp3 conversion failed for %s: %s" % (word, e))
            return audio + (name,)
    return None


def ensure_audio(col, note):
    """Fill an empty Audio, or replace a synthetic one when a human recording turned up."""
    improving = note.has_tag(TAG % "piper")
    if note["Audio"].strip() and not improving:
        return
    word = re.sub(r"<[^>]*>", "", html.unescape(note["Hanzi"])).strip()
    if not word:
        return
    audio = find_audio(word, note["Pinyin"], HUMAN_SOURCES if improving else HUMAN_SOURCES + SYNTH_SOURCES)
    if audio:
        data, ext, source = audio
        name = col.media.write_data("yomitan_audio_%s.%s" % (hashlib.sha1(data).hexdigest(), ext), data)
        note["Audio"] = "[sound:%s]" % name
        note.tags = [t for t in note.tags if not t.lower().startswith("audio::")]
        note.add_tag(TAG % source)


# ---- wiring ----

def log(msg):
    print("yomitan_hooks: " + msg, file=sys.stderr, flush=True)


def handles(note):
    return note.note_type()["name"] in NOTE_TYPES


def process(col, note):
    """Clean and fill a Yomitan note in place; returns whether anything changed."""
    before = (note["Meaning"], note["Examples"], note["Audio"], tuple(note.tags))
    note["Meaning"] = clean_meaning(note["Meaning"])
    note["Examples"] = scrub_contacts(note["Examples"])
    ensure_audio(col, note)
    return before != (note["Meaning"], note["Examples"], note["Audio"], tuple(note.tags))


def on_note_will_be_added(col, note, deck_id):
    # An error here would make the add fail, and the card is better messy than lost.
    try:
        if handles(note):
            process(col, note)
    except Exception as e:
        log("could not process %s: %s" % (note.fields[0] if note.fields else "?", e))


def register():
    import anki.collection  # noqa: F401  (before anki.hooks, or the import is circular)
    from anki import hooks
    if on_note_will_be_added not in hooks.note_will_be_added._hooks:
        hooks.note_will_be_added.append(on_note_will_be_added)


def fix_collection(col):
    """Run the hooks over the notes already in the collection; returns how many changed."""
    changed = 0
    for name in NOTE_TYPES:
        for nid in col.find_notes('"note:%s"' % name):
            note = col.get_note(nid)
            if process(col, note):
                col.update_note(note)
                changed += 1
    return changed
