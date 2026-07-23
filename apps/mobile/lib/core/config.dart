/// PAWD Supabase configuration.
///
/// The anon key is a PUBLIC client key by design — it is safe to ship in the
/// app binary. All data access is protected by Row Level Security on the server.
/// Override at build time with:
///   flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
class Config {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://vaeiskltcpzthaffyejg.supabase.co',
  );

  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZhZWlza2x0Y3B6dGhhZmZ5ZWpnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ3NDY0NTcsImV4cCI6MjEwMDMyMjQ1N30.Pf9ErK05eZNLrbGkRPvmj118kFUMGhCQn106NcQCNyc',
  );

  static const petPhotosBucket = 'pet-photos';
  static const chatImagesBucket = 'chat-images';

  static String publicUrl(String bucket, String path) =>
      '$supabaseUrl/storage/v1/object/public/$bucket/$path';
}
