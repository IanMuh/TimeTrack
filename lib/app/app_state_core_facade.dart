part of 'app_state.dart';

mixin AppStateCoreFacade on ChangeNotifier {
  AppRefreshState get _refreshState;

  DateTime get selectedDay => _refreshState.selectedDay;

  set selectedDay(DateTime value) {
    _refreshState.selectedDay = value;
  }

  DateTime get now => _refreshState.now;

  set now(DateTime value) {
    _refreshState.now = value;
  }

  ValueNotifier<DateTime> get clockNotifier => _refreshState.clockNotifier;

  int get dataRevision => _refreshState.dataRevision;
}
