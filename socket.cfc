component {

    // DI
    property name="CommandCompletor" inject="CommandCompletor";
    property name="CommandParser" inject="CommandParser";
    property name="CommandHighlighter" inject="CommandHighlighter";
    property name="SignalHandler" inject="SignalHandler";
    property name="homedir" inject="homedir@constants";
    property name="commandHistoryFile" inject="commandHistoryFile@constants";
    property name="REPLScriptHistoryFile" inject="REPLScriptHistoryFile@constants";
    property name="REPLTagHistoryFile" inject="REPLTagHistoryFile@constants";
    property name="systemSettings" inject="SystemSettings";
    property name="configService" inject="ConfigService";

    function run() {
        try {
            var serverSocket = createObject('java', 'java.net.ServerSocket').init(12345);
            systemOutput('Server started.', 1);

            try {
                close = false;
                systemOutput('Waiting for a connection...', 1);
                clientSocket = serverSocket.accept();

                systemOutput('Client connected.', 1);
                var input = clientSocket.getInputStream();
                var output = clientSocket.getOutputStream();

                var reader = getTerminalInstance(input, output);

                while (!close) {
                    var command_arg = reader.readLine('commandbox-proxy> ');
                    systemOutput('Command received: ' & command_arg, 1);

                    switch (command_arg) {
                        case 'close':
                            response = 'Goodbye!';
                            close = true;
                            break;
                        default:
                            try {
                                response = command(command_arg).run(returnOutput = true);
                            } catch (any e) {
                                response = 'Error: ' & e.message;
                            }
                    }

                    reader
                        .getTerminal()
                        .writer()
                        .print(response);
                    reader
                        .getTerminal()
                        .writer()
                        .flush();
                }
            } catch (org.jline.reader.UserInterruptException e) {
                systemOutput('Client disconnected.', 1);
                break;
            } catch (java.net.SocketException e) {
                systemOutput('Client disconnected.', 1);
                break;
            } catch (org.jline.reader.EndOfFileException e) {
                systemOutput('Client disconnected.', 1);
                break;
            } finally {
                if (local.keyExists('input')) input.close();
                if (local.keyExists('output')) output.close();
                if (local.keyExists('clientSocket')) clientSocket.close();
            }
        } finally {
            if (local.keyExists('serverSocket')) serverSocket.close();
        }
    }

    /**
     * Build a jline console reader instance
     * @inStream.hint input stream if running externally
     * @outputStream.hint output stream if running externally
     */
    function getTerminalInstance(inStream, outputStream) {
        var reader = '';


        // Work around for lockdown STIGs on govt machines.
        // By default JANSI tries to write files into a locked down folder under appData
        var JANSI_path = expandPath('/commandbox-home/lib/jansi');
        if (!directoryExists(JANSI_path)) {
            directoryCreate(JANSI_path);
        }
        // The JANSI lib will pick this up and use it
        systemSettings.setSystemProperty('library.jansi.path', JANSI_path);
        // https://github.com/fusesource/jansi/blob/2cf446182c823a4c110411b765a1f0367eb8a913/src/main/java/org/fusesource/jansi/internal/JansiLoader.java#L80
        systemSettings.setSystemProperty('jansi.tmpdir', JANSI_path);
        // And JNA will pick this up.
        // https://java-native-access.github.io/jna/4.2.1/com/sun/jna/Native.html#getTempDir--
        systemSettings.setSystemProperty('jna.tmpdir', JANSI_path);

        if (configService.getSetting('colorInDumbTerminal', false)) {
            systemSettings.setSystemProperty('org.jline.terminal.dumb.color', 'true');
        }

        // Creating static references to these so we can get at nested classes and their properties
        var LineReaderClass = createObject('java', 'org.jline.reader.LineReader');
        var LineReaderOptionClass = createObject('java', 'org.jline.reader.LineReader$Option');

        // CFC instances that implements a JLine Java interfaces
        var jCompletor = createDynamicProxy(CommandCompletor, ['org.jline.reader.Completer']);
        var jParser = createDynamicProxy(CommandParser, ['org.jline.reader.Parser']);
        var jHighlighter = createDynamicProxy(CommandHighlighter, ['org.jline.reader.Highlighter']);
        var jSignalHandler = createDynamicProxy(SignalHandler, ['org.jline.terminal.Terminal$SignalHandler']);

        // Build our terminal instance
        var terminal = createObject('java', 'org.jline.terminal.impl.DumbTerminal').init(inStream, outputStream);

        systemOutput(terminal.getClass().getName(), 1);

        var shellVariables = {
            // The default file for history is set into the shell here though it's used by the DefaultHistory class
            '#LineReaderClass.HISTORY_FILE#': commandHistoryFile,
            '#LineReaderClass.BLINK_MATCHING_PAREN#': 0
        };

        if (configService.getSetting('tabCompleteInline', false)) {
            shellVariables.append({
                // These color tweaks are to improve the default ugly "pink" color in the optional AUTO_MENU_LIST setting (activated below)
                '#LineReaderClass.COMPLETION_STYLE_LIST_BACKGROUND#': 'bg:~grey',
                '#LineReaderClass.COMPLETION_STYLE_LIST_DESCRIPTION#': 'fg:blue,bg:~grey',
                '#LineReaderClass.COMPLETION_STYLE_LIST_STARTING#': 'inverse,bg:~grey'
            });
        }

        // Build our reader instance
        reader = createObject('java', 'org.jline.reader.LineReaderBuilder')
            .builder()
            .terminal(terminal)
            .variables(shellVariables)
            .completer(jCompletor)
            .parser(jParser)
            .highlighter(jHighlighter)
            .build();

        // This lets you hit tab with nothing entered on the prompt and get auto-complete
        reader.unsetOpt(LineReaderOptionClass.INSERT_TAB);
        // This turns off annoying Vim stuff built into JLine
        reader.setOpt(LineReaderOptionClass.DISABLE_EVENT_EXPANSION);
        // Makes auto complete case insensitive
        reader.setOpt(LineReaderOptionClass.CASE_INSENSITIVE);
        // Makes i-search case insensitive (Ctrl-R and Ctrl-S)
        reader.setOpt(LineReaderOptionClass.CASE_INSENSITIVE_SEARCH);
        // Use groups in tab completion
        reader.setOpt(LineReaderOptionClass.GROUP_PERSIST);
        // Activate inline list tab completion
        if (configService.getSetting('tabCompleteInline', false)) {
            reader.setOpt(LineReaderOptionClass.AUTO_MENU_LIST);
        }


        return reader;
    }

}
