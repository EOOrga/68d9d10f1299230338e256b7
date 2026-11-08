import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String appName = 'EMERA LE VAL FLEURY';
const String developerName = 'EMERA LE VAL FLEURY';
const String supportEmail = 'support@emeralevalfleury.com';
const bool screenshotMode = bool.fromEnvironment('SCREENSHOT_MODE');

const Color brandNavy = Color(0xFF00122C);
const Color brandBlue = Color(0xFF003060);
const Color brandGold = Color(0xFFD09020);
const Color brandIvory = Color(0xFFF6F1E8);
const Color brandTeal = Color(0xFF1D7A78);

void main() {
  runApp(const EmeraApp());
}

class EmeraApp extends StatelessWidget {
  const EmeraApp({super.key, this.forceScreenshotMode});

  final bool? forceScreenshotMode;

  @override
  Widget build(BuildContext context) {
    final mode = forceScreenshotMode ?? screenshotMode;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: appName,
      theme: _buildTheme(),
      home: OperationsLoader(screenshotMode: mode),
    );
  }
}

ThemeData _buildTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: brandGold,
        brightness: Brightness.light,
      ).copyWith(
        primary: brandNavy,
        onPrimary: Colors.white,
        secondary: brandGold,
        onSecondary: brandNavy,
        tertiary: brandTeal,
        surface: const Color(0xFFFFFCF7),
        surfaceContainerHighest: const Color(0xFFEDE6D8),
      );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFFFBF8F1),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFFBF8F1),
      foregroundColor: brandNavy,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: brandNavy.withValues(alpha: .08)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: brandNavy,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: brandNavy.withValues(alpha: .16)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: brandGold, width: 1.5),
      ),
    ),
  );
}

class OperationsLoader extends StatefulWidget {
  const OperationsLoader({required this.screenshotMode, super.key});

  final bool screenshotMode;

  @override
  State<OperationsLoader> createState() => _OperationsLoaderState();
}

class _OperationsLoaderState extends State<OperationsLoader> {
  late final OperationsStore store;
  bool ready = false;

  @override
  void initState() {
    super.initState();
    store = OperationsStore(screenshotMode: widget.screenshotMode);
    store.load().then((_) {
      if (mounted) {
        setState(() => ready = true);
      }
    });
  }

  @override
  void dispose() {
    store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return WorkspaceShell(store: store);
  }
}

class OperationsStore extends ChangeNotifier {
  OperationsStore({required this.screenshotMode});

  static const _appointmentsKey = 'appointments';
  static const _visitorsKey = 'visitors';
  static const _tasksKey = 'tasks';
  static const _revenueKey = 'revenue';
  static const _settingsKey = 'settings';

  final bool screenshotMode;
  List<Appointment> appointments = <Appointment>[];
  List<VisitorRecord> visitors = <VisitorRecord>[];
  List<WorkTask> tasks = <WorkTask>[];
  List<RevenueEntry> revenue = <RevenueEntry>[];
  OperationsSettings settings = const OperationsSettings(
    dailyTarget: 7200,
    siteArea: 'Accueil principal',
    manager: 'Equipe operations',
  );

