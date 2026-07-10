enum TimeEntryRepositoryFailureCode {
  entryNotSplitable('entry_not_splitable'),
  splitOutOfRange('split_out_of_range'),
  mergeConfirmationRequired('merge_confirmation_required');

  const TimeEntryRepositoryFailureCode(this.code);

  final String code;
}

final class TimeEntryRepositoryException extends StateError
    implements Exception {
  TimeEntryRepositoryException(this.failureCode) : super(failureCode.code);

  final TimeEntryRepositoryFailureCode failureCode;
}
