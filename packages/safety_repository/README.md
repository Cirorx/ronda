# safety_repository

Repository layer. Contar algo que pasó as the app sees it, over `ronda_api`'s `SafetyApi`
(#71, `docs/PRODUCT.md` § Safety, `docs/ARCHITECTURE.md` § Data model):

- for a member, who "¿Con quién?" offers (the other members of their rondas), sending a report,
  adding to it and "Retirar", and their own receipts, which never say what the admin did;
- for the admin, the queue (every report, the pairs kept apart, who is out of Ronda), the unread
  count the Admin tab shows, and "Archivar", "Reabrir", "Separarlos", "Juntarlos de nuevo",
  "Sacar de Ronda" and "Dejar entrar de nuevo".

Which reports go on top (someone reported by two or more people) is the app's cubit's rule, not
this package's.

## API

| Member | Does |
|---|---|
| `SafetyRepository(safetyApi: SafetyApi)` | Built in bootstrap; tests pass a mocked `SafetyApi` |
| `Future<List<ReportPerson>> reportPeople()` | "¿Con quién?" |
| `Future<String> sendReport({text, Set<ReportTag> tags, aboutUid})` | Sends a report (`aboutUid` empty for "Alguien de afuera") |
| `Future<void> addToReport({reportId, text})` / `withdrawReport(reportId)` | The reporter's own report |
| `Stream<List<ReportReceipt>> watchReceipts(String uid)` | The reporter's receipts, newest first |
| `Stream<SafetyQueue> watchQueue()` | Admin: reports, separated pairs, removed people |
| `Stream<int> watchUnreadCount()` | Admin: the Admin tab's count |
| `markRead`, `archive`, `reopen`, `separate`, `remove` (a report id); `joinAgain` (a pair id); `letBackIn` (a uid) | Admin: what the queue does |

Every failure is a `SafetyFailure`: `forbidden`, `tooMany` (five reports a day, or twenty
additions), `gone` (withdrawn, already out, no longer separated) or `other`.
