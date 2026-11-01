import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:siband/main.dart';
import 'package:siband/screens/bpm_dashboard_screen.dart';
import 'package:siband/screens/onboarding_screen.dart';
import 'package:siband/services/auth_service.dart';

void main() {
  testWidgets('Startup tanpa token menampilkan OnboardingScreen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.byType(BpmDashboardScreen), findsNothing);
  });

  testWidgets('Startup dengan token menampilkan BpmDashboardScreen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      AuthService.tokenKey: 'valid_mock_token',
    });

    await tester.pumpWidget(const MyApp());
    // Pump frames until FutureBuilder completes
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(BpmDashboardScreen), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);
  });
}
