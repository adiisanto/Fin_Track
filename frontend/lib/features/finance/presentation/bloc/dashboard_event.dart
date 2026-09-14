import 'package:equatable/equatable.dart';

abstract class DashboardEvent extends Equatable {
  const DashboardEvent();
  @override
  List<Object> get props => [];
}

class DashboardFetchRequested extends DashboardEvent {
  final String timeframe;
  const DashboardFetchRequested(this.timeframe);

  @override
  List<Object> get props => [timeframe];
}
