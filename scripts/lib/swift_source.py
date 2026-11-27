"""Swift source as scripts/enforcement reads it: string literals, comments and the types that enclose a place in a file.

Python's standard library only, so the rules run on a runner without Swift. It reads the Swift this repository writes, not every
Swift there is: a raw string (#"…"#) is read as an ordinary one.
"""
import re

ESCAPES = {"n": "\n", "t": "\t", '"': '"', "\\": "\\", "'": "'", "0": "\0"}
TYPE = re.compile(r"\b(?:struct|class|enum|actor|extension)\s+(\w+)[^{;=]*\{")


def literal(text, i):
    """The string literal opening at text[i], each interpolation as NUL, and the index after it."""
    if text.startswith('"""', i):
        end = text.index('"""', i + 3)
        lines = text[i + 3:end].strip("\n").split("\n")
        indent = min((len(line) - len(line.lstrip()) for line in lines if line.strip()), default=0)
        return "\n".join(line[indent:] for line in lines), end + 3
    value, i = [], i + 1
    while i < len(text) and text[i] not in '"\n':
        if text[i] != "\\":
            value.append(text[i])
            i += 1
        elif text[i + 1] == "(":
            depth, i = 1, i + 2
            while depth:
                if text[i] == '"':
                    _, i = literal(text, i)
                    continue
                depth += {"(": 1, ")": -1}.get(text[i], 0)
                i += 1
            value.append("\0")
        elif text[i + 1] == "u":
            close = text.index("}", i)
            value.append(chr(int(text[i + 3:close], 16)))
            i = close + 1
        else:
            value.append(ESCAPES.get(text[i + 1], text[i + 1]))
            i += 2
    return "".join(value), i + 1


def code(text):
    """The source with every comment blanked (a line's, a trailing one, a block, nested blocks), literals kept whole. Each
    blanked character becomes a space and every newline stays, so offsets and line numbers are the source's."""
    out, i = [], 0
    while i < len(text):
        if text[i] == '"':
            _, end = literal(text, i)
        elif text.startswith("//", i):
            end = text.find("\n", i)
            end = len(text) if end == -1 else end
            out.append(" " * (end - i))
            i = end
            continue
        elif text.startswith("/*", i):
            depth, end = 1, i + 2
            while depth and end < len(text):
                if text.startswith("/*", end):
                    depth, end = depth + 1, end + 2
                elif text.startswith("*/", end):
                    depth, end = depth - 1, end + 2
                else:
                    end += 1
            out.append(re.sub(r"[^\n]", " ", text[i:end]))
            i = end
            continue
        else:
            end = i + 1
        out.append(text[i:end])
        i = end
    return "".join(out)


def skeleton(source):
    """Code (comments already blanked) with each literal's content blanked too, so its brackets are not counted."""
    out, i = [], 0
    while i < len(source):
        if source[i] == '"':
            _, end = literal(source, i)
            out.append('"' + re.sub(r"[^\n]", " ", source[i + 1:end - 1]) + '"')
            i = end
        else:
            out.append(source[i])
            i += 1
    return "".join(out)


def type_scopes(shape):
    """Each type's body in a skeleton, as (start, end, name), outermost first."""
    scopes = []
    for match in TYPE.finditer(shape):
        depth, end = 1, match.end()
        while depth and end < len(shape):
            depth += {"{": 1, "}": -1}.get(shape[end], 0)
            end += 1
        scopes.append((match.end(), end, match.group(1)))
    return scopes


def owner(scopes, position):
    """The innermost type whose body holds the position, or None."""
    inside = [scope for scope in scopes if scope[0] <= position < scope[1]]
    return max(inside, key=lambda scope: scope[0])[2] if inside else None
