/// Port of
/// uhabits-android/src/main/res/xml/preferences.xml,
/// uhabits-android/.../activities/settings/SettingsActivity.kt and
/// uhabits-android/.../activities/settings/SettingsFragment.kt.
///
/// The Android screen is an androidx `PreferenceFragmentCompat` inflating
/// `res/xml/preferences.xml` inside an activity that owns the toolbar. Flutter
/// has no preference framework, so the XML is rebuilt here as an ordinary
/// scrolling list: [SettingsCategoryHeader] is `<PreferenceCategory>` and
/// [SettingsRow] is every `<Preference>` / `<SwitchPreferenceCompat>` /
/// `<ListPreference>` / `<EditTextPreference>`, carrying the original
/// `android:key` so the order and the identity of each row stay checkable.
///
/// The rows are in `preferences.xml` order and nothing is dropped. Two of
/// them are backed by Android-only machinery with no counterpart here — the
/// ringtone picker (`reminderSound`) and the Storage Access Framework folder
/// picker (`publicBackupFolder`) — so they render disabled with the same
/// string Android shows when an intent has no handler, rather than
/// disappearing. `reminderCustomize` is not one of them: notification channels
/// are Android-only, but the app carries its own handler for them, so the row
/// acts and reports the same string only when the intent finds no home.
///
/// What the screen does *not* do is any work: exactly like
/// `SettingsFragment.setResultOnPreferenceClick`, the database and
/// troubleshooting rows close the screen with a [SettingsResult] and leave the
/// work to the list screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
// The preferences layer is not re-exported from uhabits_core.dart yet.
// ignore: implementation_imports
import 'package:uhabits_core/src/preferences/preferences.dart';
import 'package:uhabits_core/uhabits_core.dart' as core;

import '../../l10n/app_localizations.dart';
import '../../platform/flutter_notification_tray.dart'
    show LocalNotificationsChannelCreator, PlatformNotificationChannelSettings;
import '../../state/app_scope.dart';
import '../../state/settings_model.dart';
import '../theme/app_theme.dart' show coreThemeOf;

/// The settings screen.
///
/// Push it with a [SettingsResult] type argument: the export, import, bug
/// report and repair rows pop with one, mirroring `setResult(...); finish()`.
///
/// ```dart
/// final result = await Navigator.of(context).push<SettingsResult>(
///   MaterialPageRoute(builder: (_) => SettingsScreen(storage: storage)),
/// );
/// ```
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    this.storage,
    this.onOpenUrl,
    this.onShowAbout,
  });

  /// The same [PreferencesStorage] instance that was handed to
  /// `AppScope.open`. Needed for the handful of keys core has no setter for —
  /// `pref_first_weekday` and the three inert sync keys. When null those rows
  /// render read-only.
  final PreferencesStorage? storage;

  /// `startActivitySafely(Intent(ACTION_VIEW, ...))`. When null the two link
  /// rows render disabled, which is what Android degrades to when no activity
  /// can handle the intent.
  final void Function(String url)? onOpenUrl;

  /// The `<intent>` on the About row, which targets `AboutActivity`.
  final VoidCallback? onShowAbout;

  /// `@string/helpURL`.
  static const String helpUrl = 'http://loophabits.org/faq.html';

  /// `@string/playStoreURL`.
  static const String rateAppUrl = 'market://details?id=org.isoron.uhabits';

  /// `@string/bugReportTo` — the single address every bug report goes to.
  static const String bugReportTo = 'dev@loophabits.org';

  /// `@string/bugReportSubject`.
  static const String bugReportSubject = 'Bug Report - Loop Habit Tracker';

  /// `ListHabitsScreen.showSendBugReportToDeveloperScreen(log)`, which is
  /// `Activity.showSendEmailScreen(bugReportTo, bugReportSubject, log)`:
  /// `ACTION_SEND`, type `message/rfc822`, with `EXTRA_EMAIL`, `EXTRA_SUBJECT`
  /// and the report as `EXTRA_TEXT`.
  ///
  /// Flutter addresses a mail composer with a `mailto:` URI instead of an
  /// intent, so the three extras become the recipient and two query
  /// parameters. `Uri` percent-encodes both values, which is what an intent
  /// extra did not need to.
  static Uri bugReportMailto(String log) => Uri(
        scheme: 'mailto',
        path: bugReportTo,
        queryParameters: <String, String>{
          'subject': bugReportSubject,
          'body': log,
        },
      );

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<SettingsModel>(
      create: (context) =>
          SettingsModel(context.read<AppScope>(), storage: storage)..attach(),
      child: _SettingsView(onOpenUrl: onOpenUrl, onShowAbout: onShowAbout),
    );
  }
}

