import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

/// Non-nullable accessor for [AppLocalizations].
///
/// Safe because [AppLocalizations.delegate] uses [SynchronousFuture]
/// and localizations are always available synchronously in this app.
AppLocalizations l10n(BuildContext context) =>
    AppLocalizations.of(context)!;
