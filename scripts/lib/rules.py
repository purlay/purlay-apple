"""The rules of scripts/enforcement that read files as data (plists, catalogues, Swift source), run in one process per check.

  python3 scripts/lib/rules.py ROOT    print a FAIL line for each problem in the tree at ROOT; exit 1 if there is one

Python's standard library only: the rules lane runs on a runner without Swift. Each Swift file's parse is pure, so it is kept by
the file's content (and this code's) in the user's own cache folder (see CACHE): the demonstration's copies differ by one file.
"""
import hashlib
import json
import os
import pathlib
import plistlib
import re
import sys

from cache import private
from cache import root as cache_root
from sentence_calls import CALLS
from swift_source import closing, code, literal, owner, parameters, skeleton, type_scopes

HERE = pathlib.Path(__file__).resolve().parent
VERSION = hashlib.sha1(b"".join((HERE / name).read_bytes() for name in ("rules.py", "swift_source.py"))).hexdigest()
# The user's own folder (cache.py): a parse planted by someone else would be believed.
CACHE = cache_root() / "parse"

# A format specifier, positional or not, with any length modifier; a count is an integer one. Xcode writes a sentence with more
# than one count as substitutions, `%#@name@`, each read as its own specifier.
SPEC = re.compile(r"%(?:\d+\$)?(?:hh|h|ll|l|z|t|j|q)?[diouxX@feEgG]")
COUNT = re.compile(r"%(?:\d+\$)?(?:hh|h|ll|l|z|t|j|q)?[diu]")
SUBSTITUTION = re.compile(r"%(?:(\d+)\$)?#@(\w+)@")
SENTENCE = r"\[?(?:LocalizedStringKey|LocalizedStringResource|String\.LocalizationValue|IntentDialog)\]?\??"
# The type of a name bound again without one stated: no type declares a property of it, so nothing assigned through it counts.
UNKNOWN = "<unknown>"
# A binding's type read from another declaration: the one it unwraps (`if let x = y`), or the element of one it iterates.
UNWRAPPED, ELEMENT = "<unwrapped>", "<element>"
# What scripts/generate writes, from the server's contract and tokens.
GENERATED = ("Sources/PurlayContract/Generated", "Sources/PurlayKit/Generated", "Sources/PurlayTokens/Generated")


def plist(path):
    """A property list; an Info.plist is preprocessed by the build, so its #ifdef lines are taken out first."""
    return plistlib.loads(re.sub(rb"(?m)^#.*\n", b"", path.read_bytes()))


def swift_files(root, *folders):
    for folder in folders:
        for path in sorted((root / folder).rglob("*.swift")):
            if not any(path.is_relative_to(root / generated) for generated in GENERATED):
                yield path


# --- The iOS app's privacy manifest: each declared category gives at least one reason, and only reasons Apple lists for that
# category (an unknown code is refused at submission like a missing one).
REASONS = {
    "NSPrivacyAccessedAPICategoryUserDefaults": {"CA92.1", "1C8F.1", "C56D.1", "AC6B.1"},
    "NSPrivacyAccessedAPICategoryFileTimestamp": {"DDA9.1", "C617.1", "3B52.1", "0A2A.1"},
    "NSPrivacyAccessedAPICategorySystemBootTime": {"35F9.1", "8FFB.1", "3D61.1"},
    "NSPrivacyAccessedAPICategoryDiskSpace": {"85F4.1", "E174.1", "7D9E.1", "B728.1"},
    "NSPrivacyAccessedAPICategoryActiveKeyboards": {"3EC4.1", "54BD.1"},
}


def privacy_reasons(root):
    manifest = root / "Apps/iOS/App/Resources/PrivacyInfo.xcprivacy"
    if not manifest.exists():
        return []  # scripts/enforcement says so
    problems = []
    for entry in plistlib.loads(manifest.read_bytes()).get("NSPrivacyAccessedAPITypes", []):
        category = entry.get("NSPrivacyAccessedAPIType")
        given = entry.get("NSPrivacyAccessedAPITypeReasons", [])
        if category not in REASONS:
            problems.append(f"the privacy manifest declares an unknown category {category!r}")
        elif not given:
            problems.append(f"the privacy manifest gives no reason for {category}")
        else:
            problems += [f"{code!r} is not a reason Apple lists for {category}" for code in given if code not in REASONS[category]]
    return problems


