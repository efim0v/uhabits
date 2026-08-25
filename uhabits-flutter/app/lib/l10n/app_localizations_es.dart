// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class L10nEs extends L10n {
  L10nEs([String locale = 'es']) : super(locale);

  @override
  String get overview => 'Resumen';

  @override
  String get appName => 'Loop Analizador de Hábitos';

  @override
  String get mainActivityTitle => 'Hábitos';

  @override
  String get actionSettings => 'Configuración';

  @override
  String get edit => 'Editar';

  @override
  String get delete => 'Eliminar';

  @override
  String get archive => 'Archivar';

  @override
  String get unarchive => 'Desarchivar';

  @override
  String get addHabit => 'Agregar hábito';

  @override
  String get colorPickerDefaultTitle => 'Cambiar color';

  @override
  String get toastHabitCreated => 'Hábito creado';

  @override
  String get habitStrength => 'Fuerza del hábito';

  @override
  String get history => 'Historial';

  @override
  String get clear => 'Borrar';

  @override
  String get reminder => 'Recordatorio';

  @override
  String get save => 'Guardar';

  @override
  String get streaks => 'Rachas';

  @override
  String get noHabitsFound => 'No tienes hábitos activos';

  @override
  String get noHabitsLeftToDo => '¡Ya terminaste todo por hoy!';

  @override
  String get longPressToToggle => 'Mantener apretado para marcar o desmarcar';

  @override
  String get reminderOff => 'Apagado';

  @override
  String get createHabit => 'Crear hábito';

  @override
  String get editHabit => 'Editar hábito';

  @override
  String get check => 'Marcar';

  @override
  String get snooze => 'Aplazar';

  @override
  String get introTitle1 => 'Bienvenido';

  @override
  String get introDescription1 =>
      'Loop Analizador de Hábitos te ayuda a crear y mantener buenos hábitos.';

  @override
  String get introTitle2 => 'Crea algunos hábitos nuevos';

  @override
  String get introDescription2 =>
      'Cada día, después de realizar tu hábito, pon una marca en la aplicación.';

  @override
  String get introTitle4 => 'Haz un seguimiento de tu progreso';

  @override
  String get introDescription4 =>
      'Gráficos detallados te muestran cómo mejoraron tus hábitos con el tiempo.';

  @override
  String get interval15Minutes => '15 minutos';

  @override
  String get interval30Minutes => '30 minutos';

  @override
  String get interval1Hour => '1 hora';

  @override
  String get interval2Hour => '2 horas';

  @override
  String get interval4Hour => '4 horas';

  @override
  String get interval8Hour => '8 horas';

  @override
  String get interval24Hour => '24 horas';

  @override
  String get intervalAlwaysAsk => 'Preguntar siempre';

  @override
  String get intervalCustom => 'Personalizar...';

  @override
  String get prefToggleTitle =>
      'Marca las repeticiones con una pulsación corta';

  @override
  String get prefToggleDescription2 =>
      'Ponga marcas de verificación con un solo toque en lugar de mantener presionado.';

  @override
  String get prefRateThisApp => 'Califica esta aplicación en Google Play';

  @override
  String get prefSendFeedback => 'Enviar sugerencias al desarrollador';

  @override
  String get prefViewSourceCode => 'Ver código fuente en GitHub';

  @override
  String get links => 'Enlaces';

  @override
  String get name => 'Nombre';

  @override
  String get settings => 'Configuración';

  @override
  String get selectSnoozeDelay => 'Seleccione el retardo de la interrupción';

  @override
  String get hintTitle => '¿Sabías qué?';

  @override
  String get hintDrag =>
      'Para reorganizar las entradas, mantén presionado el nombre del hábito y luego arrástralo al lugar correcto.';

  @override
  String get hintLandscape =>
      'Puedes ver más días al poner tu teléfono en modo horizontal.';

  @override
  String get habitNotFound => 'Hábito eliminado / no encontrado';

  @override
  String get weekends => 'Fines de semana';

  @override
  String get anyWeekday => 'De lunes a viernes';

  @override
  String get anyDay => 'Cada día';

  @override
  String get selectWeekdays => 'Seleccionar días';

  @override
  String get exportToCsv => 'Exportar datos (CSV)';

  @override
  String get doneLabel => 'Hecho';

  @override
  String get clearLabel => 'Quitar';

  @override
  String get selectHours => 'Seleccionar horas';

  @override
  String get selectMinutes => 'Seleccionar minutos';

  @override
  String get about => 'Acerca de';

  @override
  String get translators => 'Traductores';

  @override
  String get developers => 'Desarrolladores';

  @override
  String versionN(String p1) {
    return 'Versión $p1';
  }

  @override
  String get frequency => 'Frecuencia';

  @override
  String get checkmark => 'Marca de verificación';

  @override
  String get checkmarkStackWidget => 'Checkmark Stack Widget';

  @override
  String get frequencyStackWidget => 'Frequency Stack Widget';

  @override
  String get scoreStackWidget => 'Score Stack Widget';

  @override
  String get historyStackWidget => 'History Stack Widget';

  @override
  String get streaksStackWidget => 'Streaks Stack Widget';

  @override
  String get bestStreaks => 'Mejores rachas';

  @override
  String get everyDay => 'Diariamente';

  @override
  String get everyWeek => 'Semanalmente';

  @override
  String get help => 'Ayuda & Preguntas frecuentes';

  @override
  String get couldNotExport => 'Error al exportar datos.';

  @override
  String get couldNotImport => 'Error al importar datos.';

  @override
  String get fileNotRecognized => 'Archivo no reconocido.';

  @override
  String get habitsImported => 'Hábitos importados exitosamente.';

  @override
  String get importData => 'Importar datos';

  @override
  String get exportFullBackup => 'Exportar copia de seguridad';

  @override
  String get importDataSummary =>
      'Es compatible con exportar copias de seguridad completas, así como archivos generados por Tickmate, HabitBull o Rewire. Mira el FAQ para más información.';

  @override
  String get exportAsCsvSummary =>
      'Genera archivos que pueden ser abiertos por programas de hojas de cálculo como Microsoft Excel o OpenOffice Calc. Este archivo no puede volver a importarse de vuelta.';

  @override
  String get exportFullBackupSummary =>
      'Genera un archivo que contiene todos tus datos. Este archivo puede volver a importarse de vuelta.';

  @override
  String get selectPublicBackupFolder =>
      'Seleccionar carpeta de copia de seguridad pública';

  @override
  String get noPublicBackupFolderSelected => 'Ninguna carpeta seleccionada';

  @override
  String get bugReportFailed => 'Error al generar el reporte de error.';

  @override
  String get generateBugReport => 'Generar informe de bug';

  @override
  String get troubleshooting => 'Solución de problemas';

  @override
  String get helpTranslate => 'Ayuda a traducir esta aplicación';

  @override
  String get nightMode => 'Modo nocturno';

  @override
  String get usePureBlack => 'Utilizar color negro en modo nocturno';

  @override
  String get pureBlackDescription =>
      'Reemplaza fondos grises por color negro en modo nocturno. Reduce el consumo de batería en teléfonos con pantalla AMOLED.';

  @override
  String get interfacePreferences => 'Interfaz';

  @override
  String get reverseDays => 'Invertir el orden de los días';

  @override
  String get reverseDaysDescription =>
      'Mostrar días en orden inverso en la pantalla principal.';

  @override
  String get day => 'Día';

  @override
  String get week => 'Semana';

  @override
  String get month => 'Mes';

  @override
  String get quarter => 'Trimestre';

  @override
  String get year => 'Año';

  @override
  String get total => 'Total';

  @override
  String get yesOrNo => 'Sí / No';

  @override
  String everyXDays(int p1) {
    return 'Cada $p1 días';
  }

  @override
  String everyXWeeks(int p1) {
    return 'Cada $p1 semanas';
  }

  @override
  String get score => 'Puntuación';

  @override
  String get reminderSound => 'Sonido de recordatorio';

  @override
  String get none => 'Ninguno';

  @override
  String get filter => 'Filtrar';

  @override
  String get search => 'Search';

  @override
  String get hideCompleted => 'Ocultar completos';

  @override
  String get hideEntered => 'Ocultar ingresado';

  @override
  String get hideArchived => 'Ocultar archivados';

  @override
  String get stickyNotifications => 'Hacer que las notificaciones sean fijas';

  @override
  String get stickyNotificationsDescription =>
      'Evita que las notificaciones sean descartadas.';

  @override
  String get ledNotifications => 'Luz de notificación';

  @override
  String get ledNotificationsDescription =>
      'Muestra una luz intermitente para recordatorios. Solo disponible en teléfonos con luces de notificación LED.';

  @override
  String get repairDatabase => 'Reparar base de datos';

  @override
  String get databaseRepaired => 'Base de datos reparada.';

  @override
  String get uncheck => 'Desmarcar';

  @override
  String get toggle => 'Alternar';

  @override
  String get action => 'Acción';

  @override
  String get habit => 'Hábito';

  @override
  String get sort => 'Ordenar';

  @override
  String get manually => 'Manualmente';

  @override
  String get byName => 'Por nombre';

  @override
  String get byColor => 'Por color';

  @override
  String get byScore => 'Por puntuación';

  @override
  String get byStatus => 'Por estado';

  @override
  String get export => 'Exportar';

  @override
  String get longPressToEdit => 'Mantenga presionado para cambiar el valor';

  @override
  String get value => 'Valor';

  @override
  String get calendar => 'Calendario';

  @override
  String get unit => 'Unidad';

  @override
  String get targetType => 'Tipo de objetivo';

  @override
  String get targetTypeAtLeast => 'Al menos';

  @override
  String get targetTypeAtMost => 'Como máximo';

  @override
  String get exampleQuestionBoolean => 'ej. ¿Has ejercitado hoy?';

  @override
  String get question => 'Pregunta';

  @override
  String get target => 'Objetivo';

  @override
  String get yes => 'Sí';

  @override
  String get no => 'No';

  @override
  String get customizeNotificationSummary =>
      'Cambiar sonido, vibración, luz y otros ajustes de notificación';

  @override
  String get customizeNotification => 'Personalizar las notificaciones';

  @override
  String get prefViewPrivacy => 'Ver política de privacidad';

  @override
  String get viewAllContributors => 'Ver todos los colaboradores…';

  @override
  String get database => 'Base de datos';

  @override
  String get widgetOpacityTitle => 'Opacidad del widget';

  @override
  String get widgetOpacityDescription =>
      'Hace que los widgets sean más transparentes u opacos en la pantalla de inicio.';

  @override
  String get firstDayOfTheWeek => 'Primer día de la semana';

  @override
  String get defaultReminderQuestion => '¿Has completado este hábito hoy?';

  @override
  String get notes => 'Notas';

  @override
  String get exampleNotes => '(Opcional)';

  @override
  String get yesOrNoExample =>
      'ej. ¿Te levantaste temprano hoy? ¿Hiciste ejercicio? ¿Jugaste al ajedrez?';

  @override
  String get measurable => 'Medible';

  @override
  String get measurableExample =>
      'ej. ¿Cuántas millas has corrido hoy? ¿Cuántas páginas has leído?';

  @override
  String xTimesPerWeek(int p1) {
    return '$p1 veces por semana';
  }

  @override
  String xTimesPerMonth(int p1) {
    return '$p1 veces al mes';
  }

  @override
  String xTimesPerYDays(int p1, int p2) {
    return '$p1 veces en $p2 días';
  }

  @override
  String get yesOrNoShortExample => 'ej. Ejercicio';

  @override
  String get color => 'Color';

  @override
  String get exampleTarget => 'ej. 15';

  @override
  String get measurableShortExample => 'ej. Correr';

  @override
  String get measurableQuestionExample =>
      'ej. ¿Cuántos kilómetros has corrido hoy?';

  @override
  String get measurableUnitsExample => 'ej. kilómetros';

  @override
  String get everyMonth => 'Cada mes';

  @override
  String get validationCannotBeBlank => 'No puede estar en blanco';

  @override
  String get today => 'Hoy';

  @override
  String get enter => 'Introducir';

  @override
  String get noHabits => 'No se encontraron hábitos';

  @override
  String get noNumericalHabits => 'No se encontraron hábitos medibles';

  @override
  String get noBooleanHabits => 'No se encontraron hábitos de sí o no';

  @override
  String get increment => 'Incrementar';

  @override
  String get decrement => 'Disminuir';

  @override
  String get prefSkipTitle => 'Habilitar días libres';

  @override
  String get skipDay => 'Skip';

  @override
  String get prefSkipDescription =>
      'Presionar dos veces para agregar un salto en lugar de una marca de verificación. Los saltos mantienen tu puntaje sin cambios y no rompen tu racha.';

  @override
  String get prefUnknownTitle =>
      'Mostrar signos de interrogación para datos faltantes';

  @override
  String get prefUnknownDescription =>
      'Diferenciar los días sin datos de los lapsos reales. Para ingresar un lapso, presionar dos veces.';

  @override
  String get youAreNowADeveloper => 'Ahora eres desarrollador';

  @override
  String get activityNotFound =>
      'No se encontró ninguna aplicación que admita esta acción';

  @override
  String get prefMidnightDelayTitle =>
      'Ampliar día unas horas después de medianoche';

  @override
  String get prefMidnightDelayDescription =>
      'Esperar hasta las 3:00 AM para mostrar un nuevo día. Útil si normalmente vas a dormir después de medianoche. Requiere reiniciar la aplicación.';

  @override
  String get prefAnimationsTitle => 'Disable animations';

  @override
  String get prefAnimationsDescription =>
      'Disable confetti animation after adding a checkmark.';

  @override
  String toastHabitsChanged(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Hábitos cambiados',
      one: 'Hábito cambiado',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsDeleted(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Hábitos eliminados',
      one: 'Hábito eliminado',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsArchived(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Hábitos archivados',
      one: 'Hábito archivado',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsUnarchived(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Hábitos desarchivados',
      one: 'Hábito desarchivado',
    );
    return '$_temp0';
  }

  @override
  String deleteHabitsTitle(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '¿Eliminar hábitos?',
      one: '¿Eliminar hábito?',
    );
    return '$_temp0';
  }

  @override
  String deleteHabitsMessage(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Los hábitos se eliminarán permanentemente. Esta acción no se puede deshacer.',
      one:
          'El hábito se eliminará permanentemente. Esta acción no se puede deshacer.',
    );
    return '$_temp0';
  }

  @override
  String get sleepLastNight => 'Last night';

  @override
  String get sleepBedtime => 'Bedtime';

  @override
  String get sleepWakeTime => 'Wake time';

  @override
  String get sleepDuration => 'Sleep';

  @override
  String get sleepNights => 'Nights';

  @override
  String get sleepStability => 'Stability';

  @override
  String get sleepNoData => 'No data yet';

  @override
  String sleepSpreadMinutes(String minutes) {
    return '±$minutes min';
  }

  @override
  String sleepSkippedCount(int skipped, int days) {
    return '$skipped of $days days skipped';
  }

  @override
  String get sleepMarkSkipped => 'Mark';

  @override
  String sleepLastSkipped(String date) {
    return 'Last: $date';
  }

  @override
  String get sleepWeakestSleep =>
      'Went to bed and got up on time, but slept less than the goal.';

  @override
  String get sleepWeakestBed =>
      'Slept enough and got up on time, but went to bed off schedule.';

  @override
  String get sleepWeakestWake =>
      'Slept enough and went to bed on time, but got up off schedule.';

  @override
  String get sleepPerfectNight => 'On schedule and slept enough.';

  @override
  String get sleepTargetBedtime => 'Target bedtime';

  @override
  String get sleepTargetWakeTime => 'Target wake time';

  @override
  String get sleepMinimumSleep => 'Minimum sleep';

  @override
  String get sleepHomeTimezone => 'Home time zone';

  @override
  String get sleepAdaptationRate => 'Adaptation';

  @override
  String sleepAdaptationPerDay(int minutes) {
    return '$minutes min per day';
  }

  @override
  String get sleepEnterNight => 'Enter night';

  @override
  String get sleepActuallyAsleep => 'Actually asleep';

  @override
  String get sleepHealthAccess => 'Allow access to Health';

  @override
  String get sleepHealthDenied =>
      'Without access to Health, nights have to be entered by hand.';

  @override
  String sleepSuggestGoalBed(String time) {
    return 'You have been going to bed around $time. Move the goal?';
  }

  @override
  String sleepSuggestGoalWake(String time) {
    return 'You have been getting up around $time. Move the goal?';
  }

  @override
  String get sleepSuggestSkip =>
      'Your time zone changed. Mark these days as skipped?';

  @override
  String get sleepSuggestApply => 'Move';

  @override
  String get sleepSuggestDismiss => 'Not now';

  @override
  String get sleepSkipped => 'Skipped';

  @override
  String get sleepHabitType => 'Sleep';

  @override
  String get sleepHabitTypeExample =>
      'e.g. Go to bed at 23:00, get up at 07:00, and sleep at least 7:30 — scored from Health or entered by hand.';

  @override
  String get sleepAdvanced => 'Advanced';

  @override
  String get sleepWeightSleep => 'Weight: sleep';

  @override
  String get sleepWeightBed => 'Weight: bedtime';

  @override
  String get sleepWeightWake => 'Weight: wake time';

  @override
  String get sleepHalfCreditTime => 'Half credit at (times)';

  @override
  String get sleepHalfCreditSleep => 'Half credit at (sleep)';

  @override
  String sleepMinutesShort(int minutes) {
    return '$minutes min';
  }

  @override
  String sleepTimezoneOffset(String sign, String hours, String minutes) {
    return 'UTC$sign$hours:$minutes';
  }
}
