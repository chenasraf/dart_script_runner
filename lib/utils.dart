/// Attempt to split arguments while taking into account quotes
// @internal
List<String> splitArgs(String string) {
  final out = <String>[];
  var cur = '';
  var inQuoteStr = '';
  // print('starting from: $string');
  for (var i = 0; i < string.length; i++) {
    final inQuoteCtx = inQuoteStr.isNotEmpty;
    final char = string[i];
    final curCharIsQuote = char == '"' || char == "'";
    if (!inQuoteCtx && curCharIsQuote && i < string.length - 1) {
      // print('starting quote, taking ${char + string[i + 1]}');
      // starting a quote
      // cur += string[i + 1];
      inQuoteStr = char;
      continue;
    }
    if (inQuoteCtx) {
      // terminating a quote
      if (curCharIsQuote) {
        // print('terminating quote');
        inQuoteStr = '';
        out.add(cur);
        cur = '';
        continue;
      }
    }
    if (char == ' ' && !inQuoteCtx) {
      // print('space');
      out.add(cur);
      cur = '';
      continue;
    }
    // print('taking character $char');
    cur += char;
    // print('cur: $cur, out: $out');
  }
  if (cur.isNotEmpty) {
    out.add(cur);
  }
  return out.where((e) => e.isNotEmpty).toList();
}

String stripColor(String str) {
  return str.replaceAll(RegExp(r'\x1B\[\d+m'), '');
}

T noop<T>(T arg) => arg;

/// Split string into chunks of [maxLen] characters.
// @internal
List<String> chunks(
  String str,
  int maxLen, {
  bool stripColors = false,
  String Function(String) wrapLine = noop,
}) {
  final words = str.split(' ');
  final chunks = <String>[];
  var chunk = '';
  for (final word in words) {
    // if (chunk.contains('\n')) {
    //   final lines = chunk.split('\n');
    //   for (var i = 0; i < lines.length - 1; i++) {
    //     chunks.add(wrapLine(lines[i]));
    //   }
    //   chunk = '';
    // }
    final chunkLength = stripColors ? stripColor(chunk).length : chunk.length;
    final wordLength = stripColors ? stripColor(word).length : word.length;
    if (chunkLength + wordLength > maxLen) {
      chunks.add(wrapLine(chunk));
      chunk = '';
    }
    chunk += '$word ';
  }
  chunks.add(wrapLine(chunk));
  return chunks;
}

/// wrap args with quotes if necessary
// @internal
String quoteWrap(String arg) {
  if (arg.contains(' ')) {
    return '"$arg"';
  }
  return arg;
}

/// Tries a list of nullable [T]s until one is not null.
/// Returns null if no actual value is found.
T? firstNonNull<T>(Iterable<T?> list) {
  for (final item in list) {
    if (item != null) {
      return item;
    }
  }
  return null;
}

String colorize(String text, [Iterable<TerminalColor> colors = const []]) {
  for (final color in colors) {
    text = '\x1B[${color.index}m$text';
  }
  return '$text\x1B[0m';
}

void printColor(String text, [Iterable<TerminalColor> colors = const []]) {
  print(colorize(text, colors));
}

class TerminalColor {
  const TerminalColor._(this.index);
  final int index;

  static const TerminalColor none = TerminalColor._(-1);
  static const TerminalColor red = TerminalColor._(31);
  static const TerminalColor green = TerminalColor._(32);
  static const TerminalColor yellow = TerminalColor._(33);
  static const TerminalColor blue = TerminalColor._(34);
  static const TerminalColor magenta = TerminalColor._(35);
  static const TerminalColor cyan = TerminalColor._(36);
  static const TerminalColor white = TerminalColor._(37);
  static const TerminalColor gray = TerminalColor._(90);
  static const TerminalColor brightRed = TerminalColor._(91);
  static const TerminalColor brightGreen = TerminalColor._(92);
  static const TerminalColor brightYellow = TerminalColor._(93);
  static const TerminalColor brightBlue = TerminalColor._(94);
  static const TerminalColor brightMagenta = TerminalColor._(95);
  static const TerminalColor brightCyan = TerminalColor._(96);
  static const TerminalColor brightWhite = TerminalColor._(97);

  static const TerminalColor bold = TerminalColor._(1);
  static const TerminalColor underline = TerminalColor._(4);
}

class ScriptStateError extends StateError {
  ScriptStateError(super.message);

  @override
  String toString() => message;
}
