Terminal IPython options
========================


.. configtrait:: InteractiveShellApp.code_to_run

    Execute the given command string.

    :trait type: Unicode
    :CLI option: ``-c``

.. configtrait:: InteractiveShellApp.exec_PYTHONSTARTUP

    Run the file referenced by the PYTHONSTARTUP environment
    variable at IPython startup.

    :trait type: Bool
    :default: ``True``

.. configtrait:: InteractiveShellApp.exec_files

    List of files to run at IPython startup.

    :trait type: List

.. configtrait:: InteractiveShellApp.exec_lines

    lines of code to run at IPython startup.

    :trait type: List

.. configtrait:: InteractiveShellApp.extensions

    A list of dotted module names of IPython extensions to load.

    :trait type: List

.. configtrait:: InteractiveShellApp.extra_extension

    DEPRECATED. Dotted module name of a single extra IPython extension to load.

    Only one extension can be added this way.

    Only used with traitlets < 5.0, plural extra_extensions list is used in traitlets 5.

    :trait type: Unicode

.. configtrait:: InteractiveShellApp.extra_extensions

    Dotted module name(s) of one or more IPython extensions to load.

    For specifying extra extensions to load on the command-line.

    .. versionadded:: 7.10

    :trait type: List
    :CLI option: ``--ext``

.. configtrait:: InteractiveShellApp.file_to_run

    A file to be run

    :trait type: Unicode

.. configtrait:: InteractiveShellApp.gui

    Enable GUI event loop integration with any of ('asyncio', 'glut', 'gtk', 'gtk2', 'gtk3', 'osx', 'pyglet', 'qt', 'qt4', 'qt5', 'tk', 'wx', 'gtk2', 'qt4').

    :options: ``'asyncio'``, ``'glut'``, ``'gtk'``, ``'gtk2'``, ``'gtk3'``, ``'osx'``, ``'pyglet'``, ``'qt'``, ``'qt4'``, ``'qt5'``, ``'tk'``, ``'wx'``, ``'gtk2'``, ``'qt4'``
    :CLI option: ``--gui``

.. configtrait:: InteractiveShellApp.hide_initial_ns

    Should variables loaded at startup (by startup files, exec_lines, etc.)
    be hidden from tools like %who?

    :trait type: Bool
    :default: ``True``

.. configtrait:: InteractiveShellApp.ignore_cwd

    If True, IPython will not add the current working directory to sys.path.
    When False, the current working directory is added to sys.path, allowing imports
    of modules defined in the current directory.

    :trait type: Bool
    :default: ``False``
    :CLI option: ``--ignore-cwd``

.. configtrait:: InteractiveShellApp.matplotlib

    Configure matplotlib for interactive use with
    the default matplotlib backend.

    :options: ``'auto'``, ``'agg'``, ``'gtk'``, ``'gtk3'``, ``'inline'``, ``'ipympl'``, ``'nbagg'``, ``'notebook'``, ``'osx'``, ``'pdf'``, ``'ps'``, ``'qt'``, ``'qt4'``, ``'qt5'``, ``'svg'``, ``'tk'``, ``'widget'``, ``'wx'``
    :CLI option: ``--matplotlib``

.. configtrait:: InteractiveShellApp.module_to_run

    Run the module as a script.

    :trait type: Unicode
    :CLI option: ``-m``

.. configtrait:: InteractiveShellApp.pylab

    Pre-load matplotlib and numpy for interactive use,
    selecting a particular matplotlib backend and loop integration.

    :options: ``'auto'``, ``'agg'``, ``'gtk'``, ``'gtk3'``, ``'inline'``, ``'ipympl'``, ``'nbagg'``, ``'notebook'``, ``'osx'``, ``'pdf'``, ``'ps'``, ``'qt'``, ``'qt4'``, ``'qt5'``, ``'svg'``, ``'tk'``, ``'widget'``, ``'wx'``
    :CLI option: ``--pylab``

.. configtrait:: InteractiveShellApp.pylab_import_all

    If true, IPython will populate the user namespace with numpy, pylab, etc.
    and an ``import *`` is done from numpy and pylab, when using pylab mode.

    When False, pylab mode should not import any names into the user namespace.

    :trait type: Bool
    :default: ``True``

.. configtrait:: InteractiveShellApp.reraise_ipython_extension_failures

    Reraise exceptions encountered loading IPython extensions?

    :trait type: Bool
    :default: ``False``



.. configtrait:: Application.log_datefmt

    The date format used by logging formatters for %(asctime)s

    :trait type: Unicode
    :default: ``'%Y-%m-%d %H:%M:%S'``

.. configtrait:: Application.log_format

    The Logging format template

    :trait type: Unicode
    :default: ``'[%(name)s]%(highlevel)s %(message)s'``

.. configtrait:: Application.log_level

    Set the log level by value or name.

    :options: ``0``, ``10``, ``20``, ``30``, ``40``, ``50``, ``'DEBUG'``, ``'INFO'``, ``'WARN'``, ``'ERROR'``, ``'CRITICAL'``
    :default: ``30``
    :CLI option: ``--log-level``

.. configtrait:: Application.show_config

    Instead of starting the Application, dump configuration to stdout

    :trait type: Bool
    :default: ``False``

.. configtrait:: Application.show_config_json

    Instead of starting the Application, dump configuration to stdout (as JSON)

    :trait type: Bool
    :default: ``False``

