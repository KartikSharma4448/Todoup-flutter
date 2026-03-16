import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/app.dart';
import 'src/assistant_config.dart';
import 'src/supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    SupabaseConfig.validate();
    if (AssistantConfig.isEnabled) {
      AssistantConfig.validate();
    }
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
      authOptions: const FlutterAuthClientOptions(
        detectSessionInUri: true,
        autoRefreshToken: true,
      ),
    );
    runTodoUpApp();
  } catch (error, stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'main',
        context: ErrorDescription('while initializing Supabase'),
      ),
    );
    runTodoUpBootstrapErrorApp(error.toString());
  }
}
