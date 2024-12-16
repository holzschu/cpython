IPython kernel options
======================

These options can be used in :file:`ipython_kernel_config.py`. The kernel also respects any options in `ipython_config.py`



.. configtrait:: ConnectionFileMixin.connection_file

    JSON file in which to store connection info [default: kernel-<pid>.json]

    This file will contain the IP, ports, and authentication key needed to connect
    clients to this kernel. By default, this file will be created in the security dir
    of the current profile, but can be specified by absolute path.

    :trait type: Unicode

.. configtrait:: ConnectionFileMixin.control_port

    set the control (ROUTER) port [default: random]

    :trait type: Int
    :default: ``0``

.. configtrait:: ConnectionFileMixin.hb_port

    set the heartbeat port [default: random]

    :trait type: Int
    :default: ``0``

.. configtrait:: ConnectionFileMixin.iopub_port

    set the iopub (PUB) port [default: random]

    :trait type: Int
    :default: ``0``

.. configtrait:: ConnectionFileMixin.ip

    Set the kernel's IP address [default localhost].
    If the IP address is something other than localhost, then
    Consoles on other machines will be able to connect
    to the Kernel, so be careful!

    :trait type: Unicode

.. configtrait:: ConnectionFileMixin.shell_port

    set the shell (ROUTER) port [default: random]

    :trait type: Int
    :default: ``0``

.. configtrait:: ConnectionFileMixin.stdin_port

    set the stdin (ROUTER) port [default: random]

    :trait type: Int
    :default: ``0``

.. configtrait:: ConnectionFileMixin.transport

    No description

    :options: ``'tcp'``, ``'ipc'``
    :default: ``'tcp'``

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

.. configtrait:: IPKernelApp.auto_create

    Whether to create profile dir if it doesn't exist

    :trait type: Bool
    :default: ``False``

.. configtrait:: IPKernelApp.code_to_run

    Execute the given command string.

    :trait type: Unicode

.. configtrait:: IPKernelApp.connection_file

    JSON file in which to store connection info [default: kernel-<pid>.json]

    This file will contain the IP, ports, and authentication key needed to connect
    clients to this kernel. By default, this file will be created in the security dir
    of the current profile, but can be specified by absolute path.

    :trait type: Unicode
    :CLI option: ``-f``

.. configtrait:: IPKernelApp.control_port

    set the control (ROUTER) port [default: random]

    :trait type: Int
    :default: ``0``
    :CLI option: ``--control``

.. configtrait:: IPKernelApp.copy_config_files

    Whether to install the default config files into the profile dir.
    If a new profile is being created, and IPython contains config files for that
    profile, then they will be staged into the new directory.  Otherwise,
    default config files will be automatically generated.

    :trait type: Bool
    :default: ``False``

.. configtrait:: IPKernelApp.displayhook_class

    The importstring for the DisplayHook factory

    :trait type: DottedObjectName
    :default: ``'ipykernel.displayhook.ZMQDisplayHook'``

.. configtrait:: IPKernelApp.exec_PYTHONSTARTUP

    Run the file referenced by the PYTHONSTARTUP environment
    variable at IPython startup.

    :trait type: Bool
    :default: ``True``

.. configtrait:: IPKernelApp.exec_files

    List of files to run at IPython startup.

    :trait type: List

.. configtrait:: IPKernelApp.exec_lines

    lines of code to run at IPython startup.

    :trait type: List

.. configtrait:: IPKernelApp.extensions

    A list of dotted module names of IPython extensions to load.

    :trait type: List

.. configtrait:: IPKernelApp.extra_config_file

    Path to an extra config file to load.

    If specified, load this config file in addition to any other IPython config.

    :trait type: Unicode

.. configtrait:: IPKernelApp.extra_extension

    DEPRECATED. Dotted module name of a single extra IPython extension to load.

    Only one extension can be added this way.

    Only used with traitlets < 5.0, plural extra_extensions list is used in traitlets 5.

    :trait type: Unicode

.. configtrait:: IPKernelApp.extra_extensions

    Dotted module name(s) of one or more IPython extensions to load.

    For specifying extra extensions to load on the command-line.

    .. versionadded:: 7.10

    :trait type: List

.. configtrait:: IPKernelApp.file_to_run

    A file to be run

    :trait type: Unicode

.. configtrait:: IPKernelApp.gui

    Enable GUI event loop integration with any of ('asyncio', 'glut', 'gtk', 'gtk2', 'gtk3', 'osx', 'pyglet', 'qt', 'qt4', 'qt5', 'tk', 'wx', 'gtk2', 'qt4').

    :options: ``'asyncio'``, ``'glut'``, ``'gtk'``, ``'gtk2'``, ``'gtk3'``, ``'osx'``, ``'pyglet'``, ``'qt'``, ``'qt4'``, ``'qt5'``, ``'tk'``, ``'wx'``, ``'gtk2'``, ``'qt4'``

