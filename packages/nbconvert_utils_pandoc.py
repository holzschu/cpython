"""Utility for calling pandoc"""
# Copyright (c) IPython Development Team.
# Distributed under the terms of the Modified BSD License.

import re
import shutil
import subprocess
import warnings
from io import BytesIO, TextIOWrapper
# iOS:
import mistune
import sys, os
from docutils.utils import column_width

from nbconvert.utils.version import check_version

from .exceptions import ConversionException

_minimal_version = "2.14.2"
_maximal_version = "4.0.0"

# iOS: markdown to latex renderer based on mistune
def addNewline(func):
    """Insert double newline at the beginning of string."""
    def inner(*args, **argv):
        return '\n\n%s' % func(*args, **argv)

    return inner

class LatexRenderer(mistune.HTMLRenderer):
    """Renderer for rendering markdown as LaTeX.
    Only a subset of mistune-flavored markdown is supported, which will be
    translated into a subset of LaTeX."""
    # Merge from https://github.com/kavinyao/md2latex/blob/master/md2latex.py
    # and https://github.com/zdxerr/mistune-latex/blob/master/latex_renderer.py
    # Changes based on the fact that we don't parse an entire document, but bits and pieces.
    # TODO: tables, inline HTML, block HTML

    def not_support(self, feature):
        return ('%% %s is not supported yet.' % feature)

    @addNewline
    def text(self, text):
        return text

    def link(self, link, title, text):
        if 'javascript:' in link:
            # for safety
            return ''

        # title is ignored
        return r'\href{%s}{%s}' % (link, text)

    def image(self, src, alt="", title=None):
        return '\n'.join([r'\begin{figure}',
                          r'\includegraphics{%s}' % (src, ),
                          r'\caption{%s}' % (title, ),
                          r'\label{%s}' % (alt, ),
                          r'\end{figure}'])

    def emphasis(self, text):
        return '\\emph{%s}' % text

    def strong(self, text):
        return '\\textbf{%s}' % text

    def codespan(self, text):
        return '\\texttt{%s}' % escape_latex(text)

    def linebreak(self):
        return r'\\'

    def inline_html(self, html):
        return self.not_support('Inline HTML') +  '\n% ' + html

    @addNewline
    def paragraph(self, text):
        return '%s' % text

    def heading(self, text, level):
        # Remove any leading/trailing \n:
        text = text.lstrip('\n').rstrip('\n')
        if level == 4:
            return '\\paragraph{%s}' % (text)

        if level > 4:
            return self.not_support('Header > 4') + '\n' + text

        section = ('sub'*(level-1)) + 'section'
        return '\n\\%s{%s}\n' % (section, text)

    def newline(self):
        return ''

    @addNewline
    def thematic_break(self):
        """Ref: http://tex.stackexchange.com/a/17126/43978"""
        return r'\hrulefill'

    @addNewline
    def block_text(self, text):
        return text

    @addNewline
    def block_code(self, code, info=None):
        """Ref: http://scott.sherrillmix.com/blog/programmer/displaying-code-in-latex/"""
        code = code.rstrip()
        return '\\begin{verbatim}\n%s\n\\end{verbatim}' % code

    @addNewline
    def block_quote(self, text):
        """Ref: http://tex.stackexchange.com/a/4970/43978"""
        return '\\begin{blockquote}%s\n\\end{blockquote}' % text

    @addNewline
    def block_html(self, html):
        return html 

    @addNewline
    def block_error(self, html):
        return html

    @addNewline
    def list(self, text, ordered, level, start=None):
        if ordered:
            return '\\begin{enumerate}\n%s\\end{enumerate}' % text
        else:
            return '\\begin{itemize}\n%s\\end{itemize}' % text

    def list_item(self, text, level):
        return '    \\item %s\n' % text

    def finalize(self, data):
        return ''.join(data)

    # Functions not found in BaseRenderer anymore
    def table(self, header, body):
        return self.not_support('Table environment') + '\n% ' + header +  '\n% ' + body

    def table_row(self, content):
        return '\n% ' + content

    def table_cell(self, content, **flags):
        return '\n% ' + content

    def double_emphasis(self, text):
        """Ref: http://tex.stackexchange.com/q/14667/43978"""
        return '\\textbf{%s}' % text

    def strikethrough(self, text):
        return '\\sout{%s}' % text

    def autolink(self, link, is_email=False):
        if is_email:
            return r'\href{mailto:%s}{%s}' % (link, link)
        else:
            return r'\url{%s}' % link

    def footnotes(self, text):
        return text

    def footnote_ref(self, key, index):
        return r'\footnotemark[%s]' % (key, )

    def footnote_item(self, key, text):
        return r'\footnotetext[%s]{%s}' % (key, text)

    def reference(self, key):
        return r'\cite{%s}' % (key, )