class _SettingsView extends StatelessWidget {
  const _SettingsView({this.onOpenUrl, this.onShowAbout});

  final void Function(String url)? onOpenUrl;
  final VoidCallback? onShowAbout;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final model = context.watch<SettingsModel>();
    // `AndroidThemeSwitcher.getSystemTheme()`, read from the platform instead
    // of from `Configuration.uiMode`.
    final systemTheme =
        MediaQuery.platformBrightnessOf(context) == Brightness.dark
            ? SettingsModel.themeDark
            : SettingsModel.themeLight;
    final theme = model.currentTheme(systemTheme);
    // `setupToolbar(..., color = PaletteColor(11))`, whose own branch decides
    // whether that colour is used at all: the light theme sets
    // `?attr/useHabitColorAsPrimary` true, both dark ones set it false and take
    // `?attr/colorPrimary` — #101010 dark, #000000 pure black — instead.
    final toolbarColor = _toFlutterColor(
      theme.toolbarColorFor(theme.colorOf(const core.PaletteColor(11))),
    );

    return Scaffold(
      backgroundColor: _toFlutterColor(theme.appBackgroundColor),
      appBar: AppBar(
        title: Text(l10n.settings),
        backgroundColor: toolbarColor,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              ..._interfaceCategory(context, l10n, model),
              ..._reminderCategory(context, l10n, model),
              ..._databaseCategory(context, l10n, model),
              ..._troubleshootingCategory(context, l10n),
              ..._linksCategory(context, l10n),
              if (model.isDeveloperCategoryVisible)
                ..._developmentCategory(context, model),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------
  // <PreferenceCategory android:key="interfaceCategory">
  // -------------------------------------------------------------------

  List<Widget> _interfaceCategory(
    BuildContext context,
    L10n l10n,
    SettingsModel model,
  ) {
    final weekdayNames = _longWeekdayNamesFromSaturday(context);
    return <Widget>[
      SettingsCategoryHeader(title: l10n.interfacePreferences),
      SettingsRow(
        preferenceKey: 'pref_short_toggle',
        title: l10n.prefToggleTitle,
        summary: l10n.prefToggleDescription2,
        trailing: _switch(
          model.isShortToggleEnabled,
          (value) => model.isShortToggleEnabled = value,
        ),
        onTap: () =>
            model.isShortToggleEnabled = !model.isShortToggleEnabled,
      ),
      SettingsRow(
        preferenceKey: 'pref_midnight_delay',
        title: l10n.prefMidnightDelayTitle,
        summary: l10n.prefMidnightDelayDescription,
        trailing: _switch(
          model.isMidnightDelayEnabled,
          (value) => model.isMidnightDelayEnabled = value,
        ),
        onTap: () =>
            model.isMidnightDelayEnabled = !model.isMidnightDelayEnabled,
      ),
      SettingsRow(
        preferenceKey: 'pref_skip_enabled',
        title: l10n.prefSkipTitle,
        summary: l10n.prefSkipDescription,
        trailing: _switch(
          model.isSkipEnabled,
          (value) => model.isSkipEnabled = value,
        ),
        onTap: () => model.isSkipEnabled = !model.isSkipEnabled,
      ),
      SettingsRow(
        preferenceKey: 'pref_unknown_enabled',
        title: l10n.prefUnknownTitle,
        summary: l10n.prefUnknownDescription,
        trailing: _switch(
          model.areQuestionMarksEnabled,
          (value) => model.areQuestionMarksEnabled = value,
        ),
        onTap: () =>
            model.areQuestionMarksEnabled = !model.areQuestionMarksEnabled,
      ),
      SettingsRow(
        preferenceKey: 'pref_checkmark_reverse_order',
        title: l10n.reverseDays,
        summary: l10n.reverseDaysDescription,
        trailing: _switch(
          model.isCheckmarkSequenceReversed,
          (value) => model.isCheckmarkSequenceReversed = value,
        ),
        onTap: () => model.isCheckmarkSequenceReversed =
            !model.isCheckmarkSequenceReversed,
      ),
      SettingsRow(
        preferenceKey: 'pref_pure_black',
        title: l10n.usePureBlack,
        summary: l10n.pureBlackDescription,
        trailing: _switch(
          model.isPureBlackEnabled,
          (value) => model.isPureBlackEnabled = value,
        ),
        onTap: () => model.isPureBlackEnabled = !model.isPureBlackEnabled,
      ),
      SettingsRow(
        preferenceKey: 'pref_disable_animation',
        title: l10n.prefAnimationsTitle,
        summary: l10n.prefAnimationsDescription,
        trailing: _switch(
          model.isConfettiAnimationDisabled,
          (value) => model.isConfettiAnimationDisabled = value,
        ),
        onTap: () => model.isConfettiAnimationDisabled =
            !model.isConfettiAnimationDisabled,
      ),
      SettingsRow(
        preferenceKey: 'pref_widget_opacity',
        title: l10n.widgetOpacityTitle,
        // The XML sets a static android:summary, so unlike the first-weekday
        // row this one never shows the selected entry.
        summary: l10n.widgetOpacityDescription,
        onTap: () => _pickWidgetOpacity(context),
      ),
      SettingsRow(
        preferenceKey: 'pref_first_weekday',
        title: l10n.firstDayOfTheWeek,
        // `updateWeekdayPreference`: summary = dayNames[firstWeekday % 7].
        summary: weekdayNames[model.firstWeekday % 7],
        enabled: model.canWriteRawKeys,
        note: model.canWriteRawKeys ? null : l10n.activityNotFound,
        onTap: () => _pickFirstWeekday(context, weekdayNames),
      ),
    ];
  }

  // -------------------------------------------------------------------
  // <PreferenceCategory android:key="reminderCategory">
  // -------------------------------------------------------------------

  List<Widget> _reminderCategory(
    BuildContext context,
    L10n l10n,
    SettingsModel model,
  ) {
    return <Widget>[
      SettingsCategoryHeader(title: l10n.reminder),
      // ACTION_RINGTONE_PICKER has no cross-platform equivalent. Android hides
      // this row outright (`findPreference("reminderSound").isVisible = false`);
      // the port keeps it visible but inert so the gap stays obvious.
      SettingsRow(
        preferenceKey: 'reminderSound',
        title: l10n.reminderSound,
        note: l10n.activityNotFound,
        enabled: false,
      ),
      SettingsRow(
        preferenceKey: 'pref_sticky_notifications',
        title: l10n.stickyNotifications,
        summary: l10n.stickyNotificationsDescription,
        trailing: _switch(
          model.areNotificationsSticky,
          (value) => model.areNotificationsSticky = value,
        ),
        onTap: () =>
            model.areNotificationsSticky = !model.areNotificationsSticky,
      ),
      // `SettingsFragment.onPreferenceTreeClick`, key "reminderCustomize":
      // `createAndroidNotificationChannel(requireContext())` and then
      // `startActivity(Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS))`
      // (`settings.screen.reminder-category#7`, `notifications.channel#3`).
      SettingsRow(
        preferenceKey: 'reminderCustomize',
        title: l10n.customizeNotification,
        summary: l10n.customizeNotificationSummary,
        onTap: () => _customizeNotifications(context, l10n),
      ),
    ];
  }

  /// The click handler of the "reminderCustomize" row.
  ///
  /// Both halves already shipped — [PlatformNotificationChannelSettings] over
  /// `MainActivity`'s method channel, and [LocalNotificationsChannelCreator]
  /// over the plugin — and the row still rendered `enabled: false` with the
  /// "no app was found" note under it, because nothing anywhere built them
  /// (`audit3.settings-customize-notification-is-permanently-disabled#1`,
  /// `audit3.customize-notifications-settings-row-is-hard#1`). It is built
  /// here, at the point of use, exactly as `onPreferenceTreeClick` does it:
  /// a callback passed in from above would be one more thing that can be
  /// forgotten.
  ///
  /// `openReminderChannelSettings` answers false where the intent has no
  /// handler — iOS, macOS, a desktop host — which is `startActivitySafely`'s
  /// `ActivityNotFoundException` branch, and gets the same message Android
  /// shows.
  Future<void> _customizeNotifications(BuildContext context, L10n l10n) async {
    final messenger = ScaffoldMessenger.of(context);
    final settings = PlatformNotificationChannelSettings(
      creator: LocalNotificationsChannelCreator(
        plugin: FlutterLocalNotificationsPlugin(),
        // `R.string.reminder`, the user-visible channel name
        // (`notifications.channel#1`) — the same string the category header
        // above is titled with.
        channelName: l10n.reminder,
      ),
    );
    if (await settings.openReminderChannelSettings()) return;
    messenger.showSnackBar(SnackBar(content: Text(l10n.activityNotFound)));
  }

  // -------------------------------------------------------------------
  // <PreferenceCategory android:key="databaseCategory">
  // -------------------------------------------------------------------

  List<Widget> _databaseCategory(
    BuildContext context,
    L10n l10n,
    SettingsModel model,
  ) {
    return <Widget>[
      SettingsCategoryHeader(title: l10n.database),
      SettingsRow(
        preferenceKey: 'exportDB',
        title: l10n.exportFullBackup,
        summary: l10n.exportFullBackupSummary,
        onTap: () => _finishWith(context, SettingsResult.exportDb),
      ),
      SettingsRow(
        preferenceKey: 'exportCSV',
        title: l10n.exportToCsv,
        summary: l10n.exportAsCsvSummary,
        onTap: () => _finishWith(context, SettingsResult.exportCsv),
      ),
      SettingsRow(
        preferenceKey: 'importData',
        title: l10n.importData,
        summary: l10n.importDataSummary,
        onTap: () => _finishWith(context, SettingsResult.importData),
      ),
      // ACTION_OPEN_DOCUMENT_TREE plus a persistable tree URI: Storage Access
      // Framework, Android only.
      SettingsRow(
        preferenceKey: 'publicBackupFolder',
        title: l10n.selectPublicBackupFolder,
        // `updatePublicBackupFolderSummary()`: the human-readable path, or
        // "No folder selected" when the key was never written.
        summary: model.publicBackupFolderSummary ??
            l10n.noPublicBackupFolderSelected,
        note: l10n.activityNotFound,
        enabled: false,
      ),
    ];
  }

  // -------------------------------------------------------------------
  // <PreferenceCategory android:key="pref_key_debug">
  // -------------------------------------------------------------------

  List<Widget> _troubleshootingCategory(BuildContext context, L10n l10n) {
    return <Widget>[
      SettingsCategoryHeader(title: l10n.troubleshooting),
      SettingsRow(
        preferenceKey: 'bugReport',
        title: l10n.generateBugReport,
        onTap: () => _finishWith(context, SettingsResult.bugReport),
      ),
      SettingsRow(
        preferenceKey: 'repairDB',
        title: l10n.repairDatabase,
        onTap: () => _finishWith(context, SettingsResult.repairDb),
      ),
    ];
  }

  // -------------------------------------------------------------------
  // <PreferenceCategory android:key="linksCategory">
  // -------------------------------------------------------------------

  List<Widget> _linksCategory(BuildContext context, L10n l10n) {
    final openUrl = onOpenUrl;
    final showAbout = onShowAbout;
    return <Widget>[
      SettingsCategoryHeader(title: l10n.links),
      // The Help and About rows carry no android:key in the XML; the keys used
      // here name the rows so their order can be asserted.
      SettingsRow(
        preferenceKey: 'help',
        title: l10n.help,
        enabled: openUrl != null,
        note: openUrl == null ? l10n.activityNotFound : null,
        onTap: openUrl == null ? null : () => openUrl(SettingsScreen.helpUrl),
      ),
      SettingsRow(
        preferenceKey: 'rateApp',
        title: l10n.prefRateThisApp,
        enabled: openUrl != null,
        note: openUrl == null ? l10n.activityNotFound : null,
        onTap: openUrl == null ? null : () => openUrl(SettingsScreen.rateAppUrl),
      ),
      SettingsRow(
        preferenceKey: 'about',
        title: l10n.about,
        enabled: showAbout != null,
        note: showAbout == null ? l10n.activityNotFound : null,
        onTap: showAbout,
      ),
    ];
  }

  // -------------------------------------------------------------------
  // <PreferenceCategory android:key="devCategory">
  //
  // Title and row titles are hardcoded English literals in preferences.xml,
  // so they are never translated. Ported as literals for the same reason.
  // -------------------------------------------------------------------

  List<Widget> _developmentCategory(BuildContext context, SettingsModel model) {
    return <Widget>[
      const SettingsCategoryHeader(title: 'Development'),
      SettingsRow(
        preferenceKey: 'pref_developer',
        title: 'Enable developer mode',
        trailing: _switch(
          model.isDeveloper,
          (value) => model.isDeveloper = value,
        ),
        onTap: () => model.isDeveloper = !model.isDeveloper,
      ),
      _rawStringRow(
        context: context,
        model: model,
        preferenceKey: 'pref_sync_base_url',
        title: 'Sync server',
        value: model.syncBaseUrl,
        onSubmit: (value) => model.syncBaseUrl = value,
      ),
      _rawStringRow(
        context: context,
        model: model,
        preferenceKey: 'pref_sync_key',
        title: 'Sync key',
        value: model.syncKey,
        onSubmit: (value) => model.syncKey = value,
      ),
      _rawStringRow(
        context: context,
        model: model,
        preferenceKey: 'pref_encryption_key',
        title: 'Encryption key',
        value: model.encryptionKey,
        onSubmit: (value) => model.encryptionKey = value,
      ),
    ];
  }

  Widget _rawStringRow({
    required BuildContext context,
    required SettingsModel model,
    required String preferenceKey,
    required String title,
    required String value,
    required ValueChanged<String> onSubmit,
  }) {
    return SettingsRow(
      preferenceKey: preferenceKey,
      title: title,
      summary: value.isEmpty ? null : value,
      enabled: model.canWriteRawKeys,
      note: model.canWriteRawKeys ? null : L10n.of(context).activityNotFound,
      onTap: () => _editString(
        context,
        title: title,
        initialValue: value,
        onSubmit: onSubmit,
      ),
    );
  }

  // -------------------------------------------------------------------

  Widget _switch(bool value, ValueChanged<bool> onChanged) =>
      Switch(value: value, onChanged: onChanged);

  /// `requireActivity().setResult(result); requireActivity().finish()`.
  void _finishWith(BuildContext context, SettingsResult result) {
    Navigator.of(context).maybePop<SettingsResult>(result);
  }

  Future<void> _pickWidgetOpacity(BuildContext context) async {
    final model = context.read<SettingsModel>();
    final title = L10n.of(context).widgetOpacityTitle;
    final picked = await showDialog<String>(
      context: context,
      builder: (_) => _OptionsDialog<String>(
        title: title,
        labels: SettingsModel.widgetOpacityLabels,
        values: SettingsModel.widgetOpacityValues,
        selected: model.widgetOpacity.toString(),
      ),
    );
    if (picked == null) return;
    model.widgetOpacity = int.parse(picked);
  }

  Future<void> _pickFirstWeekday(
    BuildContext context,
    List<String> weekdayNames,
  ) async {
    final model = context.read<SettingsModel>();
    final title = L10n.of(context).firstDayOfTheWeek;
    final picked = await showDialog<int>(
      context: context,
      builder: (_) => _OptionsDialog<int>(
        title: title,
        labels: weekdayNames,
        values: SettingsModel.firstWeekdayValues,
        selected: model.firstWeekday,
      ),
    );
    if (picked == null) return;
    model.firstWeekday = picked;
  }

  Future<void> _editString(
    BuildContext context, {
    required String title,
    required String initialValue,
    required ValueChanged<String> onSubmit,
  }) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) =>
          _TextInputDialog(title: title, initialValue: initialValue),
    );
    if (result == null) return;
    onSubmit(result);
  }
}

