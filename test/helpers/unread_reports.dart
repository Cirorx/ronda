import 'package:bloc_test/bloc_test.dart';
import 'package:ronda/app/cubit/unread_reports_cubit.dart';

class _MockUnreadReportsCubit extends MockCubit<int>
    implements UnreadReportsCubit;

/// The Admin tab's unread count, stuck at [count], for screens that show
/// it (the shell's Admin tab, the admin screen's link to "Reportes").
UnreadReportsCubit unreadReports([int count = 0]) {
  final cubit = _MockUnreadReportsCubit();
  whenListen(cubit, const Stream<int>.empty(), initialState: count);
  return cubit;
}