  Future<void> load() async {
    if (screenshotMode) {
      _loadSampleData();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    appointments = _decodeList(
      prefs.getString(_appointmentsKey),
      Appointment.fromJson,
    );
    visitors = _decodeList(
      prefs.getString(_visitorsKey),
      VisitorRecord.fromJson,
    );
    tasks = _decodeList(prefs.getString(_tasksKey), WorkTask.fromJson);
    revenue = _decodeList(prefs.getString(_revenueKey), RevenueEntry.fromJson);

    final rawSettings = prefs.getString(_settingsKey);
    if (rawSettings != null) {
      settings = OperationsSettings.fromJson(
        jsonDecode(rawSettings) as Map<String, dynamic>,
      );
    }

    if (appointments.isEmpty && visitors.isEmpty && tasks.isEmpty) {
      _loadStarterData();
      await _persist();
    }
  }

  Future<void> addAppointment(Appointment appointment) async {
    appointments = <Appointment>[appointment, ...appointments];
    revenue = <RevenueEntry>[
      RevenueEntry(
        id: appointment.id,
        label: appointment.service,
        amount: appointment.amount,
        category: appointment.purpose,
        collected: appointment.status == AppointmentStatus.confirmed,
      ),
      ...revenue,
    ];
    notifyListeners();
    await _persist();
  }

  Future<void> setAppointmentStatus(String id, AppointmentStatus status) async {
    appointments = appointments
        .map((item) => item.id == id ? item.copyWith(status: status) : item)
        .toList();
    revenue = revenue
        .map(
          (item) => item.id == id
              ? item.copyWith(collected: status == AppointmentStatus.confirmed)
              : item,
        )
        .toList();
    notifyListeners();
    await _persist();
  }

  Future<void> addVisitor(VisitorRecord visitor) async {
    visitors = <VisitorRecord>[visitor, ...visitors];
    notifyListeners();
    await _persist();
  }

  Future<void> setVisitorStatus(String id, VisitorStatus status) async {
    visitors = visitors
        .map((item) => item.id == id ? item.copyWith(status: status) : item)
        .toList();
    notifyListeners();
    await _persist();
  }

  Future<void> addTask(WorkTask task) async {
    tasks = <WorkTask>[task, ...tasks];
    notifyListeners();
    await _persist();
  }

  Future<void> setTaskDone(String id, bool done) async {
    tasks = tasks
        .map((item) => item.id == id ? item.copyWith(done: done) : item)
        .toList();
    notifyListeners();
    await _persist();
  }

  Future<void> updateSettings(OperationsSettings value) async {
    settings = value;
    notifyListeners();
    await _persist();
  }

  int get openTasks => tasks.where((task) => !task.done).length;

  int get expectedVisitors => visitors
      .where((visitor) => visitor.status == VisitorStatus.expected)
      .length;

  double get bookedRevenue =>
      revenue.fold(0, (total, item) => total + item.amount);

  double get collectedRevenue => revenue
      .where((item) => item.collected)
      .fold(0, (total, item) => total + item.amount);

  double get completionRate {
    if (tasks.isEmpty) {
      return 0;
    }
    final done = tasks.where((task) => task.done).length;
    return done / tasks.length;
  }

  List<T> _decodeList<T>(
    String? raw,
    T Function(Map<String, dynamic>) decoder,
  ) {
    if (raw == null || raw.isEmpty) {
      return <T>[];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return <T>[];
    }
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(decoder)
        .toList(growable: false);
  }

  Future<void> _persist() async {
    if (screenshotMode) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _appointmentsKey,
      jsonEncode(appointments.map((item) => item.toJson()).toList()),
    );
    await prefs.setString(
      _visitorsKey,
      jsonEncode(visitors.map((item) => item.toJson()).toList()),
    );
    await prefs.setString(
      _tasksKey,
      jsonEncode(tasks.map((item) => item.toJson()).toList()),
    );
    await prefs.setString(
      _revenueKey,
      jsonEncode(revenue.map((item) => item.toJson()).toList()),
    );
    await prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
  }

  void _loadStarterData() {
    appointments = <Appointment>[
      Appointment(
        id: 'apt-starter',
        guest: 'Mme Moreau',
        company: 'Famille resident',
        purpose: 'Visite accueil',
        service: 'Rendez-vous famille',
        date: _dateFromOffset(0),
        time: '10:30',
        amount: 320,
        status: AppointmentStatus.pending,
        notes: 'Confirmer le salon disponible avant arrivee.',
      ),
    ];
    visitors = <VisitorRecord>[
      VisitorRecord(
        id: 'vis-starter',
        name: 'Paul Martin',
        company: 'Maintenance ascenseur',
        host: 'Reception',
        expectedAt: '14:00',
        badge: 'B-12',
        status: VisitorStatus.expected,
      ),
    ];
    tasks = <WorkTask>[
      WorkTask(
        id: 'task-starter',
        title: 'EMERA LE VAL FLEURY',
        owner: 'Administration',
        area: 'Bureau',
        due: 'Aujourd hui',
        done: false,
      ),
    ];
    revenue = <RevenueEntry>[
      const RevenueEntry(
        id: 'rev-starter',
        label: 'Services accueil',
        amount: 320,
        category: 'Rendez-vous famille',
        collected: false,
      ),
    ];
  }