# --- The sentences: one checker for every catalogue. The engine's sentences (PurlayWords) are said by both apps, so their
# catalogue answers to every language either app declares; each app's own catalogue answers to the languages that app declares
# (CFBundleLocalizations). A sentence has one home: a key in two catalogues is two translations that can drift.
APPS = {"iOS": "Apps/iOS", "macOS": "Apps/macOS"}
# The counts that change no English word: a number shown as a label, a position, a limit in minutes. Every other count says its
# number in English plural forms whose `one` differs from `other`. A new entry here is a review point.
ONE_FORM = {
    "%@ %@ number %lld, %@: %@", "%@ and %lld more", "%@#%lld · %@", "%@, %lld", "%lld", "%lld min left", "%lld selected", "%lld unread",
    "%lld waiting", "%lld.", "Channel members, %lld", "End Deep Work (%lld min left)", "Filters (%lld)", "Inbox (%lld)",
    "Updates (%lld)",
}
# Nothing to translate: only symbols, digits and format specifiers, or a code-like address.
INERT = re.compile(r"^[^A-Za-z]*$|^[a-z0-9.\-/]+$")
PLURAL_FORMS = {"zero", "one", "two", "few", "many", "other"}
# Turkish addresses the person as siz (the server's D-350). Refused: every form of sen a pattern can tell from siz Turkish: the
# pronoun in each case (sen, seni, sana, senin, seninle, sende, senden, seninki, sence); the question particle, written apart
# (misin, mısın, musun, müsün); and the verb endings that end on the person with nothing after them: -abilirsin/-ebilirsin,
# -amazsın/-emezsin, -ıyorsun…, -acaksın/-eceksin, -malısın/-melisin, -mışsın…, değilsin, the conditional -rsan/-rsen,
# -mazsan/-mezsen, -ysan/-ysen. Each siz form goes on with "-iz" or "-niz" (misiniz, yapabilirsiniz, değiştirirseniz), so none
# is refused. Not refused, because siz Turkish spells them too: sen's past tense (-dın, as siz's imperative edin), its "your"
# (-ın, as a genitive) and its bare verb in a sentence (as a control's verb): a review point. A value is folded the Turkish way
# first (İ to i, I to ı), so capitals are read as the letters they are.
LETTER = r"[^\W\d_]"
V4 = "[ıiuü]"
SEN = re.compile(
    rf"(?<!{LETTER})(?:sen|seni|sana|senin|seninle|senle|sende|senden|seninki|seninkini|sence)(?!{LETTER})"
    rf"|(?<!{LETTER})m{V4}s{V4}n(?!{LETTER})"
    rf"|{LETTER}(?:[ae]bilirsin|amazsın|emezsin|{V4}yorsun|acaksın|eceksin|malısın|melisin|m{V4}şs{V4}n|"
    rf"{V4}rsan|{V4}rsen|arsan|ersen|mazsan|mezsen|ysan|ysen)(?!{LETTER})"
    rf"|(?<!{LETTER})değilsin(?!{LETTER})",
)


# "Purlay" is said "pörley", so its Turkish suffixes take front vowels and no buffer y: Purlay'i, Purlay'in, Purlay'de,
# Purlay'den, Purlay'e.
# The same for the English words the glossary keeps: "Thread" is said "tred" (Thread'i, Thread'de, Thread'ler) and "Deep Work"
# "dip vörk" (Deep Work'ü, Deep Work'te); Thread ends on a voiced d, so it takes -de, never -te.
WRONG_SUFFIX = re.compile(
    # Not IGNORECASE: it would read the dotless ı as i.
    r"(?:Purlay['’](?:da|dan|ı|ın|a|ya|ye|la)|[Tt]hread['’](?:ı|ın|da|dan|te|ten|a|lar|larda|u|un|ü|ün)"
    r"|[Dd]eep [Ww]ork['’](?:ı|ın|i|in|u|un|a|da|de|dan|den))(?![^\W\d_])"
)
# The server's product glossary (purlay/purlay docs/GLOSSARY.md, D-359): the Turkish words it rules out. "konu" is a channel's
# topic there, so it is refused only where the English says thread.
GLOSSARY_NEVER = [
    (re.compile(r"derin çalışma"), "Deep Work is \"Deep Work\" in both languages"),
    (re.compile(rf"(?<!{LETTER})konuk"), "a guest is \"Misafir\""),
    (re.compile(r"iki faktörlü"), "two-step verification is \"İki Adımlı Doğrulama\""),
    (re.compile(r"giriş yap|çıkış yap"), "sign in and out are \"Oturum Aç\" and \"Oturumu Kapat\""),
]
THREAD_AS_TOPIC = re.compile(rf"(?<!{LETTER})konu(?!ş)")
# "biten" is an ordinary participle ("Süresi biten davetler"); the glossary rules it out only as the name of a finished issue.
FINISHED_AS_BITEN = re.compile(rf"(?<!{LETTER})biten(?!{LETTER})")