.. configtrait:: BaseIPythonApplication.auto_create

    Whether to create profile dir if it doesn't exist

    :trait type: Bool
    :default: ``False``

.. configtrait:: BaseIPythonApplication.copy_config_files

    Whether to install the default config files into the profile dir.
    If a new profile is being created, and IPython contains config files for that
    profile, then they will be staged into the new directory.  Otherwise,
    default config files will be automatically generated.

    :trait type: Bool
    :default: ``False``

.. configtrait:: BaseIPythonApplication.extra_config_file

    Path to an extra config file to load.

    If specified, load this config file in addition to any other IPython config.

    :trait type: Unicode
    :CLI option: ``--config``

.. configtrait:: BaseIPythonApplication.ipython_dir

    The name of the IPython directory. This directory is used for logging
    configuration (through profiles), history storage, etc. The default
    is usually $HOME/.ipython. This option can also be specified through
    the environment variable IPYTHONDIR.

    :trait type: Unicode
    :CLI option: ``--ipython-dir``

.. configtrait:: BaseIPythonApplication.log_datefmt

    The date format used by logging formatters for %(asctime)s

    :trait type: Unicode
    :default: ``'%Y-%m-%d %H:%M:%S'``

.. configtrait:: BaseIPythonApplication.log_format

    The Logging format template

    :trait type: Unicode
    :default: ``'[%(name)s]%(highlevel)s %(message)s'``

.. configtrait:: BaseIPythonApplication.log_level

    Set the log level by value or name.

    :options: ``0``, ``10``, ``20``, ``30``, ``40``, ``50``, ``'DEBUG'``, ``'INFO'``, ``'WARN'``, ``'ERROR'``, ``'CRITICAL'``
    :default: ``30``

.. configtrait:: BaseIPythonApplication.overwrite

    Whether to overwrite existing config files when copying

    :trait type: Bool
    :default: ``False``

.. configtrait:: BaseIPythonApplication.profile

    The IPython profile to use.

    :trait type: Unicode
    :default: ``'default'``
    :CLI option: ``--profile``

.. configtrait:: BaseIPythonApplication.show_config

    Instead of starting the Application, dump configuration to stdout

    :trait type: Bool
    :default: ``False``

.. configtrait:: BaseIPythonApplication.show_config_json

    Instead of starting the Application, dump configuration to stdout (as JSON)

    :trait type: Bool
    :default: ``False``

.. configtrait:: BaseIPythonApplication.verbose_crash

    Create a massive crash report when IPython encounters what may be an
    internal error.  The default is to append a short message to the
    usual traceback

    :trait type: Bool
    :default: ``False``

.. configtrait:: TerminalIPythonApp.code_to_run

    Execute the given command string.

    :trait type: Unicode

.. configtrait:: TerminalIPythonApp.copy_config_files

    Whether to install the default config files into the profile dir.
    If a new profile is being created, and IPython contains config files for that
    profile, then they will be staged into the new directory.  Otherwise,
    default config files will be automatically generated.

    :trait type: Bool
    :default: ``False``

.. configtrait:: TerminalIPythonApp.display_banner

    Whether to display a banner upon starting IPython.

    :trait type: Bool
    :default: ``True``
    :CLI option: ``--banner``

.. configtrait:: TerminalIPythonApp.exec_PYTHONSTARTUP

    Run the file referenced by the PYTHONSTARTUP environment
    variable at IPython startup.

    :trait type: Bool
    :default: ``True``

.. configtrait:: TerminalIPythonApp.exec_files

    List of files to run at IPython startup.

    :trait type: List

.. configtrait:: TerminalIPythonApp.exec_lines

    lines of code to run at IPython startup.

    :trait type: List

.. configtrait:: TerminalIPythonApp.extensions

    A list of dotted module names of IPython extensions to load.

    :trait type: List

.. configtrait:: TerminalIPythonApp.extra_config_file

    Path to an extra config file to load.

    If specified, load this config file in addition to any other IPython config.

    :trait type: Unicode

.. configtrait:: TerminalIPythonApp.extra_extension

    DEPRECATED. Dotted module name of a single extra IPython extension to load.

    Only one extension can be added this way.

    Only used with traitlets < 5.0, plural extra_extensions list is used in traitlets 5.

    :trait type: Unicode

.. configtrait:: TerminalIPythonApp.extra_extensions

    Dotted module name(s) of one or more IPython extensions to load.

    For specifying extra extensions to load on the command-line.

    .. versionadded:: 7.10

    :trait type: List

.. configtrait:: TerminalIPythonApp.file_to_run

    A file to be run

    :trait type: Unicode

.. configtrait:: TerminalIPythonApp.force_interact

    If a command or file is given via the command-line,
    e.g. 'ipython foo.py', start an interactive shell after executing the
    file or command.

    :trait type: Bool
    :default: ``False``
    :CLI option: ``-i``

.. configtrait:: TerminalIPythonApp.gui

    Enable GUI event loop integration with any of ('asyncio', 'glut', 'gtk', 'gtk2', 'gtk3', 'osx', 'pyglet', 'qt', 'qt4', 'qt5', 'tk', 'wx', 'gtk2', 'qt4').

    :options: ``'asyncio'``, ``'glut'``, ``'gtk'``, ``'gtk2'``, ``'gtk3'``, ``'osx'``, ``'pyglet'``, ``'qt'``, ``'qt4'``, ``'qt5'``, ``'tk'``, ``'wx'``, ``'gtk2'``, ``'qt4'``