  void _loadSampleData() {
    settings = const OperationsSettings(
      dailyTarget: 9200,
      siteArea: 'Accueil et residence',
      manager: 'Nadia Laurent',
    );
    appointments = <Appointment>[
      Appointment(
        id: 'apt-1',
        guest: 'Claire Benoit',
        company: 'Famille resident',
        purpose: 'Salon prive',
        service: 'Reservation famille',
        date: _sampleDateFromOffset(0),
        time: '09:30',
        amount: 850,
        status: AppointmentStatus.confirmed,
        notes: 'Salon prepare, accueil informe.',
      ),
      Appointment(
        id: 'apt-2',
        guest: 'Etienne Robert',
        company: 'Cabinet medical',
        purpose: 'Consultation',
        service: 'Visite professionnelle',
        date: _sampleDateFromOffset(0),
        time: '11:45',
        amount: 420,
        status: AppointmentStatus.pending,
        notes: 'Verifier piece identite a l arrivee.',
      ),
      Appointment(
        id: 'apt-3',
        guest: 'Sophie Lemaire',
        company: 'Partenaire restauration',
        purpose: 'Coordination',
        service: 'Reunion fournisseur',
        date: _sampleDateFromOffset(1),
        time: '15:00',
        amount: 620,
        status: AppointmentStatus.confirmed,
        notes: 'Dossier menu mensuel pret.',
      ),
    ];
    visitors = <VisitorRecord>[
      const VisitorRecord(
        id: 'vis-1',
        name: 'Marc Olivier',
        company: 'Transport medical',
        host: 'Accueil',
        expectedAt: '08:50',
        badge: 'A-04',
        status: VisitorStatus.checkedIn,
      ),
      const VisitorRecord(
        id: 'vis-2',
        name: 'Ines Garin',
        company: 'Famille Dupont',
        host: 'Unite Jasmin',
        expectedAt: '13:20',
        badge: 'A-08',
        status: VisitorStatus.expected,
      ),
      const VisitorRecord(
        id: 'vis-3',
        name: 'Yann Picard',
        company: 'Maintenance cuisine',
        host: 'Services generaux',
        expectedAt: '16:10',
        badge: 'B-03',
        status: VisitorStatus.checkedOut,
      ),
    ];
    tasks = <WorkTask>[
      const WorkTask(
        id: 'task-1',
        title: 'Cloturer le rapport caisse du matin',
        owner: 'Laura',
        area: 'Administration',
        due: '10:00',
        done: true,
      ),
      const WorkTask(
        id: 'task-2',
        title: 'Preparer les badges visiteurs',
        owner: 'Samir',
        area: 'Accueil',
        due: '12:00',
        done: false,
      ),
      const WorkTask(
        id: 'task-3',
        title: 'Suivre les prestations non reglees',
        owner: 'Nadia',
        area: 'Finance',
        due: '17:30',
        done: false,
      ),
      const WorkTask(
        id: 'task-4',
        title: 'Verifier le planning des salons',
        owner: 'Laura',
        area: 'Operations',
        due: '15:00',
        done: true,
      ),
    ];
    revenue = <RevenueEntry>[
      const RevenueEntry(
        id: 'apt-1',
        label: 'Reservation famille',
        amount: 850,
        category: 'Salon prive',
        collected: true,
      ),
      const RevenueEntry(
        id: 'apt-2',
        label: 'Visite professionnelle',
        amount: 420,
        category: 'Consultation',
        collected: false,
      ),
      const RevenueEntry(
        id: 'apt-3',
        label: 'Reunion fournisseur',
        amount: 620,
        category: 'Coordination',
        collected: true,
      ),
      const RevenueEntry(
        id: 'rev-4',
        label: 'Services restauration',
        amount: 1180,
        category: 'Prestation',
        collected: true,
      ),
      const RevenueEntry(
        id: 'rev-5',
        label: 'Location espace',
        amount: 960,
        category: 'Evenement',
        collected: false,
      ),
    ];
  }
}

enum AppointmentStatus { pending, confirmed, completed }

enum VisitorStatus { expected, checkedIn, checkedOut }

class Appointment {
  const Appointment({
    required this.id,
    required this.guest,
    required this.company,
    required this.purpose,
    required this.service,
    required this.date,
    required this.time,
    required this.amount,
    required this.status,
    required this.notes,
  });

  final String id;
  final String guest;
  final String company;
  final String purpose;
  final String service;
  final String date;
  final String time;
  final double amount;
  final AppointmentStatus status;
  final String notes;

  Appointment copyWith({AppointmentStatus? status}) {
    return Appointment(
      id: id,
      guest: guest,
      company: company,
      purpose: purpose,
      service: service,
      date: date,
      time: time,
      amount: amount,
      status: status ?? this.status,
      notes: notes,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'guest': guest,
    'company': company,
    'purpose': purpose,
    'service': service,
    'date': date,
    'time': time,
    'amount': amount,
    'status': status.name,
    'notes': notes,
  };

  factory Appointment.fromJson(Map<String, dynamic> json) {
    return Appointment(
      id: _readString(json, 'id', _id('apt')),
      guest: _readString(json, 'guest', 'Invited guest'),
      company: _readString(json, 'company', 'Organisation'),
      purpose: _readString(json, 'purpose', 'Appointment'),
      service: _readString(json, 'service', 'Service booking'),
      date: _readString(json, 'date', _dateFromOffset(0)),
      time: _readString(json, 'time', '09:00'),
      amount: _readDouble(json, 'amount', 0),
      status: AppointmentStatus.values.firstWhere(
        (status) => status.name == json['status'],
        orElse: () => AppointmentStatus.pending,
      ),
      notes: _readString(json, 'notes', ''),
    );
  }
}

class VisitorRecord {
  const VisitorRecord({
    required this.id,
    required this.name,
    required this.company,
    required this.host,
    required this.expectedAt,
    required this.badge,
    required this.status,
  });

  final String id;
  final String name;
  final String company;
  final String host;
  final String expectedAt;
  final String badge;
  final VisitorStatus status;