def glossary_problem(key, value):
    """What the server's glossary rules out in a Turkish value, if anything."""
    folded = value.replace("İ", "i").replace("I", "ı").lower()
    for pattern, says in GLOSSARY_NEVER:
        if pattern.search(folded):
            return says
    if re.search(r"thread", key, re.IGNORECASE) and THREAD_AS_TOPIC.search(folded):
        return "a thread is \"Thread\", never \"konu\", which is a channel's topic"
    if re.search(r"finished|done", key, re.IGNORECASE) and FINISHED_AS_BITEN.search(folded):
        return "a finished issue is \"Bitti\", never \"Biten\""
    return None


def addresses_as_sen(value):
    """Whether a Turkish value says something to the person in a form of sen (`SEN`)."""
    return SEN.search(value.replace("İ", "i").replace("I", "ı").lower()) is not None


CATALOGUES = {
    "Apps/iOS/App/Resources/Localizable.xcstrings": ("iOS",),
    "Apps/macOS/App/Resources/Localizable.xcstrings": ("macOS",),
    "Sources/PurlayWords/Resources/Localizable.xcstrings": ("iOS", "macOS"),
}


def arguments(text, substitutions=None):
    """A value's arguments, without their positions: each specifier, and each substitution as the specifier it stands for."""
    found = [re.sub(r"\d+\$", "", match) for match in SPEC.findall(SUBSTITUTION.sub("", text))]
    for _, name in SUBSTITUTION.findall(text):
        found.append("%" + (substitutions or {}).get(name, {}).get("formatSpecifier", "?"))
    return sorted(found)


def catalogues(root):
    problems = []

    def declared(app):
        languages = plist(root / APPS[app] / "Info.plist").get("CFBundleLocalizations", [])
        if "en" not in languages or "tr" not in languages:
            problems.append(f"the {app} app does not declare English and Turkish (CFBundleLocalizations): {languages}")
        return set(languages)

    def units(path, key, language, localization):
        """Every value a language gives for a key: the one, or one per plural form (which must include `other`), and the
        forms of each substitution."""
        found = []
        if "stringUnit" in localization:
            found.append(localization["stringUnit"])
        else:
            plural = localization.get("variations", {}).get("plural")
            if plural is None:
                problems.append(f"{path}: {key!r} in {language} is neither a value nor plural forms")
            else:
                if "other" not in plural or not set(plural) <= PLURAL_FORMS:
                    problems.append(
                        f"{path}: {key!r} in {language} has plural forms {sorted(plural)}, without `other` or with an unknown one")
                found += [form.get("stringUnit", {}) for form in plural.values()]
        return found

    languages = {app: declared(app) for app in APPS}
    homes = {}
    for path, apps in CATALOGUES.items():
        wanted = set().union(*(languages[app] for app in apps))
        catalogue = json.loads((root / path).read_text())
        if catalogue.get("sourceLanguage") != "en":
            problems.append(f"{path}: the source language is not en")
        for key, entry in catalogue["strings"].items():
            homes.setdefault(key, []).append(path)
            if entry.get("shouldTranslate") is False:
                continue
            if entry.get("extractionState") == "stale":
                problems.append(f"{path}: {key!r} is stale (no code says it any more); remove it")
                continue
            localizations = entry.get("localizations", {})
            for language in sorted(wanted - {"en"}):
                if language not in localizations:
                    if not INERT.match(SPEC.sub("", key)):
                        problems.append(f"{path}: {key!r} is not translated into {language}")
                    continue
                substitutions = localizations[language].get("substitutions")
                for unit in units(path, key, language, localizations[language]):
                    if unit.get("state") != "translated" or not unit.get("value", "").strip():
                        problems.append(f"{path}: {key!r} has no final {language} value ({unit.get('state')})")
                    elif arguments(unit["value"], substitutions) != arguments(key):
                        problems.append(f"{path}: {key!r} -> {unit['value']!r}: the format specifiers differ")
                    elif language == "tr" and addresses_as_sen(unit["value"]):
                        problems.append(f"{path}: {key!r} -> {unit['value']!r}: Turkish addresses the person as siz, not sen")
                    elif language == "tr" and WRONG_SUFFIX.search(unit["value"]):
                        problems.append(
                            f"{path}: {key!r} -> {unit['value']!r}: the suffix follows how the word is said (Purlay'i, Thread'i)")
                    elif language == "tr" and (says := glossary_problem(key, unit["value"])):
                        problems.append(f"{path}: {key!r} -> {unit['value']!r}: the server's glossary: {says}")
            english = localizations.get("en", {})
            # A sentence with a count says it in English by plural forms, `one` not the same as `other`, so that 1 is never
            # "1 new replies": the forms of the whole sentence, or, for a sentence with more than one count, those of each
            # count's substitution. Turkish says a count with one form (the noun does not follow the number), so its value may
            # be a single one, or forms that are the same.
            if COUNT.search(key) and key not in ONE_FORM:
                counted = [
                    substitution.get("variations", {}).get("plural", {})
                    for substitution in english.get("substitutions", {}).values()
                    if COUNT.fullmatch("%" + substitution.get("formatSpecifier", ""))
                ] or [english.get("variations", {}).get("plural", {})]
                if len(counted) < len(COUNT.findall(key)) and len(counted) > 1:
                    problems.append(f"{path}: {key!r} has {len(COUNT.findall(key))} counts and {len(counted)} with plural forms")
                for plural in counted:
                    one, other = (plural.get(form, {}).get("stringUnit", {}).get("value") for form in ("one", "other"))
                    if not {"one", "other"} <= set(plural):
                        problems.append(f"{path}: {key!r} has a count but no English plural forms (one and other)")
                    elif one == other:
                        problems.append(f"{path}: {key!r} says one as it says other in English: {one!r}")
            # The English forms are held to the same rule, so that a plural cannot drop an argument.
            if english:
                for unit in units(path, key, "en", english):
                    if arguments(unit.get("value", key), english.get("substitutions")) != arguments(key):
                        problems.append(f"{path}: an English form of {key!r} changes its arguments")
    for key in sorted(ONE_FORM - set(homes)):
        problems.append(f"{key!r} is listed as a count that changes no English word, and no catalogue has it; remove it")
    for key, paths in homes.items():
        if len(paths) > 1:
            problems.append(f"{key!r} is in {len(paths)} catalogues ({', '.join(paths)}); a sentence has one home")
    return problems[:60] + ([f"… and {len(problems) - 60} more"] if len(problems) > 60 else [])