/// Port of `<PreferenceCategory>`: a title above the rows it groups.
///
/// The app shadows androidx's `Preference.Category.Material` style so that every
/// category header is inflated from `res/layout/preference_category_custom.xml`,
/// whose `TextView` is `android:textColor="?aboutScreenColor"` — the blue accent
/// the About screen's card headers use as well. It is a theme attribute, not a
/// Material colour-scheme role, so it comes off the core theme.
class SettingsCategoryHeader extends StatelessWidget {
  const SettingsCategoryHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final color = _toFlutterColor(coreThemeOf(context).aboutScreenColor);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}

/// Port of one `<Preference>` row.
///
/// [preferenceKey] is the row's `android:key`; it also becomes the widget key,
/// so a row can be found by the same name it has in `preferences.xml`.
/// [note] is the port's own addition: the one-line explanation shown under a
/// row whose Android behaviour has no cross-platform equivalent.
class SettingsRow extends StatelessWidget {
  SettingsRow({
    required this.preferenceKey,
    required this.title,
    this.summary,
    this.note,
    this.trailing,
    this.onTap,
    this.enabled = true,
  }) : super(key: ValueKey<String>(preferenceKey));

  final String preferenceKey;
  final String title;
  final String? summary;
  final String? note;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final summary = this.summary;
    final note = this.note;
    final lines = <Widget>[
      if (summary != null) Text(summary, style: textTheme.bodySmall),
      if (note != null)
        Text(
          note,
          style: textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
        ),
    ];
    return ListTile(
      // iconSpaceReserved="false" on every row: nothing indents for an icon.
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      enabled: enabled,
      title: Text(title),
      subtitle: lines.isEmpty
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: lines,
            ),
      trailing: trailing,
      onTap: enabled ? onTap : null,
    );
  }
}

