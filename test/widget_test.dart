import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:siband/main.dart';
import 'package:siband/screens/main_navigation_screen.dart';
import 'package:siband/screens/onboarding_screen.dart';
import 'package:siband/services/auth_service.dart';
import 'package:siband/services/heart_rate_service.dart';

void main() {
  tearDown(() {
    HeartRateService.instance.stop();
  });
  testWidgets('Startup tanpa token menampilkan OnboardingScreen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.byType(MainNavigationScreen), findsNothing);
  });

  testWidgets('Startup dengan token menampilkan MainNavigationScreen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      AuthService.tokenKey: 'valid_mock_token',
    });

    await tester.pumpWidget(const MyApp());
    // Pump frames until FutureBuilder completes
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(MainNavigationScreen), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);
  });
}
