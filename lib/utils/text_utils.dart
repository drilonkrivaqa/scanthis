bool looksLikeUrl(String value) {
  final v = value.trim();
  if (v.isEmpty) return false;

  final uri = Uri.tryParse(v);
  if (uri == null) return false;

  // Accept https/http or bare domains like example.com
  if (uri.hasScheme && (uri.scheme == 'https' || uri.scheme == 'http')) {
    return true;
  }

  // no scheme but has a dot and no spaces
  if (!v.contains(' ') && v.contains('.') && !v.startsWith('tel:')) {
    return true;
  }

  return false;
}

Uri toLaunchableUri(String value) {
  final v = value.trim();
  final uri = Uri.tryParse(v);
  if (uri == null) return Uri.parse('https://$v');

  if (uri.hasScheme) return uri;

  // if no scheme, assume https
  return Uri.parse('https://$v');
}

String ellipsizeMiddle(String text, {int max = 52}) {
  final t = text.trim();
  if (t.length <= max) return t;
  final keep = (max - 3) ~/ 2;
  return '${t.substring(0, keep)}...${t.substring(t.length - keep)}';
}
