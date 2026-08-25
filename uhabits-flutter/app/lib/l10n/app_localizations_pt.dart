// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class L10nPt extends L10n {
  L10nPt([String locale = 'pt']) : super(locale);

  @override
  String get overview => 'Visão geral';

  @override
  String get appName => 'Loop - Acompanhador de Hábitos';

  @override
  String get mainActivityTitle => 'Hábitos';

  @override
  String get actionSettings => 'Configurações';

  @override
  String get edit => 'Editar';

  @override
  String get delete => 'Deletar';

  @override
  String get archive => 'Arquivar';

  @override
  String get unarchive => 'Desarquivar';

  @override
  String get addHabit => 'Adicionar hábito';

  @override
  String get colorPickerDefaultTitle => 'Mudar cor';

  @override
  String get toastHabitCreated => 'Hábito criado.';

  @override
  String get habitStrength => 'Estabilidade';

  @override
  String get history => 'Histórico';

  @override
  String get clear => 'Limpar';

  @override
  String get reminder => 'Lembrete';

  @override
  String get save => 'Salvar';

  @override
  String get streaks => 'Correntes';

  @override
  String get noHabitsFound => 'Você não tem nenhum hábito ativo';

  @override
  String get noHabitsLeftToDo => 'Tudo terminado!';

  @override
  String get longPressToToggle =>
      'Sustente por um segundo para marcar ou desmarcar';

  @override
  String get reminderOff => 'Desligado';

  @override
  String get createHabit => 'Criar hábito';

  @override
  String get editHabit => 'Editar hábito';

  @override
  String get check => 'Marcar';

  @override
  String get snooze => 'Mais tarde';

  @override
  String get introTitle1 => 'Bem vindo';

  @override
  String get introDescription1 =>
      'Loop é um aplicativo que te ajuda a criar e manter bons hábitos.';

  @override
  String get introTitle2 => 'Adicione alguns hábitos';

  @override
  String get introDescription2 =>
      'Todo dia, depois de praticar o seu hábito, marque no aplicativo.';

  @override
  String get introTitle4 => 'Acompanhe o seu progresso';

  @override
  String get introDescription4 =>
      'Veja como seus hábitos estão progredindo através de diagramas.';

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
  String get intervalAlwaysAsk => 'Perguntar sempre';

  @override
  String get intervalCustom => 'Personalizar...';

  @override
  String get prefToggleTitle => 'Marcar repetições com um toque curto';

  @override
  String get prefToggleDescription2 =>
      'Adicione marcações com um simples toque, ao invés de pressionar e segurar.';

  @override
  String get prefRateThisApp => 'Avaliar esse app no Google Play';

  @override
  String get prefSendFeedback => 'Mandar sugestões para o desenvolvedor';

  @override
  String get prefViewSourceCode => 'Ver código-fonte no GitHub';

  @override
  String get links => 'Links';

  @override
  String get name => 'Nome';

  @override
  String get settings => 'Configurações';

  @override
  String get selectSnoozeDelay => 'Selecionar duração do \"mais tarde\"';

  @override
  String get hintTitle => 'Dica';

  @override
  String get hintDrag =>
      'Para mudar a ordem dos hábitos, aperte no nome do hábito, sustente e arraste.';

  @override
  String get hintLandscape =>
      'Para ver mais dias, coloque seu aparelho em modo paisagem.';

  @override
  String get habitNotFound => 'Hábito deletado / não encontrado';

  @override
  String get weekends => 'Fim de semana';

  @override
  String get anyWeekday => 'Segunda a sexta';

  @override
  String get anyDay => 'Qualquer dia da semana';

  @override
  String get selectWeekdays => 'Selecionar dias';

  @override
  String get exportToCsv => 'Exportar em formato CSV';

  @override
  String get doneLabel => 'Pronto';

  @override
  String get clearLabel => 'Limpar';

  @override
  String get selectHours => 'Selecionar horas';

  @override
  String get selectMinutes => 'Selecionar minutos';

  @override
  String get about => 'Sobre';

  @override
  String get translators => 'Tradutores';

  @override
  String get developers => 'Desenvolvedores';

  @override
  String versionN(String p1) {
    return 'Versão $p1';
  }

  @override
  String get frequency => 'Frequência';

  @override
  String get checkmark => 'Marcações';

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
  String get bestStreaks => 'Correntes mais longas';

  @override
  String get everyDay => 'Todo dia';

  @override
  String get everyWeek => 'Toda semana';

  @override
  String get help => 'Ajuda & FAQ';

  @override
  String get couldNotExport => 'Erro ao exportar dados.';

  @override
  String get couldNotImport => 'Erro ao importar dados.';

  @override
  String get fileNotRecognized => 'Arquivo não reconhecido.';

  @override
  String get habitsImported => 'Hábitos importados com sucesso.';

  @override
  String get importData => 'Importar dados';

  @override
  String get exportFullBackup => 'Exportar backup completo';

  @override
  String get importDataSummary =>
      'Aceita backups completos exportados por este app, além de arquivos gerados por Tickmate, HabitBull ou Rewire. Veja \"Ajuda\" para mais informações.';

  @override
  String get exportAsCsvSummary =>
      'Gera arquivos que podem ser abertos em editores de planilha, como Microsoft Excel ou Openoffice Calc. Estes arquivos não podem ser importados de volta.';

  @override
  String get exportFullBackupSummary =>
      'Gera um arquivo que contém todos os dados. Este arquivo pode ser importado de volta.';

  @override
  String get selectPublicBackupFolder => 'Selecionar pasta pública de backup';

  @override
  String get noPublicBackupFolderSelected => 'Nenhuma pasta selecionada';

  @override
  String get bugReportFailed => 'Erro ao gerar relatório de erros.';

  @override
  String get generateBugReport => 'Gerar relatório de erros.';

  @override
  String get troubleshooting => 'Solução de problemas';

  @override
  String get helpTranslate => 'Ajude a traduzir este app';

  @override
  String get nightMode => 'Modo noturno';

  @override
  String get usePureBlack => 'Usar preto em modo noturno';

  @override
  String get pureBlackDescription =>
      'Substitui os tons de cinza por preto puro em modo noturno. Economiza bateria em telefones com tela AMOLED.';

  @override
  String get interfacePreferences => 'Interface';

  @override
  String get reverseDays => 'Inverter a ordem dos dias';

  @override
  String get reverseDaysDescription =>
      'Mostra os dias em ordem inversa na tela principal';

  @override
  String get day => 'Dia';

  @override
  String get week => 'Semana';

  @override
  String get month => 'Mês';

  @override
  String get quarter => 'Trimestre';

  @override
  String get year => 'Ano';

  @override
  String get total => 'Total';

  @override
  String get yesOrNo => 'Sim ou não';

  @override
  String everyXDays(int p1) {
    return 'A cada $p1 dias';
  }

  @override
  String everyXWeeks(int p1) {
    return 'A cada $p1 semanas';
  }

  @override
  String get score => 'Estabilidade';

  @override
  String get reminderSound => 'Toque dos lembretes';

  @override
  String get none => 'Nenhum';

  @override
  String get filter => 'Filtro';

  @override
  String get search => 'Search';

  @override
  String get hideCompleted => 'Ocultar concluído';

  @override
  String get hideEntered => 'Ocultar marcado';

  @override
  String get hideArchived => 'Ocultar arquivado';

  @override
  String get stickyNotifications => 'Tornar notificações persistentes';

  @override
  String get stickyNotificationsDescription =>
      'Impede que as notificações sejam removidas.';

  @override
  String get ledNotifications => 'Luz de notificação';

  @override
  String get ledNotificationsDescription =>
      'Mostra uma luz piscando para lembretes. Disponível apenas em telefones com luzes de notificação LED.';

  @override
  String get repairDatabase => 'Reparar banco de dados';

  @override
  String get databaseRepaired => 'Banco de dados reparado.';

  @override
  String get uncheck => 'Desmarcar';

  @override
  String get toggle => 'Alternar';

  @override
  String get action => 'Ação';

  @override
  String get habit => 'Hábito';

  @override
  String get sort => 'Ordenar';

  @override
  String get manually => 'Manualmente';

  @override
  String get byName => 'Por nome';

  @override
  String get byColor => 'Por cor';

  @override
  String get byScore => 'Por score';

  @override
  String get byStatus => 'Por status';

  @override
  String get export => 'Exportar';

  @override
  String get longPressToEdit => 'Pressione e segure para alterar o valor';

  @override
  String get value => 'Valor';

  @override
  String get calendar => 'Calendário';

  @override
  String get unit => 'Unidade';

  @override
  String get targetType => 'Tipo de meta';

  @override
  String get targetTypeAtLeast => 'Pelo menos';

  @override
  String get targetTypeAtMost => 'No máximo';

  @override
  String get exampleQuestionBoolean => 'ex.: Você se exercitou hoje?';

  @override
  String get question => 'Questão';

  @override
  String get target => 'Alvo';

  @override
  String get yes => 'Sim';

  @override
  String get no => 'Não';

  @override
  String get customizeNotificationSummary =>
      'Alterar som, vibração, luz e outras configurações de notificação';

  @override
  String get customizeNotification => 'Personalizar notificações';

  @override
  String get prefViewPrivacy => 'Ver política de privacidade';

  @override
  String get viewAllContributors => 'Exibir todos os colaboradores…';

  @override
  String get database => 'Banco de dados';

  @override
  String get widgetOpacityTitle => 'Opacidade dos widgets';

  @override
  String get widgetOpacityDescription =>
      'Torna os widgets mais transparentes ou mais opacos na tela inicial.';

  @override
  String get firstDayOfTheWeek => 'Primeiro dia da semana';

  @override
  String get defaultReminderQuestion => 'Você completou este hábito hoje?';

  @override
  String get notes => 'Anotações';

  @override
  String get exampleNotes => '(Opcional)';

  @override
  String get yesOrNoExample =>
      'Ex.: Você acordou cedo hoje? Você se exercitou? Você jogou xadrez?';

  @override
  String get measurable => 'Mensurável';

  @override
  String get measurableExample =>
      'ex.: Quantos km você correu hoje? Quantas páginas você leu?';

  @override
  String xTimesPerWeek(int p1) {
    return '$p1 vezes por semana';
  }

  @override
  String xTimesPerMonth(int p1) {
    return '$p1 vezes por mês';
  }

  @override
  String xTimesPerYDays(int p1, int p2) {
    return '$p1 vezes em $p2 dias';
  }

  @override
  String get yesOrNoShortExample => 'ex: Exercício';

  @override
  String get color => 'Cor';

  @override
  String get exampleTarget => 'Ex: 15';

  @override
  String get measurableShortExample => 'Ex: Correr';

  @override
  String get measurableQuestionExample => 'Ex: Quantos km você correu hoje?';

  @override
  String get measurableUnitsExample => 'Ex: km';

  @override
  String get everyMonth => 'Todo mês';

  @override
  String get validationCannotBeBlank => 'Não pode estar em branco';

  @override
  String get today => 'Hoje';

  @override
  String get enter => 'Entrar';

  @override
  String get noHabits => 'Nenhum hábito encontrado';

  @override
  String get noNumericalHabits => 'Nenhum hábito mensurável encontrado';

  @override
  String get noBooleanHabits => 'Nenhum hábito sim-ou-não encontrado';

  @override
  String get increment => 'Incrementar';

  @override
  String get decrement => 'Decrementar';

  @override
  String get prefSkipTitle => 'Habilitar dias de folga';

  @override
  String get skipDay => 'Skip';

  @override
  String get prefSkipDescription =>
      'Clique duas vezes para adicionar um dia de folga. Esses dias mantêm a estabilidade do hábito inalterada e não quebram a corrente.';

  @override
  String get prefUnknownTitle => 'Mostrar interrogação para dados ausentes';

  @override
  String get prefUnknownDescription =>
      'Mostra dias sem dados e dias com lapsos de forma diferente. Para inserir um lapso, clique duas vezes.';

  @override
  String get youAreNowADeveloper => 'Você agora é um desenvolvedor!';

  @override
  String get activityNotFound =>
      'Nenhum app encontrado para executar esta ação';

  @override
  String get prefMidnightDelayTitle =>
      'Prolongar dia algumas horas depois da meia-noite';

  @override
  String get prefMidnightDelayDescription =>
      'Espere até às 3:00 para mostrar um novo dia. Útil se você costuma dormir depois da meia-noite. Requer reinicialização do aplicativo.';

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
      other: 'Hábitos modificados.',
      one: 'Hábito modificado.',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsDeleted(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Hábitos deletados.',
      one: 'Hábito deletado.',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsArchived(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Hábitos arquivados.',
      one: 'Hábito arquivado.',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsUnarchived(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Hábitos desarquivados.',
      one: 'Hábito desarquivado.',
    );
    return '$_temp0';
  }

  @override
  String deleteHabitsTitle(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Excluir hábitos?',
      one: 'Excluir hábito?',
    );
    return '$_temp0';
  }

  @override
  String deleteHabitsMessage(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Os hábitos serão excluídos permanentemente. Esta ação não pode ser desfeita.',
      one:
          'O hábito será excluído permanentemente. Esta ação não pode ser desfeita.',
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
  String get sleepQuestionExample => 'e.g. How did you sleep last night?';

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

/// The translations for Portuguese, as used in Brazil (`pt_BR`).
class L10nPtBr extends L10nPt {
  L10nPtBr() : super('pt_BR');

  @override
  String get overview => 'Visão geral';

  @override
  String get appName => 'Loop - Acompanhador de Hábitos';

  @override
  String get mainActivityTitle => 'Hábitos';

  @override
  String get actionSettings => 'Configurações';

  @override
  String get edit => 'Editar';

  @override
  String get delete => 'Deletar';

  @override
  String get archive => 'Arquivar';

  @override
  String get unarchive => 'Desarquivar';

  @override
  String get addHabit => 'Adicionar hábito';

  @override
  String get colorPickerDefaultTitle => 'Mudar cor';

  @override
  String get toastHabitCreated => 'Hábito criado.';

  @override
  String get habitStrength => 'Estabilidade';

  @override
  String get history => 'Histórico';

  @override
  String get clear => 'Limpar';

  @override
  String get reminder => 'Lembrete';

  @override
  String get save => 'Salvar';

  @override
  String get streaks => 'Correntes';

  @override
  String get noHabitsFound => 'Você não tem nenhum hábito ativo';

  @override
  String get noHabitsLeftToDo => 'Tudo terminado!';

  @override
  String get longPressToToggle =>
      'Sustente por um segundo para marcar ou desmarcar';

  @override
  String get reminderOff => 'Desligado';

  @override
  String get createHabit => 'Criar hábito';

  @override
  String get editHabit => 'Editar hábito';

  @override
  String get check => 'Marcar';

  @override
  String get snooze => 'Mais tarde';

  @override
  String get introTitle1 => 'Bem vindo';

  @override
  String get introDescription1 =>
      'Loop é um aplicativo que te ajuda a criar e manter bons hábitos.';

  @override
  String get introTitle2 => 'Adicione alguns hábitos';

  @override
  String get introDescription2 =>
      'Todo dia, depois de praticar o seu hábito, marque no aplicativo.';

  @override
  String get introTitle4 => 'Acompanhe o seu progresso';

  @override
  String get introDescription4 =>
      'Veja como seus hábitos estão progredindo através de diagramas.';

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
  String get intervalAlwaysAsk => 'Perguntar sempre';

  @override
  String get intervalCustom => 'Personalizar...';

  @override
  String get prefToggleTitle => 'Marcar repetições com um toque curto';

  @override
  String get prefToggleDescription2 =>
      'Adicione marcações com um simples toque, ao invés de pressionar e segurar.';

  @override
  String get prefRateThisApp => 'Avaliar esse app no Google Play';

  @override
  String get prefSendFeedback => 'Mandar sugestões para o desenvolvedor';

  @override
  String get prefViewSourceCode => 'Ver código-fonte no GitHub';

  @override
  String get links => 'Links';

  @override
  String get name => 'Nome';

  @override
  String get settings => 'Configurações';

  @override
  String get selectSnoozeDelay => 'Selecionar duração do \"mais tarde\"';

  @override
  String get hintTitle => 'Dica';

  @override
  String get hintDrag =>
      'Para mudar a ordem dos hábitos, aperte no nome do hábito, sustente e arraste.';

  @override
  String get hintLandscape =>
      'Para ver mais dias, coloque seu aparelho em modo paisagem.';

  @override
  String get habitNotFound => 'Hábito deletado / não encontrado';

  @override
  String get weekends => 'Fim de semana';

  @override
  String get anyWeekday => 'Segunda a sexta';

  @override
  String get anyDay => 'Qualquer dia da semana';

  @override
  String get selectWeekdays => 'Selecionar dias';

  @override
  String get exportToCsv => 'Exportar em formato CSV';

  @override
  String get doneLabel => 'Pronto';

  @override
  String get clearLabel => 'Limpar';

  @override
  String get selectHours => 'Selecionar horas';

  @override
  String get selectMinutes => 'Selecionar minutos';

  @override
  String get about => 'Sobre';

  @override
  String get translators => 'Tradutores';

  @override
  String get developers => 'Desenvolvedores';

  @override
  String versionN(String p1) {
    return 'Versão $p1';
  }

  @override
  String get frequency => 'Frequência';

  @override
  String get checkmark => 'Marcações';

  @override
  String get bestStreaks => 'Correntes mais longas';

  @override
  String get everyDay => 'Todo dia';

  @override
  String get everyWeek => 'Toda semana';

  @override
  String get help => 'Ajuda & FAQ';

  @override
  String get couldNotExport => 'Erro ao exportar dados.';

  @override
  String get couldNotImport => 'Erro ao importar dados.';

  @override
  String get fileNotRecognized => 'Arquivo não reconhecido.';

  @override
  String get habitsImported => 'Hábitos importados com sucesso.';

  @override
  String get importData => 'Importar dados';

  @override
  String get exportFullBackup => 'Exportar backup completo';

  @override
  String get importDataSummary =>
      'Aceita backups completos exportados por este app, além de arquivos gerados por Tickmate, HabitBull ou Rewire. Veja \"Ajuda\" para mais informações.';

  @override
  String get exportAsCsvSummary =>
      'Gera arquivos que podem ser abertos em editores de planilha, como Microsoft Excel ou Openoffice Calc. Estes arquivos não podem ser importados de volta.';

  @override
  String get exportFullBackupSummary =>
      'Gera um arquivo que contém todos os dados. Este arquivo pode ser importado de volta.';

  @override
  String get selectPublicBackupFolder => 'Selecionar pasta pública de backup';

  @override
  String get noPublicBackupFolderSelected => 'Nenhuma pasta selecionada';

  @override
  String get bugReportFailed => 'Erro ao gerar relatório de erros.';

  @override
  String get generateBugReport => 'Gerar relatório de erros.';

  @override
  String get troubleshooting => 'Solução de problemas';

  @override
  String get helpTranslate => 'Ajude a traduzir este app';

  @override
  String get nightMode => 'Modo noturno';

  @override
  String get usePureBlack => 'Usar preto em modo noturno';

  @override
  String get pureBlackDescription =>
      'Substitui os tons de cinza por preto puro em modo noturno. Economiza bateria em telefones com tela AMOLED.';

  @override
  String get interfacePreferences => 'Interface';

  @override
  String get reverseDays => 'Inverter a ordem dos dias';

  @override
  String get reverseDaysDescription =>
      'Mostra os dias em ordem inversa na tela principal';

  @override
  String get day => 'Dia';

  @override
  String get week => 'Semana';

  @override
  String get month => 'Mês';

  @override
  String get quarter => 'Trimestre';

  @override
  String get year => 'Ano';

  @override
  String get total => 'Total';

  @override
  String get yesOrNo => 'Sim ou não';

  @override
  String everyXDays(int p1) {
    return 'A cada $p1 dias';
  }

  @override
  String everyXWeeks(int p1) {
    return 'A cada $p1 semanas';
  }

  @override
  String get score => 'Estabilidade';

  @override
  String get reminderSound => 'Toque dos lembretes';

  @override
  String get none => 'Nenhum';

  @override
  String get filter => 'Filtro';

  @override
  String get hideCompleted => 'Ocultar concluído';

  @override
  String get hideEntered => 'Ocultar marcado';

  @override
  String get hideArchived => 'Ocultar arquivado';

  @override
  String get stickyNotifications => 'Tornar notificações persistentes';

  @override
  String get stickyNotificationsDescription =>
      'Impede que as notificações sejam removidas.';

  @override
  String get ledNotifications => 'Luz de notificação';

  @override
  String get ledNotificationsDescription =>
      'Mostra uma luz piscando para lembretes. Disponível apenas em telefones com luzes de notificação LED.';

  @override
  String get repairDatabase => 'Reparar banco de dados';

  @override
  String get databaseRepaired => 'Banco de dados reparado.';

  @override
  String get uncheck => 'Desmarcar';

  @override
  String get toggle => 'Alternar';

  @override
  String get action => 'Ação';

  @override
  String get habit => 'Hábito';

  @override
  String get sort => 'Ordenar';

  @override
  String get manually => 'Manualmente';

  @override
  String get byName => 'Por nome';

  @override
  String get byColor => 'Por cor';

  @override
  String get byScore => 'Por score';

  @override
  String get byStatus => 'Por status';

  @override
  String get export => 'Exportar';

  @override
  String get longPressToEdit => 'Pressione e segure para alterar o valor';

  @override
  String get value => 'Valor';

  @override
  String get calendar => 'Calendário';

  @override
  String get unit => 'Unidade';

  @override
  String get targetType => 'Tipo de meta';

  @override
  String get targetTypeAtLeast => 'Pelo menos';

  @override
  String get targetTypeAtMost => 'No máximo';

  @override
  String get exampleQuestionBoolean => 'ex.: Você se exercitou hoje?';

  @override
  String get question => 'Questão';

  @override
  String get target => 'Alvo';

  @override
  String get yes => 'Sim';

  @override
  String get no => 'Não';

  @override
  String get customizeNotificationSummary =>
      'Alterar som, vibração, luz e outras configurações de notificação';

  @override
  String get customizeNotification => 'Personalizar notificações';

  @override
  String get prefViewPrivacy => 'Ver política de privacidade';

  @override
  String get viewAllContributors => 'Exibir todos os colaboradores…';

  @override
  String get database => 'Banco de dados';

  @override
  String get widgetOpacityTitle => 'Opacidade dos widgets';

  @override
  String get widgetOpacityDescription =>
      'Torna os widgets mais transparentes ou mais opacos na tela inicial.';

  @override
  String get firstDayOfTheWeek => 'Primeiro dia da semana';

  @override
  String get defaultReminderQuestion => 'Você completou este hábito hoje?';

  @override
  String get notes => 'Anotações';

  @override
  String get exampleNotes => '(Opcional)';

  @override
  String get yesOrNoExample =>
      'Ex.: Você acordou cedo hoje? Você se exercitou? Você jogou xadrez?';

  @override
  String get measurable => 'Mensurável';

  @override
  String get measurableExample =>
      'ex.: Quantos km você correu hoje? Quantas páginas você leu?';

  @override
  String xTimesPerWeek(int p1) {
    return '$p1 vezes por semana';
  }

  @override
  String xTimesPerMonth(int p1) {
    return '$p1 vezes por mês';
  }

  @override
  String xTimesPerYDays(int p1, int p2) {
    return '$p1 vezes em $p2 dias';
  }

  @override
  String get yesOrNoShortExample => 'ex: Exercício';

  @override
  String get color => 'Cor';

  @override
  String get exampleTarget => 'Ex: 15';

  @override
  String get measurableShortExample => 'Ex: Correr';

  @override
  String get measurableQuestionExample => 'Ex: Quantos km você correu hoje?';

  @override
  String get measurableUnitsExample => 'Ex: km';

  @override
  String get everyMonth => 'Todo mês';

  @override
  String get validationCannotBeBlank => 'Não pode estar em branco';

  @override
  String get today => 'Hoje';

  @override
  String get enter => 'Entrar';

  @override
  String get noHabits => 'Nenhum hábito encontrado';

  @override
  String get noNumericalHabits => 'Nenhum hábito mensurável encontrado';

  @override
  String get noBooleanHabits => 'Nenhum hábito sim-ou-não encontrado';

  @override
  String get increment => 'Incrementar';

  @override
  String get decrement => 'Decrementar';

  @override
  String get prefSkipTitle => 'Habilitar dias de folga';

  @override
  String get prefSkipDescription =>
      'Clique duas vezes para adicionar um dia de folga. Esses dias mantêm a estabilidade do hábito inalterada e não quebram a corrente.';

  @override
  String get prefUnknownTitle => 'Mostrar interrogação para dados ausentes';

  @override
  String get prefUnknownDescription =>
      'Mostra dias sem dados e dias com lapsos de forma diferente. Para inserir um lapso, clique duas vezes.';

  @override
  String get youAreNowADeveloper => 'Você agora é um desenvolvedor!';

  @override
  String get activityNotFound =>
      'Nenhum app encontrado para executar esta ação';

  @override
  String get prefMidnightDelayTitle =>
      'Prolongar dia algumas horas depois da meia-noite';

  @override
  String get prefMidnightDelayDescription =>
      'Espere até às 3:00 para mostrar um novo dia. Útil se você costuma dormir depois da meia-noite. Requer reinicialização do aplicativo.';

  @override
  String toastHabitsChanged(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Hábitos modificados.',
      one: 'Hábito modificado.',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsDeleted(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Hábitos deletados.',
      one: 'Hábito deletado.',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsArchived(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Hábitos arquivados.',
      one: 'Hábito arquivado.',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsUnarchived(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Hábitos desarquivados.',
      one: 'Hábito desarquivado.',
    );
    return '$_temp0';
  }

  @override
  String deleteHabitsTitle(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Excluir hábitos?',
      one: 'Excluir hábito?',
    );
    return '$_temp0';
  }

  @override
  String deleteHabitsMessage(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Os hábitos serão excluídos permanentemente. Esta ação não pode ser desfeita.',
      one:
          'O hábito será excluído permanentemente. Esta ação não pode ser desfeita.',
    );
    return '$_temp0';
  }
}

/// The translations for Portuguese, as used in Portugal (`pt_PT`).
class L10nPtPt extends L10nPt {
  L10nPtPt() : super('pt_PT');

  @override
  String get overview => 'Visão geral';

  @override
  String get appName => 'Loop - Acompanhador de Hábitos';

  @override
  String get mainActivityTitle => 'Hábitos';

  @override
  String get actionSettings => 'Definições';

  @override
  String get edit => 'Editar';

  @override
  String get delete => 'Eliminar';

  @override
  String get archive => 'Arquivar';

  @override
  String get unarchive => 'Desarquivar';

  @override
  String get addHabit => 'Adicionar hábito';

  @override
  String get colorPickerDefaultTitle => 'Alterar a cor';

  @override
  String get toastHabitCreated => 'Hábito criado';

  @override
  String get habitStrength => 'Pontuação';

  @override
  String get history => 'Histórico';

  @override
  String get clear => 'Limpar';

  @override
  String get reminder => 'Lembrete';

  @override
  String get save => 'Guardar';

  @override
  String get streaks => 'Séries';

  @override
  String get noHabitsFound => 'Não tem hábitos ativos';

  @override
  String get longPressToToggle =>
      'Mantenha pressionado para marcar ou desmarcar';

  @override
  String get reminderOff => 'Desligado';

  @override
  String get createHabit => 'Criar hábito';

  @override
  String get editHabit => 'Editar hábito';

  @override
  String get check => 'Marcar';

  @override
  String get snooze => 'Mais logo';

  @override
  String get introTitle1 => 'Bem-vindo';

  @override
  String get introDescription1 =>
      'Loop é uma aplicação que o ajuda a criar e manter bons hábitos.';

  @override
  String get introTitle2 => 'Adicione alguns hábitos';

  @override
  String get introDescription2 =>
      'Todos os dias, após concluir o seu hábito, marque uma cruz na app.';

  @override
  String get introTitle4 => 'Acompanhe o seu progresso';

  @override
  String get introDescription4 =>
      'Gráficos mostram-lhe como os seus hábitos melhoraram ao longo do tempo.';

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
  String get intervalAlwaysAsk => 'Perguntar sempre';

  @override
  String get intervalCustom => 'Personalizar...';

  @override
  String get prefToggleTitle => 'Toque para alternar entre repetições';

  @override
  String get prefRateThisApp => 'Avaliar a app no Google Play';

  @override
  String get prefSendFeedback => 'Enviar feedback ao programador';

  @override
  String get prefViewSourceCode => 'Ver código-fonte no GitHub';

  @override
  String get links => 'Hiperligações';

  @override
  String get name => 'Nome';

  @override
  String get settings => 'Definições';

  @override
  String get selectSnoozeDelay => 'Definir tempo de suspensão';

  @override
  String get hintTitle => 'Sabia que?';

  @override
  String get hintDrag =>
      'Para reorganizar a lista, mantenha pressionado o nome do hábito e arraste-o para o lugar certo.';

  @override
  String get hintLandscape =>
      'Pode ver mais dias se utilizar o telemóvel em modo paisagem.';

  @override
  String get habitNotFound => 'Hábito eliminado / não encontrado';

  @override
  String get weekends => 'Fins de Semana';

  @override
  String get anyWeekday => 'Segunda a Sexta';

  @override
  String get anyDay => 'Qualquer dia da semana';

  @override
  String get selectWeekdays => 'Selecionar dias';

  @override
  String get exportToCsv => 'Exportar como CSV';

  @override
  String get doneLabel => 'Concluído';

  @override
  String get clearLabel => 'Limpar';

  @override
  String get selectHours => 'Selecionar horas';

  @override
  String get selectMinutes => 'Selecionar minutos';

  @override
  String get about => 'Sobre';

  @override
  String get translators => 'Tradutores';

  @override
  String get developers => 'Programadores';

  @override
  String versionN(String p1) {
    return 'Versão $p1';
  }

  @override
  String get frequency => 'Frequência';

  @override
  String get checkmark => 'Marca';

  @override
  String get bestStreaks => 'Melhores séries';

  @override
  String get everyDay => 'Todos os dias';

  @override
  String get everyWeek => 'Todas as semanas';

  @override
  String get help => 'Ajuda & FAQ';

  @override
  String get couldNotExport => 'Falha ao exportar dados.';

  @override
  String get couldNotImport => 'Falha ao importar dados.';

  @override
  String get fileNotRecognized => 'Ficheiro não reconhecido.';

  @override
  String get habitsImported => 'Hábitos importados com sucesso.';

  @override
  String get importData => 'Importar dados';

  @override
  String get exportFullBackup => 'Exportar cópia de segurança completa';

  @override
  String get importDataSummary =>
      'Suporta cópias de segurança completas exportadas por esta app, bem como ficheiros gerados pelo Tickmate, HabitBull ou Rewire. Veja as FAQ para mais informações.';

  @override
  String get exportAsCsvSummary =>
      'Gera ficheiros que podem ser abertos por programas de folhas de cálculo, como o Microsoft Excel ou o OpenOffice Calc. Este ficheiro não pode ser importado novamente para a app.';

  @override
  String get exportFullBackupSummary =>
      'Gera um ficheiro que contém todos os dados dos seus hábitos. Este ficheiro pode ser novamente importado para a app.';

  @override
  String get selectPublicBackupFolder =>
      'Selecionar pasta pública de cópia de segurança';

  @override
  String get noPublicBackupFolderSelected => 'Nenhuma pasta selecionada';

  @override
  String get bugReportFailed => 'Falha a gerar relatório de erros.';

  @override
  String get generateBugReport => 'Gerar relatório de erros';

  @override
  String get troubleshooting => 'Resolução de problemas';

  @override
  String get helpTranslate => 'Ajude a traduzir esta aplicação';

  @override
  String get nightMode => 'Modo noturno';

  @override
  String get usePureBlack => 'Usar preto puro no modo noturno';

  @override
  String get pureBlackDescription =>
      'Substitui os fundos cinzentos por pretos puros no modo noturno. Reduz a utilização da bateria em telemóveis com ecrã AMOLED.';

  @override
  String get interfacePreferences => 'Interface';

  @override
  String get reverseDays => 'Inverter a ordem dos dias';

  @override
  String get reverseDaysDescription =>
      'Mostra os dias em ordem inversa na página principal';

  @override
  String get day => 'Dia';

  @override
  String get week => 'Semana';

  @override
  String get month => 'Mês';

  @override
  String get quarter => 'Trimestre';

  @override
  String get year => 'Ano';

  @override
  String get total => 'Total';

  @override
  String get yesOrNo => 'Sim ou Não';

  @override
  String everyXDays(int p1) {
    return 'A cada $p1 dias';
  }

  @override
  String everyXWeeks(int p1) {
    return 'A cada $p1 semanas';
  }

  @override
  String get score => 'Pontuação';

  @override
  String get reminderSound => 'Som do lembrete';

  @override
  String get none => 'Silencioso';

  @override
  String get filter => 'Filtro';

  @override
  String get hideCompleted => 'Ocultar concluídos';

  @override
  String get hideArchived => 'Ocultar arquivado';

  @override
  String get stickyNotifications => 'Tornar as notificações persistentes';

  @override
  String get stickyNotificationsDescription =>
      'Impede que as notificações sejam removidas.';

  @override
  String get ledNotifications => 'Luz de notificação';

  @override
  String get ledNotificationsDescription =>
      'Mostra uma luz piscando para lembretes. Disponível apenas em telefones com luzes de notificação LED.';

  @override
  String get repairDatabase => 'Reparar base de dados';

  @override
  String get databaseRepaired => 'Banco de dados reparado.';

  @override
  String get uncheck => 'Não verificar';

  @override
  String get toggle => 'Alternar';

  @override
  String get action => 'Acção';

  @override
  String get habit => 'Hábit';

  @override
  String get sort => 'Ordenar';

  @override
  String get manually => 'Manualmente';

  @override
  String get byName => 'Por nome';

  @override
  String get byColor => 'Por cor';

  @override
  String get byScore => 'Por pontuação';

  @override
  String get byStatus => 'Por estado';

  @override
  String get export => 'Exportar';

  @override
  String get longPressToEdit => 'Pressione e segure para alterar o valor';

  @override
  String get value => 'Valor';

  @override
  String get calendar => 'Calendário';

  @override
  String get unit => 'Unidade';

  @override
  String get exampleQuestionBoolean => 'ex.: Você se exercitou hoje?';

  @override
  String get question => 'Pergunta';

  @override
  String get target => 'Alvo';

  @override
  String get yes => 'Sim';

  @override
  String get no => 'Não';

  @override
  String get customizeNotificationSummary =>
      'Alterar som, vibração, luz e outras configurações de notificação';

  @override
  String get customizeNotification => 'Personalizar notificações';

  @override
  String get prefViewPrivacy => 'Ver política de privacidade';

  @override
  String get viewAllContributors => 'Ver todos os colaboradores…';

  @override
  String get database => 'Banco de dados';

  @override
  String get widgetOpacityTitle => 'Opacidade do widget';

  @override
  String get widgetOpacityDescription =>
      'Torna os widgets mais transparentes ou mais opacos na sua tela inicial.';

  @override
  String get firstDayOfTheWeek => 'Primeiro dia da semana';

  @override
  String get defaultReminderQuestion => 'Concluiu este hábito hoje?';

  @override
  String get notes => 'Notas';

  @override
  String get exampleNotes => '(Opcional)';

  @override
  String get yesOrNoExample =>
      'ex. Acordou cedo hoje? Fez exercício? Jogou xadrez?';

  @override
  String get measurable => 'Mensurável';

  @override
  String xTimesPerWeek(int p1) {
    return '$p1 vezes por semana';
  }

  @override
  String xTimesPerMonth(int p1) {
    return '$p1 vezes por mês';
  }

  @override
  String xTimesPerYDays(int p1, int p2) {
    return '$p1 vezes em $p2 dias';
  }

  @override
  String get yesOrNoShortExample => 'ex. Exercício';

  @override
  String get color => 'Cor';

  @override
  String get exampleTarget => 'ex. 15';

  @override
  String get measurableShortExample => 'ex. Correr';

  @override
  String get measurableQuestionExample => 'ex. Quantas km você correu hoje?';

  @override
  String get measurableUnitsExample => 'ex. km';

  @override
  String get everyMonth => 'Todos os meses';

  @override
  String get validationCannotBeBlank => 'Não pode ficar em branco';

  @override
  String get today => 'Hoje';

  @override
  String get enter => 'Registar';

  @override
  String get increment => 'Acrescentar';

  @override
  String get decrement => 'Decrementar';

  @override
  String get youAreNowADeveloper => 'Agora é um programador!';

  @override
  String get activityNotFound =>
      'Nenhuma aplicação foi encontrada para oferecer suporte a esta ação';
}
