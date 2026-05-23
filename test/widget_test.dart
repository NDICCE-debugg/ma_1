import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:ma_1/main.dart';
import 'package:ma_1/providers/theme_provider.dart';
import 'package:ma_1/utils/supabase_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows the BioMed Assistant login screen',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
    Supabase.instance.client.auth.stopAutoRefresh();

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ThemeProvider(),
        child: const MyApp(hasSession: false),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('BioMed Assistant'), findsOneWidget);
    expect(find.text('Clinical Fleet Maintenance System'), findsOneWidget);
    expect(find.byIcon(Icons.health_and_safety), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