.. configtrait:: TerminalIPythonApp.hide_initial_ns

    Should variables loaded at startup (by startup files, exec_lines, etc.)
    be hidden from tools like %who?

    :trait type: Bool
    :default: ``True``

.. configtrait:: TerminalIPythonApp.ignore_cwd

    If True, IPython will not add the current working directory to sys.path.
    When False, the current working directory is added to sys.path, allowing imports
    of modules defined in the current directory.

    :trait type: Bool
    :default: ``False``

.. configtrait:: TerminalIPythonApp.interactive_shell_class

    Class to use to instantiate the TerminalInteractiveShell object. Useful for custom Frontends

    :trait type: Type
    :default: ``'IPython.terminal.interactiveshell.TerminalInteractiveShell'``

.. configtrait:: TerminalIPythonApp.ipython_dir

    The name of the IPython directory. This directory is used for logging
    configuration (through profiles), history storage, etc. The default
    is usually $HOME/.ipython. This option can also be specified through
    the environment variable IPYTHONDIR.

    :trait type: Unicode

.. configtrait:: TerminalIPythonApp.log_datefmt

    The date format used by logging formatters for %(asctime)s

    :trait type: Unicode
    :default: ``'%Y-%m-%d %H:%M:%S'``

.. configtrait:: TerminalIPythonApp.log_format

    The Logging format template

    :trait type: Unicode
    :default: ``'[%(name)s]%(highlevel)s %(message)s'``

.. configtrait:: TerminalIPythonApp.log_level

    Set the log level by value or name.

    :options: ``0``, ``10``, ``20``, ``30``, ``40``, ``50``, ``'DEBUG'``, ``'INFO'``, ``'WARN'``, ``'ERROR'``, ``'CRITICAL'``
    :default: ``30``

.. configtrait:: TerminalIPythonApp.matplotlib

    Configure matplotlib for interactive use with
    the default matplotlib backend.

    :options: ``'auto'``, ``'agg'``, ``'gtk'``, ``'gtk3'``, ``'inline'``, ``'ipympl'``, ``'nbagg'``, ``'notebook'``, ``'osx'``, ``'pdf'``, ``'ps'``, ``'qt'``, ``'qt4'``, ``'qt5'``, ``'svg'``, ``'tk'``, ``'widget'``, ``'wx'``

.. configtrait:: TerminalIPythonApp.module_to_run

    Run the module as a script.

    :trait type: Unicode

.. configtrait:: TerminalIPythonApp.overwrite

    Whether to overwrite existing config files when copying

    :trait type: Bool
    :default: ``False``

.. configtrait:: TerminalIPythonApp.profile

    The IPython profile to use.

    :trait type: Unicode
    :default: ``'default'``

.. configtrait:: TerminalIPythonApp.pylab

    Pre-load matplotlib and numpy for interactive use,
    selecting a particular matplotlib backend and loop integration.

    :options: ``'auto'``, ``'agg'``, ``'gtk'``, ``'gtk3'``, ``'inline'``, ``'ipympl'``, ``'nbagg'``, ``'notebook'``, ``'osx'``, ``'pdf'``, ``'ps'``, ``'qt'``, ``'qt4'``, ``'qt5'``, ``'svg'``, ``'tk'``, ``'widget'``, ``'wx'``

.. configtrait:: TerminalIPythonApp.pylab_import_all

    If true, IPython will populate the user namespace with numpy, pylab, etc.
    and an ``import *`` is done from numpy and pylab, when using pylab mode.

    When False, pylab mode should not import any names into the user namespace.

    :trait type: Bool
    :default: ``True``

.. configtrait:: TerminalIPythonApp.quick

    Start IPython quickly by skipping the loading of config files.

    :trait type: Bool
    :default: ``False``
    :CLI option: ``--quick``

.. configtrait:: TerminalIPythonApp.reraise_ipython_extension_failures

    Reraise exceptions encountered loading IPython extensions?

    :trait type: Bool
    :default: ``False``

.. configtrait:: TerminalIPythonApp.show_config

    Instead of starting the Application, dump configuration to stdout

    :trait type: Bool
    :default: ``False``

.. configtrait:: TerminalIPythonApp.show_config_json

    Instead of starting the Application, dump configuration to stdout (as JSON)

    :trait type: Bool
    :default: ``False``

.. configtrait:: TerminalIPythonApp.verbose_crash

    Create a massive crash report when IPython encounters what may be an
    internal error.  The default is to append a short message to the
    usual traceback

    :trait type: Bool
    :default: ``False``

.. configtrait:: InteractiveShell.ast_node_interactivity

    'all', 'last', 'last_expr' or 'none', 'last_expr_or_assign' specifying
    which nodes should be run interactively (displaying output from expressions).

    :options: ``'all'``, ``'last'``, ``'last_expr'``, ``'none'``, ``'last_expr_or_assign'``
    :default: ``'last_expr'``

.. configtrait:: InteractiveShell.ast_transformers

    A list of ast.NodeTransformer subclass instances, which will be applied
    to user input before code is run.

    :trait type: List

.. configtrait:: InteractiveShell.autoawait

    Automatically run await statement in the top level repl.

    :trait type: Bool
    :default: ``True``