.. configtrait:: IPKernelApp.hb_port

    set the heartbeat port [default: random]

    :trait type: Int
    :default: ``0``
    :CLI option: ``--hb``

.. configtrait:: IPKernelApp.hide_initial_ns

    Should variables loaded at startup (by startup files, exec_lines, etc.)
    be hidden from tools like %who?

    :trait type: Bool
    :default: ``True``

.. configtrait:: IPKernelApp.ignore_cwd

    If True, IPython will not add the current working directory to sys.path.
    When False, the current working directory is added to sys.path, allowing imports
    of modules defined in the current directory.

    :trait type: Bool
    :default: ``False``

.. configtrait:: IPKernelApp.interrupt

    ONLY USED ON WINDOWS
    Interrupt this process when the parent is signaled.

    :trait type: Int
    :default: ``0``

.. configtrait:: IPKernelApp.iopub_port

    set the iopub (PUB) port [default: random]

    :trait type: Int
    :default: ``0``
    :CLI option: ``--iopub``

.. configtrait:: IPKernelApp.ip

    Set the kernel's IP address [default localhost].
    If the IP address is something other than localhost, then
    Consoles on other machines will be able to connect
    to the Kernel, so be careful!

    :trait type: Unicode
    :CLI option: ``--ip``

.. configtrait:: IPKernelApp.ipython_dir

    The name of the IPython directory. This directory is used for logging
    configuration (through profiles), history storage, etc. The default
    is usually $HOME/.ipython. This option can also be specified through
    the environment variable IPYTHONDIR.

    :trait type: Unicode

.. configtrait:: IPKernelApp.kernel_class

    The Kernel subclass to be used.

    This should allow easy re-use of the IPKernelApp entry point
    to configure and launch kernels other than IPython's own.

    :trait type: Type
    :default: ``'ipykernel.ipkernel.IPythonKernel'``

.. configtrait:: IPKernelApp.log_datefmt

    The date format used by logging formatters for %(asctime)s

    :trait type: Unicode
    :default: ``'%Y-%m-%d %H:%M:%S'``

.. configtrait:: IPKernelApp.log_format

    The Logging format template

    :trait type: Unicode
    :default: ``'[%(name)s]%(highlevel)s %(message)s'``

.. configtrait:: IPKernelApp.log_level

    Set the log level by value or name.

    :options: ``0``, ``10``, ``20``, ``30``, ``40``, ``50``, ``'DEBUG'``, ``'INFO'``, ``'WARN'``, ``'ERROR'``, ``'CRITICAL'``
    :default: ``30``

.. configtrait:: IPKernelApp.matplotlib

    Configure matplotlib for interactive use with
    the default matplotlib backend.

    :options: ``'auto'``, ``'agg'``, ``'gtk'``, ``'gtk3'``, ``'inline'``, ``'ipympl'``, ``'nbagg'``, ``'notebook'``, ``'osx'``, ``'pdf'``, ``'ps'``, ``'qt'``, ``'qt4'``, ``'qt5'``, ``'svg'``, ``'tk'``, ``'widget'``, ``'wx'``

.. configtrait:: IPKernelApp.module_to_run

    Run the module as a script.

    :trait type: Unicode

.. configtrait:: IPKernelApp.no_stderr

    redirect stderr to the null device

    :trait type: Bool
    :default: ``False``
    :CLI option: ``--no-stderr``

.. configtrait:: IPKernelApp.no_stdout

    redirect stdout to the null device

    :trait type: Bool
    :default: ``False``
    :CLI option: ``--no-stdout``

.. configtrait:: IPKernelApp.outstream_class

    The importstring for the OutStream factory

    :trait type: DottedObjectName
    :default: ``'ipykernel.iostream.OutStream'``

.. configtrait:: IPKernelApp.overwrite

    Whether to overwrite existing config files when copying

    :trait type: Bool
    :default: ``False``

.. configtrait:: IPKernelApp.parent_handle

    kill this process if its parent dies.  On Windows, the argument
    specifies the HANDLE of the parent process, otherwise it is simply boolean.

    :trait type: Int
    :default: ``0``

.. configtrait:: IPKernelApp.profile

    The IPython profile to use.

    :trait type: Unicode
    :default: ``'default'``