class AsciidocRenderer(mistune.HTMLRenderer):
    """Renderer for rendering markdown as AsciiDoc. http://asciidoc.org
    Only a subset of mistune-flavored markdown is supported, which will be
    translated into a subset of AsciiDoc."""
    list_marker = '{#__rest_list_mark__#}'
    indent = ' ' * 3
    hmarks = {
        1: '=',
        2: '-',
        3: '~',
        4: '^',
        5: '+',
    }

    def _indent_block(self, block):
        return '\n'.join(self.indent + line if line else ''
                         for line in block.splitlines())

    def not_support(self, feature):
        return ('// %s is not supported yet.' % feature)

    def block_code(self, code, lang=None):
        first_line = '--------------------------------------'
        return '\n' + first_line + '\n' + code + '\n' + first_line + '\n'

    def block_quote(self, text):
        first_line = '____________________________________________________________________'
        return '\n' + first_line + text + '\n' + first_line

    def heading(self, text, level):
        return '\n{0}\n{1}\n'.format(text,
                                     self.hmarks[level] * column_width(text))
    def hrule(self):
        return '\n\'\'\'\n'

    def list(self, text, ordered, level, start=None):
        # TODO: imbricated lists. Need access to depth.
        mark = '1. ' if ordered else '- '
        lines = text.splitlines()
        for i, line in enumerate(lines):
            if line and not line.startswith(self.list_marker):
                lines[i] = ' ' * len(mark) + line
        return '\n{}\n'.format(
            '\n'.join(lines)).replace(self.list_marker, mark)

    def list_item(self, text, level):
        """Rendering list item snippet. Like ``<li>``."""
        return '\n' + self.list_marker + text

    def paragraph(self, text):
        return '\n' + text + '\n'

    def table(self, header, body):
        """Rendering table element. Wrap header and body in it.

        :param header: header part of the table.
        :param body: body part of the table.
        """
        table = '\n'
        if header and not header.isspace():
            table = '\n[options="header"]\n' + header + '\n'
        else:
            table = table + '\n'
        table = table + body + '\n'
        return table

    def table_row(self, content):
        contents = content.splitlines()
        if not contents:
            return ''
        clist = [contents[0]]
        if len(contents) > 1:
            for c in contents[1:]:
                clist.append('  ' + c)
        return '\n'.join(clist) + '\n'

    def table_cell(self, content, **flags):
        return '| ' + content

    def double_emphasis(self, text):
        return ' *{}* '.format(text)

    def emphasis(self, text):
        return ' _{}_ '.format(text)

    def codespan(self, text):
        return ' +{}+ '.format(text)

    def linebreak(self):
        return r'\\'

    def strikethrough(self, text):
        return ' [line-through]#{}# '.format(text)

    def autolink(self, link, is_email=False):
        return link

    def link(self, link, title, text):
        return link + '[' + title + ']'

    def image(self, src, title, text):
        """ image::<target>[<attributes>]
        """
        image =  '\nimage::' + format(src)
        if (title or text):
            image =  image + '['
            if (title): image = image + 'title = "' + format(title) + '"'
            if (title and text): image = image + ', '
            if (text): image = image + 'alt="' + format(text) + '"'
            image = image+ ']\n'
        return image

    def inline_html(self, html):
        return self.not_support('Inline HTML') +  '\n' + html

    def block_html(self, html):
        return self.not_support('Block HTML') +  '\n' + html

    def footnotes(self, text):
        """Wrapper for all footnotes.

        :param text: contents of all footnotes.
        """
        return text

    def footnote_ref(self, key, index):
        """Rendering the ref anchor of a footnote.

        :param key: identity key for the footnote.
        :param index: the index count of current footnote.
        footnoteref:[<id>,<text>]
        """
        return r'footnoteref:[%s]' % (key)

    def footnote_item(self, key, text):
        """Rendering a footnote item.

        :param key: identity key for the footnote.
        :param text: text content of the footnote.
        """
        return r'footnoteref:[%s, %s]' % (key, text)

    def reference(self, key):
        return r'<<%s>>' % (key, )


