class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const updateReleasesUrl = String.fromEnvironment(
    'UPDATE_RELEASES_URL',
    defaultValue: 'https://api.github.com/repos/IanMuh/TimeTrack/releases',
  );

  static bool get hasSupabase =>
      supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;

  static Uri get updateReleasesUri {
    final uri = Uri.parse(updateReleasesUrl);
    if (uri.scheme.toLowerCase() != 'https' || uri.host.isEmpty) {
      throw const FormatException(
        'UPDATE_RELEASES_URL must be an HTTPS URL.',
        updateReleasesUrl,
      );
    }
    return uri;
  }
}