# --- A sentence in a catalogue is one some code says. The catalogues carry no extraction state (the iOS one is edited by hand, the
# others are synced only by scripts/localize), so `stale` never shows a sentence the code stopped saying: the code is read here.
# Each catalogue is read by its own code: the iOS app's, the Mac app's with PurlayMacUI, and PurlayWords'. A comment is not code,
# and a literal counts only where it is said as a sentence:
# - an argument a call of the SDK takes as one (sentence_calls.py, written from the SDK's interfaces by scripts/dev/sentence-calls);
# - an argument of a function, initialiser or memberwise initialiser of the repository's own code (any module, since an app
#   calls the design system's) whose parameter or property is typed as one: LocalizedStringKey, LocalizedStringResource,
#   String.LocalizationValue, IntentDialog, or an array of them;
# - the value of a declaration so typed (a ternary of literals too), or a literal its computed body gives;
# - what is assigned to a property so typed, through `self` or a value whose type the code states.
# The compiler's own extraction (scripts/localize) needs Swift, which this lane does not have.
READERS = {
    "Apps/iOS/App/Resources/Localizable.xcstrings": ["Apps/iOS/App"],
    "Apps/macOS/App/Resources/Localizable.xcstrings": ["Apps/macOS/App", "Sources/PurlayMacUI"],
    "Sources/PurlayWords/Resources/Localizable.xcstrings": ["Sources/PurlayWords"],
}
COLOUR_ALLOWED = ("Sources/PurlayDesign/Logo.swift", "Sources/PurlayMacUI/NativePalette.swift")
COMPONENTS = (r"red|srgbRed|white|hue|gray|displayP3Red|calibratedRed|deviceRed|calibratedWhite|deviceWhite|calibratedHue"
              r"|deviceHue|genericGamma22White|genericGamma22Gray|genericCMYKCyan|cyan")
COLOUR = re.compile(
    r"\b0[xX](?P<hex>[0-9A-Fa-f_]+)\b|#colorLiteral"
    r"|(?:\bColor|\bNSColor|\bUIColor|\bCGColor|\.init)\(\s*"
    r"(?:(?:Color\.RGBColorSpace)?\.(?:sRGB|sRGBLinear|displayP3)\s*,\s*)?"
    rf"(?:{COMPONENTS})\s*:\s*[-+]?(?:\w+\(\s*)?\.?[0-9]")