  VisitorRecord copyWith({VisitorStatus? status}) {
    return VisitorRecord(
      id: id,
      name: name,
      company: company,
      host: host,
      expectedAt: expectedAt,
      badge: badge,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'company': company,
    'host': host,
    'expectedAt': expectedAt,
    'badge': badge,
    'status': status.name,
  };

  factory VisitorRecord.fromJson(Map<String, dynamic> json) {
    return VisitorRecord(
      id: _readString(json, 'id', _id('vis')),
      name: _readString(json, 'name', 'Visitor'),
      company: _readString(json, 'company', 'Organisation'),
      host: _readString(json, 'host', 'Reception'),
      expectedAt: _readString(json, 'expectedAt', '09:00'),
      badge: _readString(json, 'badge', 'A-01'),
      status: VisitorStatus.values.firstWhere(
        (status) => status.name == json['status'],
        orElse: () => VisitorStatus.expected,
      ),
    );
  }
}

class WorkTask {
  const WorkTask({
    required this.id,
    required this.title,
    required this.owner,
    required this.area,
    required this.due,
    required this.done,
  });

  final String id;
  final String title;
  final String owner;
  final String area;
  final String due;
  final bool done;

  WorkTask copyWith({bool? done}) {
    return WorkTask(
      id: id,
      title: title,
      owner: owner,
      area: area,
      due: due,
      done: done ?? this.done,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'owner': owner,
    'area': area,
    'due': due,
    'done': done,
  };

  factory WorkTask.fromJson(Map<String, dynamic> json) {
    return WorkTask(
      id: _readString(json, 'id', _id('task')),
      title: _readString(json, 'title', 'Task'),
      owner: _readString(json, 'owner', 'Team'),
      area: _readString(json, 'area', 'Operations'),
      due: _readString(json, 'due', 'Today'),
      done: json['done'] == true,
    );
  }
}

class RevenueEntry {
  const RevenueEntry({
    required this.id,
    required this.label,
    required this.amount,
    required this.category,
    required this.collected,
  });

  final String id;
  final String label;
  final double amount;
  final String category;
  final bool collected;

  RevenueEntry copyWith({bool? collected}) {
    return RevenueEntry(
      id: id,
      label: label,
      amount: amount,
      category: category,
      collected: collected ?? this.collected,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'label': label,
    'amount': amount,
    'category': category,
    'collected': collected,
  };

  factory RevenueEntry.fromJson(Map<String, dynamic> json) {
    return RevenueEntry(
      id: _readString(json, 'id', _id('rev')),
      label: _readString(json, 'label', 'Revenue'),
      amount: _readDouble(json, 'amount', 0),
      category: _readString(json, 'category', 'Operations'),
      collected: json['collected'] == true,
    );
  }
}

class OperationsSettings {
  const OperationsSettings({
    required this.dailyTarget,
    required this.siteArea,
    required this.manager,
  });

  final double dailyTarget;
  final String siteArea;
  final String manager;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'dailyTarget': dailyTarget,
    'siteArea': siteArea,
    'manager': manager,
  };

  factory OperationsSettings.fromJson(Map<String, dynamic> json) {
    return OperationsSettings(
      dailyTarget: _readDouble(json, 'dailyTarget', 7200),
      siteArea: _readString(json, 'siteArea', 'Accueil principal'),
      manager: _readString(json, 'manager', 'Equipe operations'),
    );
  }
}

class WorkspaceShell extends StatefulWidget {
  const WorkspaceShell({required this.store, super.key});

  final OperationsStore store;

  @override
  State<WorkspaceShell> createState() => _WorkspaceShellState();
}

class _WorkspaceShellState extends State<WorkspaceShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      OverviewScreen(store: widget.store),
      BookingScreen(store: widget.store),
      VisitorScreen(store: widget.store),
      AnalyticsScreen(store: widget.store),
      TaskSettingsScreen(store: widget.store),
    ];
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text(appName),
            actions: <Widget>[
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _StatusPill(
                  icon: Icons.lock_outline,
                  label: 'Local',
                  color: brandTeal,
                ),
              ),
            ],
          ),
          body: SafeArea(child: screens[index]),
          bottomNavigationBar: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: (value) => setState(() => index = value),
            destinations: const <NavigationDestination>[
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: 'Overview',
              ),
              NavigationDestination(
                icon: Icon(Icons.event_note_outlined),
                selectedIcon: Icon(Icons.event_note),
                label: 'Bookings',
              ),
              NavigationDestination(
                icon: Icon(Icons.badge_outlined),
                selectedIcon: Icon(Icons.badge),
                label: 'Visitors',
              ),
              NavigationDestination(
                icon: Icon(Icons.query_stats_outlined),
                selectedIcon: Icon(Icons.query_stats),
                label: 'Analytics',
              ),
              NavigationDestination(
                icon: Icon(Icons.task_alt_outlined),
                selectedIcon: Icon(Icons.task_alt),
                label: 'Tasks',
              ),
            ],
          ),
        );
      },
    );
  }
}

class OverviewScreen extends StatelessWidget {
  const OverviewScreen({required this.store, super.key});

  final OperationsStore store;