.. configtrait:: InteractiveShell.autocall

    Make IPython automatically call any callable object even if you didn't
    type explicit parentheses. For example, 'str 43' becomes 'str(43)'
    automatically. The value can be '0' to disable the feature, '1' for
    'smart' autocall, where it is not applied if there are no more
    arguments on the line, and '2' for 'full' autocall, where all callable
    objects are automatically called (even if no arguments are present).

    :options: ``0``, ``1``, ``2``
    :default: ``0``
    :CLI option: ``--autocall``

.. configtrait:: InteractiveShell.autoindent

    Autoindent IPython code entered interactively.

    :trait type: Bool
    :default: ``True``
    :CLI option: ``--autoindent``

.. configtrait:: InteractiveShell.automagic

    Enable magic commands to be called without the leading %.

    :trait type: Bool
    :default: ``True``
    :CLI option: ``--automagic``

.. configtrait:: InteractiveShell.banner1

    The part of the banner to be printed before the profile

    :trait type: Unicode
    :default: ``"Python 3.8.5 | packaged by conda-forge | (default, Sep 16 20...``

.. configtrait:: InteractiveShell.banner2

    The part of the banner to be printed after the profile

    :trait type: Unicode

.. configtrait:: InteractiveShell.cache_size

    Set the size of the output cache.  The default is 1000, you can
    change it permanently in your config file.  Setting it to 0 completely
    disables the caching system, and the minimum value accepted is 3 (if
    you provide a value less than 3, it is reset to 0 and a warning is
    issued).  This limit is defined because otherwise you'll spend more
    time re-flushing a too small cache than working

    :trait type: Int
    :default: ``1000``
    :CLI option: ``--cache-size``

.. configtrait:: InteractiveShell.color_info

    Use colors for displaying information about objects. Because this
    information is passed through a pager (like 'less'), and some pagers
    get confused with color codes, this capability can be turned off.

    :trait type: Bool
    :default: ``True``
    :CLI option: ``--color-info``

.. configtrait:: InteractiveShell.colors

    Set the color scheme (NoColor, Neutral, Linux, or LightBG).

    :options: ``'Neutral'``, ``'NoColor'``, ``'LightBG'``, ``'Linux'``
    :default: ``'Neutral'``
    :CLI option: ``--colors``

.. configtrait:: InteractiveShell.debug

    No description

    :trait type: Bool
    :default: ``False``

.. configtrait:: InteractiveShell.disable_failing_post_execute

    Don't call post-execute functions that have failed in the past.

    :trait type: Bool
    :default: ``False``

.. configtrait:: InteractiveShell.display_page

    If True, anything that would be passed to the pager
    will be displayed as regular output instead.

    :trait type: Bool
    :default: ``False``

.. configtrait:: InteractiveShell.enable_html_pager

    (Provisional API) enables html representation in mime bundles sent
    to pagers.

    :trait type: Bool
    :default: ``False``

.. configtrait:: InteractiveShell.history_length

    Total length of command history

    :trait type: Int
    :default: ``10000``

.. configtrait:: InteractiveShell.history_load_length

    The number of saved history entries to be loaded
    into the history buffer at startup.

    :trait type: Int
    :default: ``1000``

.. configtrait:: InteractiveShell.ipython_dir

    No description

    :trait type: Unicode

.. configtrait:: InteractiveShell.logappend

    Start logging to the given file in append mode.
    Use `logfile` to specify a log file to **overwrite** logs to.

    :trait type: Unicode
    :CLI option: ``--logappend``

.. configtrait:: InteractiveShell.logfile

    The name of the logfile to use.

    :trait type: Unicode
    :CLI option: ``--logfile``

.. configtrait:: InteractiveShell.logstart

    Start logging to the default log file in overwrite mode.
    Use `logappend` to specify a log file to **append** logs to.

    :trait type: Bool
    :default: ``False``

.. configtrait:: InteractiveShell.loop_runner

    Select the loop runner that will be used to execute top-level asynchronous code

    :trait type: Any
    :default: ``'IPython.core.interactiveshell._asyncio_runner'``

.. configtrait:: InteractiveShell.object_info_string_level

    No description

    :options: ``0``, ``1``, ``2``
    :default: ``0``

.. configtrait:: InteractiveShell.pdb

    Automatically call the pdb debugger after every exception.

    :trait type: Bool
    :default: ``False``
    :CLI option: ``--pdb``

.. configtrait:: InteractiveShell.prompt_in1

    Deprecated since IPython 4.0 and ignored since 5.0, set TerminalInteractiveShell.prompts object directly.

    :trait type: Unicode
    :default: ``'In [\\#]: '``

.. configtrait:: InteractiveShell.prompt_in2

    Deprecated since IPython 4.0 and ignored since 5.0, set TerminalInteractiveShell.prompts object directly.

    :trait type: Unicode
    :default: ``'   .\\D.: '``

.. configtrait:: InteractiveShell.prompt_out

    Deprecated since IPython 4.0 and ignored since 5.0, set TerminalInteractiveShell.prompts object directly.

    :trait type: Unicode
    :default: ``'Out[\\#]: '``

.. configtrait:: InteractiveShell.prompts_pad_left

    Deprecated since IPython 4.0 and ignored since 5.0, set TerminalInteractiveShell.prompts object directly.

    :trait type: Bool
    :default: ``True``