def parse(text):
    """What the rules need from one Swift file, from its text alone."""
    source = code(text)
    shape = skeleton(source)
    scopes = type_scopes(shape)
    result = {"calls": [], "properties": [], "sites": [], "colours": []}
    blocks = [(i, closing(shape, i)) for i, c in enumerate(shape) if c == "{"]
    # Each name declared with a type the code states, and where that declaration holds: (name, type, from, to). A parameter
    # holds in its function's body; a let or var in the block that declares it; `let x = T(…)` states T as well.
    declarations = []
    for match in re.finditer(r"\b(?:func\s+(\w+)|init)\s*(?:<[^(]*?>)?\(", shape):
        end = closing(shape, match.end() - 1)
        call = match.group(1) or owner(scopes, match.start())
        body = shape.find("{", end)
        body_end = closing(shape, body) if body != -1 else end
        for parameter in parameters(shape[match.end():end]):
            typed = re.match(rf"\s*(\w+)(?:\s+\w+)?\s*:\s*(?:@\w+(?:\([^)]*\))?\s+)*{SENTENCE}", parameter)
            if typed and call:
                result["calls"].append([call, "" if typed.group(1) == "_" else typed.group(1)])
            named = re.match(r"\s*(?:\w+\s+)?(\w+)\s*:\s*(?:@\w+(?:\([^)]*\))?\s+|inout\s+)*(\[?\w+\]?\??)", parameter)
            if named and body != -1:
                declarations.append([named.group(1), named.group(2), body, body_end])
    for match in re.finditer(r"\b(?:let|var)\s+(\w+)\s*(?::\s*(\[?[\w.]+\]?)|=\s*([A-Z]\w*)\s*\()", shape):
        kind = owner(scopes, match.start())
        type_name = match.group(2) or match.group(3)
        if kind and match.group(2):
            result["properties"].append([kind, match.group(1), type_name, bool(re.fullmatch(SENTENCE, type_name))])
        holding = [block for block in blocks if block[0] < match.start() < block[1]]
        start, end = max(holding) if holding else (0, len(shape))
        declarations.append([match.group(1), type_name, match.start(), end])
    # A name bound again without a stated type hides the outer declaration where it holds, with the type it takes when the
    # code shows it (what `if let x = y` or `if var x` unwraps, the element `for x in ys` or `ys.forEach { x in` iterates,
    # read from y's and ys's own declarations) and a type not known (UNKNOWN) otherwise, so a receiver of that name is not
    # taken for the outer one: a pattern's `let x`, `catch let x`, another closure's parameters, `let x = <an expression>`.
    for match in re.finditer(r"\b(?:let|var)\s+(\w+)\s*(?:=\s*(?!\s*[A-Z]\w*\s*\()(\w+)?(\s*[,{]|\s*$)?|[,){])", shape):
        start, end = bound(shape, blocks, match.start())
        condition = re.search(r"\b(?:if|guard|while)\b[^{};]*$", shape[max(0, match.start() - 200):match.start()])
        if match.group(2) and match.group(3) is not None:
            stated = f"{UNWRAPPED}{match.group(2)}"  # `let x = y`: y's type, unwrapped
        elif condition and "=" not in match.group(0):
            stated = f"{UNWRAPPED}{match.group(1)}"  # `if let x`, `if var x`: the outer x, unwrapped
        else:
            stated = UNKNOWN
        declarations.append([match.group(1), stated, start, end])
    for match in re.finditer(r"\bfor\s+(?:(case\s+let\s+|var\s+)?)\(?\s*(\w+)\s*\)?\s+in\s+(\w+)?", shape):
        body = shape.find("{", match.end())
        if body != -1:
            iterated = match.group(3) and not (match.group(1) or "").startswith("case")
            declarations.append([match.group(2), f"{ELEMENT}{match.group(3)}" if iterated else UNKNOWN,
                                 body, closing(shape, body)])
    for match in re.finditer(r"\bcatch\s+let\s+(\w+)", shape):
        body = shape.find("{", match.end())
        if body != -1:
            declarations.append([match.group(1), UNKNOWN, body, closing(shape, body)])
    for match in re.finditer(r"(?:(\w+)\s*\.\s*forEach\s*)?\{\s*\(?\s*(\w+(?:\s*,\s*\w+)*)\s*\)?\s+in\b", shape):
        names = re.split(r"\s*,\s*", match.group(2))
        brace = shape.index("{", match.start())
        for name in names:
            stated = f"{ELEMENT}{match.group(1)}" if match.group(1) and len(names) == 1 else UNKNOWN
            declarations.append([name, stated, brace, closing(shape, brace)])
    result["sites"] = sites(source, scopes, declarations)
    for match in COLOUR.finditer(source):
        # A colour's hex is six or eight digits, its separators (if any) between pairs: 0x25_63_EB. A mask grouped by fours
        # (0x7fff_ffff) is not a colour.
        groups = (match.group("hex") or "").split("_")
        if match.group("hex") is not None and (
                len("".join(groups)) not in (6, 8) or (len(groups) > 1 and any(len(group) != 2 for group in groups))):
            continue
        result["colours"].append([source.count("\n", 0, match.start()) + 1, " ".join(match.group(0).split())])
    return result


