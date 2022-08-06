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
  return out.where((e) => e.isNotEmpty).toList();
}