.. configtrait:: InteractiveShell.quiet

    No description

    :trait type: Bool
    :default: ``False``

.. configtrait:: InteractiveShell.separate_in

    No description

    :trait type: SeparateUnicode
    :default: ``'\\n'``

.. configtrait:: InteractiveShell.separate_out

    No description

    :trait type: SeparateUnicode

.. configtrait:: InteractiveShell.separate_out2

    No description

    :trait type: SeparateUnicode

.. configtrait:: InteractiveShell.show_rewritten_input

    Show rewritten input, e.g. for autocall.

    :trait type: Bool
    :default: ``True``

.. configtrait:: InteractiveShell.sphinxify_docstring

    Enables rich html representation of docstrings. (This requires the
    docrepr module).

    :trait type: Bool
    :default: ``False``

.. configtrait:: InteractiveShell.wildcards_case_sensitive

    No description

    :trait type: Bool
    :default: ``True``

.. configtrait:: InteractiveShell.xmode

    Switch modes for the IPython exception handlers.

    :options: ``'Context'``, ``'Plain'``, ``'Verbose'``, ``'Minimal'``
    :default: ``'Context'``

.. configtrait:: TerminalInteractiveShell.ast_node_interactivity

    'all', 'last', 'last_expr' or 'none', 'last_expr_or_assign' specifying
    which nodes should be run interactively (displaying output from expressions).

    :options: ``'all'``, ``'last'``, ``'last_expr'``, ``'none'``, ``'last_expr_or_assign'``
    :default: ``'last_expr'``

.. configtrait:: TerminalInteractiveShell.ast_transformers

    A list of ast.NodeTransformer subclass instances, which will be applied
    to user input before code is run.

    :trait type: List

.. configtrait:: TerminalInteractiveShell.autoawait

    Automatically run await statement in the top level repl.

    :trait type: Bool
    :default: ``True``

.. configtrait:: TerminalInteractiveShell.autocall

    Make IPython automatically call any callable object even if you didn't
    type explicit parentheses. For example, 'str 43' becomes 'str(43)'
    automatically. The value can be '0' to disable the feature, '1' for
    'smart' autocall, where it is not applied if there are no more
    arguments on the line, and '2' for 'full' autocall, where all callable
    objects are automatically called (even if no arguments are present).

    :options: ``0``, ``1``, ``2``
    :default: ``0``

.. configtrait:: TerminalInteractiveShell.autoformatter

    Autoformatter to reformat Terminal code. Can be `'black'` or `None`

    :trait type: Unicode

.. configtrait:: TerminalInteractiveShell.autoindent

    Autoindent IPython code entered interactively.

    :trait type: Bool
    :default: ``True``

.. configtrait:: TerminalInteractiveShell.automagic

    Enable magic commands to be called without the leading %.

    :trait type: Bool
    :default: ``True``

.. configtrait:: TerminalInteractiveShell.banner1

    The part of the banner to be printed before the profile

    :trait type: Unicode
    :default: ``"Python 3.8.5 | packaged by conda-forge | (default, Sep 16 20...``

.. configtrait:: TerminalInteractiveShell.banner2

    The part of the banner to be printed after the profile

    :trait type: Unicode

.. configtrait:: TerminalInteractiveShell.cache_size

    Set the size of the output cache.  The default is 1000, you can
    change it permanently in your config file.  Setting it to 0 completely
    disables the caching system, and the minimum value accepted is 3 (if
    you provide a value less than 3, it is reset to 0 and a warning is
    issued).  This limit is defined because otherwise you'll spend more
    time re-flushing a too small cache than working

    :trait type: Int
    :default: ``1000``

.. configtrait:: TerminalInteractiveShell.color_info

    Use colors for displaying information about objects. Because this
    information is passed through a pager (like 'less'), and some pagers
    get confused with color codes, this capability can be turned off.

    :trait type: Bool
    :default: ``True``

.. configtrait:: TerminalInteractiveShell.colors

    Set the color scheme (NoColor, Neutral, Linux, or LightBG).

    :options: ``'Neutral'``, ``'NoColor'``, ``'LightBG'``, ``'Linux'``
    :default: ``'Neutral'``

.. configtrait:: TerminalInteractiveShell.confirm_exit

    Set to confirm when you try to exit IPython with an EOF (Control-D
    in Unix, Control-Z/Enter in Windows). By typing 'exit' or 'quit',
    you can force a direct exit without any confirmation.

    :trait type: Bool
    :default: ``True``
    :CLI option: ``--confirm-exit``

.. configtrait:: TerminalInteractiveShell.debug

    No description

    :trait type: Bool
    :default: ``False``

.. configtrait:: TerminalInteractiveShell.disable_failing_post_execute

    Don't call post-execute functions that have failed in the past.

    :trait type: Bool
    :default: ``False``

.. configtrait:: TerminalInteractiveShell.display_completions

    Options for displaying tab completions, 'column', 'multicolumn', and 'readlinelike'. These options are for `prompt_toolkit`, see `prompt_toolkit` documentation for more information.

    :options: ``'column'``, ``'multicolumn'``, ``'readlinelike'``
    :default: ``'multicolumn'``

.. configtrait:: TerminalInteractiveShell.display_page

    If True, anything that would be passed to the pager
    will be displayed as regular output instead.

    :trait type: Bool
    :default: ``False``