def bound(shape, blocks, position):
    """Where a binding at `position` holds: the block an `if` or `while` condition opens, else the block that holds it."""
    if re.search(r"\b(?:if|while)\b[^{};]*$", shape[max(0, position - 200):position]):
        body = shape.find("{", position)
        if body != -1:
            return position, closing(shape, body)
    holding = [block for block in blocks if block[0] < position < block[1]]
    return (position, max(holding)[1]) if holding else (position, len(shape))


def stated_type(declarations, name, position, depth=0):
    """The type, as written (`T`, `T?`, `[T]`), that the innermost declaration of `name` holding at `position` states, following
    a binding to the declaration it unwraps or iterates; UNKNOWN when it cannot be read, None when nothing declares it."""
    holding = [d for d in declarations if d[0] == name and d[2] <= position <= d[3]]
    if not holding:
        return None
    declaration = max(holding, key=lambda d: (d[2], -d[3]))
    written = declaration[1]
    for marker in (UNWRAPPED, ELEMENT):
        if written.startswith(marker):
            if depth > 8:
                return UNKNOWN
            source = stated_type(declarations, written[len(marker):], declaration[2] - 1, depth + 1)
            if source in (None, UNKNOWN):
                return UNKNOWN
            if marker == ELEMENT:
                element = re.fullmatch(r"\[(\w+)\]\??", source)
                return element.group(1) if element else UNKNOWN
            return source.rstrip("?")
    return written


def receiver(declarations, name, position):
    """The type of `name` where it is used, without its optional or array marks; UNKNOWN or None as stated_type says."""
    written = stated_type(declarations, name, position)
    return written if written in (None, UNKNOWN) else written.strip("[]?")


def sites(text, scopes, declarations):
    """Each literal of a file with the place it stands in: the call and argument it is given to, the bracket that holds it,
    and what it is assigned to. Whether the place says a sentence is decided later, once every file's declarations are known."""
    found, frames, word, i = [], [], "", 0  # a frame per open bracket: [bracket, call, argument label, typed]
    declared = re.compile(rf":\s*{SENTENCE}\s*=\s*(?:[^=;\n]*\?\s*(?:\"[^\"\n]*\"\s*:\s*)?)?$")
    while i < len(text):
        c = text[i]
        if c == '"':
            value, end = literal(text, i)
            before = text[max(0, i - 160):i]
            frame = frames[-1] if frames else None
            site = {"value": value}
            if frame and frame[0] == "(":
                site["call"] = [frame[1], frame[2]]
            if frame and frame[0] == "[":
                site["list"] = frame[3]
            if frame and frame[0] == "{" and any(f[0] == "{" and f[3] for f in frames):
                site["body"] = True
            if declared.search(before):
                site["declared"] = True
            assigned = re.search(
                r"(?<![\w.?!])((?:\w+[?!]?\.)*)(\w+)\s*=\s*(?:[^=;\n]*\?\s*(?:\"[^\"\n]*\"\s*:\s*)?)?$", before)
            if assigned and not re.search(r"\b(?:let|var)\s+\w+\s*=", before[assigned.start():]):
                chain = [link.rstrip("?!") for link in assigned.group(1).rstrip(".").split(".")] if assigned.group(1) else []
                stated = receiver(declarations, chain[0], i) if chain and chain[0] != "self" else None
                site["assigned"] = [chain, assigned.group(2), owner(scopes, i), stated]
            if re.match(r"\s*as\s+String\b", text[end:]):
                site = {"value": value}  # said as a String, not as a sentence
            found.append(site)
            i, word = end, ""
            continue
        if c.isalnum() or c == "_":
            end = re.match(r"\w+", text[i:]).end() + i
            word, i = text[i:end], end
            continue
        before = text[max(0, i - 160):i]
        if c == "(":
            call = word
            if word == "init":  # Text.init("…") is Text("…")
                named = re.search(r"(\w+)\s*\.\s*init\s*$", before)
                call = named.group(1) if named else word
            frames.append(["(", call, "", False])
        elif c == "[":
            parent = [frames[-1][1], frames[-1][2]] if frames and frames[-1][0] == "(" else None
            frames.append(["[", None, "", {"call": parent, "declared": bool(declared.search(before))}])
        elif c == "{":
            frames.append(["{", None, "", bool(re.search(rf"(?:->|:)\s*{SENTENCE}\s*$", before))])
        elif c in ")]}" and frames:
            frames.pop()
        elif c == "," and frames and frames[-1][0] == "(":
            frames[-1][2] = ""
        elif c == ":" and frames and frames[-1][0] == "(":
            label = re.search(r"[(,]\s*(\w+)\s*$", before)
            if label:
                frames[-1][2] = label.group(1)
        if not c.isspace() and c != ".":
            word = ""
        i += 1
    return found