  @override
  Widget build(BuildContext context) {
    final nextAppointments = store.appointments.take(3).toList();
    return ListView(
      key: const ValueKey('overview_screen'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            children: <Widget>[
              Image.asset(
                'assets/brand/featured.png',
                height: 154,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
              Container(
                height: 154,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[
                      brandNavy.withValues(alpha: .92),
                      brandNavy.withValues(alpha: .30),
                    ],
                  ),
                ),
              ),
              const Positioned(
                left: 18,
                right: 18,
                bottom: 18,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Daily command center',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Bookings, visitors, revenue, and tasks in one local workspace.',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.35,
          children: <Widget>[
            MetricCard(
              label: 'Today bookings',
              value: store.appointments.length.toString(),
              icon: Icons.event_available,
              color: brandBlue,
            ),
            MetricCard(
              label: 'Expected visitors',
              value: store.expectedVisitors.toString(),
              icon: Icons.groups_2_outlined,
              color: brandTeal,
            ),
            MetricCard(
              label: 'Booked revenue',
              value: _money(store.bookedRevenue),
              icon: Icons.payments_outlined,
              color: brandGold,
            ),
            MetricCard(
              label: 'Open tasks',
              value: store.openTasks.toString(),
              icon: Icons.playlist_add_check,
              color: const Color(0xFF6A4C93),
            ),
          ],
        ),
        const SizedBox(height: 18),
        SectionHeader(
          title: 'Priority schedule',
          action: '${store.settings.siteArea} area',
        ),
        const SizedBox(height: 8),
        ...nextAppointments.map(
          (appointment) => AppointmentTile(
            appointment: appointment,
            onTap: () => _showAppointmentDetail(context, store, appointment),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(Icons.insights, color: brandGold),
                    const SizedBox(width: 8),
                    Text(
                      'Operational pulse',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ProgressLine(
                  label: 'Task completion',
                  value: store.completionRate,
                  trailing: '${(store.completionRate * 100).round()}%',
                ),
                const SizedBox(height: 12),
                ProgressLine(
                  label: 'Revenue collected',
                  value: store.settings.dailyTarget == 0
                      ? 0
                      : (store.collectedRevenue / store.settings.dailyTarget)
                            .clamp(0, 1),
                  trailing:
                      '${_money(store.collectedRevenue)} / ${_money(store.settings.dailyTarget)}',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class BookingScreen extends StatelessWidget {
  const BookingScreen({required this.store, super.key});

  final OperationsStore store;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('bookings_screen'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: <Widget>[
          const SectionHeader(
            title: 'Appointment booking',
            action: 'Front desk workflow',
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _StatusPill(
                icon: Icons.schedule,
                label: '${store.appointments.length} scheduled',
                color: brandBlue,
              ),
              _StatusPill(
                icon: Icons.verified_outlined,
                label:
                    '${store.appointments.where((item) => item.status == AppointmentStatus.confirmed).length} confirmed',
                color: brandTeal,
              ),
              _StatusPill(
                icon: Icons.payments_outlined,
                label: _money(store.bookedRevenue),
                color: brandGold,
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...store.appointments.map(
            (appointment) => AppointmentTile(
              appointment: appointment,
              onTap: () => _showAppointmentDetail(context, store, appointment),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('addAppointmentButton'),
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => AppointmentForm(store: store),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Book'),
      ),
    );
  }
}

class VisitorScreen extends StatelessWidget {
  const VisitorScreen({required this.store, super.key});

  final OperationsStore store;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('visitors_screen'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: <Widget>[
          const SectionHeader(
            title: 'Visitor management',
            action: 'Badges and arrival status',
          ),
          const SizedBox(height: 10),
          ...store.visitors.map(
            (visitor) => Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        CircleAvatar(
                          backgroundColor: brandBlue,
                          foregroundColor: Colors.white,
                          child: Text(visitor.badge.split('-').last),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                visitor.name,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                '${visitor.company} • Host: ${visitor.host}',
                              ),
                            ],
                          ),
                        ),
                        _StatusPill(
                          icon: _visitorIcon(visitor.status),
                          label: _visitorLabel(visitor.status),
                          color: _visitorColor(visitor.status),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Expected ${visitor.expectedAt} • Badge ${visitor.badge}',
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: visitor.status == VisitorStatus.checkedIn
                                ? null
                                : () => store.setVisitorStatus(
                                    visitor.id,
                                    VisitorStatus.checkedIn,
                                  ),
                            icon: const Icon(Icons.login),
                            label: const Text('Check in'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed:
                                visitor.status == VisitorStatus.checkedOut
                                ? null
                                : () => store.setVisitorStatus(
                                    visitor.id,
                                    VisitorStatus.checkedOut,
                                  ),
                            icon: const Icon(Icons.logout),
                            label: const Text('Check out'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('addVisitorButton'),
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => VisitorForm(store: store),
        ),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Visitor'),
      ),
    );
  }
}

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({required this.store, super.key});

  final OperationsStore store;

  @override
  Widget build(BuildContext context) {
    final maxAmount = store.revenue.fold<double>(
      1,
      (max, item) => item.amount > max ? item.amount : max,
    );
    return ListView(
      key: const ValueKey('analytics_screen'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: <Widget>[
        const SectionHeader(
          title: 'Revenue analytics',
          action: 'Local entries only',
        ),
        const SizedBox(height: 10),
        Card(
          color: brandNavy,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Collected today',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 8),
                Text(
                  _money(store.collectedRevenue),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Booked total ${_money(store.bookedRevenue)} across ${store.revenue.length} entries',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        SectionHeader(
          title: 'Revenue sources',
          action: 'Target ${_money(store.settings.dailyTarget)}',
        ),
        const SizedBox(height: 8),
        ...store.revenue.map(
          (entry) => Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          entry.label,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Text(
                        _money(entry.amount),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${entry.category} • ${entry.collected ? 'Collected' : 'Pending'}',
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: entry.amount / maxAmount,
                      minHeight: 9,
                      color: entry.collected ? brandTeal : brandGold,
                      backgroundColor: brandNavy.withValues(alpha: .08),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class TaskSettingsScreen extends StatefulWidget {
  const TaskSettingsScreen({required this.store, super.key});

  final OperationsStore store;

  @override
  State<TaskSettingsScreen> createState() => _TaskSettingsScreenState();
}

class _TaskSettingsScreenState extends State<TaskSettingsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController controller;

  @override
  void initState() {
    super.initState();
    controller = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('tasks_screen'),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: TabBar(
          controller: controller,
          tabs: const <Widget>[
            Tab(icon: Icon(Icons.task_alt), text: 'Tasks'),
            Tab(icon: Icon(Icons.settings_outlined), text: 'Settings'),
          ],
        ),
      ),
      body: TabBarView(
        controller: controller,
        children: <Widget>[
          TaskList(store: widget.store),
          SettingsPanel(store: widget.store),
        ],
      ),
      floatingActionButton: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          if (controller.index != 0) {
            return const SizedBox.shrink();
          }
          return FloatingActionButton.extended(
            key: const ValueKey('addTaskButton'),
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => TaskForm(store: widget.store),
            ),
            icon: const Icon(Icons.add_task),
            label: const Text('Task'),
          );
        },
      ),
    );
  }
}

class TaskList extends StatelessWidget {
  const TaskList({required this.store, super.key});

  final OperationsStore store;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: <Widget>[
        SectionHeader(
          title: 'Task management',
          action: '${store.openTasks} open',
        ),
        const SizedBox(height: 10),
        ...store.tasks.map(
          (task) => Card(
            child: CheckboxListTile(
              value: task.done,
              onChanged: (value) => store.setTaskDone(task.id, value ?? false),
              title: Text(task.title),
              subtitle: Text(
                '${task.area} • Owner ${task.owner} • Due ${task.due}',
              ),
              secondary: Icon(
                task.done ? Icons.verified : Icons.radio_button_unchecked,
                color: task.done ? brandTeal : brandGold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class SettingsPanel extends StatelessWidget {
  const SettingsPanel({required this.store, super.key});

  final OperationsStore store;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: <Widget>[
        const SectionHeader(
          title: 'Settings and privacy',
          action: 'No account required',
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Workspace profile',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                _SettingRow(
                  icon: Icons.apartment,
                  label: 'Site area',
                  value: store.settings.siteArea,
                ),
                _SettingRow(
                  icon: Icons.supervisor_account_outlined,
                  label: 'Operations lead',
                  value: store.settings.manager,
                ),
                _SettingRow(
                  icon: Icons.flag_outlined,
                  label: 'Daily revenue target',
                  value: _money(store.settings.dailyTarget),
                ),
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(Icons.privacy_tip_outlined, color: brandTeal),
                    const SizedBox(width: 8),
                    Text(
                      'Local data handling',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Appointments, visitor logs, revenue entries, task status, and workspace preferences stay on this device. The app has no login, cloud sync, analytics, ads, or network features.',
                ),
                const SizedBox(height: 14),
                SelectableText('Support: $supportEmail'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class AppointmentForm extends StatefulWidget {
  const AppointmentForm({required this.store, super.key});

  final OperationsStore store;

  @override
  State<AppointmentForm> createState() => _AppointmentFormState();
}

class _AppointmentFormState extends State<AppointmentForm> {
  final formKey = GlobalKey<FormState>();
  final guest = TextEditingController();
  final company = TextEditingController();
  final purpose = TextEditingController(text: 'Family visit');
  final service = TextEditingController(text: 'Appointment booking');
  final time = TextEditingController(text: '09:00');
  final amount = TextEditingController(text: '450');
  final notes = TextEditingController();

  @override
  void dispose() {
    guest.dispose();
    company.dispose();
    purpose.dispose();
    service.dispose();
    time.dispose();
    amount.dispose();
    notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FormSheet(
      title: 'New appointment',
      formKey: formKey,
      submitLabel: 'Save booking',
      onSubmit: () async {
        if (!formKey.currentState!.validate()) {
          return;
        }
        await widget.store.addAppointment(
          Appointment(
            id: _id('apt'),
            guest: guest.text.trim(),
            company: company.text.trim(),
            purpose: purpose.text.trim(),
            service: service.text.trim(),
            date: _dateFromOffset(0),
            time: time.text.trim(),
            amount: double.tryParse(amount.text.trim()) ?? 0,
            status: AppointmentStatus.pending,
            notes: notes.text.trim(),
          ),
        );
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
      children: <Widget>[
        AppTextField(
          fieldKey: const ValueKey('appointmentGuestField'),
          controller: guest,
          label: 'Guest name',
          icon: Icons.person_outline,
        ),
        AppTextField(
          fieldKey: const ValueKey('appointmentCompanyField'),
          controller: company,
          label: 'Company or relation',
          icon: Icons.business_outlined,
        ),
        AppTextField(
          controller: purpose,
          label: 'Purpose',
          icon: Icons.topic_outlined,
        ),
        AppTextField(
          controller: service,
          label: 'Service',
          icon: Icons.room_service_outlined,
        ),
        Row(
          children: <Widget>[
            Expanded(
              child: AppTextField(
                controller: time,
                label: 'Time',
                icon: Icons.schedule,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppTextField(
                controller: amount,
                label: 'Revenue',
                icon: Icons.euro,
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        AppTextField(
          controller: notes,
          label: 'Operational notes',
          icon: Icons.notes_outlined,
          required: false,
          minLines: 2,
        ),
      ],
    );
  }
}

class VisitorForm extends StatefulWidget {
  const VisitorForm({required this.store, super.key});

  final OperationsStore store;

  @override
  State<VisitorForm> createState() => _VisitorFormState();
}

class _VisitorFormState extends State<VisitorForm> {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController();
  final company = TextEditingController();
  final host = TextEditingController(text: 'Reception');
  final time = TextEditingController(text: '13:00');
  final badge = TextEditingController(text: 'A-10');

  @override
  void dispose() {
    name.dispose();
    company.dispose();
    host.dispose();
    time.dispose();
    badge.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FormSheet(
      title: 'Register visitor',
      formKey: formKey,
      submitLabel: 'Save visitor',
      onSubmit: () async {
        if (!formKey.currentState!.validate()) {
          return;
        }
        await widget.store.addVisitor(
          VisitorRecord(
            id: _id('vis'),
            name: name.text.trim(),
            company: company.text.trim(),
            host: host.text.trim(),
            expectedAt: time.text.trim(),
            badge: badge.text.trim(),
            status: VisitorStatus.expected,
          ),
        );
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
      children: <Widget>[
        AppTextField(
          controller: name,
          label: 'Visitor name',
          icon: Icons.person_add_alt_1,
        ),
        AppTextField(
          controller: company,
          label: 'Company or family',
          icon: Icons.apartment,
        ),
        AppTextField(
          controller: host,
          label: 'Host',
          icon: Icons.support_agent,
        ),
        Row(
          children: <Widget>[
            Expanded(
              child: AppTextField(
                controller: time,
                label: 'Expected time',
                icon: Icons.schedule,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppTextField(
                controller: badge,
                label: 'Badge',
                icon: Icons.badge_outlined,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class TaskForm extends StatefulWidget {
  const TaskForm({required this.store, super.key});

  final OperationsStore store;

  @override
  State<TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends State<TaskForm> {
  final formKey = GlobalKey<FormState>();
  final title = TextEditingController();
  final owner = TextEditingController();
  final area = TextEditingController(text: 'Operations');
  final due = TextEditingController(text: 'Today');

  @override
  void dispose() {
    title.dispose();
    owner.dispose();
    area.dispose();
    due.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FormSheet(
      title: 'New task',
      formKey: formKey,
      submitLabel: 'Save task',
      onSubmit: () async {
        if (!formKey.currentState!.validate()) {
          return;
        }
        await widget.store.addTask(
          WorkTask(
            id: _id('task'),
            title: title.text.trim(),
            owner: owner.text.trim(),
            area: area.text.trim(),
            due: due.text.trim(),
            done: false,
          ),
        );
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
      children: <Widget>[
        AppTextField(
          controller: title,
          label: 'Task title',
          icon: Icons.task_alt,
        ),
        AppTextField(
          controller: owner,
          label: 'Owner',
          icon: Icons.person_outline,
        ),
        Row(
          children: <Widget>[
            Expanded(
              child: AppTextField(
                controller: area,
                label: 'Area',
                icon: Icons.location_city,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppTextField(
                controller: due,
                label: 'Due',
                icon: Icons.flag_outlined,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class FormSheet extends StatelessWidget {
  const FormSheet({
    required this.title,
    required this.formKey,
    required this.submitLabel,
    required this.onSubmit,
    required this.children,
    super.key,
  });

  final String title;
  final GlobalKey<FormState> formKey;
  final String submitLabel;
  final VoidCallback onSubmit;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 14),
              ...children.expand(
                (field) => <Widget>[field, const SizedBox(height: 10)],
              ),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onSubmit,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(submitLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppTextField extends StatelessWidget {
  const AppTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.fieldKey,
    this.keyboardType,
    this.required = true,
    this.minLines = 1,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final Key? fieldKey;
  final TextInputType? keyboardType;
  final bool required;
  final int minLines;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: fieldKey,
      controller: controller,
      keyboardType: keyboardType,
      minLines: minLines,
      maxLines: minLines > 1 ? 4 : 1,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      validator: (value) {
        if (!required) {
          return null;
        }
        if (value == null || value.trim().isEmpty) {
          return '$label is required';
        }
        return null;
      },
    );
  }
}

class AppointmentTile extends StatelessWidget {
  const AppointmentTile({
    required this.appointment,
    required this.onTap,
    super.key,
  });

  final Appointment appointment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: brandNavy,
          foregroundColor: Colors.white,
          child: Text(appointment.time.substring(0, 2)),
        ),
        title: Text(appointment.guest),
        subtitle: Text(
          '${appointment.service} • ${appointment.company}\n${appointment.date} at ${appointment.time}',
        ),
        isThreeLine: true,
        trailing: _StatusPill(
          icon: _appointmentIcon(appointment.status),
          label: _appointmentLabel(appointment.status),
          color: _appointmentColor(appointment.status),
        ),
      ),
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Icon(icon, color: color),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({required this.title, required this.action, super.key});

  final String title;
  final String action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        Text(action, style: TextStyle(color: brandNavy.withValues(alpha: .64))),
      ],
    );
  }
}

class ProgressLine extends StatelessWidget {
  const ProgressLine({
    required this.label,
    required this.value,
    required this.trailing,
    super.key,
  });

  final String label;
  final double value;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(child: Text(label)),
            Text(trailing, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: value.clamp(0, 1),
            minHeight: 10,
            backgroundColor: brandNavy.withValues(alpha: .08),
            color: brandGold,
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color == brandGold ? brandNavy : color,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: <Widget>[
          Icon(icon, color: brandNavy),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

void _showAppointmentDetail(
  BuildContext context,
  OperationsStore store,
  Appointment appointment,
) {
  showModalBottomSheet<void>(
    context: context,
    builder: (context) => Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            appointment.guest,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text('${appointment.company} • ${appointment.purpose}'),
          const SizedBox(height: 8),
          Text('${appointment.date} at ${appointment.time}'),
          const SizedBox(height: 12),
          Text(
            appointment.notes.isEmpty
                ? 'No notes recorded.'
                : appointment.notes,
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await store.setAppointmentStatus(
                      appointment.id,
                      AppointmentStatus.confirmed,
                    );
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  icon: const Icon(Icons.verified_outlined),
                  label: const Text('Confirm'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () async {
                    await store.setAppointmentStatus(
                      appointment.id,
                      AppointmentStatus.completed,
                    );
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  icon: const Icon(Icons.done_all),
                  label: const Text('Complete'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

IconData _appointmentIcon(AppointmentStatus status) {
  return switch (status) {
    AppointmentStatus.pending => Icons.pending_actions,
    AppointmentStatus.confirmed => Icons.verified_outlined,
    AppointmentStatus.completed => Icons.done_all,
  };
}

String _appointmentLabel(AppointmentStatus status) {
  return switch (status) {
    AppointmentStatus.pending => 'Pending',
    AppointmentStatus.confirmed => 'Confirmed',
    AppointmentStatus.completed => 'Done',
  };
}

Color _appointmentColor(AppointmentStatus status) {
  return switch (status) {
    AppointmentStatus.pending => brandGold,
    AppointmentStatus.confirmed => brandTeal,
    AppointmentStatus.completed => brandBlue,
  };
}

IconData _visitorIcon(VisitorStatus status) {
  return switch (status) {
    VisitorStatus.expected => Icons.schedule,
    VisitorStatus.checkedIn => Icons.login,
    VisitorStatus.checkedOut => Icons.logout,
  };
}

String _visitorLabel(VisitorStatus status) {
  return switch (status) {
    VisitorStatus.expected => 'Expected',
    VisitorStatus.checkedIn => 'In',
    VisitorStatus.checkedOut => 'Out',
  };
}

Color _visitorColor(VisitorStatus status) {
  return switch (status) {
    VisitorStatus.expected => brandGold,
    VisitorStatus.checkedIn => brandTeal,
    VisitorStatus.checkedOut => brandBlue,
  };
}

String _money(double value) {
  final rounded = value.round().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < rounded.length; i++) {
    final left = rounded.length - i;
    buffer.write(rounded[i]);
    if (left > 1 && left % 3 == 1) {
      buffer.write(' ');
    }
  }
  return '${buffer.toString()} EUR';
}

String _dateFromOffset(int days) {
  final date = DateTime.now().add(Duration(days: days));
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

String _sampleDateFromOffset(int days) {
  final date = DateTime(2026, 5, 11).add(Duration(days: days));
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

String _id(String prefix) => '$prefix-${DateTime.now().microsecondsSinceEpoch}';

String _readString(Map<String, dynamic> json, String key, String fallback) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) {
    return value;
  }
  return fallback;
}

double _readDouble(Map<String, dynamic> json, String key, double fallback) {
  final value = json[key];
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value) ?? fallback;
  }
  return fallback;
}
