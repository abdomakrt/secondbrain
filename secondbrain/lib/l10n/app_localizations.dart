import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('ar')];

  /// No description provided for @appTitle.
  ///
  /// In ar, this message translates to:
  /// **'العقل الثاني'**
  String get appTitle;

  /// No description provided for @appTagline.
  ///
  /// In ar, this message translates to:
  /// **'منظّم شخصي للمهام والمشاريع والمعرفة: نفّذ عملك، احفظ ما تتعلمه، واسترجعه بسرعة.'**
  String get appTagline;

  /// No description provided for @dashboardTitle.
  ///
  /// In ar, this message translates to:
  /// **'الرئيسية'**
  String get dashboardTitle;

  /// No description provided for @tasksTitle.
  ///
  /// In ar, this message translates to:
  /// **'المهام'**
  String get tasksTitle;

  /// No description provided for @projectsTitle.
  ///
  /// In ar, this message translates to:
  /// **'المشاريع'**
  String get projectsTitle;

  /// No description provided for @knowledgeTitle.
  ///
  /// In ar, this message translates to:
  /// **'المعرفة'**
  String get knowledgeTitle;

  /// No description provided for @coursesTitle.
  ///
  /// In ar, this message translates to:
  /// **'الكورسات'**
  String get coursesTitle;

  /// No description provided for @inboxTitle.
  ///
  /// In ar, this message translates to:
  /// **'الوارد'**
  String get inboxTitle;

  /// No description provided for @searchTitle.
  ///
  /// In ar, this message translates to:
  /// **'البحث'**
  String get searchTitle;

  /// No description provided for @settingsTitle.
  ///
  /// In ar, this message translates to:
  /// **'الإعدادات'**
  String get settingsTitle;

  /// No description provided for @courses.
  ///
  /// In ar, this message translates to:
  /// **'الكورسات'**
  String get courses;

  /// No description provided for @inbox.
  ///
  /// In ar, this message translates to:
  /// **'الوارد'**
  String get inbox;

  /// No description provided for @settings.
  ///
  /// In ar, this message translates to:
  /// **'الإعدادات'**
  String get settings;

  /// No description provided for @trash.
  ///
  /// In ar, this message translates to:
  /// **'السلة المحذوفات'**
  String get trash;

  /// No description provided for @trashTitle.
  ///
  /// In ar, this message translates to:
  /// **'المحذوفات'**
  String get trashTitle;

  /// No description provided for @taskStatusTodo.
  ///
  /// In ar, this message translates to:
  /// **'لم تبدأ'**
  String get taskStatusTodo;

  /// No description provided for @taskStatusDoing.
  ///
  /// In ar, this message translates to:
  /// **'قيد التنفيذ'**
  String get taskStatusDoing;

  /// No description provided for @taskStatusDone.
  ///
  /// In ar, this message translates to:
  /// **'مكتملة'**
  String get taskStatusDone;

  /// No description provided for @taskStatusCanceled.
  ///
  /// In ar, this message translates to:
  /// **'ملغاة'**
  String get taskStatusCanceled;

  /// No description provided for @completedCourses.
  ///
  /// In ar, this message translates to:
  /// **'مكتملة'**
  String get completedCourses;

  /// No description provided for @lastLesson.
  ///
  /// In ar, this message translates to:
  /// **'آخر درس'**
  String get lastLesson;

  /// No description provided for @nextLesson.
  ///
  /// In ar, this message translates to:
  /// **'الدرس التالي'**
  String get nextLesson;

  /// No description provided for @more.
  ///
  /// In ar, this message translates to:
  /// **'المزيد'**
  String get more;

  /// No description provided for @viewAll.
  ///
  /// In ar, this message translates to:
  /// **'عرض الكل'**
  String get viewAll;

  /// No description provided for @quickAdd.
  ///
  /// In ar, this message translates to:
  /// **'إضافة سريع'**
  String get quickAdd;

  /// No description provided for @close.
  ///
  /// In ar, this message translates to:
  /// **'إغلاق'**
  String get close;

  /// No description provided for @confirm.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد'**
  String get confirm;

  /// No description provided for @retry.
  ///
  /// In ar, this message translates to:
  /// **'إعادة المحاولة'**
  String get retry;

  /// No description provided for @next.
  ///
  /// In ar, this message translates to:
  /// **'التالي'**
  String get next;

  /// No description provided for @saved.
  ///
  /// In ar, this message translates to:
  /// **'تم الحفظ'**
  String get saved;

  /// No description provided for @untitledItem.
  ///
  /// In ar, this message translates to:
  /// **'عنصر بلا عنوان'**
  String get untitledItem;

  /// No description provided for @titleRequired.
  ///
  /// In ar, this message translates to:
  /// **'العنوان مطلوب'**
  String get titleRequired;

  /// No description provided for @newItem.
  ///
  /// In ar, this message translates to:
  /// **'عنصر جديد'**
  String get newItem;

  /// No description provided for @newTask.
  ///
  /// In ar, this message translates to:
  /// **'مهمة جديدة'**
  String get newTask;

  /// No description provided for @newProject.
  ///
  /// In ar, this message translates to:
  /// **'مشروع جديد'**
  String get newProject;

  /// No description provided for @newNote.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظة جديدة'**
  String get newNote;

  /// No description provided for @newIdea.
  ///
  /// In ar, this message translates to:
  /// **'فكرة جديدة'**
  String get newIdea;

  /// No description provided for @newLink.
  ///
  /// In ar, this message translates to:
  /// **'رابط جديد'**
  String get newLink;

  /// No description provided for @newCourse.
  ///
  /// In ar, this message translates to:
  /// **'كورس جديد'**
  String get newCourse;

  /// No description provided for @newSubtaskHint.
  ///
  /// In ar, this message translates to:
  /// **'خطوة فرعية جديدة…'**
  String get newSubtaskHint;

  /// No description provided for @addSubtask.
  ///
  /// In ar, this message translates to:
  /// **'إضافة خطوة فرعية'**
  String get addSubtask;

  /// No description provided for @search.
  ///
  /// In ar, this message translates to:
  /// **'بحث'**
  String get search;

  /// No description provided for @searchHint.
  ///
  /// In ar, this message translates to:
  /// **'ابحث في معرفتك…'**
  String get searchHint;

  /// No description provided for @searchKnowledgeHint.
  ///
  /// In ar, this message translates to:
  /// **'ابحث في المعرفة…'**
  String get searchKnowledgeHint;

  /// No description provided for @searchProjectsHint.
  ///
  /// In ar, this message translates to:
  /// **'ابحث في المشاريع…'**
  String get searchProjectsHint;

  /// No description provided for @searchStartTitle.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ البحث'**
  String get searchStartTitle;

  /// No description provided for @searchStartHint.
  ///
  /// In ar, this message translates to:
  /// **'اكتب كلمة للبحث في المعرفة والمشاريع والمهام والكورسات.'**
  String get searchStartHint;

  /// No description provided for @searchFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر البحث'**
  String get searchFailed;

  /// No description provided for @searchFailedHint.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ أثناء البحث. حاول مرة أخرى.'**
  String get searchFailedHint;

  /// No description provided for @noResultsHint.
  ///
  /// In ar, this message translates to:
  /// **'جرّب كلمات أخرى أو أزل بعض عوامل التصفية.'**
  String get noResultsHint;

  /// No description provided for @newestFirst.
  ///
  /// In ar, this message translates to:
  /// **'الأحدث'**
  String get newestFirst;

  /// No description provided for @today.
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get today;

  /// No description provided for @upcoming.
  ///
  /// In ar, this message translates to:
  /// **'القادمة'**
  String get upcoming;

  /// No description provided for @overdue.
  ///
  /// In ar, this message translates to:
  /// **'المتأخرة'**
  String get overdue;

  /// No description provided for @allTasks.
  ///
  /// In ar, this message translates to:
  /// **'كل المهام'**
  String get allTasks;

  /// No description provided for @all.
  ///
  /// In ar, this message translates to:
  /// **'الكل'**
  String get all;

  /// No description provided for @archived.
  ///
  /// In ar, this message translates to:
  /// **'المؤرشف'**
  String get archived;

  /// No description provided for @emptyTasks.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد مهام'**
  String get emptyTasks;

  /// No description provided for @emptyTasksHint.
  ///
  /// In ar, this message translates to:
  /// **'أنشئ مهمة جديدة أو اسحب مهمة إلى اليوم.'**
  String get emptyTasksHint;

  /// No description provided for @noTasksToday.
  ///
  /// In ar, this message translates to:
  /// **'لا مهام مجدولة اليوم — يوم هادئ.'**
  String get noTasksToday;

  /// No description provided for @noScheduledTasks.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد مهام بوقت بداية محدد.'**
  String get noScheduledTasks;

  /// No description provided for @noTasksInProject.
  ///
  /// In ar, this message translates to:
  /// **'لا مهام في هذا المشروع'**
  String get noTasksInProject;

  /// No description provided for @noTasksInProjectHint.
  ///
  /// In ar, this message translates to:
  /// **'أضف مهمة该项目 لتتبع التقدم.'**
  String get noTasksInProjectHint;

  /// No description provided for @addTaskToProject.
  ///
  /// In ar, this message translates to:
  /// **'إضافة مهمة للمشروع'**
  String get addTaskToProject;

  /// No description provided for @addKnowledgeToProject.
  ///
  /// In ar, this message translates to:
  /// **'إضافة معلومة مرتبطة'**
  String get addKnowledgeToProject;

  /// No description provided for @todaySummary.
  ///
  /// In ar, this message translates to:
  /// **'ملخص اليوم'**
  String get todaySummary;

  /// No description provided for @totalTasks.
  ///
  /// In ar, this message translates to:
  /// **'الإجمالي'**
  String get totalTasks;

  /// No description provided for @completedTasks.
  ///
  /// In ar, this message translates to:
  /// **'المكتمل'**
  String get completedTasks;

  /// No description provided for @remainingTasks.
  ///
  /// In ar, this message translates to:
  /// **'المتبقي'**
  String get remainingTasks;

  /// No description provided for @overdueTasks.
  ///
  /// In ar, this message translates to:
  /// **'المتأخر'**
  String get overdueTasks;

  /// No description provided for @topTasksToday.
  ///
  /// In ar, this message translates to:
  /// **'أهم مهام اليوم'**
  String get topTasksToday;

  /// No description provided for @dayTimeline.
  ///
  /// In ar, this message translates to:
  /// **'الجدول اليومي'**
  String get dayTimeline;

  /// No description provided for @activeProjects.
  ///
  /// In ar, this message translates to:
  /// **'المشاريع النشطة'**
  String get activeProjects;

  /// No description provided for @plannedProjects.
  ///
  /// In ar, this message translates to:
  /// **'مخطط لها'**
  String get plannedProjects;

  /// No description provided for @pausedProjects.
  ///
  /// In ar, this message translates to:
  /// **'متوقفة مؤقتًا'**
  String get pausedProjects;

  /// No description provided for @completedProjects.
  ///
  /// In ar, this message translates to:
  /// **'مكتملة'**
  String get completedProjects;

  /// No description provided for @archivedProjects.
  ///
  /// In ar, this message translates to:
  /// **'مؤرشفة'**
  String get archivedProjects;

  /// No description provided for @currentCourse.
  ///
  /// In ar, this message translates to:
  /// **'الكورس الحالي'**
  String get currentCourse;

  /// No description provided for @recentKnowledge.
  ///
  /// In ar, this message translates to:
  /// **'آخر المعلومات المحفوظة'**
  String get recentKnowledge;

  /// No description provided for @inboxNeedsOrganizing.
  ///
  /// In ar, this message translates to:
  /// **'عناصر الوارد تحتاج تنظيمًا'**
  String get inboxNeedsOrganizing;

  /// No description provided for @noActiveProjects.
  ///
  /// In ar, this message translates to:
  /// **'لا مشاريع نشطة.'**
  String get noActiveProjects;

  /// No description provided for @noActiveCourses.
  ///
  /// In ar, this message translates to:
  /// **'لا كورسات نشطة.'**
  String get noActiveCourses;

  /// No description provided for @emptyProjects.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد مشاريع'**
  String get emptyProjects;

  /// No description provided for @emptyProjectsHint.
  ///
  /// In ar, this message translates to:
  /// **'أنشئ مشروعًا لتتبع مهامك ومعلوماتك.'**
  String get emptyProjectsHint;

  /// No description provided for @emptyCourses.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد كورسات'**
  String get emptyCourses;

  /// No description provided for @emptyCoursesHint.
  ///
  /// In ar, this message translates to:
  /// **'أضف كورسًا لتتبع دروسك وما تعلمته.'**
  String get emptyCoursesHint;

  /// No description provided for @emptyKnowledge.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد معلومات محفوظة'**
  String get emptyKnowledge;

  /// No description provided for @emptyKnowledgeHint.
  ///
  /// In ar, this message translates to:
  /// **'احفظ أول ملاحظة أو فكرة أو رابط.'**
  String get emptyKnowledgeHint;

  /// No description provided for @emptyInbox.
  ///
  /// In ar, this message translates to:
  /// **'الوارد فارغ'**
  String get emptyInbox;

  /// No description provided for @emptyInboxHint.
  ///
  /// In ar, this message translates to:
  /// **'ما تلتقطه من الكمبيوتر أو الهاتف يظهر هنا لتنظيمه لاحقًا.'**
  String get emptyInboxHint;

  /// No description provided for @emptyStateHint.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ بإضافة عنصر.'**
  String get emptyStateHint;

  /// No description provided for @emptyList.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد عناصر بعد'**
  String get emptyList;

  /// No description provided for @greetingMorning.
  ///
  /// In ar, this message translates to:
  /// **'صباح الخير'**
  String get greetingMorning;

  /// No description provided for @greetingAfternoon.
  ///
  /// In ar, this message translates to:
  /// **'طاب يومك'**
  String get greetingAfternoon;

  /// No description provided for @greetingEvening.
  ///
  /// In ar, this message translates to:
  /// **'مساء الخير'**
  String get greetingEvening;

  /// No description provided for @priorityLabel.
  ///
  /// In ar, this message translates to:
  /// **'الأهمية والاستعجال'**
  String get priorityLabel;

  /// No description provided for @priorityImportantUrgent.
  ///
  /// In ar, this message translates to:
  /// **'مهم وعاجل'**
  String get priorityImportantUrgent;

  /// No description provided for @priorityImportantNotUrgent.
  ///
  /// In ar, this message translates to:
  /// **'مهم وغير عاجل'**
  String get priorityImportantNotUrgent;

  /// No description provided for @priorityNotImportantUrgent.
  ///
  /// In ar, this message translates to:
  /// **'غير مهم وعاجل'**
  String get priorityNotImportantUrgent;

  /// No description provided for @priorityNotImportantNotUrgent.
  ///
  /// In ar, this message translates to:
  /// **'غير مهم وغير عاجل'**
  String get priorityNotImportantNotUrgent;

  /// No description provided for @importantOnly.
  ///
  /// In ar, this message translates to:
  /// **'المهمة المهمة فقط'**
  String get importantOnly;

  /// No description provided for @taskDetails.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل المهمة'**
  String get taskDetails;

  /// No description provided for @taskDetailsTitle.
  ///
  /// In ar, this message translates to:
  /// **'المهمة'**
  String get taskDetailsTitle;

  /// No description provided for @dueDate.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ الاستحقاق'**
  String get dueDate;

  /// No description provided for @plannedDay.
  ///
  /// In ar, this message translates to:
  /// **'يوم الجدولة'**
  String get plannedDay;

  /// No description provided for @plannedStart.
  ///
  /// In ar, this message translates to:
  /// **'وقت البداية'**
  String get plannedStart;

  /// No description provided for @estimatedMinutes.
  ///
  /// In ar, this message translates to:
  /// **'المدة التقديرية (دقيقة)'**
  String get estimatedMinutes;

  /// No description provided for @estimatedMinutesHint.
  ///
  /// In ar, this message translates to:
  /// **'مثال: 45'**
  String get estimatedMinutesHint;

  /// No description provided for @notesLabel.
  ///
  /// In ar, this message translates to:
  /// **'الوصف'**
  String get notesLabel;

  /// No description provided for @linkedProject.
  ///
  /// In ar, this message translates to:
  /// **'المشروع المرتبط'**
  String get linkedProject;

  /// No description provided for @noProject.
  ///
  /// In ar, this message translates to:
  /// **'بدون مشروع'**
  String get noProject;

  /// No description provided for @subtasks.
  ///
  /// In ar, this message translates to:
  /// **'خطوات فرعية'**
  String get subtasks;

  /// No description provided for @noSubtasks.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد خطوات فرعية.'**
  String get noSubtasks;

  /// No description provided for @subtaskAdded.
  ///
  /// In ar, this message translates to:
  /// **'أُضيفت الخطوة'**
  String get subtaskAdded;

  /// No description provided for @markDone.
  ///
  /// In ar, this message translates to:
  /// **'إكمال'**
  String get markDone;

  /// No description provided for @markNotDone.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الإكمال'**
  String get markNotDone;

  /// No description provided for @taskCreated.
  ///
  /// In ar, this message translates to:
  /// **'أُنشئت المهمة'**
  String get taskCreated;

  /// No description provided for @postponeToTomorrow.
  ///
  /// In ar, this message translates to:
  /// **'تأجيل إلى الغد'**
  String get postponeToTomorrow;

  /// No description provided for @postponedToTomorrow.
  ///
  /// In ar, this message translates to:
  /// **'أُجّلت المهمة إلى الغد'**
  String get postponedToTomorrow;

  /// No description provided for @postponedTimes.
  ///
  /// In ar, this message translates to:
  /// **'مؤجلة ×{count}'**
  String postponedTimes(int count);

  /// No description provided for @moveTaskToTrashConfirm.
  ///
  /// In ar, this message translates to:
  /// **'ستنتقل المهمة إلى سلة المحذوفات. يمكنك استرجاعها لاحقًا. هل تريد المتابعة؟'**
  String get moveTaskToTrashConfirm;

  /// No description provided for @dueAt.
  ///
  /// In ar, this message translates to:
  /// **'الاستحقاق: {day} • {time}'**
  String dueAt(String day, String time);

  /// No description provided for @projectDetails.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل المشروع'**
  String get projectDetails;

  /// No description provided for @projectNameLabel.
  ///
  /// In ar, this message translates to:
  /// **'اسم المشروع'**
  String get projectNameLabel;

  /// No description provided for @projectGoalLabel.
  ///
  /// In ar, this message translates to:
  /// **'الهدف'**
  String get projectGoalLabel;

  /// No description provided for @projectGoalHint.
  ///
  /// In ar, this message translates to:
  /// **'ما الذي تريد تحقيقه؟'**
  String get projectGoalHint;

  /// No description provided for @descriptionLabel.
  ///
  /// In ar, this message translates to:
  /// **'الوصف'**
  String get descriptionLabel;

  /// No description provided for @status.
  ///
  /// In ar, this message translates to:
  /// **'الحالة'**
  String get status;

  /// No description provided for @statusPlanned.
  ///
  /// In ar, this message translates to:
  /// **'مخطط'**
  String get statusPlanned;

  /// No description provided for @statusActive.
  ///
  /// In ar, this message translates to:
  /// **'نشط'**
  String get statusActive;

  /// No description provided for @statusPaused.
  ///
  /// In ar, this message translates to:
  /// **'متوقف مؤقتًا'**
  String get statusPaused;

  /// No description provided for @statusCompleted.
  ///
  /// In ar, this message translates to:
  /// **'مكتمل'**
  String get statusCompleted;

  /// No description provided for @statusArchived.
  ///
  /// In ar, this message translates to:
  /// **'مؤرشف'**
  String get statusArchived;

  /// No description provided for @statusChanged.
  ///
  /// In ar, this message translates to:
  /// **'تغيّرت الحالة'**
  String get statusChanged;

  /// No description provided for @changeStatus.
  ///
  /// In ar, this message translates to:
  /// **'تغيير الحالة'**
  String get changeStatus;

  /// No description provided for @tasksDoneOf.
  ///
  /// In ar, this message translates to:
  /// **'{done} منجزة • {remaining} متبقية'**
  String tasksDoneOf(int done, int remaining);

  /// No description provided for @percentOfProgress.
  ///
  /// In ar, this message translates to:
  /// **'{percent}%'**
  String percentOfProgress(int percent);

  /// No description provided for @noTasksYet.
  ///
  /// In ar, this message translates to:
  /// **'لا مهام'**
  String get noTasksYet;

  /// No description provided for @lastActivity.
  ///
  /// In ar, this message translates to:
  /// **'آخر نشاط'**
  String get lastActivity;

  /// No description provided for @nextStep.
  ///
  /// In ar, this message translates to:
  /// **'الخطوة التالية'**
  String get nextStep;

  /// No description provided for @lastStop.
  ///
  /// In ar, this message translates to:
  /// **'آخر نقطة توقف'**
  String get lastStop;

  /// No description provided for @stopPointAndNextStep.
  ///
  /// In ar, this message translates to:
  /// **'نقطة التوقف والخطوة التالية'**
  String get stopPointAndNextStep;

  /// No description provided for @openProject.
  ///
  /// In ar, this message translates to:
  /// **'فتح المشروع'**
  String get openProject;

  /// No description provided for @setActiveCaptureProject.
  ///
  /// In ar, this message translates to:
  /// **'تعيين كمشروع الالتقاط النشط'**
  String get setActiveCaptureProject;

  /// No description provided for @captureProjectSet.
  ///
  /// In ar, this message translates to:
  /// **'تم تعيين مشروع الالتقاط النشط'**
  String get captureProjectSet;

  /// No description provided for @captureProjectCleared.
  ///
  /// In ar, this message translates to:
  /// **'أُلغي تعيين مشروع الالتقاط — الوجهة هي الوارد'**
  String get captureProjectCleared;

  /// No description provided for @overview.
  ///
  /// In ar, this message translates to:
  /// **'نظرة عامة'**
  String get overview;

  /// No description provided for @decisions.
  ///
  /// In ar, this message translates to:
  /// **'القرارات'**
  String get decisions;

  /// No description provided for @noDecisions.
  ///
  /// In ar, this message translates to:
  /// **'لا قرارات مسجلة'**
  String get noDecisions;

  /// No description provided for @noDecisionsHint.
  ///
  /// In ar, this message translates to:
  /// **'سجّل القرارات المهمة لهذا المشروع.'**
  String get noDecisionsHint;

  /// No description provided for @filesAndAttachments.
  ///
  /// In ar, this message translates to:
  /// **'الملفات والمرفقات'**
  String get filesAndAttachments;

  /// No description provided for @noAttachments.
  ///
  /// In ar, this message translates to:
  /// **'لا مرفقات'**
  String get noAttachments;

  /// No description provided for @noAttachmentsHint.
  ///
  /// In ar, this message translates to:
  /// **'أضف مرفقات من تفاصيل عنصر المعرفة.'**
  String get noAttachmentsHint;

  /// No description provided for @noKnowledgeInProject.
  ///
  /// In ar, this message translates to:
  /// **'لا معلومات مرتبطة بالمشروع'**
  String get noKnowledgeInProject;

  /// No description provided for @noKnowledgeInProjectHint.
  ///
  /// In ar, this message translates to:
  /// **'اربط ملاحظاتك وقراراتك بالمشروع.'**
  String get noKnowledgeInProjectHint;

  /// No description provided for @activityLogUnavailable.
  ///
  /// In ar, this message translates to:
  /// **'سجل النشاط غير متاح في نموذج البيانات الحالي.'**
  String get activityLogUnavailable;

  /// No description provided for @itemDetails.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل المعرفة'**
  String get itemDetails;

  /// No description provided for @itemOrganized.
  ///
  /// In ar, this message translates to:
  /// **'تم إخراج العنصر من الوارد'**
  String get itemOrganized;

  /// No description provided for @projectLinked.
  ///
  /// In ar, this message translates to:
  /// **'تم ربط العنصر بالمشروع'**
  String get projectLinked;

  /// No description provided for @tagsUpdated.
  ///
  /// In ar, this message translates to:
  /// **'تم تحديث الوسوم'**
  String get tagsUpdated;

  /// No description provided for @typeChanged.
  ///
  /// In ar, this message translates to:
  /// **'تم تغيير النوع'**
  String get typeChanged;

  /// No description provided for @markAsOrganized.
  ///
  /// In ar, this message translates to:
  /// **'تم التنظيم'**
  String get markAsOrganized;

  /// No description provided for @linkToProject.
  ///
  /// In ar, this message translates to:
  /// **'ربط بمشروع'**
  String get linkToProject;

  /// No description provided for @changeType.
  ///
  /// In ar, this message translates to:
  /// **'تغيير النوع'**
  String get changeType;

  /// No description provided for @quickActions.
  ///
  /// In ar, this message translates to:
  /// **'إجراءات سريعة'**
  String get quickActions;

  /// No description provided for @linkedTo.
  ///
  /// In ar, this message translates to:
  /// **'مرتبط بـ'**
  String get linkedTo;

  /// No description provided for @linkedCourse.
  ///
  /// In ar, this message translates to:
  /// **'الكورس'**
  String get linkedCourse;

  /// No description provided for @linkedTask.
  ///
  /// In ar, this message translates to:
  /// **'المهمة'**
  String get linkedTask;

  /// No description provided for @createdAt.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ الإنشاء'**
  String get createdAt;

  /// No description provided for @copy.
  ///
  /// In ar, this message translates to:
  /// **'نسخ'**
  String get copy;

  /// No description provided for @copied.
  ///
  /// In ar, this message translates to:
  /// **'تم النسخ'**
  String get copied;

  /// No description provided for @openSource.
  ///
  /// In ar, this message translates to:
  /// **'فتح المصدر'**
  String get openSource;

  /// No description provided for @sourceTitleLabel.
  ///
  /// In ar, this message translates to:
  /// **'عنوان المصدر'**
  String get sourceTitleLabel;

  /// No description provided for @sourceUrlLabel.
  ///
  /// In ar, this message translates to:
  /// **'رابط المصدر'**
  String get sourceUrlLabel;

  /// No description provided for @sourceAppLabel.
  ///
  /// In ar, this message translates to:
  /// **'التطبيق المصدر'**
  String get sourceAppLabel;

  /// No description provided for @courseDetails.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل الكورس'**
  String get courseDetails;

  /// No description provided for @courseNameLabel.
  ///
  /// In ar, this message translates to:
  /// **'اسم الكورس'**
  String get courseNameLabel;

  /// No description provided for @courseSource.
  ///
  /// In ar, this message translates to:
  /// **'المصدر'**
  String get courseSource;

  /// No description provided for @lessons.
  ///
  /// In ar, this message translates to:
  /// **'الدروس'**
  String get lessons;

  /// No description provided for @lessonsLabel.
  ///
  /// In ar, this message translates to:
  /// **'الدروس'**
  String get lessonsLabel;

  /// No description provided for @lessonsProgress.
  ///
  /// In ar, this message translates to:
  /// **'{done} من {total} دروس'**
  String lessonsProgress(int done, int total);

  /// No description provided for @activeCourses.
  ///
  /// In ar, this message translates to:
  /// **'نشطة'**
  String get activeCourses;

  /// No description provided for @noLessons.
  ///
  /// In ar, this message translates to:
  /// **'لا دروس بعد'**
  String get noLessons;

  /// No description provided for @noLessonsHint.
  ///
  /// In ar, this message translates to:
  /// **'أضف دروس الكورس لتتبع تقدمك.'**
  String get noLessonsHint;

  /// No description provided for @otherLessons.
  ///
  /// In ar, this message translates to:
  /// **'دروس أخرى'**
  String get otherLessons;

  /// No description provided for @continueLearning.
  ///
  /// In ar, this message translates to:
  /// **'تابع التعلم'**
  String get continueLearning;

  /// No description provided for @lessonDetails.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل الدرس'**
  String get lessonDetails;

  /// No description provided for @lessonStatusTodo.
  ///
  /// In ar, this message translates to:
  /// **'لم يبدأ'**
  String get lessonStatusTodo;

  /// No description provided for @lessonStatusInProgress.
  ///
  /// In ar, this message translates to:
  /// **'قيد التنفيذ'**
  String get lessonStatusInProgress;

  /// No description provided for @lessonStatusDone.
  ///
  /// In ar, this message translates to:
  /// **'مكتمل'**
  String get lessonStatusDone;

  /// No description provided for @markLessonDone.
  ///
  /// In ar, this message translates to:
  /// **'تحديد الدرس كمكتمل'**
  String get markLessonDone;

  /// No description provided for @whatILearned.
  ///
  /// In ar, this message translates to:
  /// **'ملخص ما تعلمته'**
  String get whatILearned;

  /// No description provided for @notesAndImportantInfo.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظات ومعلومات مهمة'**
  String get notesAndImportantInfo;

  /// No description provided for @questionsToReview.
  ///
  /// In ar, this message translates to:
  /// **'أسئلة ونقاط للمراجعة'**
  String get questionsToReview;

  /// No description provided for @noSummaryYet.
  ///
  /// In ar, this message translates to:
  /// **'لم تحفظ ملخصًا لهذا الدرس بعد.'**
  String get noSummaryYet;

  /// No description provided for @noNotesYet.
  ///
  /// In ar, this message translates to:
  /// **'لا ملاحظات محفوظة.'**
  String get noNotesYet;

  /// No description provided for @noQuestionsYet.
  ///
  /// In ar, this message translates to:
  /// **'لا أسئلة للمراجعة.'**
  String get noQuestionsYet;

  /// No description provided for @needsReview.
  ///
  /// In ar, this message translates to:
  /// **'بانتظار المراجعة'**
  String get needsReview;

  /// No description provided for @reviewed.
  ///
  /// In ar, this message translates to:
  /// **'تمت المراجعة'**
  String get reviewed;

  /// No description provided for @markReviewed.
  ///
  /// In ar, this message translates to:
  /// **'تعليم كمراجَع'**
  String get markReviewed;

  /// No description provided for @saveNoteFromLesson.
  ///
  /// In ar, this message translates to:
  /// **'احفظ ملاحظة من هذا الدرس'**
  String get saveNoteFromLesson;

  /// No description provided for @createTaskFromLesson.
  ///
  /// In ar, this message translates to:
  /// **'أنشئ مهمة من هذا الدرس'**
  String get createTaskFromLesson;

  /// No description provided for @noKnowledgeInCourse.
  ///
  /// In ar, this message translates to:
  /// **'لا معلومات مرتبطة بالكورس'**
  String get noKnowledgeInCourse;

  /// No description provided for @noKnowledgeInCourseHint.
  ///
  /// In ar, this message translates to:
  /// **'احفظ ملاحظاتك من داخل الدروس.'**
  String get noKnowledgeInCourseHint;

  /// No description provided for @captureTitle.
  ///
  /// In ar, this message translates to:
  /// **'حفظ عنصر جديد'**
  String get captureTitle;

  /// No description provided for @captureProject.
  ///
  /// In ar, this message translates to:
  /// **'المشروع'**
  String get captureProject;

  /// No description provided for @captureContentRequired.
  ///
  /// In ar, this message translates to:
  /// **'اكتب محتوى أولًا.'**
  String get captureContentRequired;

  /// No description provided for @captureSaved.
  ///
  /// In ar, this message translates to:
  /// **'تم الحفظ'**
  String get captureSaved;

  /// No description provided for @captureFailed.
  ///
  /// In ar, this message translates to:
  /// **'فشل الحفظ — لم تُفقد المسودة'**
  String get captureFailed;

  /// No description provided for @captureUnavailable.
  ///
  /// In ar, this message translates to:
  /// **'التقاط المحتوى غير متاح في هذه النسخة'**
  String get captureUnavailable;

  /// No description provided for @captureUnavailableHint.
  ///
  /// In ar, this message translates to:
  /// **'استخدم اللصق اليدوي أو شارك من الهاتف.'**
  String get captureUnavailableHint;

  /// No description provided for @captureWindowHint.
  ///
  /// In ar, this message translates to:
  /// **'نافذة مستقلة لحفظ المحتوى دون مغادرة عملك.'**
  String get captureWindowHint;

  /// No description provided for @openCaptureWindow.
  ///
  /// In ar, this message translates to:
  /// **'فتح نافذة الالتقاط'**
  String get openCaptureWindow;

  /// No description provided for @contentLabel.
  ///
  /// In ar, this message translates to:
  /// **'المحتوى'**
  String get contentLabel;

  /// No description provided for @titleLabelOptional.
  ///
  /// In ar, this message translates to:
  /// **'العنوان (اختياري)'**
  String get titleLabelOptional;

  /// No description provided for @commentLabelOptional.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظتي (اختياري)'**
  String get commentLabelOptional;

  /// No description provided for @sourceDetails.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل المصدر'**
  String get sourceDetails;

  /// No description provided for @clearSource.
  ///
  /// In ar, this message translates to:
  /// **'حذف بيانات المصدر'**
  String get clearSource;

  /// No description provided for @inboxDestination.
  ///
  /// In ar, this message translates to:
  /// **'الوارد (بلا مشروع)'**
  String get inboxDestination;

  /// No description provided for @setupWelcome.
  ///
  /// In ar, this message translates to:
  /// **'الترحيب'**
  String get setupWelcome;

  /// No description provided for @setupData.
  ///
  /// In ar, this message translates to:
  /// **'البيانات'**
  String get setupData;

  /// No description provided for @setupPairing.
  ///
  /// In ar, this message translates to:
  /// **'ربط الأجهزة'**
  String get setupPairing;

  /// No description provided for @setupDataHint.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ من جديد، أو استعد نسخة احتياطية سابقة.'**
  String get setupDataHint;

  /// No description provided for @setupNew.
  ///
  /// In ar, this message translates to:
  /// **'إعداد جديد'**
  String get setupNew;

  /// No description provided for @setupRestore.
  ///
  /// In ar, this message translates to:
  /// **'استعادة نسخة احتياطية'**
  String get setupRestore;

  /// No description provided for @setupPairingHint.
  ///
  /// In ar, this message translates to:
  /// **'اربط هذا الجهاز بالكمبيوتر لمزامنة البيانات بين الأجهزة. يمكنك تخطي هذه الخطوة.'**
  String get setupPairingHint;

  /// No description provided for @setupServerHint.
  ///
  /// In ar, this message translates to:
  /// **'شغّل خادم المزامنة على الكمبيوتر:'**
  String get setupServerHint;

  /// No description provided for @setupQrHint.
  ///
  /// In ar, this message translates to:
  /// **'سيظهر رمز QR على الكمبيوتر لمسحه من الهاتف عند تفعيل الاقتران.'**
  String get setupQrHint;

  /// No description provided for @newSetupReady.
  ///
  /// In ar, this message translates to:
  /// **'تم تجهيز حساب جديد على هذا الجهاز.'**
  String get newSetupReady;

  /// No description provided for @finishSetup.
  ///
  /// In ar, this message translates to:
  /// **'إنهاء الإعداد'**
  String get finishSetup;

  /// No description provided for @pairingCode.
  ///
  /// In ar, this message translates to:
  /// **'رمز الاقتران'**
  String get pairingCode;

  /// No description provided for @testConnection.
  ///
  /// In ar, this message translates to:
  /// **'اختبار الاتصال'**
  String get testConnection;

  /// No description provided for @connectionTestResult.
  ///
  /// In ar, this message translates to:
  /// **'نتيجة اختبار الاتصال'**
  String get connectionTestResult;

  /// No description provided for @connected.
  ///
  /// In ar, this message translates to:
  /// **'تم الاتصال'**
  String get connected;

  /// No description provided for @language.
  ///
  /// In ar, this message translates to:
  /// **'اللغة'**
  String get language;

  /// No description provided for @languageAndAppearance.
  ///
  /// In ar, this message translates to:
  /// **'اللغة والمظهر'**
  String get languageAndAppearance;

  /// No description provided for @arabicOnly.
  ///
  /// In ar, this message translates to:
  /// **'العربية (الافتراضية)'**
  String get arabicOnly;

  /// No description provided for @englishComingSoon.
  ///
  /// In ar, this message translates to:
  /// **'الإنجليزية مهيأة في بنية الترجمة وستُضاف لاحقًا.'**
  String get englishComingSoon;

  /// No description provided for @theme.
  ///
  /// In ar, this message translates to:
  /// **'المظهر'**
  String get theme;

  /// No description provided for @themeSystem.
  ///
  /// In ar, this message translates to:
  /// **'حسب النظام'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In ar, this message translates to:
  /// **'فاتح'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In ar, this message translates to:
  /// **'داكن'**
  String get themeDark;

  /// No description provided for @dashboardCustomization.
  ///
  /// In ar, this message translates to:
  /// **'تخصيص لوحة التحكم'**
  String get dashboardCustomization;

  /// No description provided for @tagsAndTypes.
  ///
  /// In ar, this message translates to:
  /// **'الوسوم وأنواع المحتوى'**
  String get tagsAndTypes;

  /// No description provided for @manageTags.
  ///
  /// In ar, this message translates to:
  /// **'إدارة الوسوم'**
  String get manageTags;

  /// No description provided for @manageTagsHint.
  ///
  /// In ar, this message translates to:
  /// **'أعد تسمية الوسوم أو أزلها.'**
  String get manageTagsHint;

  /// No description provided for @manageTypes.
  ///
  /// In ar, this message translates to:
  /// **'إدارة أنواع المحتوى'**
  String get manageTypes;

  /// No description provided for @manageTypesHint.
  ///
  /// In ar, this message translates to:
  /// **'الأنواع المدمجة الاثنا عشر قابلة للاستخدام كما هي.'**
  String get manageTypesHint;

  /// No description provided for @builtinType.
  ///
  /// In ar, this message translates to:
  /// **'نوع مدمج'**
  String get builtinType;

  /// No description provided for @noTagsYet.
  ///
  /// In ar, this message translates to:
  /// **'لا وسوم بعد.'**
  String get noTagsYet;

  /// No description provided for @taskSettings.
  ///
  /// In ar, this message translates to:
  /// **'إعدادات المهام والتنبيهات'**
  String get taskSettings;

  /// No description provided for @weekStart.
  ///
  /// In ar, this message translates to:
  /// **'بداية الأسبوع'**
  String get weekStart;

  /// No description provided for @weekStartsSaturday.
  ///
  /// In ar, this message translates to:
  /// **'السبت (قابل للتغيير)'**
  String get weekStartsSaturday;

  /// No description provided for @reminders.
  ///
  /// In ar, this message translates to:
  /// **'التذكيرات'**
  String get reminders;

  /// No description provided for @remindersComingSoon.
  ///
  /// In ar, this message translates to:
  /// **'التذكيرات المحلية تأتي في مرحلة لاحقة.'**
  String get remindersComingSoon;

  /// No description provided for @quickCapture.
  ///
  /// In ar, this message translates to:
  /// **'الالتقاط السريع'**
  String get quickCapture;

  /// No description provided for @captureShortcut.
  ///
  /// In ar, this message translates to:
  /// **'اختصار الالتقاط'**
  String get captureShortcut;

  /// No description provided for @captureShortcutHint.
  ///
  /// In ar, this message translates to:
  /// **'الاختصار المقترح: Ctrl + Alt + Shift + C. يجب التحقق من نجاح تسجيله.'**
  String get captureShortcutHint;

  /// No description provided for @shortcutSaved.
  ///
  /// In ar, this message translates to:
  /// **'تم حفظ الاختصار'**
  String get shortcutSaved;

  /// No description provided for @activeCaptureProject.
  ///
  /// In ar, this message translates to:
  /// **'مشروع الالتقاط النشط'**
  String get activeCaptureProject;

  /// No description provided for @inboxIsDefaultDestination.
  ///
  /// In ar, this message translates to:
  /// **'الوارد (الوجهة الافتراضية)'**
  String get inboxIsDefaultDestination;

  /// No description provided for @devicesAndConnection.
  ///
  /// In ar, this message translates to:
  /// **'الأجهزة المقترنة والاتصال'**
  String get devicesAndConnection;

  /// No description provided for @pairedDevices.
  ///
  /// In ar, this message translates to:
  /// **'الأجهزة المقترنة'**
  String get pairedDevices;

  /// No description provided for @noPairedDevices.
  ///
  /// In ar, this message translates to:
  /// **'لا أجهزة مقترنة بعد.'**
  String get noPairedDevices;

  /// No description provided for @serverAddress.
  ///
  /// In ar, this message translates to:
  /// **'عنوان الخادم'**
  String get serverAddress;

  /// No description provided for @notSet.
  ///
  /// In ar, this message translates to:
  /// **'غير محدد'**
  String get notSet;

  /// No description provided for @connectionStatus.
  ///
  /// In ar, this message translates to:
  /// **'حالة الاتصال'**
  String get connectionStatus;

  /// No description provided for @backupAndData.
  ///
  /// In ar, this message translates to:
  /// **'النسخ الاحتياطي والبيانات'**
  String get backupAndData;

  /// No description provided for @about.
  ///
  /// In ar, this message translates to:
  /// **'حول التطبيق'**
  String get about;

  /// No description provided for @versionInfo.
  ///
  /// In ar, this message translates to:
  /// **'الإصدار 1.0.0'**
  String get versionInfo;

  /// No description provided for @keepImport.
  ///
  /// In ar, this message translates to:
  /// **'استيراد Google Keep'**
  String get keepImport;

  /// No description provided for @keepImportDeferred.
  ///
  /// In ar, this message translates to:
  /// **'مؤجَّل إلى الإصدار الثاني'**
  String get keepImportDeferred;

  /// No description provided for @keepImportDeferredHint.
  ///
  /// In ar, this message translates to:
  /// **'محرك الاستيراد سيأتي في الإصدار الثاني. البيانات الأصلية في Takeout لا تُلمس أبدًا، والاستيراد لن يتم إلا بعد المعاينة والتأكيد.'**
  String get keepImportDeferredHint;

  /// No description provided for @keepImportSteps.
  ///
  /// In ar, this message translates to:
  /// **'خطوات الاستيراد'**
  String get keepImportSteps;

  /// No description provided for @keepImportPreserves.
  ///
  /// In ar, this message translates to:
  /// **'ما يمكن الحفاظ عليه'**
  String get keepImportPreserves;

  /// No description provided for @keepImportStepsList.
  ///
  /// In ar, this message translates to:
  /// **'نزّل بيانات Keep من Google Takeout.\nاختر ملف ZIP الذي نزّلته.\nافحص الملفات محتوياتها.\nراجع المعاينة قبل الاستيراد.\nاختر الكل أو تصنيفات/عناصر محددة.\nأكّد الاستيراد.\nاقرأ تقرير النتيجة.'**
  String get keepImportStepsList;

  /// No description provided for @keepImportPreservesList.
  ///
  /// In ar, this message translates to:
  /// **'العنوان والمحتوى\nالتصنيفات كوسوم مع علاقاتها\nالقوائم وعناصرها وحالات إنجازها\nالصور والمرفقات\nتواريخ الإنشاء والتعديل\nالتثبيت والأرشفة\nالألوان والتذكيرات'**
  String get keepImportPreservesList;

  /// No description provided for @chooseKeepArchive.
  ///
  /// In ar, this message translates to:
  /// **'اختر ملف Takeout'**
  String get chooseKeepArchive;

  /// No description provided for @keepArchiveSelected.
  ///
  /// In ar, this message translates to:
  /// **'تم اختيار الملف — ستبدأ المعاينة عند توفر محرك الاستيراد.'**
  String get keepArchiveSelected;

  /// No description provided for @keepImportFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّرت قراءة الملف'**
  String get keepImportFailed;

  /// No description provided for @titleLabel.
  ///
  /// In ar, this message translates to:
  /// **'العنوان'**
  String get titleLabel;

  /// No description provided for @bodyLabel.
  ///
  /// In ar, this message translates to:
  /// **'النص (Markdown)'**
  String get bodyLabel;

  /// No description provided for @commentLabel.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظتي'**
  String get commentLabel;

  /// No description provided for @answerLabel.
  ///
  /// In ar, this message translates to:
  /// **'الجواب'**
  String get answerLabel;

  /// No description provided for @typeLabel.
  ///
  /// In ar, this message translates to:
  /// **'النوع'**
  String get typeLabel;

  /// No description provided for @tagsLabel.
  ///
  /// In ar, this message translates to:
  /// **'الوسوم (مفصولة بفواصل)'**
  String get tagsLabel;

  /// No description provided for @tagsHint.
  ///
  /// In ar, this message translates to:
  /// **'مثال: عمل، قراءة'**
  String get tagsHint;

  /// No description provided for @inboxSwitch.
  ///
  /// In ar, this message translates to:
  /// **'أبقه في الوارد'**
  String get inboxSwitch;

  /// No description provided for @addTag.
  ///
  /// In ar, this message translates to:
  /// **'إضافة وسم'**
  String get addTag;

  /// No description provided for @relatedItems.
  ///
  /// In ar, this message translates to:
  /// **'العناصر المرتبطة'**
  String get relatedItems;

  /// No description provided for @linkExisting.
  ///
  /// In ar, this message translates to:
  /// **'ربط عنصر موجود'**
  String get linkExisting;

  /// No description provided for @unlink.
  ///
  /// In ar, this message translates to:
  /// **'فصل الربط'**
  String get unlink;

  /// No description provided for @pickItem.
  ///
  /// In ar, this message translates to:
  /// **'اختر عنصرًا للربط'**
  String get pickItem;

  /// No description provided for @noRelated.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد عناصر مرتبطة'**
  String get noRelated;

  /// No description provided for @attachments.
  ///
  /// In ar, this message translates to:
  /// **'المرفقات'**
  String get attachments;

  /// No description provided for @addAttachment.
  ///
  /// In ar, this message translates to:
  /// **'إضافة مرفق'**
  String get addAttachment;

  /// No description provided for @attachmentTooBig.
  ///
  /// In ar, this message translates to:
  /// **'حجم المرفق يتجاوز الحد الأقصى (50MB)'**
  String get attachmentTooBig;

  /// No description provided for @fileNotFound.
  ///
  /// In ar, this message translates to:
  /// **'الملف غير موجود'**
  String get fileNotFound;

  /// No description provided for @noResults.
  ///
  /// In ar, this message translates to:
  /// **'لا نتائج مطابقة'**
  String get noResults;

  /// No description provided for @emptyTrash.
  ///
  /// In ar, this message translates to:
  /// **'السلة فارغة'**
  String get emptyTrash;

  /// No description provided for @filterType.
  ///
  /// In ar, this message translates to:
  /// **'النوع'**
  String get filterType;

  /// No description provided for @filterTag.
  ///
  /// In ar, this message translates to:
  /// **'الوسم'**
  String get filterTag;

  /// No description provided for @filterProject.
  ///
  /// In ar, this message translates to:
  /// **'المشروع'**
  String get filterProject;

  /// No description provided for @filterStatus.
  ///
  /// In ar, this message translates to:
  /// **'الحالة'**
  String get filterStatus;

  /// No description provided for @filterFrom.
  ///
  /// In ar, this message translates to:
  /// **'من تاريخ'**
  String get filterFrom;

  /// No description provided for @filterTo.
  ///
  /// In ar, this message translates to:
  /// **'إلى تاريخ'**
  String get filterTo;

  /// No description provided for @clearFilters.
  ///
  /// In ar, this message translates to:
  /// **'مسح التصفية'**
  String get clearFilters;

  /// No description provided for @filters.
  ///
  /// In ar, this message translates to:
  /// **'التصفية'**
  String get filters;

  /// No description provided for @sourceLabel.
  ///
  /// In ar, this message translates to:
  /// **'المصدر'**
  String get sourceLabel;

  /// No description provided for @back.
  ///
  /// In ar, this message translates to:
  /// **'رجوع'**
  String get back;

  /// No description provided for @dateFrom.
  ///
  /// In ar, this message translates to:
  /// **'من تاريخ'**
  String get dateFrom;

  /// No description provided for @dateTo.
  ///
  /// In ar, this message translates to:
  /// **'إلى تاريخ'**
  String get dateTo;

  /// No description provided for @lastUpdated.
  ///
  /// In ar, this message translates to:
  /// **'آخر تحديث'**
  String get lastUpdated;

  /// No description provided for @open.
  ///
  /// In ar, this message translates to:
  /// **'فتح'**
  String get open;

  /// No description provided for @backupTitle.
  ///
  /// In ar, this message translates to:
  /// **'النسخ الاحتياطي'**
  String get backupTitle;

  /// No description provided for @createBackup.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء نسخة احتياطية'**
  String get createBackup;

  /// No description provided for @chooseBackupFolder.
  ///
  /// In ar, this message translates to:
  /// **'اختيار مجلد النسخ'**
  String get chooseBackupFolder;

  /// No description provided for @backupDone.
  ///
  /// In ar, this message translates to:
  /// **'تم إنشاء النسخة في:'**
  String get backupDone;

  /// No description provided for @backupFailed.
  ///
  /// In ar, this message translates to:
  /// **'فشل إنشاء النسخة الاحتياطية'**
  String get backupFailed;

  /// No description provided for @verifyBackup.
  ///
  /// In ar, this message translates to:
  /// **'التحقق من النسخة'**
  String get verifyBackup;

  /// No description provided for @pickBackupFile.
  ///
  /// In ar, this message translates to:
  /// **'اختر ملف النسخة'**
  String get pickBackupFile;

  /// No description provided for @restoreBackup.
  ///
  /// In ar, this message translates to:
  /// **'استعادة نسخة'**
  String get restoreBackup;

  /// No description provided for @restoreConfirmTitle.
  ///
  /// In ar, this message translates to:
  /// **'استعادة نسخة احتياطية؟'**
  String get restoreConfirmTitle;

  /// No description provided for @restoreConfirmBody.
  ///
  /// In ar, this message translates to:
  /// **'سيُستبدل الوضع الحالي بالكامل بمحتوى النسخة. تُؤخذ نسخة أمان تلقائيًا قبل الاستعادة. هل تريد المتابعة؟'**
  String get restoreConfirmBody;

  /// No description provided for @restoreDone.
  ///
  /// In ar, this message translates to:
  /// **'تمت الاستعادة بنجاح'**
  String get restoreDone;

  /// No description provided for @restoreFailed.
  ///
  /// In ar, this message translates to:
  /// **'فشلت الاستعادة'**
  String get restoreFailed;

  /// No description provided for @exportMd.
  ///
  /// In ar, this message translates to:
  /// **'تصدير Markdown'**
  String get exportMd;

  /// No description provided for @exportDone.
  ///
  /// In ar, this message translates to:
  /// **'تم التصدير إلى:'**
  String get exportDone;

  /// No description provided for @exportFailed.
  ///
  /// In ar, this message translates to:
  /// **'فشل التصدير'**
  String get exportFailed;

  /// No description provided for @autoDailyBackup.
  ///
  /// In ar, this message translates to:
  /// **'نسخ تلقائي يومي'**
  String get autoDailyBackup;

  /// No description provided for @backupIntegrity.
  ///
  /// In ar, this message translates to:
  /// **'سلامة القاعدة'**
  String get backupIntegrity;

  /// No description provided for @backupCounts.
  ///
  /// In ar, this message translates to:
  /// **'العدّادات'**
  String get backupCounts;

  /// No description provided for @missingBlobs.
  ///
  /// In ar, this message translates to:
  /// **'مرفقات ناقصة'**
  String get missingBlobs;

  /// No description provided for @corruptBlobs.
  ///
  /// In ar, this message translates to:
  /// **'مرفقات تالفة'**
  String get corruptBlobs;

  /// No description provided for @noMissingBlobs.
  ///
  /// In ar, this message translates to:
  /// **'لا مرفقات ناقصة'**
  String get noMissingBlobs;

  /// No description provided for @noCorruptBlobs.
  ///
  /// In ar, this message translates to:
  /// **'لا مرفقات تالفة'**
  String get noCorruptBlobs;

  /// No description provided for @verifyOk.
  ///
  /// In ar, this message translates to:
  /// **'النسخة سليمة'**
  String get verifyOk;

  /// No description provided for @backupFolderNotSet.
  ///
  /// In ar, this message translates to:
  /// **'لم يُحدَّد مجلد النسخ بعد'**
  String get backupFolderNotSet;

  /// No description provided for @restore.
  ///
  /// In ar, this message translates to:
  /// **'استرجاع'**
  String get restore;

  /// No description provided for @restoreVersion.
  ///
  /// In ar, this message translates to:
  /// **'استعادة هذه النسخة'**
  String get restoreVersion;

  /// No description provided for @versions.
  ///
  /// In ar, this message translates to:
  /// **'النسخ السابقة'**
  String get versions;

  /// No description provided for @noVersions.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد نسخ سابقة'**
  String get noVersions;

  /// No description provided for @edit.
  ///
  /// In ar, this message translates to:
  /// **'تعديل'**
  String get edit;

  /// No description provided for @save.
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get cancel;

  /// No description provided for @moveToTrash.
  ///
  /// In ar, this message translates to:
  /// **'نقل إلى السلة'**
  String get moveToTrash;

  /// No description provided for @pin.
  ///
  /// In ar, this message translates to:
  /// **'تثبيت'**
  String get pin;

  /// No description provided for @unpin.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء التثبيت'**
  String get unpin;

  /// No description provided for @archive.
  ///
  /// In ar, this message translates to:
  /// **'أرشفة'**
  String get archive;

  /// No description provided for @unarchive.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الأرشفة'**
  String get unarchive;

  /// No description provided for @preview.
  ///
  /// In ar, this message translates to:
  /// **'معاينة'**
  String get preview;

  /// No description provided for @write.
  ///
  /// In ar, this message translates to:
  /// **'تحرير'**
  String get write;

  /// No description provided for @errorTitle.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ'**
  String get errorTitle;

  /// No description provided for @captureNotAvailable.
  ///
  /// In ar, this message translates to:
  /// **'الالتقاط السريع غير متاح على هذه المنصة.'**
  String get captureNotAvailable;

  /// No description provided for @shortcutRegistered.
  ///
  /// In ar, this message translates to:
  /// **'تم تسجيل الاختصار بنجاح — اضغطه في أي تطبيق.'**
  String get shortcutRegistered;

  /// No description provided for @shortcutFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تسجيل الاختصار — جرّب اختصارًا آخر.'**
  String get shortcutFailed;

  /// No description provided for @desktopEnvironment.
  ///
  /// In ar, this message translates to:
  /// **'بيئة سطح المكتب'**
  String get desktopEnvironment;

  /// No description provided for @desktopEnvironmentUnknown.
  ///
  /// In ar, this message translates to:
  /// **'غير معروفة'**
  String get desktopEnvironmentUnknown;

  /// No description provided for @session.
  ///
  /// In ar, this message translates to:
  /// **'الجلسة'**
  String get session;

  /// No description provided for @display.
  ///
  /// In ar, this message translates to:
  /// **'العرض'**
  String get display;

  /// No description provided for @errorBody.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ غير متوقع. سُجّل التفصيل في ملف السجل. يمكنك متابعة استخدام التطبيق.'**
  String get errorBody;

  /// No description provided for @addSearchTextAsTodayNote.
  ///
  /// In ar, this message translates to:
  /// **'أضف النص كملاحظة اليوم'**
  String get addSearchTextAsTodayNote;

  /// No description provided for @addedToTodayNotes.
  ///
  /// In ar, this message translates to:
  /// **'أُضيفت إلى ملاحظات اليوم'**
  String get addedToTodayNotes;

  /// No description provided for @todayNoteTag.
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get todayNoteTag;

  /// No description provided for @newCapture.
  ///
  /// In ar, this message translates to:
  /// **'التقاط جديد'**
  String get newCapture;

  /// No description provided for @saveFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر الحفظ'**
  String get saveFailed;

  /// No description provided for @todayNote.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظة اليوم'**
  String get todayNote;

  /// No description provided for @syncNotEnabledYet.
  ///
  /// In ar, this message translates to:
  /// **'المزامنة بين الأجهزة غير مفعّلة في هذه النسخة — البيانات محلية على هذا الجهاز.'**
  String get syncNotEnabledYet;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