def parsed(path, cache):
    """parse(path), kept by the file's content and this code's when there is a private cache."""
    data = path.read_bytes()
    key = hashlib.sha1(VERSION.encode() + data).hexdigest()
    cached = CACHE / f"{key}.json"
    if cache:
        try:
            return json.loads(cached.read_text())
        except (OSError, ValueError):
            pass
    result = parse(data.decode())
    if not cache:
        return result
    try:
        partial = cached.with_suffix(f".{os.getpid()}.partial")
        partial.write_text(json.dumps(result))
        partial.replace(cached)
    except OSError:
        pass  # a cache that cannot be written only makes the next run slower
    return result


def said(root, parses):
    """The catalogue sentences no code says."""
    calls = {name: set(labels) for name, labels in CALLS.items()}
    sentence_properties, property_types = set(), {}
    for result in parses.values():
        for call, label in result["calls"]:
            calls.setdefault(call, set()).add(label)
        for kind, name, type_name, sentence in result["properties"]:
            property_types.setdefault((kind, name), type_name.strip("[]?"))
            if sentence:
                # A stored property is an argument of its type's memberwise initialiser, by its name.
                calls.setdefault(kind, set()).add(name)
                sentence_properties.add((kind, name))

    def says(site):
        call = site.get("call")
        if call and call[1] in calls.get(call[0], ()):
            return True
        listed = site.get("list")
        if listed and (listed["declared"] or (listed["call"] and listed["call"][1] in calls.get(listed["call"][0], ()))):
            return True
        if site.get("body") or site.get("declared"):
            return True
        assigned = site.get("assigned")
        if not assigned:
            return False
        chain, name, kind, stated = assigned
        if chain and chain[0] == "self":
            chain = chain[1:]
            stated = None
        if chain:
            # The receiver's type, as the code states it where it is used (a declaration in scope there, its type's
            # property in this file among them), else a property of the enclosing type declared in another file.
            kind = stated or property_types.get((kind, chain[0]))
            for member in chain[1:]:
                kind = property_types.get((kind, member))
        return (kind, name) in sentence_properties

    problems = []
    for path, folders in READERS.items():
        words = set()
        for folder in folders:
            for file, result in parses.items():
                if file.is_relative_to(root / folder):
                    words |= {site["value"] for site in result["sites"] if says(site)}
        for key, entry in json.loads((root / path).read_text())["strings"].items():
            if entry.get("shouldTranslate") is not False and SPEC.sub("\0", SUBSTITUTION.sub("\0", key)) not in words:
                problems.append(
                    f"{path}: {key!r} is said by no code that reads this catalogue: remove it, or, if a call of the SDK says it "
                    "as a sentence, regenerate scripts/lib/sentence_calls.py with scripts/dev/sentence-calls (adding the "
                    "framework to it if it does not read it yet)")
    return problems


# --- A colour is a token. A colour written as a literal (a hex value, with or without its alpha, in either case and with
# separators, or components given as numbers, in any colour space and through `.init` or CGColor as well) is allowed only where
# its value is stated: the tokens (generated from the server's tokens.json), the logo (Logo.swift, written from Design/purlay.svg),
# and NativePalette.swift, the allowlist of the Mac's neutral greys and status colours, which no token states yet. Each file is
# read whole and without its comments, so an initialiser wrapped across lines (as swift-format wraps a long one) is read as one
# and a colour named in a comment is not code. An asset catalogue's colour is a literal too: the only colour set is each app's
# AccentColor, which accent() holds to the accent token.
def colours(root, parses):
    problems = []
    for path, result in parses.items():
        if str(path.relative_to(root)) in COLOUR_ALLOWED:
            continue
        problems += [f"{path}:{line}: {text}: a colour literal outside the tokens, the logo and NativePalette.swift; name a token"
                     for line, text in result["colours"]]
    accents = {root / f"Apps/{app}/App/Resources/Assets.xcassets/AccentColor.colorset" for app in APPS}
    for colours_ in sorted([*(root / "Apps").rglob("*.colorset"), *(root / "Sources").rglob("*.colorset")]):
        if colours_ not in accents:
            problems.append(f"{colours_}: a colour set other than an app's AccentColor; name a token")
    return problems