def pandoc(source, fmt, to, extra_args=None, encoding="utf-8"):
    """Convert an input string using pandoc.

    Pandoc converts an input string `from` a format `to` a target format.

    Parameters
    ----------
    source : string
        Input string, assumed to be valid format `from`.
    fmt : string
        The name of the input format (markdown, etc.)
    to : string
        The name of the output format (html, etc.)

    Returns
    -------
    out : unicode
        Output as returned by pandoc.

    Raises
    ------
    PandocMissing
        If pandoc is not installed.
    Any error messages generated by pandoc are printed to stderr.

    """
    cmd = ["pandoc", "-f", fmt, "-t", to]
    if extra_args:
        cmd.extend(extra_args)

    # iOS: we cannot call pandoc, so we just don't convert markdown cells.
    # This is not perfect (...) but it lets the conversion machine work.
    # iOS: we replaced pandoc with a mistune plugin. It's not as good but it works
    # iOS, TODO: tables in LaTeX, html in LaTeX
    # IOS: also possible: switch to multimarkdown for latex output
    # markdown -> rst used to be done with m2r, but it's not incompatible with docutils
    # and m2r2 is not compatible with mistune > 0.8.4
    if (sys.platform == 'darwin' and os.uname().machine.startswith('iP')):
        if (fmt.startswith('markdown') and to.startswith('latex')):
            markdown_to_latex = mistune.Markdown(renderer=LatexRenderer())
            return markdown_to_latex(source)
        elif (fmt.startswith('markdown') and to.startswith('asciidoc')):
            # This one works for asciidoc
            markdown_to_asciidoc = mistune.Markdown(renderer=AsciidocRenderer())
            return markdown_to_asciidoc(source)
        return source

    # this will raise an exception that will pop us out of here
    check_pandoc_version()

    # we can safely continue
    p = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE)  # noqa: S603
    out, _ = p.communicate(source.encode())
    out_str = TextIOWrapper(BytesIO(out), encoding, "replace").read()
    return out_str.rstrip("\n")


def get_pandoc_version():
    """Gets the Pandoc version if Pandoc is installed.

    If the minimal version is not met, it will probe Pandoc for its version, cache it and return that value.
    If the minimal version is met, it will return the cached version and stop probing Pandoc
    (unless `clean_cache()` is called).

    Raises
    ------
    PandocMissing
        If pandoc is unavailable.
    """
    global __version  # noqa: PLW0603

    if __version is None:
        if not shutil.which("pandoc"):
            raise PandocMissing()

        out = subprocess.check_output(["pandoc", "-v"])  # noqa: S607, S603
        out_lines = out.splitlines()
        version_pattern = re.compile(r"^\d+(\.\d+){1,}$")
        for tok in out_lines[0].decode("ascii", "replace").split():
            if version_pattern.match(tok):
                __version = tok  # type:ignore[assignment]
                break
    return __version


def check_pandoc_version():
    """Returns True if pandoc's version meets at least minimal version.

    Raises
    ------
    PandocMissing
        If pandoc is unavailable.
    """
    if check_pandoc_version._cached is not None:  # type:ignore[attr-defined]
        return check_pandoc_version._cached  # type:ignore[attr-defined]

    v = get_pandoc_version()
    if v is None:
        warnings.warn(
            "Sorry, we cannot determine the version of pandoc.\n"
            "Please consider reporting this issue and include the"
            "output of pandoc --version.\nContinuing...",
            RuntimeWarning,
            stacklevel=2,
        )
        return False
    ok = check_version(v, _minimal_version, max_v=_maximal_version)
    check_pandoc_version._cached = ok  # type:ignore[attr-defined]
    if not ok:
        warnings.warn(
            "You are using an unsupported version of pandoc (%s).\n" % v
            + "Your version must be at least (%s) " % _minimal_version
            + "but less than (%s).\n" % _maximal_version
            + "Refer to https://pandoc.org/installing.html.\nContinuing with doubts...",
            RuntimeWarning,
            stacklevel=2,
        )
    return ok


check_pandoc_version._cached = None  # type:ignore[attr-defined]

# -----------------------------------------------------------------------------
# Exception handling
# -----------------------------------------------------------------------------


class PandocMissing(ConversionException):
    """Exception raised when Pandoc is missing."""

    def __init__(self, *args, **kwargs):
        """Initialize the exception."""
        super().__init__(
            "Pandoc wasn't found.\n"
            "Please check that pandoc is installed:\n"
            "https://pandoc.org/installing.html"
        )


# -----------------------------------------------------------------------------
# Internal state management
# -----------------------------------------------------------------------------
def clean_cache():
    """Clean the internal cache."""
    global __version  # noqa: PLW0603
    __version = None


__version = None
