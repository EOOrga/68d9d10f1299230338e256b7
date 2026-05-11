import 'package:emera_val_fleury/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('navigates across the operations workspace', (tester) async {
    await tester.pumpWidget(const EmeraApp(forceScreenshotMode: true));
    await tester.pumpAndSettle();

    expect(find.text('Daily command center'), findsOneWidget);

    await tester.tap(find.text('Bookings'));
    await tester.pumpAndSettle();
    expect(find.text('Appointment booking'), findsOneWidget);

    await tester.tap(find.text('Visitors'));
    await tester.pumpAndSettle();
    expect(find.text('Visitor management'), findsOneWidget);

    await tester.tap(find.text('Analytics'));
    await tester.pumpAndSettle();
    expect(find.text('Revenue analytics'), findsOneWidget);

    await tester.tap(find.text('Tasks'));
    await tester.pumpAndSettle();
    expect(find.text('Task management'), findsOneWidget);
  });

  test('creates an appointment in the local operations store', () async {
    final store = OperationsStore(screenshotMode: true);
    await store.load();

    await store.addAppointment(
      const Appointment(
        id: 'apt-test',
        guest: 'Alex Morgan',
        company: 'Partner team',
        purpose: 'Planning',
        service: 'Appointment booking',
        date: '2026-05-11',
        time: '09:00',
        amount: 450,
        status: AppointmentStatus.pending,
        notes: 'Prepare front desk packet.',
      ),
    );

    expect(store.appointments.first.guest, 'Alex Morgan');
    expect(store.revenue.first.amount, 450);
  });
}