# --- Both apps' controls are tinted with the accent token: each app's AccentColor asset is the token's value
# (Sources/PurlayTokens/Generated/Colors.swift), in every appearance the asset gives.
def accent(root):
    colours_ = (root / "Sources/PurlayTokens/Generated/Colors.swift").read_text()
    match = re.search(r'name: "accent",\s*light: RGBA\(hex: 0x([0-9a-fA-F]{6})\),\s*dark: RGBA\(hex: 0x([0-9a-fA-F]{6})\)', colours_)
    if not match:
        return ["the accent token is not in the generated colours"]
    token = {"light": match.group(1).lower(), "dark": match.group(2).lower()}

    def byte(component):
        return int(component, 16) if component.lower().startswith("0x") else round(float(component) * 255)

    problems = []
    for app in APPS:
        path = root / f"Apps/{app}/App/Resources/Assets.xcassets/AccentColor.colorset/Contents.json"
        try:
            entries = json.loads(path.read_text())["colors"]
        except (OSError, KeyError, ValueError):
            problems.append(f"the {app} app has no AccentColor asset")
            continue
        for entry in entries:
            dark = any(a.get("appearance") == "luminosity" and a.get("value") == "dark" for a in entry.get("appearances", []))
            parts = entry["color"]["components"]
            value = "".join(f"{byte(parts[c]):02x}" for c in ("red", "green", "blue"))
            if entry["color"].get("color-space") != "srgb" or value != token["dark" if dark else "light"]:
                problems.append(f"the {app} AccentColor is #{value}, not the accent token #{token['dark' if dark else 'light']}")
    return problems


# --- The Mac app: Sparkle needs its public key to check an update's signature, and the feed it reads; the sandbox's
# entitlements are the allowlist, and only the Debug file may add one key (scripts/verify checks the signed apps).
ENTITLEMENTS = {
    "com.apple.security.app-sandbox": True,
    "com.apple.security.files.user-selected.read-write": True,
    "com.apple.security.network.client": True,
    "com.apple.security.temporary-exception.mach-lookup.global-name": [
        "$(PRODUCT_BUNDLE_IDENTIFIER)-spks", "$(PRODUCT_BUNDLE_IDENTIFIER)-spki"],
}


def mac(root):
    info = plist(root / "Apps/macOS/Info.plist")
    problems = [f"the Mac app's Info.plist has no {key}" for key in ("SUPublicEDKey", "SUFeedURL") if not str(info.get(key, "")).strip()]
    resources = root / "Apps/macOS/App/Resources"
    release = plistlib.loads((resources / "Purlay.entitlements").read_bytes())
    debug = plistlib.loads((resources / "Purlay.Debug.entitlements").read_bytes())
    if not (release == ENTITLEMENTS and debug.pop("com.apple.security.cs.disable-library-validation", None) is True
            and debug == ENTITLEMENTS):
        problems.append("the Mac entitlements are not the allowlist")
    return problems


# --- Both apps register their URL type alike: the same name (the app's own bundle identifier) and the same scheme.
def url_types(root):
    expected = [{"CFBundleURLName": "$(PRODUCT_BUNDLE_IDENTIFIER)", "CFBundleURLSchemes": ["$(PURLAY_URL_SCHEME)"]}]
    if all(plist(root / APPS[app] / "Info.plist").get("CFBundleURLTypes") == expected for app in APPS):
        return []
    return ["the apps' URL types differ, or are not named by the bundle identifier"]


def main(root):
    cache = private(CACHE)
    parses = {path: parsed(path, cache) for path in swift_files(root, "Sources", *(f"Apps/{app}/App" for app in APPS))}
    problems = [*privacy_reasons(root), *catalogues(root), *said(root, parses), *colours(root, parses), *accent(root),
                *mac(root), *url_types(root)]
    for problem in problems:
        print("FAIL: " + problem, file=sys.stderr)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(pathlib.Path(sys.argv[1]).resolve()))
