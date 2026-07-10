import 'sync_bundle.dart';

abstract class SyncBundleStore {
  Future<SyncBundle> exportBundle();

  Future<void> mergeBundle(SyncBundle bundle);
}
