import 'package:ronda/l10n/l10n.dart';
import 'package:safety_repository/safety_repository.dart';

/// What a report's [tag] says ("Me molestó"), for the form and the admin's
/// queue alike.
String reportTagLabel(AppLocalizations l10n, ReportTag tag) => switch (tag) {
  ReportTag.askedForMoney => l10n.reportTagAskedForMoney,
  ReportTag.bothered => l10n.reportTagBothered,
  ReportTag.romantic => l10n.reportTagRomantic,
  ReportTag.minor => l10n.reportTagMinor,
  ReportTag.privatePlace => l10n.reportTagPrivatePlace,
  ReportTag.other => l10n.reportTagOther,
};