/// Port of the `ListPreference` dialog: a title, the entries, and a dismiss
/// that selects. Android closes the dialog as soon as an entry is picked.
class _OptionsDialog<T> extends StatelessWidget {
  const _OptionsDialog({
    required this.title,
    required this.labels,
    required this.values,
    required this.selected,
  });

  final String title;
  final List<String> labels;
  final List<T> values;
  final T selected;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (var i = 0; i < labels.length; i++)
                ListTile(
                  key: ValueKey<Object?>('option-${values[i]}'),
                  title: Text(labels[i]),
                  trailing:
                      values[i] == selected ? const Icon(Icons.check) : null,
                  onTap: () => Navigator.of(context).pop(values[i]),
                ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
      ],
    );
  }
}

/// Port of the `EditTextPreference` dialog.
class _TextInputDialog extends StatefulWidget {
  const _TextInputDialog({required this.title, required this.initialValue});

  final String title;
  final String initialValue;

  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<_TextInputDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final materialL10n = MaterialLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(controller: _controller, autofocus: true),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(materialL10n.cancelButtonLabel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(materialL10n.okButtonLabel),
        ),
      ],
    );
  }
}

/// `JavaLocalDateFormatter(Locale.getDefault()).longWeekdayNames(SATURDAY)`:
/// the seven long weekday names, starting at Saturday.
///
/// 2024-01-06 is a Saturday, so formatting seven consecutive days from it
/// produces exactly the Android order.
List<String> _longWeekdayNamesFromSaturday(BuildContext context) {
  const List<String> fallback = <String>[
    'Saturday',
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
  ];
  try {
    final localeName = Localizations.localeOf(context).toString();
    final format = intl.DateFormat.EEEE(localeName);
    return List<String>.generate(
      7,
      (offset) => format.format(DateTime(2024, 1, 6 + offset)),
    );
  } catch (_) {
    // Locale data that flutter_localizations has not initialised.
    return fallback;
  }
}

Color _toFlutterColor(core.Color color) => Color.fromARGB(
      (color.alpha * 255).round().clamp(0, 255),
      (color.red * 255).round().clamp(0, 255),
      (color.green * 255).round().clamp(0, 255),
      (color.blue * 255).round().clamp(0, 255),
    );