.. configtrait:: IPKernelApp.pylab

    Pre-load matplotlib and numpy for interactive use,
    selecting a particular matplotlib backend and loop integration.

    :options: ``'auto'``, ``'agg'``, ``'gtk'``, ``'gtk3'``, ``'inline'``, ``'ipympl'``, ``'nbagg'``, ``'notebook'``, ``'osx'``, ``'pdf'``, ``'ps'``, ``'qt'``, ``'qt4'``, ``'qt5'``, ``'svg'``, ``'tk'``, ``'widget'``, ``'wx'``

.. configtrait:: IPKernelApp.pylab_import_all

    If true, IPython will populate the user namespace with numpy, pylab, etc.
    and an ``import *`` is done from numpy and pylab, when using pylab mode.

    When False, pylab mode should not import any names into the user namespace.

    :trait type: Bool
    :default: ``True``

.. configtrait:: IPKernelApp.quiet

    Only send stdout/stderr to output stream

    :trait type: Bool
    :default: ``True``

.. configtrait:: IPKernelApp.reraise_ipython_extension_failures

    Reraise exceptions encountered loading IPython extensions?

    :trait type: Bool
    :default: ``False``

.. configtrait:: IPKernelApp.shell_port

    set the shell (ROUTER) port [default: random]

    :trait type: Int
    :default: ``0``
    :CLI option: ``--shell``

.. configtrait:: IPKernelApp.show_config

    Instead of starting the Application, dump configuration to stdout

    :trait type: Bool
    :default: ``False``

.. configtrait:: IPKernelApp.show_config_json

    Instead of starting the Application, dump configuration to stdout (as JSON)

    :trait type: Bool
    :default: ``False``

.. configtrait:: IPKernelApp.stdin_port

    set the stdin (ROUTER) port [default: random]

    :trait type: Int
    :default: ``0``
    :CLI option: ``--stdin``

.. configtrait:: IPKernelApp.transport

    No description

    :options: ``'tcp'``, ``'ipc'``
    :default: ``'tcp'``
    :CLI option: ``--transport``

.. configtrait:: IPKernelApp.trio_loop

    Set main event loop.

    :trait type: Bool
    :default: ``False``

.. configtrait:: IPKernelApp.verbose_crash

    Create a massive crash report when IPython encounters what may be an
    internal error.  The default is to append a short message to the
    usual traceback

    :trait type: Bool
    :default: ``False``

.. configtrait:: Kernel._darwin_app_nap

    Whether to use appnope for compatibility with OS X App Nap.

    Only affects OS X >= 10.9.

    :trait type: Bool
    :default: ``True``

.. configtrait:: Kernel._execute_sleep

    No description

    :trait type: Float
    :default: ``0.0005``

.. configtrait:: Kernel._poll_interval

    No description

    :trait type: Float
    :default: ``0.01``

.. configtrait:: Kernel.stop_on_error_timeout

    time (in seconds) to wait for messages to arrive
    when aborting queued requests after an error.

    Requests that arrive within this window after an error
    will be cancelled.

    Increase in the event of unusually slow network
    causing significant delays,
    which can manifest as e.g. "Run all" in a notebook
    aborting some, but not all, messages after an error.

    :trait type: Float
    :default: ``0.1``

.. configtrait:: IPythonKernel._darwin_app_nap

    Whether to use appnope for compatibility with OS X App Nap.

    Only affects OS X >= 10.9.

    :trait type: Bool
    :default: ``True``

.. configtrait:: IPythonKernel._execute_sleep

    No description

    :trait type: Float
    :default: ``0.0005``

.. configtrait:: IPythonKernel._poll_interval

    No description

    :trait type: Float
    :default: ``0.01``

.. configtrait:: IPythonKernel.help_links

    No description

    :trait type: List

.. configtrait:: IPythonKernel.stop_on_error_timeout

    time (in seconds) to wait for messages to arrive
    when aborting queued requests after an error.

    Requests that arrive within this window after an error
    will be cancelled.

    Increase in the event of unusually slow network
    causing significant delays,
    which can manifest as e.g. "Run all" in a notebook
    aborting some, but not all, messages after an error.

    :trait type: Float
    :default: ``0.1``

.. configtrait:: IPythonKernel.use_experimental_completions

    Set this flag to False to deactivate the use of experimental IPython completion APIs.

    :trait type: Bool
    :default: ``True``

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

.. configtrait:: ZMQInteractiveShell.ast_node_interactivity

    'all', 'last', 'last_expr' or 'none', 'last_expr_or_assign' specifying
    which nodes should be run interactively (displaying output from expressions).

    :options: ``'all'``, ``'last'``, ``'last_expr'``, ``'none'``, ``'last_expr_or_assign'``
    :default: ``'last_expr'``