.. configtrait:: TerminalInteractiveShell.editing_mode

    Shortcut style to use at the prompt. 'vi' or 'emacs'.

    :trait type: Unicode
    :default: ``'emacs'``

.. configtrait:: TerminalInteractiveShell.editor

    Set the editor used by IPython (default to $EDITOR/vi/notepad).

    :trait type: Unicode
    :default: ``'vim'``

.. configtrait:: TerminalInteractiveShell.enable_history_search

    Allows to enable/disable the prompt toolkit history search

    :trait type: Bool
    :default: ``True``

.. configtrait:: TerminalInteractiveShell.enable_html_pager

    (Provisional API) enables html representation in mime bundles sent
    to pagers.

    :trait type: Bool
    :default: ``False``

.. configtrait:: TerminalInteractiveShell.extra_open_editor_shortcuts

    Enable vi (v) or Emacs (C-X C-E) shortcuts to open an external editor. This is in addition to the F2 binding, which is always enabled.

    :trait type: Bool
    :default: ``False``

.. configtrait:: TerminalInteractiveShell.handle_return

    Provide an alternative handler to be called when the user presses Return. This is an advanced option intended for debugging, which may be changed or removed in later releases.

    :trait type: Any

.. configtrait:: TerminalInteractiveShell.highlight_matching_brackets

    Highlight matching brackets.

    :trait type: Bool
    :default: ``True``

.. configtrait:: TerminalInteractiveShell.highlighting_style

    The name or class of a Pygments style to use for syntax
    highlighting. To see available styles, run `pygmentize -L styles`.

    :trait type: Union

.. configtrait:: TerminalInteractiveShell.highlighting_style_overrides

    Override highlighting format for specific tokens

    :trait type: Dict

.. configtrait:: TerminalInteractiveShell.history_length

    Total length of command history

    :trait type: Int
    :default: ``10000``

.. configtrait:: TerminalInteractiveShell.history_load_length

    The number of saved history entries to be loaded
    into the history buffer at startup.

    :trait type: Int
    :default: ``1000``

.. configtrait:: TerminalInteractiveShell.ipython_dir

    No description

    :trait type: Unicode

.. configtrait:: TerminalInteractiveShell.logappend

    Start logging to the given file in append mode.
    Use `logfile` to specify a log file to **overwrite** logs to.

    :trait type: Unicode

.. configtrait:: TerminalInteractiveShell.logfile

    The name of the logfile to use.

    :trait type: Unicode

.. configtrait:: TerminalInteractiveShell.logstart

    Start logging to the default log file in overwrite mode.
    Use `logappend` to specify a log file to **append** logs to.

    :trait type: Bool
    :default: ``False``

.. configtrait:: TerminalInteractiveShell.loop_runner

    Select the loop runner that will be used to execute top-level asynchronous code

    :trait type: Any
    :default: ``'IPython.core.interactiveshell._asyncio_runner'``

.. configtrait:: TerminalInteractiveShell.mime_renderers

    No description

    :trait type: Dict

.. configtrait:: TerminalInteractiveShell.mouse_support

    Enable mouse support in the prompt
    (Note: prevents selecting text with the mouse)

    :trait type: Bool
    :default: ``False``

.. configtrait:: TerminalInteractiveShell.object_info_string_level

    No description

    :options: ``0``, ``1``, ``2``
    :default: ``0``

.. configtrait:: TerminalInteractiveShell.pdb

    Automatically call the pdb debugger after every exception.

    :trait type: Bool
    :default: ``False``

.. configtrait:: TerminalInteractiveShell.prompt_in1

    Deprecated since IPython 4.0 and ignored since 5.0, set TerminalInteractiveShell.prompts object directly.

    :trait type: Unicode
    :default: ``'In [\\#]: '``

.. configtrait:: TerminalInteractiveShell.prompt_in2

    Deprecated since IPython 4.0 and ignored since 5.0, set TerminalInteractiveShell.prompts object directly.

    :trait type: Unicode
    :default: ``'   .\\D.: '``

.. configtrait:: TerminalInteractiveShell.prompt_includes_vi_mode

    Display the current vi mode (when using vi editing mode).

    :trait type: Bool
    :default: ``True``

.. configtrait:: TerminalInteractiveShell.prompt_out

    Deprecated since IPython 4.0 and ignored since 5.0, set TerminalInteractiveShell.prompts object directly.

    :trait type: Unicode
    :default: ``'Out[\\#]: '``

.. configtrait:: TerminalInteractiveShell.prompts_class

    Class used to generate Prompt token for prompt_toolkit

    :trait type: Type
    :default: ``'IPython.terminal.prompts.Prompts'``

.. configtrait:: TerminalInteractiveShell.prompts_pad_left

    Deprecated since IPython 4.0 and ignored since 5.0, set TerminalInteractiveShell.prompts object directly.

    :trait type: Bool
    :default: ``True``

.. configtrait:: TerminalInteractiveShell.quiet

    No description

    :trait type: Bool
    :default: ``False``

.. configtrait:: TerminalInteractiveShell.separate_in

    No description

    :trait type: SeparateUnicode
    :default: ``'\\n'``

.. configtrait:: TerminalInteractiveShell.separate_out

    No description

    :trait type: SeparateUnicode

.. configtrait:: TerminalInteractiveShell.separate_out2

    No description

    :trait type: SeparateUnicode

.. configtrait:: TerminalInteractiveShell.show_rewritten_input

    Show rewritten input, e.g. for autocall.

    :trait type: Bool
    :default: ``True``

.. configtrait:: TerminalInteractiveShell.simple_prompt

    Use `raw_input` for the REPL, without completion and prompt colors.

    Useful when controlling IPython as a subprocess, and piping STDIN/OUT/ERR. Known usage are:
    IPython own testing machinery, and emacs inferior-shell integration through elpy.

    This mode default to `True` if the `IPY_TEST_SIMPLE_PROMPT`
    environment variable is set, or the current terminal is not a tty.

    :trait type: Bool
    :default: ``False``
    :CLI option: ``--simple-prompt``

.. configtrait:: TerminalInteractiveShell.space_for_menu

    Number of line at the bottom of the screen to reserve for the tab completion menu, search history, ...etc, the height of these menus will at most this value. Increase it is you prefer long and skinny menus, decrease for short and wide.

    :trait type: Int
    :default: ``6``

.. configtrait:: TerminalInteractiveShell.sphinxify_docstring

    Enables rich html representation of docstrings. (This requires the
    docrepr module).

    :trait type: Bool
    :default: ``False``

.. configtrait:: TerminalInteractiveShell.term_title

    Automatically set the terminal title

    :trait type: Bool
    :default: ``True``
    :CLI option: ``--term-title``

.. configtrait:: TerminalInteractiveShell.term_title_format

    Customize the terminal title format.  This is a python format string. Available substitutions are: {cwd}.

    :trait type: Unicode
    :default: ``'IPython: {cwd}'``

.. configtrait:: TerminalInteractiveShell.true_color

    Use 24bit colors instead of 256 colors in prompt highlighting. If your terminal supports true color, the following command should print 'TRUECOLOR' in orange: printf "\x1b[38;2;255;100;0mTRUECOLOR\x1b[0m\n"

    :trait type: Bool
    :default: ``False``

.. configtrait:: TerminalInteractiveShell.wildcards_case_sensitive

    No description

    :trait type: Bool
    :default: ``True``

.. configtrait:: TerminalInteractiveShell.xmode

    Switch modes for the IPython exception handlers.

    :options: ``'Context'``, ``'Plain'``, ``'Verbose'``, ``'Minimal'``
    :default: ``'Context'``


.. configtrait:: HistoryAccessor.connection_options

    Options for configuring the SQLite connection

    These options are passed as keyword args to sqlite3.connect
    when establishing database connections.

    :trait type: Dict

.. configtrait:: HistoryAccessor.enabled

    enable the SQLite history

    set enabled=False to disable the SQLite history,
    in which case there will be no stored history, no SQLite connection,
    and no background saving thread.  This may be necessary in some
    threaded environments where IPython is embedded.

    :trait type: Bool
    :default: ``True``

.. configtrait:: HistoryAccessor.hist_file

    Path to file to use for SQLite history database.

    By default, IPython will put the history database in the IPython
    profile directory.  If you would rather share one history among
    profiles, you can set this value in each, so that they are consistent.

    Due to an issue with fcntl, SQLite is known to misbehave on some NFS
    mounts.  If you see IPython hanging, try setting this to something on a
    local disk, e.g::

        ipython --HistoryManager.hist_file=/tmp/ipython_hist.sqlite

    you can also use the specific value `:memory:` (including the colon
    at both end but not the back ticks), to avoid creating an history file.

    :trait type: Unicode

.. configtrait:: HistoryManager.connection_options

    Options for configuring the SQLite connection

    These options are passed as keyword args to sqlite3.connect
    when establishing database connections.

    :trait type: Dict

.. configtrait:: HistoryManager.db_cache_size

    Write to database every x commands (higher values save disk access & power).
    Values of 1 or less effectively disable caching.

    :trait type: Int
    :default: ``0``

.. configtrait:: HistoryManager.db_log_output

    Should the history database include output? (default: no)

    :trait type: Bool
    :default: ``False``

.. configtrait:: HistoryManager.enabled

    enable the SQLite history

    set enabled=False to disable the SQLite history,
    in which case there will be no stored history, no SQLite connection,
    and no background saving thread.  This may be necessary in some
    threaded environments where IPython is embedded.

    :trait type: Bool
    :default: ``True``

.. configtrait:: HistoryManager.hist_file

    Path to file to use for SQLite history database.

    By default, IPython will put the history database in the IPython
    profile directory.  If you would rather share one history among
    profiles, you can set this value in each, so that they are consistent.

    Due to an issue with fcntl, SQLite is known to misbehave on some NFS
    mounts.  If you see IPython hanging, try setting this to something on a
    local disk, e.g::

        ipython --HistoryManager.hist_file=/tmp/ipython_hist.sqlite

    you can also use the specific value `:memory:` (including the colon
    at both end but not the back ticks), to avoid creating an history file.

    :trait type: Unicode

.. configtrait:: ProfileDir.location

    Set the profile location directly. This overrides the logic used by the
    `profile` option.

    :trait type: Unicode
    :CLI option: ``--profile-dir``

.. configtrait:: BaseFormatter.deferred_printers

    No description

    :trait type: Dict

.. configtrait:: BaseFormatter.enabled

    No description

    :trait type: Bool
    :default: ``True``

.. configtrait:: BaseFormatter.singleton_printers

    No description

    :trait type: Dict