.. configtrait:: ZMQInteractiveShell.ast_transformers

    A list of ast.NodeTransformer subclass instances, which will be applied
    to user input before code is run.

    :trait type: List

.. configtrait:: ZMQInteractiveShell.autoawait

    Automatically run await statement in the top level repl.

    :trait type: Bool
    :default: ``True``

.. configtrait:: ZMQInteractiveShell.autocall

    Make IPython automatically call any callable object even if you didn't
    type explicit parentheses. For example, 'str 43' becomes 'str(43)'
    automatically. The value can be '0' to disable the feature, '1' for
    'smart' autocall, where it is not applied if there are no more
    arguments on the line, and '2' for 'full' autocall, where all callable
    objects are automatically called (even if no arguments are present).

    :options: ``0``, ``1``, ``2``
    :default: ``0``

.. configtrait:: ZMQInteractiveShell.automagic

    Enable magic commands to be called without the leading %.

    :trait type: Bool
    :default: ``True``

.. configtrait:: ZMQInteractiveShell.banner1

    The part of the banner to be printed before the profile

    :trait type: Unicode
    :default: ``"Python 3.8.5 | packaged by conda-forge | (default, Sep 16 20...``

.. configtrait:: ZMQInteractiveShell.banner2

    The part of the banner to be printed after the profile

    :trait type: Unicode

.. configtrait:: ZMQInteractiveShell.cache_size

    Set the size of the output cache.  The default is 1000, you can
    change it permanently in your config file.  Setting it to 0 completely
    disables the caching system, and the minimum value accepted is 3 (if
    you provide a value less than 3, it is reset to 0 and a warning is
    issued).  This limit is defined because otherwise you'll spend more
    time re-flushing a too small cache than working

    :trait type: Int
    :default: ``1000``

.. configtrait:: ZMQInteractiveShell.color_info

    Use colors for displaying information about objects. Because this
    information is passed through a pager (like 'less'), and some pagers
    get confused with color codes, this capability can be turned off.

    :trait type: Bool
    :default: ``True``

.. configtrait:: ZMQInteractiveShell.colors

    Set the color scheme (NoColor, Neutral, Linux, or LightBG).

    :options: ``'Neutral'``, ``'NoColor'``, ``'LightBG'``, ``'Linux'``
    :default: ``'Neutral'``

.. configtrait:: ZMQInteractiveShell.debug

    No description

    :trait type: Bool
    :default: ``False``

.. configtrait:: ZMQInteractiveShell.disable_failing_post_execute

    Don't call post-execute functions that have failed in the past.

    :trait type: Bool
    :default: ``False``

.. configtrait:: ZMQInteractiveShell.display_page

    If True, anything that would be passed to the pager
    will be displayed as regular output instead.

    :trait type: Bool
    :default: ``False``

.. configtrait:: ZMQInteractiveShell.enable_html_pager

    (Provisional API) enables html representation in mime bundles sent
    to pagers.

    :trait type: Bool
    :default: ``False``

.. configtrait:: ZMQInteractiveShell.history_length

    Total length of command history

    :trait type: Int
    :default: ``10000``

.. configtrait:: ZMQInteractiveShell.history_load_length

    The number of saved history entries to be loaded
    into the history buffer at startup.

    :trait type: Int
    :default: ``1000``

.. configtrait:: ZMQInteractiveShell.ipython_dir

    No description

    :trait type: Unicode

.. configtrait:: ZMQInteractiveShell.logappend

    Start logging to the given file in append mode.
    Use `logfile` to specify a log file to **overwrite** logs to.

    :trait type: Unicode

.. configtrait:: ZMQInteractiveShell.logfile

    The name of the logfile to use.

    :trait type: Unicode

.. configtrait:: ZMQInteractiveShell.logstart

    Start logging to the default log file in overwrite mode.
    Use `logappend` to specify a log file to **append** logs to.

    :trait type: Bool
    :default: ``False``

.. configtrait:: ZMQInteractiveShell.loop_runner

    Select the loop runner that will be used to execute top-level asynchronous code

    :trait type: Any
    :default: ``'IPython.core.interactiveshell._asyncio_runner'``

.. configtrait:: ZMQInteractiveShell.object_info_string_level

    No description

    :options: ``0``, ``1``, ``2``
    :default: ``0``

.. configtrait:: ZMQInteractiveShell.pdb

    Automatically call the pdb debugger after every exception.

    :trait type: Bool
    :default: ``False``

.. configtrait:: ZMQInteractiveShell.prompt_in1

    Deprecated since IPython 4.0 and ignored since 5.0, set TerminalInteractiveShell.prompts object directly.

    :trait type: Unicode
    :default: ``'In [\\#]: '``

.. configtrait:: ZMQInteractiveShell.prompt_in2

    Deprecated since IPython 4.0 and ignored since 5.0, set TerminalInteractiveShell.prompts object directly.

    :trait type: Unicode
    :default: ``'   .\\D.: '``

.. configtrait:: ZMQInteractiveShell.prompt_out

    Deprecated since IPython 4.0 and ignored since 5.0, set TerminalInteractiveShell.prompts object directly.

    :trait type: Unicode
    :default: ``'Out[\\#]: '``

.. configtrait:: ZMQInteractiveShell.prompts_pad_left

    Deprecated since IPython 4.0 and ignored since 5.0, set TerminalInteractiveShell.prompts object directly.

    :trait type: Bool
    :default: ``True``

.. configtrait:: ZMQInteractiveShell.quiet

    No description

    :trait type: Bool
    :default: ``False``

.. configtrait:: ZMQInteractiveShell.separate_in

    No description

    :trait type: SeparateUnicode
    :default: ``'\\n'``

.. configtrait:: ZMQInteractiveShell.separate_out

    No description

    :trait type: SeparateUnicode

.. configtrait:: ZMQInteractiveShell.separate_out2

    No description

    :trait type: SeparateUnicode

.. configtrait:: ZMQInteractiveShell.show_rewritten_input

    Show rewritten input, e.g. for autocall.

    :trait type: Bool
    :default: ``True``

.. configtrait:: ZMQInteractiveShell.sphinxify_docstring

    Enables rich html representation of docstrings. (This requires the
    docrepr module).

    :trait type: Bool
    :default: ``False``

.. configtrait:: ZMQInteractiveShell.wildcards_case_sensitive

    No description

    :trait type: Bool
    :default: ``True``

.. configtrait:: ZMQInteractiveShell.xmode

    Switch modes for the IPython exception handlers.

    :options: ``'Context'``, ``'Plain'``, ``'Verbose'``, ``'Minimal'``
    :default: ``'Context'``

.. configtrait:: ProfileDir.location

    Set the profile location directly. This overrides the logic used by the
    `profile` option.

    :trait type: Unicode
    :CLI option: ``--profile-dir``

.. configtrait:: Session.buffer_threshold

    Threshold (in bytes) beyond which an object's buffer should be extracted to avoid pickling.

    :trait type: Int
    :default: ``1024``

.. configtrait:: Session.check_pid

    Whether to check PID to protect against calls after fork.

    This check can be disabled if fork-safety is handled elsewhere.

    :trait type: Bool
    :default: ``True``

.. configtrait:: Session.copy_threshold

    Threshold (in bytes) beyond which a buffer should be sent without copying.

    :trait type: Int
    :default: ``65536``

.. configtrait:: Session.debug

    Debug output in the Session

    :trait type: Bool
    :default: ``False``

.. configtrait:: Session.digest_history_size

    The maximum number of digests to remember.

    The digest history will be culled when it exceeds this value.

    :trait type: Int
    :default: ``65536``

.. configtrait:: Session.item_threshold

    The maximum number of items for a container to be introspected for custom serialization.
    Containers larger than this are pickled outright.

    :trait type: Int
    :default: ``64``

.. configtrait:: Session.key

    execution key, for signing messages.

    :trait type: CBytes
    :default: ``b''``

.. configtrait:: Session.keyfile

    path to file containing execution key.

    :trait type: Unicode
    :CLI option: ``--keyfile``

.. configtrait:: Session.metadata

    Metadata dictionary, which serves as the default top-level metadata dict for each message.

    :trait type: Dict

.. configtrait:: Session.packer

    The name of the packer for serializing messages.
    Should be one of 'json', 'pickle', or an import name
    for a custom callable serializer.

    :trait type: DottedObjectName
    :default: ``'json'``

.. configtrait:: Session.session

    The UUID identifying this session.

    :trait type: CUnicode
    :CLI option: ``--ident``

.. configtrait:: Session.signature_scheme

    The digest scheme used to construct the message signatures.
    Must have the form 'hmac-HASH'.

    :trait type: Unicode
    :default: ``'hmac-sha256'``

.. configtrait:: Session.unpacker

    The name of the unpacker for unserializing messages.
    Only used with custom functions for `packer`.

    :trait type: DottedObjectName
    :default: ``'json'``

.. configtrait:: Session.username

    Username for the Session. Default is your system username.

    :trait type: Unicode
    :default: ``'bussonniermatthias'``
    :CLI option: ``--user``