.. configtrait:: BaseFormatter.type_printers

    No description

    :trait type: Dict

.. configtrait:: PlainTextFormatter.deferred_printers

    No description

    :trait type: Dict

.. configtrait:: PlainTextFormatter.float_precision

    No description

    :trait type: CUnicode

.. configtrait:: PlainTextFormatter.max_seq_length

    Truncate large collections (lists, dicts, tuples, sets) to this size.

    Set to 0 to disable truncation.

    :trait type: Int
    :default: ``1000``

.. configtrait:: PlainTextFormatter.max_width

    No description

    :trait type: Int
    :default: ``79``

.. configtrait:: PlainTextFormatter.newline

    No description

    :trait type: Unicode
    :default: ``'\\n'``

.. configtrait:: PlainTextFormatter.pprint

    No description

    :trait type: Bool
    :default: ``True``
    :CLI option: ``--pprint``

.. configtrait:: PlainTextFormatter.singleton_printers

    No description

    :trait type: Dict

.. configtrait:: PlainTextFormatter.type_printers

    No description

    :trait type: Dict

.. configtrait:: PlainTextFormatter.verbose

    No description

    :trait type: Bool
    :default: ``False``

.. configtrait:: Completer.backslash_combining_completions

    Enable unicode completions, e.g. \alpha<tab> . Includes completion of latex commands, unicode names, and expanding unicode characters back to latex commands.

    :trait type: Bool
    :default: ``True``

.. configtrait:: Completer.debug

    Enable debug for the Completer. Mostly print extra information for experimental jedi integration.

    :trait type: Bool
    :default: ``False``

.. configtrait:: Completer.greedy

    Activate greedy completion
    PENDING DEPRECTION. this is now mostly taken care of with Jedi.

    This will enable completion on elements of lists, results of function calls, etc.,
    but can be unsafe because the code is actually evaluated on TAB.

    :trait type: Bool
    :default: ``False``

.. configtrait:: Completer.jedi_compute_type_timeout

    Experimental: restrict time (in milliseconds) during which Jedi can compute types.
    Set to 0 to stop computing types. Non-zero value lower than 100ms may hurt
    performance by preventing jedi to build its cache.

    :trait type: Int
    :default: ``400``

.. configtrait:: Completer.use_jedi

    Experimental: Use Jedi to generate autocompletions. Default to True if jedi is installed.

    :trait type: Bool
    :default: ``True``

.. configtrait:: IPCompleter.backslash_combining_completions

    Enable unicode completions, e.g. \alpha<tab> . Includes completion of latex commands, unicode names, and expanding unicode characters back to latex commands.

    :trait type: Bool
    :default: ``True``

.. configtrait:: IPCompleter.debug

    Enable debug for the Completer. Mostly print extra information for experimental jedi integration.

    :trait type: Bool
    :default: ``False``

.. configtrait:: IPCompleter.greedy

    Activate greedy completion
    PENDING DEPRECTION. this is now mostly taken care of with Jedi.

    This will enable completion on elements of lists, results of function calls, etc.,
    but can be unsafe because the code is actually evaluated on TAB.

    :trait type: Bool
    :default: ``False``

.. configtrait:: IPCompleter.jedi_compute_type_timeout

    Experimental: restrict time (in milliseconds) during which Jedi can compute types.
    Set to 0 to stop computing types. Non-zero value lower than 100ms may hurt
    performance by preventing jedi to build its cache.

    :trait type: Int
    :default: ``400``

.. configtrait:: IPCompleter.limit_to__all__

    DEPRECATED as of version 5.0.

    Instruct the completer to use __all__ for the completion

    Specifically, when completing on ``object.<tab>``.

    When True: only those names in obj.__all__ will be included.

    When False [default]: the __all__ attribute is ignored

    :trait type: Bool
    :default: ``False``

.. configtrait:: IPCompleter.merge_completions

    Whether to merge completion results into a single list

    If False, only the completion results from the first non-empty
    completer will be returned.

    :trait type: Bool
    :default: ``True``

.. configtrait:: IPCompleter.omit__names

    Instruct the completer to omit private method names

    Specifically, when completing on ``object.<tab>``.

    When 2 [default]: all names that start with '_' will be excluded.

    When 1: all 'magic' names (``__foo__``) will be excluded.

    When 0: nothing will be excluded.

    :options: ``0``, ``1``, ``2``
    :default: ``2``

.. configtrait:: IPCompleter.use_jedi

    Experimental: Use Jedi to generate autocompletions. Default to True if jedi is installed.

    :trait type: Bool
    :default: ``True``


.. configtrait:: ScriptMagics.script_magics

    Extra script cell magics to define

    This generates simple wrappers of `%%script foo` as `%%foo`.

    If you want to add script magics that aren't on your path,
    specify them in script_paths

    :trait type: List

.. configtrait:: ScriptMagics.script_paths

    Dict mapping short 'ruby' names to full paths, such as '/opt/secret/bin/ruby'

    Only necessary for items in script_magics where the default path will not
    find the right interpreter.

    :trait type: Dict

.. configtrait:: LoggingMagics.quiet

    Suppress output of log state when logging is enabled

    :trait type: Bool
    :default: ``False``

.. configtrait:: StoreMagics.autorestore

    If True, any %store-d variables will be automatically restored
    when IPython starts.

    :trait type: Bool
    :default: ``False``

